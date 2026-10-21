# π by Machin's formula

A program that calculates π to thousands of digits, reconstructed from one
written years ago in BASIC on a Camputers Lynx, then moved step by step into
6809 machine code. The method stays the same throughout; each version moves
one more piece of the work out of BASIC so its effect can be timed on its own.

[`Pi_6809_Progression.pdf`](Pi_6809_Progression.pdf) explains the method, each
change and the timings, and has every listing in its appendices.

## The method

π/4 = 4·arctan(1/5) − arctan(1/239), with each arctangent summed as a series.
Numbers are held one decimal digit per byte in paged RAM. Each new power
term is the previous one divided by the small integer x² (25 or 57121), so
only short division, addition and subtraction are needed. Leading zeros are
skipped, 1/239 is tiled from its 7-digit repeating pattern (0041841), and six
guard digits absorb the truncation errors.

## Files

| Version | Files | What runs where | 100 digits | 1,000 digits |
|---|---|---|---|---|
| 1 | `PI_V1.bas` | Everything in TSC Extended BASIC | 12:02 | ≈ 17.4 h (est.) |
| 2 | `PI_V2.bas`, `PIDIV_V2.asm` | BASIC + machine-code divide | 4:36 | ≈ 7.4 h (est.) |
| 3 | `PI_V3.bas`, `PIMATH_V3.asm` | BASIC + machine-code divide and add/subtract | 0:25 | 7:45 |
| 4 | `PI_V4.bas`, `PIMATH_V4.asm` | BASIC + fast 16-bit divide path | ≈ 0:25 (est.) | 6:00 |
| 5 | `PI.asm`, `PI.CMD` | Native FLEX command, all machine code | ≈ 0:02 (est.) | 2:20 |
| 5a | `PI.asm`, `PI.CMD` | As 5, dividing by 25 as ×4 and a two-digit shift | ≈ 0:01 (est.) | 1:58 (3:56 on a 1 MHz board) |

Times are on the 2 MHz board. Estimates come from emulator statement and
cycle counts at 610 BASIC statements per second and 2 million cycles per
second, which matched every measured run to within a few percent.

Versions 2 to 4 load their machine code from DATA lines (with a checksum)
and call it through XBASIC's `USR` function, so the `.asm` files are there
for reference and for rebuilding the DATA lines. The parameter block is at
`$C100` in FLEX's utility area, and the USR vector at `$BFFD` assumes
MEMEND = `$BFFF`.

Version 5a is the current `PI.asm` and `PI.CMD`. The PDF describes
version 5, before this change.

## Dividing by 25 as a multiply by 4

Because the digits are held in decimal, P/25 can be worked out as 4P/100:
multiply every digit by 4 (with carry), then move the result two places
along, which is all that dividing by 100 means in decimal. The answer is
exactly the same, digit for digit, as dividing by 25, but a multiply by 4
is two shifts and a table look-up instead of a trial division. In `PI.asm`
the routine `DIV25` does this, taking 67 cycles per digit against 212 for
the divide. Only the 1/5 series benefits (1/57121 has no such shortcut), so
the whole program is about 19% faster.

The BASIC versions still use the divide, since they are there to show the
method step by step. To try the idea in `PI_V1.bas`, replace the call that
forms the next power term (lines 7170–7200) with a loop over the digits
from N−1 down to F that multiplies each one by 4, adds the carry, keeps the
units digit, carries the tens, and writes the digit two places further on
(index I+2, dropping anything past N−1). The final carry goes to digit
F+1 and digit F becomes 0. F1, the first non-zero digit, is then F+1 or F+2.

## Running PI.CMD

Copy `PI.CMD` to a FLEX disk, then:

```
+++PI 1000
```

or just `PI` to be asked. It accepts 1 to 65,529 digits, loads at `$0100`,
and returns to FLEX when it finishes. To rebuild it:

```
a09 -FPI.CMD PI.asm
```

## For comparison: the same method on a Mac

[`mac/PiMac.swift`](mac/PiMac.swift) is a small SwiftUI app that runs exactly
the same algorithm as `PI.CMD`: one decimal digit per byte, short division,
the leading-zero skip, the 1/239 pattern and six guard digits. It shows the
digits in a window and can save them to a text file.

It is deliberately not tuned for the Mac. It uses one thread, no SIMD, no
multi-digit words and no faster formula. So the comparison measures the
hardware running the 6809's algorithm, not how fast a Mac can compute π.
Specialised programs using many digits per word and FFT multiplication
reach 100,000 digits in milliseconds.

| Digits | PI.CMD, 6809 at 2 MHz | PiMac, Apple Silicon Mac | Ratio |
|---|---|---|---|
| 1,000 | 2:20 (measured) | ≈ 5 ms (scaled from below) | ≈ 29,000× |
| 100,000 | ≈ 16 days (est.; beyond PI.CMD's 65,529-digit limit) | 48 s (measured) | ≈ 29,000× |
| 1,000,000 | ≈ 4½ years (est.) | 3.5 h (measured) | ≈ 11,000× |

Up to 100,000 digits the ratio stays the same, because the work grows with
the square of the digit count on both machines. At a million digits the Mac
took about 2½ times longer than that scaling predicts. The likely causes are
the 1 MB digit buffers no longer fitting in the fastest caches, and macOS
moving a long job in a background window onto its slower efficiency cores.
Which of these mattered hasn't been checked. The 6809 has no such effects,
since every byte of its memory takes the same time to reach.

Build and run it with the Xcode command-line tools, no project needed:

```
swiftc -O -parse-as-library PiMac.swift -o PiMac
./PiMac
```

## Paged memory

All versions use the board's 4 KB paging window. Two things matter:

- **The window is at `$E000`–`$EFFF`**, selected by writing a block number
  (0–127) to `$F280`. Block 14 is the RAM normally there, which the monitor
  selects at reset. After the ROM-to-RAM copy that block holds the monitor and
  parts of the FLEX BIOS, so it must be mapped back in before any call to FLEX,
  and before PRINT or INPUT in BASIC.
- **`$F280` must only ever be written.** The 74HC373 latch also clocks on a
  read, so a read loads whatever is on the data bus and the window jumps to a
  random block. The monitor's memory-examine command hangs on `$F280` for this
  reason. Keep a copy of the current block in a variable instead of reading it.

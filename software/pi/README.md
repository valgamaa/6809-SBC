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

Times are on the 2 MHz board. Estimates come from emulator statement and
cycle counts at 610 BASIC statements per second and 2 million cycles per
second, which matched every measured run to within a few percent.

Versions 2 to 4 load their machine code from DATA lines (with a checksum)
and call it through XBASIC's `USR` function, so the `.asm` files are there
for reference and for rebuilding the DATA lines. The parameter block is at
`$C100` in FLEX's utility area, and the USR vector at `$BFFD` assumes
MEMEND = `$BFFF`.

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

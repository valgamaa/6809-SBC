# 6809 SBC software

Firmware, drivers and test programs for a self-built 6809 single-board
computer that runs **FLEX 9** from a CompactFlash card.

The board: 6809 CPU, 1 MHz bus from a 4 MHz crystal, MC68681 DUART for the
console, CompactFlash in 16-bit True IDE mode (low byte only), Epson
RTC-72421/72423 real-time clock, and an MC6859 data-security device. The
monitor is a modified **Assist09**; at reset it copies itself from ROM to RAM,
then starts Microsoft Extended BASIC if you have added it to the ROM (see
[docs/basic-port.md](docs/basic-port.md)), or the monitor if not.

The host-side tools for building these programs and for making and sending
FLEX disk images are in the companion project,
[A09Studio](https://github.com/valgamaa/A09Studio).

## What is here

| Folder | Contents |
|---|---|
| `monitor/` | `Assist09-Flex.asm` — the modified Assist09 monitor: boots FLEX, reads the RTC and sets FLEX's date, adds the `F`, `X`, `U` and `K` commands, and starts BASIC at reset when it is in the ROM |
| `rtc/` | RTC support: `Assist09_Flex_RTC.asm` (date sync and 1-minute interrupt, called from the monitor), `Flex_DatePatch.asm` (stops FLEX asking for the date), `RTC_Set.asm` (the clock-setting program run by `K`), `TIME.asm` / `TIME.CMD` (a FLEX command that prints the RTC time and date), and RTC test programs |
| `flex-bios/` | `Flex_BIOS.asm` — FLEX's disk and console drivers for the CF card and serial port; `Flex_BIOS_DiskLoader.asm` — receives a FLEX disk image over serial and writes it to the card; `inch_outch_test.asm` — console I/O test |
| `cf-tools/` | `FlexFormat.asm` — formats a FLEX disk on the CF card; `CF_Test_4.asm` — CF card exerciser |
| `rom-images/` | The ROM image (v7, without BASIC) as `.bin` and `.hex`, the previous v6 image, and `FLEX-core.hex` — the FLEX part of the image, used to rebuild it |
| `des/` | `DESFILE` — encrypts and decrypts FLEX text files with the MC6859 DES chip, as a TSC XBASIC program and as a native FLEX command — see [des/README.md](des/README.md) |
| `pi/` | π by Machin's formula, in five versions from pure TSC XBASIC to a native FLEX command (`PI.CMD`), with a [PDF](pi/Pi_6809_Progression.pdf) explaining each step and its timing — see [pi/README.md](pi/README.md) |
| `docs/` | `monitor-commands.md` / [PDF](docs/monitor-commands.pdf) (the added commands), `basic-port.md` (adding Microsoft Extended BASIC to the ROM), `xbasic-patching.md`, and a spreadsheet of the added commands |

Each source file has a header comment saying what it does and where it lives
in memory. The `.hex` / `.s19` files are assembler output kept for convenience.

## Hardware addresses

| Address | Device |
|---|---|
| `$F000`–`$F7FF` | I/O space (decoded as a 2K block) |
| `$F230` | Epson RTC |
| `$F278` | MC6859 (responds in the top 8 bytes of its decode window) |
| `$F2C0`, `$F300` | CompactFlash register blocks |
| `$F340` | MC68681 DUART, port A (console) |
| `$F280` | 4K page register, write only (a read latches the data bus); block 14 at reset |
| `$E000`–`$EFFF` | 4K paging window onto any of the 128 RAM blocks |
| `$9C00`–`$BFFF` | Microsoft Extended BASIC, if added to the ROM (not included; see [docs/basic-port.md](docs/basic-port.md)) |
| `$FFF0` | Monitor entry vector (the 6809's unused reserved vector), used by BASIC's `MONITOR` and `FLEX` commands |

Software entry points and load addresses (for example `Flex_BIOS` at `$F800`
with its disk vector table at `$DE00`, the RTC sync routine at `$FB00`, and the
disk loader at `$EE00`) are given in each source file's header comment.

## Building

The sources assemble with the `a09` assembler. For example:

```
a09 -xFlex_BIOS.hex -lFlex_BIOS.lst Flex_BIOS.asm
```

`-x` writes Intel hex, `-s` S-records, `-b` raw binary and `-l` a listing.
A09Studio wraps the same assembler with an editor and a terminal, and drives
a TL866 programmer to burn the ROM.

## Building and burning the ROM image

The ROM image is 32 KB and sits at `$8000`-`$FFFF` in the board's memory map,
so the chip's own addresses are the board's minus `$8000`. The image
(`rom-images/Monolithic-Flex-Assist09-BIOS-Format-Loader_v7`) is made from
eight Intel hex files that never overlap:

| File | Contents | Address |
|---|---|---|
| `monitor/Assist09-Flex.hex` | the modified Assist09 monitor | `$E000`-`$FFFF` |
| `rtc/Assist09_Flex_RTC.hex` | RTC date sync and 1-minute interrupt | `$FB00`-`$FD10` |
| `flex-bios/Flex_BIOS.hex` | FLEX disk and console drivers | `$D3E5`-`$FA85` |
| `flex-bios/Flex_BIOS_DiskLoader.hex` | serial-to-CF disk loader (`U`) | `$EE00`-`$EEBE` |
| `cf-tools/FlexFormat.hex` | CF formatter (`X`) | `$E900`-`$EDB8` |
| `rtc/Flex_DatePatch.hex` | stops FLEX asking for the date | `$CA50`-`$CA55` |
| `rtc/RTC_Set.hex` | the clock-setting program run by `K` | `$C000`-`$C558` |
| `rom-images/FLEX-core.hex` | the FLEX 9.1 code and tables the pieces above don't replace | `$C559`-`$FFEF`, in several ranges |

At reset the monitor copies the ROM to RAM, which is why the code runs at
these addresses.

**1. Assemble** whichever source file you changed (in A09Studio, or with
`a09 -x<name>.hex <name>.asm`). The other `.hex` files are already in the
repository.

**2. Merge and burn** in A09Studio's **TL866 Programmer** form:

1. Choose the programmer and type the chip into **Chip**. The board uses a 28C256 (32 KB EEPROM); pick the entry for your manufacturer's part from the list.
2. Set **PROM Base 0x** to `8000`. This is subtracted from every file's addresses so they land at the start of the chip.
3. Click **Add Files…** and add the eight `.hex` files above. Leave each file's **Base** at `0000`.
4. Click **Write**, then **Verify**.

With more than one file, or a non-zero base, A09Studio merges the files with
`srec_cat` (`brew install srecord`) before sending them to `minipro`
(`brew install minipro`). Unused addresses are left at `$FF`. If you change a
file so that it overlaps another, the merge will fail rather than silently
overwrite.

The merged result matches the v7 image in `rom-images/` byte for byte.

To include Microsoft Extended BASIC, add the BASIC hex file you have built as
a ninth file (`$9C00`-`$BFF3`). It is not part of this repository; see
[docs/basic-port.md](docs/basic-port.md) for how to make it from Grant
Searle's source. Without it, the board starts in the monitor as before.

The v6 image is kept for reference. Its monitor always starts in Assist09 and
has no `$FFF0` entry vector.

## Bring-up order

1. Burn the ROM image (`rom-images/`) and check the monitor prompt on the serial console. If you added BASIC, you get the BASIC banner instead; type `MONITOR` to reach the monitor.
2. Format the CF card with the monitor's `X` command, or send a whole disk image to it with `U` and the Disk Image tool in A09Studio.
3. Use `K` to set the clock, then boot FLEX with `F`. The monitor sets FLEX's date from the RTC.

The monitor's added commands (`F`, `X`, `U`, `K`) are described in
[docs/monitor-commands.md](docs/monitor-commands.md).

## Using Microsoft Extended BASIC

With BASIC in the ROM, the board starts in BASIC. `MONITOR` enters Assist09
(`G 9C00` goes back with the program intact) and `FLEX` boots FLEX the way the
monitor's `F` command does. See [docs/basic-port.md](docs/basic-port.md).

## Using TSC Extended BASIC

TSC XBASIC needs a few per-system patches before it runs on this board. See
[docs/xbasic-patching.md](docs/xbasic-patching.md). The program itself is not
included here.

## Licence

The code in this repository is released under the [MIT licence](../LICENSE).
Parts of it derive from third-party software; see [NOTICE.md](../NOTICE.md).
FLEX and TSC programs are not included and belong to their owners.

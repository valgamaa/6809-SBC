# 6809 SBC software

Firmware, drivers and test programs for a self-built 6809 single-board
computer that runs **FLEX 9** from a CompactFlash card.

The board: 6809 CPU, 1 MHz bus from a 4 MHz crystal, MC68681 DUART for the
console, CompactFlash in 16-bit True IDE mode (low byte only), Epson
RTC-72421/72423 real-time clock, and an MC6859 data-security device. The
monitor is a modified **Assist09**; at reset it copies itself from ROM to RAM.

The host-side tools for building these programs and for making and sending
FLEX disk images are in the companion project,
[A09Studio](https://github.com/valgamaa/A09Studio).

## What is here

| Folder | Contents |
|---|---|
| `monitor/` | `Assist09-Flex.asm` — the modified Assist09 monitor: boots FLEX, reads the RTC and sets FLEX's date, and adds the `F`, `X`, `U` and `K` commands |
| `rtc/` | RTC support: `Assist09_Flex_RTC.asm` (date sync and 1-minute interrupt, called from the monitor), `Flex_DatePatch.asm` (stops FLEX asking for the date), `RTC_Set.asm` (the clock-setting program run by `K`), and RTC test programs |
| `flex-bios/` | `Flex_BIOS.asm` — FLEX's disk and console drivers for the CF card and serial port; `Flex_BIOS_DiskLoader.asm` — receives a FLEX disk image over serial and writes it to the card; `inch_outch_test.asm` — console I/O test |
| `cf-tools/` | `FlexFormat.asm` — formats a FLEX disk on the CF card; `CF_Test_4.asm` — CF card exerciser |
| `rom-images/` | The programmed ROM image (v6) as `.bin` and `.hex` |
| `docs/` | `monitor-commands.md` / [PDF](docs/monitor-commands.pdf) (the added commands), `xbasic-patching.md`, and a spreadsheet of the added commands |

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

> TODO: add step-by-step instructions for assembling the pieces into the
> combined ROM image and burning it.

## Bring-up order

1. Burn the ROM image (`rom-images/`) and check the monitor prompt on the serial console.
2. Format the CF card with the monitor's `X` command, or send a whole disk image to it with `U` and the Disk Image tool in A09Studio.
3. Use `K` to set the clock, then boot FLEX with `F`. The monitor sets FLEX's date from the RTC.

The monitor's added commands (`F`, `X`, `U`, `K`) are described in
[docs/monitor-commands.md](docs/monitor-commands.md).

## Using TSC Extended BASIC

TSC XBASIC needs a few per-system patches before it runs on this board. See
[docs/xbasic-patching.md](docs/xbasic-patching.md). The program itself is not
included here.

## Licence

The code in this repository is released under the [MIT licence](../LICENSE).
Parts of it derive from third-party software; see [NOTICE.md](../NOTICE.md).
FLEX and TSC programs are not included and belong to their owners.

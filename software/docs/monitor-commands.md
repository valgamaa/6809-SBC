# Added monitor commands

The monitor is Assist09 with four commands added. All of them use letters
that stock Assist09 does not use (it already uses B, C, D, E, G, L, M, N, O,
P, R, S, T, V and W). The ROM image is
`rom-images/Monolithic-Flex-Assist09-BIOS-Format-Loader_v6`.

| Command | Name | Runs at | Source |
|---|---|---|---|
| `F` | Boot FLEX | `$CD00` | `monitor/Assist09-Flex.asm`, `rtc/Assist09_Flex_RTC.asm`, `rtc/Flex_DatePatch.asm` |
| `X` | Format | `$E900` | `cf-tools/FlexFormat.asm` |
| `U` | Upload | `$EE00` | `flex-bios/Flex_BIOS_DiskLoader.asm` |
| `K` | Clock | `$C000` | `rtc/RTC_Set.asm` |

## `F` — boot FLEX

Starts FLEX, with the date taken from the real-time clock.

1. Reads the RTC and prints it as `DD/MM/YY HH:MM:SS`. If the clock is unset
   or holds an impossible date, it prints a message instead.
2. Writes the date into FLEX's date bytes (`$CC0E`–`$CC10`).
3. Arms the RTC's 1-minute interrupt, so the date stays current without
   anyone typing `DATE`.
4. Waits for the console to finish printing, then starts FLEX.

FLEX skips its "date?" prompt when the date has been set. If the clock can't
be read, FLEX starts with whatever date it already had and the interrupt
stays off. Use `K` to set the clock.

## `X` — format

Starts the disk formatter, which formats the CF card for FLEX. It writes a
new, empty FLEX disk: the System Information Record, an empty directory, and
a free-space chain over the rest of the card. **This erases the disk.**

## `U` — upload

Starts the disk loader. Once it is running, send a disk image from the host
over the serial link and it is written to the CF card, sector by sector. In
A09Studio use the **Disk Image…** tool (or **Send to CF…** from the Disk
Builder or DSK Browser). This overwrites the target drive.

## `K` — clock

Starts the clock program, for setting the time and date from scratch or for
checking a new board. **Starting it stops and resets the clock.** At its
prompt:

| Key | Action |
|---|---|
| `S` | Set the time |
| `E` | Set the date (`DD MM YY`) |
| `I` | Toggle the 1-minute interrupt |
| `Q` | Quit back to the monitor |

After setting the clock, use `F` to boot FLEX with the new date.

## Notes

- The formatter, loader and clock program sit in ROM above or away from user
  RAM, so `$0000`–`$BFFF` stays free. The clock program at `$C000` is
  restored from the ROM image on every reset.
- The monitor masks the RTC interrupt at reset, so a cold power-up can't fire
  it before `F` has installed the handler.

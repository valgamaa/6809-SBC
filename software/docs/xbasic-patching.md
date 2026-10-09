# Patching TSC Extended BASIC (6809) for this board

TSC XBASIC reads the console directly and exits through a fixed address, so
it has to be patched for each system. The manual describes the patch points
(see the XBASIC manual, pages 82–83). On this board the console is not a
simple ACIA at one address, so input goes through the `Flex_BIOS` routines.

XBASIC is not distributed here. Take your own copy of `XBASIC.CMD` and apply
these changes to the loaded program.

## The patches

Addresses are the load addresses in the program image. XBASIC loads from
`$0000`, and the file may contain an early record that is overwritten by a
later one at the same address; patch the bytes that end up in memory.

| Address | Original | Patched | Purpose |
|---|---|---|---|
| `$0008` | `14` | `1A` | Exit jumps to the monitor (`MONITR`, `$F81A`) instead of `$F814` |
| `$0022`–`$0023` | `A6 01` | `8D E8` | Console character read becomes `BSR $000C`, which jumps to FLEX `GETCHR` (`$CD15`) |
| `$01C5`–`$01CA` | `A6 D9 xx xx 84 01` | `BD F8 50 12 12 12` | Console status test becomes `JSR $F850` (`STAT`), then three `NOP`s |
| `$0220`–`$0225` | `A6 D9 xx xx 84 01` | `BD F8 50 12 12 12` | The same change at the second status test |

The two bytes shown as `xx xx` in the status-test patches depend on the
build of XBASIC: they were `04 92`, `04 93` or `03 F7` in the builds tried.
Search for the pattern `A6 D9 xx xx 84 01` rather than relying on the
address alone. Each build had exactly two matches.

## Notes

- The ACIA pointer at `$004D`–`$004E` is left unchanged.
- XBASIC loads to roughly `$48B7`–`$4930`, depending on the build.
- Test a patched copy by entering `10 PRINT "HELLO"`, then `LIST` and `RUN`,
  followed by a loop with decimal arithmetic and a `SAVE` and `LOAD`.

# Third-party notices

## Assist09

`monitor/Assist09-Flex.asm` is a modified version of **Assist09**, the 6809
monitor written by Motorola. Check Motorola's distribution terms for the
original before reusing this file. The MIT licence in this repository covers
only the changes made for this board (the FLEX boot command, RTC handling,
the `K` command and the I/O changes), not the original monitor code.

## FLEX and TSC software

FLEX, TSC Extended BASIC (`XBASIC`) and other TSC utilities are not part of
this repository and are not covered by its licence. The files here that work
with FLEX (`Flex_BIOS`, `FlexFormat` and others) are original code written to
fit FLEX's published interfaces.

## Tools

The programs are assembled with `a09` (L.C. Benschop, H. Seib), licensed
under the GNU General Public License version 2. It is not included here; its
source is in A09Studio's `a09Tool/` folder.

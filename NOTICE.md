# Third-party notices

## Assist09

`monitor/Assist09-Flex.asm` is a modified version of **Assist09**, the 6809
monitor written by Motorola. Motorola published Assist09 openly, with its
source, to encourage people to build systems around the 6809, and it has
been freely circulated ever since. I have not found a formal licence text
for it. The original code remains Motorola's work; the MIT licence in this
repository covers only the changes made for this board (the FLEX boot
command, RTC handling, the `K` command, the I/O changes, and the reset check
for BASIC with its `$FFF0` entry point). If you hold
better information about its terms, please open an issue.

## FLEX and TSC software

The ROM image in `software/rom-images/` includes the FLEX 9.1 operating
system code (`FLEX-core.hex`). Dave Shirk, the TSC copyright holder, has given
permission for FLEX to be used freely, including commercially, on the one
condition that he is told of, or sent a copy of, anything done with it
(see the [FLEX User Group page](http://www.flexusergroup.com/flexusergroup/fug7.htm)).
That permission is for FLEX itself; it is not a public-domain dedication and
it does not change the MIT licence on the rest of this repository.
TSC Extended BASIC (`XBASIC`) and other TSC utilities are
not part of this repository and are not covered by its licence. The files here
that work with FLEX (`Flex_BIOS`, `FlexFormat` and others) are original code
written to fit FLEX's published interfaces.

## Microsoft Extended BASIC

Microsoft's 6809 Extended BASIC is not included in this repository or in its
ROM images. `software/docs/basic-port.md` describes changes to Grant Searle's
port of it, which he derived from the *Color BASIC Unravelled II* and
*Extended BASIC Unravelled II* listings; his source is available from his own
site. The BASIC code remains Microsoft's. The parts covered by this
repository's licence are the monitor support for it (`BOOT` and `MONENT`) and
`software/basic/BasicSBC.asm`, which is original code that BASIC includes:
the `MONITOR` and `FLEX` commands, `MEM`, and the disk commands. It refers to
BASIC's routines by their labels but contains none of Microsoft's code.

## Tools

The programs are assembled with `a09` (L.C. Benschop, H. Seib), licensed
under the GNU General Public License version 2. It is not included here; its
source is in A09Studio's `a09Tool/` folder.

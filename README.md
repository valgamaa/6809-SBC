# 6809 SBC

A self-built 6809 single-board computer that runs **FLEX 9** from a
CompactFlash card: schematics and boards, the firmware and drivers that run
on it, and the host-side tools used with it.

## Contents

| Folder | Contents |
|---|---|
| [`hardware/`](hardware/) | Schematics and board files (current version: V6) |
| [`software/`](software/) | Monitor, FLEX BIOS and disk drivers, RTC support, CF tools and the ROM image — see [software/README.md](software/README.md) |
| [`tools/octave/`](tools/octave/) | Octave scripts for FLEX disk images and S-record handling |

The companion Mac application [A09Studio](https://github.com/valgamaa/A09Studio)
assembles the code, programs the ROM, sends FLEX disk images to the CF card,
and browses and builds FLEX disks.

## Licence

The code in this repository is released under the [MIT licence](LICENSE).
Parts derive from third-party software; see [NOTICE.md](NOTICE.md). FLEX and
TSC programs are not included and belong to their owners.

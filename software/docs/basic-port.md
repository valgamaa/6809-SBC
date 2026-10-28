# Microsoft Extended BASIC in ROM

The monitor can start Microsoft 6809 Extended BASIC straight from reset.
BASIC gets two commands to leave it, `MONITOR` and `FLEX`, and five disk
commands that use FLEX disks on the CF cards: `CAT`, `CATW`, `LOAD`, `SAVE`
and `DELETE`.

BASIC itself is **not included in this repository**: it is Microsoft's code,
and no licence allows it to be republished here. This page describes how to
build it from Grant Searle's port and add it to the ROM yourself. The board's
additions, [`basic/BasicSBC.asm`](../basic/BasicSBC.asm), are original code
and are included; Grant's file pulls them in with one `INCLUDE` line.

Without BASIC the ROM behaves exactly as before: reset starts Assist09.

## Where to get it

Grant Searle ported Color BASIC and Extended BASIC from the *Color BASIC
Unravelled II* and *Extended BASIC Unravelled II* listings to a simple serial
6809 computer. His source, `ExBasRom.asm`, is in the zip on his
[6809 page](http://searle.x10host.com/6809/Simple6809.html)
([direct link](http://searle.x10host.com/6809/ExBasRom.zip)). The changes below
are to that file (the version dated 14 August 2013).

## How it fits the board

| Address | Use |
|---|---|
| `$0000`–`$0216` | BASIC's variables, line buffer and stack |
| `$0217`–`$8FFE` | your program, its variables and strings (about 36 KB) |
| `$9000`–`$9849` | `BasicSBC.asm`: the commands and their variables |
| `$984A`–`$9B49` | three 256-byte sector buffers (RAM only, not in the ROM image) |
| `$9C00`–`$BFF0` | BASIC (`$9C00` is its entry point, a `JMP`) |

The ROM image has nothing else in `$8000`–`$BFFF`, so BASIC goes in as one
more hex file. The monitor copies it to RAM at reset with the rest of the ROM.

- **Reset.** The monitor's `BOOT` routine copies the ROM to RAM and sets up the
  68681. If the byte at `$9C00` is `$7E` (`JMP`), it starts BASIC; otherwise it
  starts Assist09. A power-up is a cold start; after a reset BASIC warm-starts
  and keeps the program in memory.
- **`MONITOR`** enters Assist09. `G 9C00` returns to BASIC with the program
  still there.
- **`FLEX`** does what the monitor's `F` command does: sets FLEX's date from the
  RTC, arms the 1-minute interrupt and starts FLEX. FLEX's `MON` command still
  returns to Assist09. FLEX uses the memory BASIC was in, so from FLEX the way
  back to BASIC is a reset.
- Both commands leave BASIC through the vector at `$FFF0` (the 6809's unused
  reserved vector), which points at `MONENT` in the monitor. `A`=0 enters
  Assist09 and `A`=`'F'` boots FLEX. `MONENT` rebuilds the monitor's work page
  first, because a large BASIC program can overwrite it.
- BASIC uses the monitor's work page at `$7000`–`$70FF` for program space. A
  program that has grown that far may be damaged by a reset, since the monitor
  rebuilds its work page before BASIC warm-starts.
- **Disks** are reached through the FLEX BIOS jump table at `$DE00`. The FLEX
  image, BIOS included, is in RAM after every reset, so the disk commands work
  without FLEX having been booted.

## The disk commands

| Command | What it does |
|---|---|
| `CAT` *[drive]* | Lists the directory: each file's name, size in sectors and date (DD/MM/YY), then the free space. `Ctrl-S` pauses, `Ctrl-C` stops. |
| `CATW` *[drive]* | Lists just the names, five to a line. |
| `LOAD "`*spec*`"` | Replaces the program with the file. |
| `LOAD` | Reloads the current file. |
| `SAVE "`*spec*`"` | Writes the program to a new file. If the file exists it is left alone and you get `?AE ERROR`. |
| `SAVE` | Rewrites the current file: the one last loaded or saved. |
| `DELETE "`*spec*`"` | Deletes the file. (`DEL` still deletes program lines, as before.) |

A *spec* is `[drive.]NAME[.EXT]`, as in FLEX: drive 0–3 (default 0), a name of
1–8 letters, digits, `-` or `_` starting with a letter, and an extension of
1–3 such characters (default `BAS`). Lower case is accepted and stored as
upper case. The spec can be any string expression, so `SAVE N$` works. *drive*
for `CAT` and `CATW` is a number, default 0.

Programs are stored as FLEX text files, one line per program line, ending in
a carriage return, exactly as `LIST` shows them. FLEX's own tools can read and
print them, and a file made elsewhere can be loaded: `LOAD` expands FLEX's
space compression, ignores line feeds and other control characters, and
accepts a last line with no carriage return.

- A line in the file without a line number is run as a direct command while
  the file loads, as if typed.
- `Ctrl-C` stops a load. An error part way through (for example in such a
  direct line) also stops it. Either way the program is left as far as it
  got, and the file is no longer the current file.
- The current file is forgotten by `NEW`, by a reset, by `DELETE`ing it and by a
  load that doesn't finish, so a plain `SAVE` can't write the wrong program
  over a file.
- `SAVE` typed as a command ends its line, as `LIST` does: anything after it
  on the same line (`SAVE "X":PRINT "DONE"`) is not run. In a program it
  carries on to the next statement.
- New files are dated from the RTC. If the clock can't be read they have no
  date, which `CAT` shows as a blank.
- Writes are ordered so that an interrupted `SAVE` or `DELETE` can lose free
  sectors but never damage another file. A `SAVE` that runs out of space
  (`?DF ERROR`) changes nothing on the disk, and a plain `SAVE` that doesn't
  fit keeps the old file.

| Error | Meaning |
|---|---|
| `?NE` | File not found |
| `?AE` | File already exists (`SAVE "`*spec*`"`) |
| `?DF` | Disk full, or no room in the directory |
| `?FN` | Bad file name, or no current file for a plain `SAVE`/`LOAD` |
| `?IO` | Not a FLEX disk, or no card in that slot |

## Building

1. Copy `ExBasRom.asm` from Grant's zip to a new name, for example
   `ExBasROM_SBC.asm`, and make the changes below.
2. Assemble it with `a09`:

   ```
   a09 -xExBasROM_SBC.hex -lExBasROM_SBC.lst ExBasROM_SBC.asm
   ```

   The hex file should cover `$9000`–`$9849` and `$9C00`–`$BFF0`, and
   nothing else.
3. Add it as a ninth file in A09Studio's TL866 form, alongside the eight in
   the [README](../README.md#building-and-burning-the-rom-image), and write the
   chip.

The `INCLUDE` line (change 8) must be able to find `BasicSBC.asm`. `a09` opens
the name relative to the folder it runs in. A09Studio assembles a copy of the
source in a temporary folder, so there give the full path, for example
`INCLUDE "/Users/you/6809-SBC/software/basic/BasicSBC.asm"`.

### Checking the build

In the listing's symbol table, these values must come out as shown. If any
token is wrong, the precedence change (change 4) has been missed somewhere.

| Symbol | Value |
|---|---|
| `TOK_REM` | `$82` |
| `TOK_ELSE` | `$84` |
| `TOK_PRINT` | `$87` |
| `TOK_INPUT` | `$89` |
| `TOK_HIGH_EXEC` | `$9E` |
| `NUM_SEC_FNS` | `$1D` (29) |
| `TOK_MONITOR`, `TOK_FLEX` | `$B2`, `$B3` |
| `TOK_CATW`, `TOK_CAT`, `TOK_LOAD`, `TOK_SAVE` | `$B4`–`$B7` |
| `DSKBEG`, `XCMD` | `$9000` |
| `BASEND` | `$BFF1` (BASIC must end below `$C000`, where the clock program starts) |

## The changes

Each change gives the original lines and what replaces them. Line numbers are
for Grant's file and shift as you edit, so search for the text. Comments on
the new lines are optional.

### 1. Console on the 68681 (top of the file)

Grant's port drives a 6850 ACIA at `$A000`. The board's console is port A of
the 68681 at `$F340`: status register at `+1`, receive and transmit buffers at
`+3`. `OPT TSC` makes `a09` treat the text after an operand as a comment, as
Grant's assembler (AS9) does; without it, comments such as `*PV ...` are read
as part of the operand.

Replace

```
UART      EQU  $A000
RECEV     EQU  UART+1
TRANS     EQU  UART+1
USTAT     EQU  UART
UCTRL     EQU  UART
```

with

```
          OPT  TSC
DUART     EQU  $F340          MC68681 PORT A (CONSOLE)
UART      EQU  DUART
RECEV     EQU  UART+3         RHRA
TRANS     EQU  UART+3         THRA
USTAT     EQU  UART+1         SRA
```

In `KEYIN`, add two `NOP`s after `BEQ  NOCHAR` (before `LDA  RECEV`), the same
bus-recovery delay the monitor's `CIDTA` uses before reading the receive
buffer:

```
          NOP
          NOP
```

In `WRWAIT`, the 68681's transmitter-ready bit is bit 2, not bit 1. Change
`BITA #2` to `BITA #4`.

Delete the two lines that initialise the ACIA (the monitor has already set up
the 68681, and `$F341` is its clock-select register):

```
          LDA  #RTS_LOW       DIV16 CLOCK -> 7372800 / 4 / 16 = 115200
          STA  UCTRL
```

### 2. Code at `$9C00`, with a fixed entry point

Replace `          ORG  $DB00` with

```
          ORG  $9C00
BASBEG    JMP  RESVEC         FIXED ENTRY POINT FOR MONITOR
```

The `JMP` is also what the monitor checks for at reset.

### 3. Memory size and page zero

The cold start probes upward for the end of RAM. On this board it would find
RAM all the way through BASIC itself and into the I/O space at `$F000`.
Replace the eight lines of the probe loop, from `LA084` to `BRA  LA084` (keep
the `LA093` line after it), with

```
          LDX  #DSKBEG-2      TOP OF RAM: TWO BELOW BASICSBC.ASM, AS THE PROBE LEFT IT
```

The probe stops two bytes below the first address that isn't RAM, and the
string space relies on that margin: with the top set to `DSKBEG` itself, the
first string stored overwrites the first instruction of `BasicSBC.asm`.

In the page-zero variables, `GETNCH` to `JMP BROMHK` is written as code, which
makes `a09` emit hex records at `$007C` and breaks the ROM merge. BASIC copies
these 12 bytes in from `LA10D` at cold start anyway, so reserve them instead.
Replace the eight lines from `GETNCH` to `JMP  BROMHK` with

```
GETNCH    RMB  6              INC <CHARAD+1 / BNE GETCCH / INC <CHARAD
GETCCH    RMB  1              LDA EXTENDED OPCODE ($B6)
CHARAD    RMB  2              ADDRESS OF CURRENT BASIC CHARACTER
          RMB  3              JMP BROMHK
```

### 4. Operator precedence

AS9 evaluates expressions strictly left to right; `a09` applies normal
precedence. Seventeen expressions rely on left-to-right evaluation, and if
they are left alone every token number is wrong and every line gives
`?SN ERROR`. Add brackets to each:

| Line | Change to |
|---|---|
| `TOK_USR`, `TOK_LEFT`, `TOK_MID`, `TOK_INKEY` | `EQU  (*-FUNC_TAB)/2+$7F` |
| `TOK_FF_USR` | `EQU  (*-FUNC_TAB)/2+$FF7F` |
| `NUM_SEC_FNS` | `EQU  (*-FUNC_TAB)/2` |
| `TOK_REM`, `TOK_SNGL_Q`, `TOK_ELSE`, `TOK_IF`, `TOK_DATA`, `TOK_PRINT`, `TOK_INPUT`, `TOK_HIGH_EXEC` | `EQU  (*-CMD_TAB)/2+$7F` |
| `CMPB #NUM_SEC_FNS-1*2` | `CMPB #(NUM_SEC_FNS-1)*2` |
| `CMPB #TOK_LEFT-$80*2` | `CMPB #(TOK_LEFT-$80)*2` |
| `CMPB #TOK_INKEY-$80*2` | `CMPB #(TOK_INKEY-$80)*2` |

With these brackets, `OPT TSC` and change 7 (which `a09` rejects as written),
`a09` assembles Grant's original file to the same bytes as his own hex file,
apart from the two bytes change 7 corrects.

### 5. Interrupts stay masked

The main loop enables IRQ and FIRQ for the Color Computer's 60 Hz timer, which
this board doesn't have. An interrupt would go through the monitor's vector
table, which BASIC may have overwritten. Replace

```
LAD9E     ANDCC #$AF           ENABLE IRQ,FIRQ
```

with

```
LAD9E     EQU  *              (ANDCC #$AF REMOVED - LEAVE IRQ/FIRQ MASKED)
```

### 6. The new keywords

Six keywords go at the end of the keyword table, as tokens `$B2`–`$B7`, so no
existing token changes. The tokeniser takes the first keyword that matches,
which is why `CATW` comes before `CAT` (the other way round, `CATW` would be
read as `CAT` followed by `W`), and why `DELETE` is not a keyword of its own:
`DEL` is earlier in the table, so `DELETE` is always stored as `DEL` followed
by the letters `ETE`, and change 10 catches it there. Change the keyword count
from 50 to 56:

```
COMVEC    FCB  56             56 BASIC COMMANDS
```

After the `USING` entry (the line `TOK_USING EQU  $B1`), add

```
          FCC  "MONITO"       B2
          FCB  $80+'R'
TOK_MONITOR EQU  $B2
          FCC  "FLE"          B3
          FCB  $80+'X'
TOK_FLEX  EQU  $B3
          FCC  "CAT"          B4
          FCB  $80+'W'
TOK_CATW  EQU  $B4
          FCC  "CA"           B5
          FCB  $80+'T'
TOK_CAT   EQU  $B5
          FCC  "LOA"          B6
          FCB  $80+'D'
TOK_LOAD  EQU  $B6
          FCC  "SAV"          B7
          FCB  $80+'E'
TOK_SAVE  EQU  $B7
```

In the command dispatcher (just after `CMPA #TOK_HIGH_EXEC`), send anything
above the last standard command to `XCMD` in `BasicSBC.asm` instead of straight
to a syntax error. Replace `          BHI  LADB1` with

```
          LBHI XCMD           NOT A STANDARD COMMAND - BASICSBC.ASM
```

### 7. PRINT USING `$`

A typo in the original makes PRINT USING's `$` test compare against memory
location `$00`. Change `CMPA $'$'` to `CMPA #'$'`.

### 8. End of the file

BASIC must not set the hardware vectors; the monitor owns them. Replace the
vector table at the end, from `ORG  $FFF0` to `LBFFE`, with

```
BASEND    EQU  *
          INCLUDE "BasicSBC.asm"
          END
```

using the path to `BasicSBC.asm` that `a09` will find (see
[Building](#building)).

### 9. MEM

`MEM` converts the free byte count as a signed 16-bit number, which never
mattered on a Color Computer with at most 32 KB free; here it prints a
negative number. `BasicSBC.asm` has a replacement that uses the unsigned
conversion BASIC uses for line numbers, so delete Microsoft's three lines:

```
MEM       TFR  S,D            PUT STACK POINTER INTO ACCD
          SUBD ARYEND         SUBTRACT END OF ARRAYS
          FCB  SKP1           SKIP ONE BYTE
```

Leave the `LB4F3` line that follows; other code still uses it. `VARPTR` has
the same quirk for variables above `$7FFF`, which is harmless because `PEEK`
and `POKE` accept the negative form, so it is left alone.

### 10. Hooks for the disk commands

Four error messages go after the last one in the table (`L890D  FCC "NE"`),
as errors 27–30:

```
LERRAE    FCC  "AE"           27 FILE ALREADY EXISTS
LERRDF    FCC  "DF"           28 DISK FULL
LERRFN    FCC  "FN"           29 BAD FILE NAME
LERRIO    FCC  "IO"           30 NOT A FLEX DISK (OR NO DISK)
```

`LOAD` feeds the file to BASIC's main loop a line at a time, as if typed, so
Microsoft's own code stores the lines. In the main loop, replace
`LAC7C     JSR  LA390` with

```
LAC7C     JSR  DSKLIN         GET AN INPUT LINE (FROM THE FILE DURING A LOAD)
```

An error must stop a load. At the start of the error handler, replace
`LAC46     JSR  LAD33` with

```
LAC46     JSR  DSKERR         STOP ANY LOAD IN PROGRESS
          JSR  LAD33          RESET STACK, STRING STACK, CONTINUE POINTER
```

`DELETE` is stored as `DEL` followed by `ETE` (see change 6). At the start of
the `DEL` command, replace `DEL       LBEQ LB44A` with

```
DEL       JSR  DSKDEL         DELETE "FILE"? (KEEPS A AND CC IF NOT)
          LBEQ LB44A          FC ERROR IF NO ARGUMENT
```

`DSKDEL` carries out `DELETE` and returns straight to the interpreter; for a
plain `DEL` it returns with A and the flags unchanged, and `DEL` carries on as
before. A `DELETE` typed with a space (`DEL ETE`) is not caught, and gives the
error `DEL` would.

`NEW` forgets the current file. Replace `NEW       BNE  LAD14` with

```
NEW       JSR  DSKNEW         FORGET THE CURRENT FILE (KEEPS CC)
          BNE  LAD14          BRANCH IF ARGUMENT GIVEN
```

## Testing

After burning, check in this order:

1. Power up: the BASIC banner and `OK`. `PRINT 2+2` gives `4`, and `PRINT MEM`
   gives about `36000`, not a negative number.
2. `10 PRINT "HELLO"`, `20 A$="X"+"Y"`, then `RUN` and `LIST`.
3. `MONITOR` gives the Assist09 prompt; `G 9C00` returns to BASIC and `LIST`
   still shows the program. (Line 20 checks change 3: with the top of RAM set
   wrongly, the string overwrites BASIC's entry point and this crashes.)
4. Press reset: BASIC warm-starts and the program is still there.
5. `CAT` lists drive 0. `SAVE "HELLO"`, then `CAT` again shows `HELLO.BAS`
   with today's date.
6. `NEW`, `LOAD "HELLO"`, `LIST`. Add a line, `SAVE` with no name, and
   `LOAD "HELLO"` again to see the new line.
7. `SAVE "HELLO"` gives `?AE ERROR`; `DELETE "HELLO"` and `CATW` show it gone.
   `DEL 10` still deletes line 10 of a program.
8. `FLEX` prints the date and time and starts FLEX; FLEX's `CAT` lists the
   files BASIC wrote, and `MON` returns to Assist09.
9. `PRINT USING "$$##.##";12.5` checks change 7.

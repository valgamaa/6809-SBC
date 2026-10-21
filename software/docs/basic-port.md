# Microsoft Extended BASIC in ROM

The monitor can start Microsoft 6809 Extended BASIC straight from reset, and
BASIC has two extra commands, `MONITOR` and `FLEX`, to leave it. BASIC itself
is **not included in this repository**: it is Microsoft's code, and no licence
allows it to be republished here. This page describes how to build it from
Grant Searle's port and add it to the ROM yourself.

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
| `$0217`–`$9BFF` | your program, its variables and strings (about 39 KB) |
| `$9C00`–`$BFEA` | BASIC (`$9C00` is its entry point, a `JMP`) |

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
  returns to Assist09.
- Both commands leave BASIC through the vector at `$FFF0` (the 6809's unused
  reserved vector), which points at `MONENT` in the monitor. `A`=0 enters
  Assist09 and `A`=`'F'` boots FLEX. `MONENT` rebuilds the monitor's work page
  first, because a large BASIC program can overwrite it.
- BASIC uses the monitor's work page at `$7000`–`$70FF` for program space. A
  program that has grown that far may be damaged by a reset, since the monitor
  rebuilds its work page before BASIC warm-starts.

## Building

1. Copy `ExBasRom.asm` from Grant's zip to a new name, for example
   `ExBasROM_SBC.asm`, and make the changes below.
2. Assemble it with `a09`:

   ```
   a09 -xExBasROM_SBC.hex -lExBasROM_SBC.lst ExBasROM_SBC.asm
   ```

   The hex file should cover `$9C00`–`$BFEA` and nothing else.
3. Add it as a ninth file in A09Studio's TL866 form, alongside the eight in
   the [README](../README.md#building-and-burning-the-rom-image), and write the
   chip.

### Checking the build

In the listing's symbol table, these values must come out as shown. If they
don't, the precedence change (change 4) has been missed somewhere.

| Symbol | Value |
|---|---|
| `TOK_REM` | `$82` |
| `TOK_ELSE` | `$84` |
| `TOK_PRINT` | `$87` |
| `TOK_INPUT` | `$89` |
| `TOK_HIGH_EXEC` | `$9E` |
| `NUM_SEC_FNS` | `$1D` (29) |
| `TOK_MONITOR` | `$B2` |
| `TOK_FLEX` | `$B3` |

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
          LDX  #BASBEG        TOP OF RAM = START OF BASIC CODE
```

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

### 6. `MONITOR` and `FLEX` commands

The two keywords go at the end of the keyword table, as tokens `$B2` and
`$B3`, so no existing token changes. Change the keyword count from 50 to 52:

```
COMVEC    FCB  52             52 BASIC COMMANDS (50 + MONITOR, FLEX)
```

After the `USING` entry (the line `TOK_USING EQU  $B1`), add

```
          FCC  "MONITO"       B2
          FCB  $80+'R'
TOK_MONITOR EQU  $B2
          FCC  "FLE"          B3
          FCB  $80+'X'
TOK_FLEX  EQU  $B3
```

In the command dispatcher (just after `CMPA #TOK_HIGH_EXEC`), send anything
above the last standard command to the new code instead of straight to a
syntax error. Replace `          BHI  LADB1` with

```
          LBHI XCMD           NOT A STANDARD COMMAND - CHECK MONITOR/FLEX
```

The new code goes at the end of the file (change 8).

### 7. PRINT USING `$`

A typo in the original makes PRINT USING's `$` test compare against memory
location `$00`. Change `CMPA $'$'` to `CMPA #'$'`.

### 8. End of the file

BASIC must not set the hardware vectors; the monitor owns them. Replace the
vector table at the end, from `ORG  $FFF0` to `LBFFE`, with

```
XCMD      CMPA #TOK_MONITOR   MONITOR TOKEN?
          BEQ  MONCMD         YES
          CMPA #TOK_FLEX      FLEX TOKEN?
          BEQ  FLXCMD         YES
          JMP  LADB1          ANYTHING ELSE - SYNTAX ERROR
MONCMD    CLRA                ENTER ASSIST09
          FCB  SKP2           SKIP THE NEXT TWO BYTES
FLXCMD    LDA  #'F            BOOT FLEX
          ORCC #$50           MASK INTERRUPTS
          JMP  [$FFF0]        MONENT
BASEND    EQU  *
          END
```

## Testing

After burning, check in this order:

1. Power up: the BASIC banner and `OK`. `PRINT 2+2` gives `4`.
2. `10 PRINT "HELLO"` then `LIST`.
3. `MONITOR` gives the Assist09 prompt; `G 9C00` returns to BASIC and `LIST`
   still shows line 10.
4. Press reset: BASIC warm-starts and line 10 is still there.
5. `FLEX` prints the date and time and starts FLEX; `MON` in FLEX returns to
   Assist09.
6. `PRINT USING "$$##.##";12.5` checks change 7.

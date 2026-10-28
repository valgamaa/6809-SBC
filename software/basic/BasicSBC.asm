**************************************************************
* BASICSBC.ASM - 6809 SBC additions to Microsoft Extended BASIC
*
* Copyright (c) 2026 Phil Macphail. Released under the MIT licence
* (see LICENSE at the top of this repository).
*
* Everything added to the ROM BASIC described in docs/basic-port.md
* that is not a small change to Microsoft's own code:
*
*   MONITOR            enter Assist09
*   FLEX               boot FLEX, as the monitor's F command does
*   MEM                free memory, as an unsigned number
*   CAT [drive]        list the directory: name, size, date
*   CATW [drive]       list just the names, five to a line
*   LOAD "spec"        replace the program with a file from disk
*   SAVE "spec"        write the program to a new file
*   SAVE               rewrite the file last loaded or saved
*   DELETE "spec"      delete a file
*
* A spec is [drive.]NAME[.EXT], FLEX style: drive 0-3 (default 0),
* a name of 1-8 letters, digits, '-' or '_' starting with a letter,
* and an extension of 1-3 such characters (default BAS).
*
* Programs are stored as FLEX text files: one line per program line,
* ending in CR, exactly as LIST shows them. FLEX's own tools can read
* and print them, and files edited elsewhere can be loaded. LOAD
* expands FLEX's space compression ($09,count) and ignores LF and
* other control characters. Lines without a line number are run as
* direct commands while the file loads, as if typed.
*
* SAVE "spec" refuses to overwrite an existing file (?AE ERROR); use
* plain SAVE to update the file last loaded or saved, or DELETE first.
* The name is forgotten by NEW, by a reset, and by a failed LOAD, so
* a plain SAVE can't put the wrong program into a file.
*
* Disk access goes through the FLEX BIOS jump table at $DE00. The
* monitor copies the whole ROM image to RAM at every reset, so the
* BIOS is there whether or not FLEX has been booted.
*
* This file is assembled as part of ExBasROM_SBC.asm (INCLUDE at the
* end of that file, which must be able to find it) and uses BASIC's own labels, so it follows that
* file's TSC-style syntax: no spaces in operands, comments after them.
*
* Writes are ordered so an interrupted SAVE or DELETE can only lose free
* sectors, never damage another file: data sectors first (they are
* still in the free chain until the SIR is written), then the SIR,
* then the directory entry, then any sectors being given back.
**************************************************************

* FLEX BIOS disk entry points (Flex_BIOS.asm)
BREAD     EQU  $DE00          READ SECTOR: X=BUFFER A=TRACK B=SECTOR
BWRITE    EQU  $DE03          WRITE SECTOR: X=BUFFER A=TRACK B=SECTOR
BDRIVE    EQU  $DE0C          SELECT DRIVE: X=FCB, DRIVE NUMBER AT 3,X
BINIT     EQU  $DE15          INITIALISE THE CF CARDS

RTCBASE   EQU  $F230          EPSON RTC-72421
RTCCD     EQU  $0D            CONTROL REGISTER D (HOLD/BUSY)

* SYSTEM INFORMATION RECORD (TRACK 0 SECTOR 3)
SIRLAB    EQU  $10            VOLUME LABEL (11 BYTES)
SIRVOL    EQU  $1B            VOLUME NUMBER
SIRFF     EQU  $1D            FIRST FREE TRACK/SECTOR
SIRLF     EQU  $1F            LAST FREE TRACK/SECTOR
SIRCNT    EQU  $21            FREE SECTOR COUNT
SIRMT     EQU  $26            MAXIMUM TRACK
SIRMS     EQU  $27            MAXIMUM SECTOR

* DIRECTORY ENTRY (24 BYTES, 10 PER SECTOR FROM OFFSET 16)
DESTRT    EQU  13             START TRACK/SECTOR
DEEND     EQU  15             END TRACK/SECTOR
DECNT     EQU  17             SECTOR COUNT

* ERROR NUMBERS (MESSAGES ADDED TO BASIC'S TABLE AT LABAF)
ERRNE     EQU  L890D-LABAF    FILE NOT FOUND
ERRAE     EQU  LERRAE-LABAF   FILE ALREADY EXISTS
ERRDF     EQU  LERRDF-LABAF   DISK FULL
ERRFN     EQU  LERRFN-LABAF   BAD FILE NAME
ERRIO     EQU  LERRIO-LABAF   NOT A FLEX DISK (OR NO DISK)

          ORG  $9000
DSKBEG    EQU  *              BASIC'S RAM ENDS HERE

**************************************************************
* COMMAND DISPATCH - BASIC'S DISPATCHER (LADC6) COMES HERE FOR ANY
* TOKEN ABOVE ITS LAST STANDARD COMMAND, WITH A = TOKEN
**************************************************************
XCMD      CMPA #TOK_MONITOR
          BEQ  MONCMD
          CMPA #TOK_FLEX
          BEQ  FLXCMD
          CMPA #TOK_CATW
          LBEQ DKCATW
          CMPA #TOK_CAT
          LBEQ DKCAT
          CMPA #TOK_LOAD
          LBEQ DKLOAD
          CMPA #TOK_SAVE
          LBEQ DKSAVE
          JMP  LADB1          ANYTHING ELSE - SYNTAX ERROR

* MONITOR / FLEX - LEAVE BASIC THROUGH THE MONITOR ENTRY VECTOR AT
* $FFF0 (MONENT IN ASSIST09-FLEX.ASM): A=0 ENTERS ASSIST09, A='F'
* BOOTS FLEX
MONCMD    CLRA                ENTER ASSIST09
          FCB  SKP2           SKIP THE NEXT TWO BYTES
FLXCMD    LDA  #'F            BOOT FLEX
          ORCC #$50           MASK INTERRUPTS
          JMP  [$FFF0]        MONENT

* MEM - FREE BYTES. MICROSOFT'S VERSION CONVERTED THE COUNT AS A SIGNED
* NUMBER, WHICH WENT NEGATIVE WITH MORE THAN 32K FREE; THIS USES THE
* UNSIGNED CONVERSION BASIC USES FOR LINE NUMBERS (LBDCC)
MEM       CLR  VALTYP         NUMERIC RESULT
          TFR  S,D
          SUBD ARYEND         STACK MINUS END OF ARRAYS
          STD  FPA0
          LDB  #$90           EXPONENT FOR AN INTEGER IN THE TOP HALF
          COMA                CARRY SET: UNSIGNED
          JMP  LBC86          ZERO THE REST OF FPA0 AND NORMALIZE

**************************************************************
* HOOKS CALLED FROM BASIC
**************************************************************
* DSKLIN - REPLACES "JSR LA390" IN BASIC'S MAIN LOOP (LAC7C). WHILE A
* LOAD IS RUNNING IT RETURNS THE NEXT LINE OF THE FILE AS IF TYPED:
* X = LINBUF, LINE AT LINBUF+1 ENDED BY 0, CARRY CLEAR.
DSKLIN    TST  LDACT
          BNE  DL1
          JMP  LA390          NOT LOADING - READ THE KEYBOARD
DL1       JSR  KEYIN          BREAK STOPS THE LOAD
          CMPA #3
          BEQ  DLSTOP
          TST  LDEOF
          BNE  DLEND
          LDX  #LINBUF+1
          CLRB
DL2       PSHS B,X
          JSR  RDBYTE         A = NEXT CHARACTER, CARRY SET AT END OF FILE
          PULS B,X
          BCS  DLEOF
          CMPA #CR
          BEQ  DLRET
          CMPA #SPACE
          BLO  DL2            IGNORE LF, NUL AND OTHER CONTROL CHARACTERS
          CMPA #'z+1
          BHS  DL2            SAME AS THE KEYBOARD: NOTHING ABOVE 'z'
          CMPB #LBUFMX
          BHS  DL2            LINE TOO LONG - DROP THE EXCESS
          STA  ,X+
          INCB
          BRA  DL2
DLEOF     INC  LDEOF          NEXT CALL ENDS THE LOAD
          TSTB
          BEQ  DLEND          NOTHING ON THE LAST LINE
DLRET     CLR  ,X
          LDX  #LINBUF
          ANDCC #$FE          NOT BREAK
          RTS
DLSTOP    CLR  CURVLD         PART-LOADED: DON'T LET SAVE OVERWRITE THE FILE
DLEND     CLR  LDACT
          LEAS 2,S            DROP LAC7C'S RETURN ADDRESS
          JMP  LAC73          PRINT OK AND CARRY ON FROM THE KEYBOARD

* DSKERR - CALLED AT THE START OF BASIC'S ERROR HANDLER (LAC46).
* AN ERROR DURING A LOAD STOPS IT AND FORGETS THE FILE NAME.
* B (THE ERROR NUMBER) IS PRESERVED.
DSKERR    TST  LDACT
          BEQ  DE9
          CLR  LDACT
          CLR  CURVLD
DE9       RTS

* DSKDEL - CALLED AT THE START OF BASIC'S DEL COMMAND. DEL COMES FIRST
* IN THE KEYWORD TABLE, SO "DELETE" IS STORED AS THE DEL TOKEN FOLLOWED
* BY THE LETTERS ETE (AND LISTS BACK AS DELETE). IF THEY FOLLOW, THIS IS
* DELETE "SPEC": DO IT AND RETURN STRAIGHT TO THE INTERPRETER. OTHERWISE
* RETURN TO DEL WITH A AND CC AS THEY WERE.
DSKDEL    PSHS CC,A,X
          LDX  CHARAD
          LDA  ,X
          CMPA #'E
          BNE  DD9
          LDA  1,X
          CMPA #'T
          BNE  DD9
          LDA  2,X
          CMPA #'E
          BNE  DD9
          LEAS 6,S            DROP CC,A,X AND THE RETURN TO DEL
          JSR  GETNCH         ON TO THE T
          JSR  GETNCH         AND THE LAST E
          JMP  DKDEL
DD9       PULS CC,A,X,PC

* DSKNEW - CALLED AT THE START OF THE NEW COMMAND. CC IS PRESERVED
* FOR NEW'S OWN TEST OF ITS ARGUMENT.
DSKNEW    PSHS CC
          CLR  CURVLD
          PULS CC,PC

**************************************************************
* CAT [DRIVE] - NAME, SIZE IN SECTORS AND DATE (DD/MM/YY)
**************************************************************
DKCAT     JSR  GETNCH         SKIP THE TOKEN
          JSR  GETDRV
          JSR  RDSIR
          LDX  #TDRIVE
          JSR  PRSTR
          LDA  FDRV
          ADDA #'0
          JSR  PUTCHR
          LDB  #2
          JSR  SPACES
          LDX  #SIRBUF+SIRLAB
          LDB  #11
          JSR  PRFLD
          LDX  #THASH
          JSR  PRSTR
          LDD  SIRBUF+SIRVOL
          JSR  PRNUM
          JSR  NEWLN
          JSR  DIRFST
CT1       JSR  LA549          BREAK OR PAUSE (CTRL-C / CTRL-S)
          JSR  DIRNXT
          BCS  CT9
          LDA  ,X
          BEQ  CT9            END OF DIRECTORY
          BMI  CT1            DELETED ENTRY
          STX  CATPTR
          JSR  PRNAME
          LDB  #13
          SUBB PCNT
          JSR  SPACES
          LDX  CATPTR
          LDD  DECNT,X
          JSR  PRNUM5
          LDX  CATPTR
          LDA  21,X           MONTH
          BEQ  CT2            NO DATE
          LDB  #2
          JSR  SPACES
          LDA  22,X           DAY
          JSR  PR2
          LDA  #'/
          JSR  PUTCHR
          LDA  21,X
          JSR  PR2
          LDA  #'/
          JSR  PUTCHR
          LDA  23,X           YEAR
          JSR  PR2
CT2       JSR  NEWLN
          BRA  CT1
CT9       LDD  SIRBUF+SIRCNT
          JSR  PRNUM5
          LDX  #TFREE
          JSR  PRSTR
          JMP  NEWLN

**************************************************************
* CATW [DRIVE] - NAMES ONLY, FIVE TO A LINE
**************************************************************
DKCATW    JSR  GETNCH         SKIP THE TOKEN
          JSR  GETDRV
          JSR  RDSIR
          CLR  CATCOL
          JSR  DIRFST
CW1       JSR  LA549          BREAK OR PAUSE
          JSR  DIRNXT
          BCS  CW9
          LDA  ,X
          BEQ  CW9
          BMI  CW1
          JSR  PRNAME
          INC  CATCOL
          LDA  CATCOL
          CMPA #5
          BEQ  CW2
          LDB  #13
          SUBB PCNT
          JSR  SPACES
          BRA  CW1
CW2       JSR  NEWLN
          CLR  CATCOL
          BRA  CW1
CW9       TST  CATCOL
          BEQ  CW10
          JMP  NEWLN
CW10      RTS

**************************************************************
* LOAD ["SPEC"] - NEW, THEN FEED THE FILE TO THE MAIN LOOP
**************************************************************
DKLOAD    JSR  GETNCH         SKIP THE TOKEN
          BNE  LD1
          TST  CURVLD         NO NAME: RELOAD THE CURRENT FILE
          LBEQ BADNAM
          JSR  CUR2F
          BRA  LD2
LD1       JSR  GETNAM
LD2       JSR  RDSIR
          JSR  FINDF
          BCC  LD3
          LDB  #ERRNE         NOT FOUND - THE PROGRAM IS LEFT ALONE
          JMP  LAC46
LD3       LDA  FDRV
          STA  LDDRV
          LDX  #LDBUF
          LDD  FSTRT
          JSR  BREAD          FIRST SECTOR
          LDA  #4
          STA  RPTR
          CLR  SPCNT
          CLR  LDEOF
          JSR  F2CUR          REMEMBER THE NAME FOR SAVE
          JSR  LAD19          NEW (RESETS THE STACK, THEN RETURNS)
          LDA  #1
          STA  LDACT
          JMP  LAC7C          MAIN LOOP - DSKLIN SUPPLIES THE LINES

**************************************************************
* SAVE ["SPEC"]
**************************************************************
DKSAVE    JSR  GETNCH         SKIP THE TOKEN
          BNE  SV1
          TST  CURVLD         NO NAME: UPDATE THE CURRENT FILE
          LBEQ BADNAM
          JSR  CUR2F
          LDA  #1
          STA  SVUPD
          BRA  SV2
SV1       JSR  GETNAM
          CLR  SVUPD
SV2       JSR  RDSIR
          JSR  FINDF
          BCS  SV3            NOT ON THE DISK
          TST  SVUPD
          BNE  SV4            UPDATING: REUSE ITS DIRECTORY ENTRY
          LDB  #ERRAE         SAVE "SPEC" NEVER OVERWRITES
          JMP  LAC46
SV3       CLR  SVUPD          (UPDATE OF A FILE THAT HAS GONE: WRITE IT NEW)
          TST  SLVLD
          BNE  SV4
          LDB  #ERRDF         DIRECTORY FULL
          JMP  LAC46
SV4       JSR  WRFILE         DATA SECTORS, SIR UPDATED IN SIRBUF
          JSR  WRSIR
          TST  SVUPD
          BEQ  SV5
          LDD  FDTRK          THE OLD ENTRY
          STD  DTRK
          LDB  FDOFF
          BRA  SV6
SV5       LDD  SLTRK          THE FREE SLOT
          STD  DTRK
          LDB  SLOFF
SV6       STB  DOFF
          JSR  DIRRD
          LDX  #DATBUF
          LDB  DOFF
          ABX
          LDU  #FNAME
          LDB  #11
SV7       LDA  ,U+            NAME AND EXTENSION
          STA  ,X+
          DECB
          BNE  SV7
          CLR  ,X+            11-12 RESERVED
          CLR  ,X+
          LDD  WSTRT          13-14 START
          STD  ,X++
          LDD  WCUR           15-16 END
          STD  ,X++
          LDD  WCNT           17-18 SECTOR COUNT
          STD  ,X++
          CLR  ,X+            19 SEQUENTIAL FILE
          CLR  ,X+            20 RESERVED
          PSHS X
          JSR  GETDAT
          PULS X
          LDA  DMON           21-23 DATE
          STA  ,X+
          LDA  DDAY
          STA  ,X+
          LDA  DYR
          STA  ,X
          JSR  DIRWR
          TST  SVUPD
          BEQ  SV8
          JSR  FREECH         GIVE THE OLD SECTORS BACK
          JSR  WRSIR
SV8       JSR  F2CUR          REMEMBER THE NAME
          LDA  CURLIN         IN A PROGRAM, CARRY ON
          INCA
          BEQ  SV9
          RTS
* IN DIRECT MODE THE LINE BEING RUN WAS IN LINBUF, WHICH WRFILE HAS
* USED TO UNCRUNCH THE PROGRAM, SO END IT HERE AS LIST DOES: THE REST
* OF A TYPED LINE AFTER SAVE IS NOT RUN
SV9       LEAS 2,S            DROP THE RETURN TO THE INTERPRETER LOOP
          JMP  LAC73          OK, THEN THE NEXT LINE

* WRFILE - WRITE THE PROGRAM AS TEXT INTO SECTORS TAKEN FROM THE
* HEAD OF THE FREE CHAIN, AND UPDATE SIRBUF TO MATCH. NOTHING IS
* COMMITTED UNTIL THE CALLER WRITES THE SIR: A ?DF ERROR PART WAY
* LEAVES THE FREE CHAIN'S LINKS AS THEY WERE.
WRFILE    LDD  SIRBUF+SIRFF
          BNE  WF1
          LDB  #ERRDF
          JMP  LAC46
WF1       STD  WSTRT
          STD  WCUR
          JSR  WRLD           READ IT TO LEARN ITS LINK
          LDD  #1
          STD  WSEQ
          STD  WCNT
          STD  DATBUF+2
          LDA  #4
          STA  WPTR
          LDX  TXTTAB
WF2       LDD  ,X
          BEQ  WF4            END OF PROGRAM
          STX  SVLIN
          LDD  2,X            LINE NUMBER
          JSR  DECSTR
          LDX  #DECBUF
          JSR  WRSTR
          LDA  #SPACE
          JSR  WRBYTE
          LDX  SVLIN
          JSR  LB7C2          UNCRUNCH INTO LINBUF+1, AS LIST DOES
          LDX  #LINBUF+1
          JSR  WRSTR
          LDA  #CR
          JSR  WRBYTE
          LDX  [SVLIN]        NEXT LINE
          BRA  WF2
WF4       LDD  DATBUF         THE LAST SECTOR'S LINK IS THE NEW FREE HEAD
          STD  NEWFRE
          CLR  DATBUF
          CLR  DATBUF+1
          LDB  WPTR
          BEQ  WF6            SECTOR EXACTLY FULL
          LDX  #DATBUF
          ABX
WF5       CLR  ,X+            ZERO THE REST
          INCB
          BNE  WF5
WF6       LDX  #DATBUF
          LDD  WCUR
          JSR  BWRITE
          LDD  NEWFRE
          STD  SIRBUF+SIRFF
          BNE  WF7
          STD  SIRBUF+SIRLF   FREE CHAIN NOW EMPTY
WF7       LDD  SIRBUF+SIRCNT
          SUBD WCNT
          STD  SIRBUF+SIRCNT
          RTS

* WRBYTE - ADD A TO THE FILE. ALL REGISTERS PRESERVED.
WRBYTE    PSHS A,B,X
          LDB  WPTR
          BNE  WB1
          JSR  WRNEXT         SECTOR FULL - ON TO THE NEXT
          LDB  #4
WB1       LDX  #DATBUF
          ABX
          LDA  ,S
          STA  ,X
          INCB
          STB  WPTR
          PULS A,B,X,PC

WRNEXT    LDD  DATBUF         NEXT FREE SECTOR
          BNE  WN1
          LDB  #ERRDF
          JMP  LAC46
WN1       STD  WNEXT
          LDX  #DATBUF
          LDD  WCUR
          JSR  BWRITE         LINK LEFT AS IT WAS: THE NEXT SECTOR OF THE FILE
          LDD  WNEXT
          STD  WCUR
          JSR  WRLD
          LDD  WSEQ
          ADDD #1
          STD  WSEQ
          STD  DATBUF+2
          LDD  WCNT
          ADDD #1
          STD  WCNT
          RTS

WRLD      LDX  #DATBUF
          LDD  WCUR
          JMP  BREAD

* WRSTR - WRITE THE STRING AT X, ENDED BY 0
WRSTR     LDA  ,X+
          BEQ  WS9
          JSR  WRBYTE
          BRA  WRSTR
WS9       RTS

**************************************************************
* DELETE "SPEC" (REACHED FROM DSKDEL)
**************************************************************
DKDEL     JSR  GETNCH         SKIP THE LAST E OF DELETE
          LBEQ BADNAM         A NAME IS REQUIRED
          JSR  GETNAM
          JSR  RDSIR
          JSR  FINDF
          BCC  KL1
          LDB  #ERRNE
          JMP  LAC46
KL1       LDD  FDTRK          MARK THE ENTRY DELETED FIRST
          STD  DTRK
          JSR  DIRRD
          LDX  #DATBUF
          LDB  FDOFF
          ABX
          LDA  ,X
          ORA  #$80
          STA  ,X
          JSR  DIRWR
          JSR  FREECH         THEN GIVE ITS SECTORS BACK
          JSR  WRSIR
          JSR  SAMECUR        WAS IT THE CURRENT FILE?
          BNE  KL9
          CLR  CURVLD
KL9       RTS

* FREECH - APPEND THE CHAIN FSTRT..FEND (FCNT SECTORS) TO THE END OF
* THE FREE CHAIN, IN SIRBUF. THE CALLER WRITES THE SIR.
FREECH    LDD  SIRBUF+SIRFF
          BNE  FC1
          LDD  FSTRT          FREE CHAIN WAS EMPTY
          STD  SIRBUF+SIRFF
          BRA  FC2
FC1       LDD  SIRBUF+SIRLF
          LBEQ BADDSK         FIRST FREE SET BUT NO LAST FREE
          LDX  #DATBUF
          JSR  BREAD
          LDD  FSTRT
          STD  DATBUF         LINK THE OLD LAST FREE SECTOR TO THE CHAIN
          LDX  #DATBUF
          LDD  SIRBUF+SIRLF
          JSR  BWRITE
FC2       LDD  FEND
          STD  SIRBUF+SIRLF
          LDD  SIRBUF+SIRCNT
          ADDD FCNT
          STD  SIRBUF+SIRCNT
          RTS

**************************************************************
* DISK HELPERS
**************************************************************
* SELECT FDRV (INITIALISING THE CARDS ON FIRST USE) AND READ ITS SIR.
* AN IMPOSSIBLE SIR - NO CARD, OR NOT A FLEX DISK - GIVES ?IO ERROR.
RDSIR     LDA  FDRV
          JSR  SELA
          LDX  #SIRBUF
          LDD  #$0003
          JSR  BREAD
          LDB  SIRBUF+SIRMS
          BEQ  BADDSK
          LDA  SIRBUF+SIRMT
          MUL                 (MAXTRACK+1)*MAXSECTOR SECTORS IN ALL
          ADDB SIRBUF+SIRMS
          ADCA #0
          CMPD SIRBUF+SIRCNT
          BLO  BADDSK         MORE FREE THAN THERE ARE
          LDD  SIRBUF+SIRCNT
          BEQ  RS9
          LDA  SIRBUF+SIRFF
          CMPA SIRBUF+SIRMT
          BHI  BADDSK
          LDB  SIRBUF+SIRFF+1
          BEQ  BADDSK
          CMPB SIRBUF+SIRMS
          BHI  BADDSK
RS9       RTS
BADDSK    LDB  #ERRIO
          JMP  LAC46

* SELA - SELECT DRIVE A
SELA      TST  DSKINI
          BNE  SA1
          PSHS A
          JSR  BINIT
          PULS A
          INC  DSKINI
SA1       LDX  #DFCB
          STA  3,X
          JMP  BDRIVE

WRSIR     LDX  #SIRBUF
          LDD  #$0003
          JMP  BWRITE

DIRRD     LDX  #DATBUF
          LDD  DTRK
          JMP  BREAD

DIRWR     LDX  #DATBUF
          LDD  DTRK
          JMP  BWRITE

* DIRFST / DIRNXT - WALK THE DIRECTORY. DIRNXT RETURNS X = NEXT ENTRY
* IN DATBUF, OR CARRY SET WHEN THE CHAIN ENDS. AT MOST 255 SECTORS
* ARE READ, SO A DAMAGED CHAIN CAN'T LOOP FOR EVER.
DIRFST    CLR  DTRK
          LDA  #5
          STA  DSEC
          LDA  #255
          STA  DCAP
          CLR  DENT
          BRA  DIRRD

DIRNXT    LDB  DENT
          CMPB #10
          BLO  DN1
          LDD  DATBUF         LINK TO THE NEXT DIRECTORY SECTOR
          BEQ  DNEND
          DEC  DCAP
          BEQ  DNEND
          STD  DTRK
          BSR  DIRRD
          CLR  DENT
          CLRB
DN1       LDA  #24
          MUL
          ADDD #DATBUF+16
          TFR  D,X
          INC  DENT
          ANDCC #$FE
          RTS
DNEND     ORCC #1
          RTS

* FINDF - LOOK FOR FNAME/FEXT. CARRY CLEAR = FOUND: FDTRK/FDSEC/FDOFF
* LOCATE THE ENTRY AND FSTRT/FEND/FCNT ARE COPIED FROM IT. CARRY SET =
* NOT FOUND. EITHER WAY, SLVLD/SLTRK/SLSEC/SLOFF GIVE THE FIRST FREE
* ENTRY (DELETED OR NEVER USED), IF THERE IS ONE.
FINDF     CLR  SLVLD
          BSR  DIRFST
FF1       BSR  DIRNXT
          BCS  FFNO
          LDA  ,X
          BEQ  FFEND          NEVER USED: THE END OF THE DIRECTORY
          BMI  FFDEL          DELETED
          LDU  #FNAME
          PSHS X
          LDB  #11
FF2       LDA  ,X+
          CMPA ,U+
          BNE  FF3
          DECB
          BNE  FF2
          PULS X              FOUND
          LDD  DTRK
          STD  FDTRK
          BSR  ENTOFF
          STB  FDOFF
          LDD  DESTRT,X
          STD  FSTRT
          LDD  DEEND,X
          STD  FEND
          LDD  DECNT,X
          STD  FCNT
          ANDCC #$FE
          RTS
FF3       PULS X
          BRA  FF1
FFDEL     BSR  SLOT
          BRA  FF1
FFEND     BSR  SLOT
FFNO      ORCC #1
          RTS
SLOT      TST  SLVLD
          BNE  SL9
          LDD  DTRK
          STD  SLTRK
          BSR  ENTOFF
          STB  SLOFF
          INC  SLVLD
SL9       RTS
ENTOFF    TFR  X,D            B = OFFSET OF ENTRY X IN DATBUF
          SUBD #DATBUF
          RTS

* RDBYTE - NEXT CHARACTER OF THE FILE BEING LOADED, IN A, WITH FLEX
* SPACE COMPRESSION ($09,COUNT) EXPANDED. CARRY SET AT END OF FILE.
RDBYTE    TST  SPCNT
          BEQ  RB1
          DEC  SPCNT
          LDA  #SPACE
          ANDCC #$FE
          RTS
RB1       BSR  RAWBYT
          BCS  RB9
          CMPA #9
          BNE  RB8
          BSR  RAWBYT         THE COUNT
          BCS  RB9
          TSTA
          BEQ  RB1
          DECA
          STA  SPCNT
          LDA  #SPACE
RB8       ANDCC #$FE
RB9       RTS

RAWBYT    LDB  RPTR
          BNE  RW1
          LDD  LDBUF          FOLLOW THE LINK
          BEQ  RWEOF
          PSHS D
          LDA  LDDRV          A COMMAND IN THE FILE MAY HAVE
          JSR  SELA           SELECTED ANOTHER DRIVE
          PULS D
          LDX  #LDBUF
          JSR  BREAD
          LDB  #4
RW1       LDX  #LDBUF
          ABX
          LDA  ,X
          INCB
          STB  RPTR
          ANDCC #$FE
          RTS
RWEOF     ORCC #1
          RTS

**************************************************************
* FILE NAMES
**************************************************************
* GETDRV - OPTIONAL DRIVE NUMBER FOR CAT/CATW
GETDRV    CLR  FDRV
          JSR  GETCCH
          BEQ  GD9
          JSR  LB70B          VALUE IN B, ?FC ERROR ABOVE 255
          LBNE LB277          ANYTHING AFTER IT - ?SN ERROR
          CMPB #3
          LBHI LB44A          ?FC ERROR
          STB  FDRV
GD9       RTS

* GETNAM - EVALUATE A STRING EXPRESSION AND PARSE IT INTO FDRV, FNAME
* (8 BYTES) AND FEXT (3 BYTES), ZERO-PADDED AS FLEX STORES THEM.
GETNAM    JSR  LB156          EVALUATE THE EXPRESSION
          JSR  LB654          X = STRING, B = LENGTH (?TM ERROR IF NUMERIC)
          STB  PLEN
          JSR  GETCCH
          LBNE LB277          ANYTHING AFTER IT - ?SN ERROR
          CLR  FDRV
          LDU  #FNAME
          LDB  #11
GN1       CLR  ,U+
          DECB
          BNE  GN1
          LDA  PLEN           "D." DRIVE PREFIX?
          CMPA #2
          BLO  GN2
          LDA  ,X
          CMPA #'0
          BLO  GN2
          CMPA #'3
          BHI  GN2
          LDB  1,X
          CMPB #'.
          BNE  GN2
          SUBA #'0
          STA  FDRV
          LEAX 2,X
          DEC  PLEN
          DEC  PLEN
GN2       LDU  #FNAME
          LDB  #8
          BSR  PFIELD
          TSTA
          BEQ  GN3            NO EXTENSION
          LDU  #FEXT
          LDB  #3
          BSR  PFIELD
          TSTA
          BNE  BADNAM         A SECOND '.'
          RTS
GN3       LDD  #$4241         DEFAULT EXTENSION "BAS"
          STD  FEXT
          LDA  #$53
          STA  FEXT+2
          RTS
BADNAM    LDB  #ERRFN
          JMP  LAC46

* PFIELD - COPY UP TO B NAME CHARACTERS FROM X TO U, STOPPING AT '.'
* OR THE END. RETURNS A = '.' OR 0. AT LEAST ONE CHARACTER, THE FIRST
* A LETTER.
PFIELD    STB  PMAX
          CLR  PCNT
PF1       BSR  NXTCH
          BEQ  PF4
          CMPA #'.
          BEQ  PF4
          BSR  ISNAMC
          BCS  BADNAM
          TST  PCNT
          BNE  PF2
          CMPA #'A            THE FIRST MUST BE A LETTER
          BLO  BADNAM
          CMPA #'Z
          BHI  BADNAM
PF2       LDB  PCNT
          CMPB PMAX
          BHS  BADNAM
          STA  ,U+
          INC  PCNT
          BRA  PF1
PF4       TST  PCNT
          BEQ  BADNAM
          RTS

* NXTCH - NEXT CHARACTER OF THE NAME IN A, UPPER CASE; A = 0 AND Z SET
* AT THE END
NXTCH     CLRA
          TST  PLEN
          BEQ  NC9
          DEC  PLEN
          LDA  ,X+
          CMPA #'a
          BLO  NC8
          CMPA #'z
          BHI  NC8
          SUBA #$20
NC8       TSTA
NC9       RTS

* ISNAMC - CARRY CLEAR IF A IS A LETTER, DIGIT, '-' OR '_'
ISNAMC    CMPA #'A
          BLO  IC1
          CMPA #'Z
          BLS  ICOK
IC1       CMPA #'0
          BLO  IC2
          CMPA #'9
          BLS  ICOK
IC2       CMPA #'-
          BEQ  ICOK
          CMPA #'_
          BEQ  ICOK
          ORCC #1
          RTS
ICOK      ANDCC #$FE
          RTS

* F2CUR / CUR2F - COPY THE PARSED NAME TO OR FROM THE CURRENT FILE
F2CUR     LDX  #FDRV
          LDU  #CURDRV
          BSR  CPY12
          LDA  #1
          STA  CURVLD
          RTS
CUR2F     LDX  #CURDRV
          LDU  #FDRV
CPY12     LDB  #12
CP1       LDA  ,X+
          STA  ,U+
          DECB
          BNE  CP1
          RTS

* SAMECUR - Z SET IF THE PARSED NAME IS THE CURRENT FILE
SAMECUR   LDX  #FDRV
          LDU  #CURDRV
          LDB  #12
SC1       LDA  ,X+
          CMPA ,U+
          BNE  SC9
          DECB
          BNE  SC1
SC9       RTS

**************************************************************
* DATE FROM THE RTC (SAME HOLD/BUSY PROTOCOL AS ASSIST09_FLEX_RTC)
* DMON/DDAY/DYR IN BINARY, OR ALL ZERO IF THE CLOCK CAN'T BE READ
**************************************************************
GETDAT    CLR  DMON
          CLR  DDAY
          CLR  DYR
          LDU  #RTCBASE
          LDB  #$40           TRIES
GT1       LDA  #1
          STA  RTCCD,U        HOLD
          LDA  RTCCD,U
          BITA #2             BUSY?
          BEQ  GT2
          CLR  RTCCD,U        RELEASE AND TRY AGAIN
          CLRA
GT1D      DECA
          BNE  GT1D
          DECB
          BNE  GT1
          RTS                 NOT RESPONDING: NO DATE
GT2       LDX  #RAWD          DAY, MONTH, YEAR DIGITS (REGISTERS 6-11)
          LEAY 6,U
          LDB  #6
GT3       LDA  ,Y+
          ANDA #$0F
          STA  ,X+
          DECB
          BNE  GT3
          CLR  RTCCD,U        RELEASE HOLD
          LDA  RAWD+3
          LDB  RAWD+2
          BSR  TWODIG
          STB  DMON
          LDA  RAWD+1
          LDB  RAWD
          BSR  TWODIG
          STB  DDAY
          LDA  RAWD+5
          LDB  RAWD+4
          BSR  TWODIG
          STB  DYR
          LDA  DMON
          BEQ  GTBAD
          CMPA #12
          BHI  GTBAD
          LDA  DDAY
          BEQ  GTBAD
          CMPA #31
          BLS  GT9
GTBAD     CLR  DMON
          CLR  DDAY
          CLR  DYR
GT9       RTS
TWODIG    PSHS B              B = A*10+B
          LDB  #10
          MUL
          ADDB ,S+
          RTS

**************************************************************
* OUTPUT
**************************************************************
NEWLN     LDA  #CR
          JMP  PUTCHR

* PRSTR - PRINT THE STRING AT X, ENDED BY 0
PRSTR     LDA  ,X+
          BEQ  PS9
          JSR  PUTCHR
          BRA  PRSTR
PS9       RTS

* PRFLD - PRINT UP TO B CHARACTERS AT X, STOPPING AT A 0
PRFLD     LDA  ,X+
          BEQ  PD9
          JSR  PUTCHR
          DECB
          BNE  PRFLD
PD9       RTS

* SPACES - PRINT B SPACES (NONE IF B <= 0)
SPACES    TSTB
          BLE  SP9
SP1       LDA  #SPACE
          JSR  PUTCHR
          DECB
          BNE  SP1
SP9       RTS

* PRNAME - PRINT NAME.EXT OF THE ENTRY AT X; PCNT = CHARACTERS PRINTED
PRNAME    CLR  PCNT
          PSHS X
          LDB  #8
PN1       LDA  ,X+
          BEQ  PN2
          JSR  PUTCHR
          INC  PCNT
          DECB
          BNE  PN1
PN2       PULS X
          LEAX 8,X
          LDA  ,X
          BEQ  PN4            NO EXTENSION
          LDA  #'.
          JSR  PUTCHR
          INC  PCNT
          LDB  #3
PN3       LDA  ,X+
          BEQ  PN4
          JSR  PUTCHR
          INC  PCNT
          DECB
          BNE  PN3
PN4       RTS

* PR2 - PRINT A (0-99) AS TWO DIGITS
PR2       PSHS A
          LDB  #'0
P21       SUBA #10
          BLO  P22
          INCB
          BRA  P21
P22       ADDA #10+'0
          PSHS A
          TFR  B,A
          JSR  PUTCHR
          PULS A
          JSR  PUTCHR
          PULS A,PC

* PRNUM - PRINT D IN DECIMAL; PRNUM5 - THE SAME, RIGHT-JUSTIFIED IN 5
PRNUM     BSR  DECSTR
          LDX  #DECBUF
          JMP  PRSTR
PRNUM5    BSR  DECSTR
          NEGB
          ADDB #5
          JSR  SPACES
          LDX  #DECBUF
          JMP  PRSTR

* DECSTR - D AS UNSIGNED DECIMAL AT DECBUF, ENDED BY 0; B = DIGITS
DECSTR    STD  DVAL
          LDX  #DECPOW
          LDU  #DECBUF
          CLR  DLEAD
DC1       LDA  #'0
          STA  DDIG
          LDD  DVAL
DC2       CMPD ,X
          BLO  DC3
          SUBD ,X
          INC  DDIG
          BRA  DC2
DC3       STD  DVAL
          LDA  DDIG
          CMPX #DECPOW+8      THE UNITS DIGIT IS ALWAYS PRINTED
          BEQ  DC4
          TST  DLEAD
          BNE  DC4
          CMPA #'0
          BEQ  DC5            LEADING ZERO
DC4       STA  ,U+
          INC  DLEAD
DC5       LEAX 2,X
          CMPX #DECPOW+10
          BNE  DC1
          CLR  ,U
          TFR  U,D
          SUBD #DECBUF
          RTS
DECPOW    FDB  10000,1000,100,10,1

TDRIVE    FCC  "DRIVE "
          FCB  0
THASH     FCC  " #"
          FCB  0
TFREE     FCC  " SECTORS FREE"
          FCB  0

**************************************************************
* VARIABLES. THESE ARE PART OF THE ROM IMAGE, SO THE MONITOR'S COPY
* TO RAM AT RESET CLEARS THEM: THE CARDS ARE INITIALISED AGAIN AND
* NO FILE IS CURRENT.
**************************************************************
DSKINI    FCB  0              CF CARDS INITIALISED
CURVLD    FCB  0              CURDRV/CURNAM HOLD THE CURRENT FILE
LDACT     FCB  0              A LOAD IS FEEDING THE MAIN LOOP
LDEOF     FCB  0              ...AND HAS REACHED THE END OF THE FILE
SVUPD     FCB  0              SAVE IS UPDATING AN EXISTING FILE
SLVLD     FCB  0              SLTRK/SLSEC/SLOFF IS A FREE DIRECTORY ENTRY
CATCOL    FCB  0
PLEN      FCB  0
PCNT      FCB  0
PMAX      FCB  0
DENT      FCB  0
DCAP      FCB  0
DOFF      FCB  0
DLEAD     FCB  0
DDIG      FCB  0
WPTR      FCB  0
RPTR      FCB  0
SPCNT     FCB  0
LDDRV     FCB  0
FDOFF     FCB  0
SLOFF     FCB  0
DMON      FCB  0
DDAY      FCB  0
DYR       FCB  0
DTRK      FCB  0              DTRK/DSEC: CURRENT DIRECTORY SECTOR
DSEC      FCB  0
FDTRK     FDB  0              DIRECTORY SECTOR OF THE FILE FOUND
SLTRK     FDB  0              DIRECTORY SECTOR OF THE FREE ENTRY
FSTRT     FDB  0
FEND      FDB  0
FCNT      FDB  0
WSTRT     FDB  0
WCUR      FDB  0
WNEXT     FDB  0
WSEQ      FDB  0
WCNT      FDB  0
NEWFRE    FDB  0
SVLIN     FDB  0
CATPTR    FDB  0
DVAL      FDB  0
FDRV      FCB  0              FDRV, FNAME, FEXT: THE NAME BEING USED (12 BYTES)
FNAME     FCB  0,0,0,0,0,0,0,0
FEXT      FCB  0,0,0
CURDRV    FCB  0              CURDRV, CURNAM: THE CURRENT FILE (12 BYTES)
CURNAM    FCB  0,0,0,0,0,0,0,0,0,0,0
DECBUF    FCB  0,0,0,0,0,0
RAWD      FCB  0,0,0,0,0,0
DFCB      FCB  0,0,0,0        DRIVE NUMBER AT 3 FOR THE BIOS
DSKEND    EQU  *

* SECTOR BUFFERS (NOT PART OF THE ROM IMAGE)
SIRBUF    RMB  256
DATBUF    RMB  256            DIRECTORY AND FILE WRITES
LDBUF     RMB  256            THE FILE BEING LOADED
BUFEND    EQU  *

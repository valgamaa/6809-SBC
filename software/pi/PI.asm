* PI - CALCULATE PI TO MANY DIGITS BY MACHIN'S FORMULA
*
*   PI/4 = 4*ARCTAN(1/5) - ARCTAN(1/239)
*
* FLEX 9 COMMAND. USAGE:  PI 1000   OR JUST  PI  TO BE ASKED.
* UP TO 65529 DIGITS.
*
* ONE DECIMAL DIGIT PER BYTE, HELD IN PAGED RAM: FOUR BUFFERS
* OF 16 4K BLOCKS EACH, SEEN THROUGH A 4K WINDOW AT $E000.
* THE BLOCK IS SELECTED BY WRITING $F280 (WRITE ONLY - A READ
* LATCHES THE DATA BUS INTO THE PAGE REGISTER). BLOCK 14, THE
* NATIVE $E000 RAM, IS MAPPED BACK IN BEFORE EVERY FLEX CALL.

* FLEX ENTRY POINTS
WARMS   EQU     $CD03           RETURN TO FLEX
PUTCHR  EQU     $CD18           OUTPUT CHARACTER IN A
INBUFF  EQU     $CD1B           INPUT A LINE TO THE LINE BUFFER
PSTRNG  EQU     $CD1E           CR/LF THEN STRING AT X TO $04
PCRLF   EQU     $CD24           OUTPUT CR/LF
LBPTR   EQU     $CC14           LINE BUFFER POINTER

* HARDWARE
PAGREG  EQU     $F280           PAGE SELECT REGISTER (WRITE ONLY)
WINDOW  EQU     $E000           START OF 4K WINDOW
WINEND  EQU     $F000           FIRST ADDRESS PAST THE WINDOW
NATIVE  EQU     14              BLOCK THAT IS NORMALLY AT $E000

* DIGIT BUFFERS (FIRST BLOCK OF EACH, 16 BLOCKS = 65536 DIGITS)
PBUF    EQU     16              POWER TERM 1/X^(2M+1)
TBUF    EQU     32              CURRENT TERM P/(2M+1)
ABUF    EQU     48              ARCTAN(1/5), THEN THE RESULT
BBUF    EQU     64              ARCTAN(1/239)

GUARD   EQU     6               EXTRA DIGITS TO ABSORB ROUNDING
MAXDIG  EQU     65535-GUARD     LARGEST DIGIT COUNT ALLOWED
PERLIN  EQU     50              DIGITS PER OUTPUT LINE

        ORG     $0100

*******************************************************
* MAIN PROGRAM
START   LDX     LBPTR           LOOK FOR A NUMBER AFTER "PI"
        JSR     GETNUM
        BCC     GOTN
ASK     LDX     #PROMPT
        JSR     PSTRNG
        JSR     INBUFF
        LDX     LBPTR
        JSR     GETNUM
        BCS     ASK
GOTN    STD     N1              DIGITS WANTED
        BEQ     ASK
        ADDD    #GUARD          N = N1 + GUARD
        STD     NN
*
* ARCTAN(1/5), STARTING FROM 1/5 = 0.2
        LDX     #MSG5
        JSR     PSTRNG
        LDA     #ABUF
        JSR     CLEAR
        LDA     #PBUF
        JSR     CLEAR
        LDA     #PBUF           P(0) = 2
        STA     PAGREG
        LDA     #2
        STA     WINDOW
        LDD     #25
        STD     X2
        LDA     #ABUF
        STA     ZBUF
        JSR     ARCTAN
*
* ARCTAN(1/239), 1/239 = 0.0041841 REPEATING
        LDX     #MSG239
        JSR     PSTRNG
        LDA     #BBUF
        JSR     CLEAR
        JSR     FILL239
        LDD     #57121
        STD     X2
        LDA     #BBUF
        STA     ZBUF
        JSR     ARCTAN
*
* PI = 4 * (4*ARCTAN(1/5) - ARCTAN(1/239))
        LDA     #ABUF
        LDB     #4
        JSR     MULSM
        LDD     #BBUF
        STD     SRC
        LDD     #ABUF
        STD     DST
        LDD     #0
        STD     FF
        LDD     #1              SUBTRACT
        STD     SS
        JSR     ADDSUB
        LDA     #ABUF
        LDB     #4
        JSR     MULSM           CARRY OUT IS THE INTEGER PART, 3
        JSR     PCRLF
        JSR     PRINTPI
        JSR     PCRLF
        JMP     WARMS

*******************************************************
* GETNUM - READ A DECIMAL NUMBER FROM THE STRING AT X
* RETURNS D = NUMBER, CARRY CLEAR IF OK.
* CARRY SET IF NO DIGITS OR THE NUMBER IS TOO BIG.
GETNUM  LDA     ,X+             SKIP SPACES
        CMPA    #$20
        BEQ     GETNUM
        LEAX    -1,X
        CLR     GNCNT
        LDD     #0
        STD     GNVAL
GN1     LDB     ,X+
        SUBB    #'0
        BLO     GN2             NOT A DIGIT - END OF NUMBER
        CMPB    #9
        BHI     GN2
        STB     GNDIG
        INC     GNCNT
        LDD     GNVAL           VALUE = VALUE * 10 + DIGIT
        ASLB
        ROLA
        BCS     GNBAD
        STD     GNTMP
        ASLB
        ROLA
        BCS     GNBAD
        ASLB
        ROLA
        BCS     GNBAD
        ADDD    GNTMP
        BCS     GNBAD
        ADDB    GNDIG
        ADCA    #0
        BCS     GNBAD
        STD     GNVAL
        BRA     GN1
GN2     TST     GNCNT
        BEQ     GNBAD
        LDD     GNVAL
        CMPD    #MAXDIG
        BHI     GNBAD
        ANDCC   #$FE            CLEAR CARRY - OK
        RTS
GNBAD   ORCC    #$01            SET CARRY - NO GOOD
        RTS

*******************************************************
* ARCTAN - ADD THE SERIES FOR ARCTAN(1/X) INTO BUFFER ZBUF
* ON ENTRY PBUF HOLDS 1/X AND X2 = X*X.
*   Z = P/1 - P/(3X^2) + P/(5X^4) - ...
ARCTAN  LDD     #0
        STD     MM              TERM NUMBER M
        STD     FF              FIRST NON-ZERO DIGIT OF P
        STD     SGN             0 = ADD, 1 = SUBTRACT
AT1     LDD     FF              DONE WHEN P IS ALL ZERO
        CMPD    NN
        BHS     ATDONE
*
        LDD     #PBUF           T = P / (2M+1)
        STD     SRC
        LDD     #TBUF
        STD     DST
        LDD     MM
        ASLB
        ROLA
        ADDD    #1
        STD     VV
        JSR     DIVIDE
*
        LDD     #TBUF           Z = Z + OR - T
        STD     SRC
        LDB     ZBUF
        CLRA
        STD     DST
        LDD     SGN
        STD     SS
        JSR     ADDSUB
*
        LDD     #PBUF           P = P / X2, IN PLACE
        STD     SRC
        STD     DST
        LDD     X2
        STD     VV
        JSR     DIVIDE
        LDD     RES             FIRST NON-ZERO DIGIT
        STD     FF
*
        LDD     MM              NEXT TERM
        ADDD    #1
        STD     MM
        LDB     SGN+1           FLIP SIGN
        EORB    #1
        STB     SGN+1
        BRA     AT1
ATDONE  RTS

*******************************************************
* CLEAR - SET THE FIRST NN DIGITS OF BUFFER A TO ZERO
CLEAR   STA     CBLK
        LDY     NN
CL1     LDA     CBLK
        STA     PAGREG
        LDX     #WINDOW
CL2     CLR     ,X+
        LEAY    -1,Y
        BEQ     CLDONE
        CMPX    #WINEND
        BNE     CL2
        INC     CBLK
        BRA     CL1
CLDONE  LDA     #NATIVE
        STA     PAGREG
        RTS

*******************************************************
* FILL239 - FILL PBUF WITH 1/239 = 0.0041841 0041841 ...
FILL239 LDA     #PBUF
        STA     CBLK
        LDY     NN
        CLRB                    B = POSITION IN THE 7-DIGIT PATTERN
FI1     LDA     CBLK
        STA     PAGREG
        LDX     #WINDOW
FI2     LDU     #PAT239
        LDA     B,U
        STA     ,X+
        INCB
        CMPB    #7
        BNE     FI3
        CLRB
FI3     LEAY    -1,Y
        BEQ     FIDONE
        CMPX    #WINEND
        BNE     FI2
        INC     CBLK
        BRA     FI1
FIDONE  LDA     #NATIVE
        STA     PAGREG
        RTS
PAT239  FCB     0,0,4,1,8,4,1

*******************************************************
* MULSM - MULTIPLY BUFFER A BY THE SMALL NUMBER IN B, IN PLACE
* WORKS FROM DIGIT NN-1 DOWN TO 0. RETURNS THE CARRY OUT
* OF THE TOP IN CARRYO.
MULSM   STA     CBLK
        STB     MULT
        CLR     CARRYO
        LDD     NN              INDEX NN-1
        SUBD    #1
        STD     MIDX
        LSRA                    BLOCK = BUFFER + INDEX/4096
        LSRA
        LSRA
        LSRA
        ADDA    CBLK
        STA     CBLK
        LDD     MIDX
        ANDA    #$0F
        ADDD    #WINDOW
        TFR     D,X
        LDY     NN              COUNT
ML1     LDA     CBLK
        STA     PAGREG
ML2     LDA     ,X              DIGIT * MULT + CARRY
        LDB     MULT
        MUL
        ADDB    CARRYO
        CLRA                    A = NEW CARRY
ML3     CMPB    #10
        BLO     ML4
        SUBB    #10
        INCA
        BRA     ML3
ML4     STB     ,X
        STA     CARRYO
        LEAY    -1,Y
        BEQ     MLDONE
        LEAX    -1,X
        CMPX    #WINDOW-1
        BNE     ML2
        LDX     #WINEND-1
        DEC     CBLK
        BRA     ML1
MLDONE  LDA     #NATIVE
        STA     PAGREG
        RTS

*******************************************************
* PRINTPI - PRINT "3." AND THE FIRST N1 DIGITS OF ABUF,
* PERLIN DIGITS PER LINE, LATER LINES INDENTED TWO SPACES
PRINTPI LDA     CARRYO          INTEGER PART
        ADDA    #'0
        JSR     PUTCHR
        LDA     #'.
        JSR     PUTCHR
        LDA     #ABUF
        STA     CBLK
        LDX     #WINDOW
        LDY     N1
        LDB     #PERLIN
        STB     LINCNT
PP1     LDA     CBLK            FETCH NEXT DIGIT
        STA     PAGREG
        LDA     ,X+
        LDB     #NATIVE         MAP NATIVE BLOCK BEFORE CALLING FLEX
        STB     PAGREG
        ADDA    #'0
        PSHS    X,Y
        JSR     PUTCHR
        PULS    X,Y
        CMPX    #WINEND
        BNE     PP2
        LDX     #WINDOW
        INC     CBLK
PP2     LEAY    -1,Y
        BEQ     PPDONE
        DEC     LINCNT
        BNE     PP1
        LDB     #PERLIN         NEW LINE, INDENTED
        STB     LINCNT
        PSHS    X,Y
        JSR     PCRLF
        LDA     #$20
        JSR     PUTCHR
        LDA     #$20
        JSR     PUTCHR
        PULS    X,Y
        BRA     PP1
PPDONE  RTS

*******************************************************
* DIVIDE - DST(F..N-1) = SRC(F..N-1) / V, RETURNS F1 IN RES
* (SAME CODE AS THE BASIC VERSION'S MACHINE CODE ROUTINE)
DIVIDE  PSHS    D,X,Y,U         KEEP BASIC'S REGISTERS
        LDD     NN
        STD     F1              F1 = N UNTIL A NON-ZERO DIGIT
        CLR     FOUND
        CLR     RH              REMAINDER = 0
        CLR     RM
        CLR     RL
        LDD     NN              CNT = N - F DIGITS TO DO
        SUBD    FF
        LBLS    DVEXIT          NOTHING TO DO IF N <= F
        STD     CNT
*
* SET UP SOURCE BLOCK/POINTER FOR INDEX F
        LDD     FF
        LSRA                    A = F / 4096
        LSRA
        LSRA
        LSRA
        ADDA    SRC+1
        STA     SBLK
        LDD     FF
        ANDA    #$0F            OFFSET = F AND $0FFF
        ADDD    #WINDOW
        TFR     D,X             X = SOURCE POINTER
*
* SAME FOR DESTINATION
        LDD     FF
        LSRA
        LSRA
        LSRA
        LSRA
        ADDA    DST+1
        STA     DBLK
        LDD     FF
        ANDA    #$0F
        ADDD    #WINDOW
        TFR     D,Y             Y = DEST POINTER
*
* CHOOSE THE FAST 16-BIT PATH IF R*10+9 FITS IN 16 BITS,
* I.E. V <= 6553. OTHERWISE USE THE GENERAL 24-BIT PATH.
        LDD     VV
        CMPD    #6553
        BHI     DVLOOP
        ASLB                    V5 = 5 * V
        ROLA
        ASLB
        ROLA
        ADDD    VV
        STD     V5
        LBRA    FAST
*
* GENERAL 24-BIT PATH - ONE DIGIT PER PASS
DVLOOP  LDA     SBLK            MAP SOURCE BLOCK
        STA     PAGREG
        LDB     ,X+             FETCH DIGIT
        STB     DIG
        CMPX    #WINEND         OFF THE END OF THE WINDOW?
        BNE     DV1
        LDX     #WINDOW         YES - NEXT BLOCK
        INC     SBLK
*
* R = R * 10 + DIGIT (24 BIT)
DV1     ASL     RL              R = R * 2
        ROL     RM
        ROL     RH
        LDD     RM              T = R * 2
        STD     TM
        LDA     RH
        STA     TH
        ASL     RL              R = R * 8
        ROL     RM
        ROL     RH
        ASL     RL
        ROL     RM
        ROL     RH
        LDD     RM              R = R*8 + R*2
        ADDD    TM
        STD     RM
        LDA     RH
        ADCA    TH
        STA     RH
        LDD     RM              R = R + DIGIT
        ADDB    DIG
        ADCA    #0
        STD     RM
        LDA     RH
        ADCA    #0
        STA     RH
*
* Q = R / V BY REPEATED SUBTRACTION (AT MOST 9 TIMES)
        CLR     QQ
DV2     LDD     RM
        SUBD    VV
        STD     TM
        LDA     RH
        SBCA    #0
        BCS     DV3             BORROW - R < V, Q IS DONE
        STA     RH
        LDD     TM
        STD     RM
        INC     QQ
        BRA     DV2
*
* RECORD THE FIRST NON-ZERO QUOTIENT DIGIT
DV3     TST     QQ
        BEQ     DV4
        TST     FOUND
        BNE     DV4
        LDD     NN              INDEX = N - CNT
        SUBD    CNT
        STD     F1
        INC     FOUND
*
* STORE THE QUOTIENT DIGIT
DV4     LDA     DBLK            MAP DEST BLOCK
        STA     PAGREG
        LDB     QQ
        STB     ,Y+
        CMPY    #WINEND
        BNE     DV5
        LDY     #WINDOW
        INC     DBLK
*
DV5     LDD     CNT             COUNT DOWN
        SUBD    #1
        STD     CNT
        LBNE    DVLOOP
*
DVEXIT  LDA     #NATIVE         RESTORE NATIVE BLOCK
        STA     PAGREG
        LDD     F1
        STD     RES
        PULS    D,X,Y,U,PC      RESTORE REGISTERS AND RETURN
*
* FAST 16-BIT PATH (V <= 6553)
* D = REMAINDER R, U = QUOTIENT DIGIT, X/Y = SRC/DEST POINTERS
FAST    LDD     #0              R = 0
FLOOP   ASLB                    R = R * 2
        ROLA
        STD     TT2
        ASLB                    R = R * 8
        ROLA
        ASLB
        ROLA
        ADDD    TT2             R = R * 10
        STD     TT2
        LDA     SBLK            MAP SOURCE BLOCK
        STA     PAGREG
        LDB     ,X+             FETCH DIGIT
        CLRA
        ADDD    TT2             R = R * 10 + DIGIT
        CMPX    #WINEND
        BNE     FL1
        LDX     #WINDOW
        INC     SBLK
*
* QUOTIENT: TRY 5V FIRST, THEN SUBTRACT V UNTIL IT GOES NEGATIVE
FL1     SUBD    V5
        BCC     FL2
        ADDD    V5              LESS THAN 5V - UNDO, Q STARTS AT 0
        LDU     #0
        BRA     FL3
FL2     LDU     #5              AT LEAST 5V - Q STARTS AT 5
FL3     SUBD    VV
        BCS     FL4
        LEAU    1,U
        BRA     FL3
FL4     ADDD    VV              UNDO LAST SUBTRACT - D = REMAINDER
        STD     RR2
*
* RECORD THE FIRST NON-ZERO QUOTIENT DIGIT
        TST     FOUND
        BNE     FL5
        CMPU    #0
        BEQ     FL5
        LDD     NN              INDEX = N - CNT
        SUBD    CNT
        STD     F1
        INC     FOUND
*
* STORE THE QUOTIENT DIGIT
FL5     LDA     DBLK
        STA     PAGREG
        TFR     U,D
        STB     ,Y+
        CMPY    #WINEND
        BNE     FL6
        LDY     #WINDOW
        INC     DBLK
*
FL6     LDD     CNT
        SUBD    #1
        STD     CNT
        LBEQ    DVEXIT
        LDD     RR2             RESTORE REMAINDER
        LBRA    FLOOP


*******************************************************
* ADDSUB - DST = DST + OR - SRC FOR DIGITS N-1 DOWN TO F,
* THEN CARRY/BORROW INTO THE DIGITS ABOVE F
ADDSUB  PSHS    D,X,Y,U         KEEP BASIC'S REGISTERS
        CLR     CY
        LDA     SS+1
        STA     SUBF
        LDD     NN              CNT = N - F DIGITS TO DO
        SUBD    FF
        LBLS    ASEXIT          NOTHING TO DO IF N <= F
        STD     CNT
        LDD     NN              START AT INDEX N-1
        SUBD    #1
        STD     IDX
*
* SOURCE BLOCK/POINTER FOR INDEX N-1
        LSRA
        LSRA
        LSRA
        LSRA
        ADDA    SRC+1
        STA     SBLK
        LDD     IDX
        ANDA    #$0F
        ADDD    #WINDOW
        TFR     D,X
*
* DEST BLOCK/POINTER FOR INDEX N-1
        LDD     IDX
        LSRA
        LSRA
        LSRA
        LSRA
        ADDA    DST+1
        STA     DBLK
        LDD     IDX
        ANDA    #$0F
        ADDD    #WINDOW
        TFR     D,Y
*
* MAIN LOOP - ONE DIGIT PER PASS, WORKING DOWNWARDS
ASLOOP  LDA     SBLK            MAP SOURCE BLOCK
        STA     PAGREG
        LDB     ,X
        STB     DIG
        LEAX    -1,X            STEP BACK
        CMPX    #WINDOW-1       OFF THE START OF THE WINDOW?
        BNE     AS1
        LDX     #WINEND-1       YES - PREVIOUS BLOCK
        DEC     SBLK
*
AS1     LDA     DBLK            MAP DEST BLOCK
        STA     PAGREG
        LDB     ,Y              B = DEST DIGIT
        TST     SUBF
        BNE     ASSUB
*
        ADDB    DIG             ADD: B = DEST + SRC + CARRY
        ADDB    CY
        CMPB    #10
        BLO     ASNC
        SUBB    #10
        LDA     #1              CARRY
        BRA     AS2
*
ASSUB   SUBB    DIG             SUBTRACT: B = DEST - SRC - BORROW
        SUBB    CY
        BGE     ASNC
        ADDB    #10
        LDA     #1              BORROW
        BRA     AS2
*
ASNC    CLRA                    NO CARRY OR BORROW
AS2     STA     CY
        STB     ,Y              STORE RESULT DIGIT
        LEAY    -1,Y
        CMPY    #WINDOW-1
        BNE     AS3
        LDY     #WINEND-1
        DEC     DBLK
*
AS3     LDD     CNT
        SUBD    #1
        STD     CNT
        BNE     ASLOOP
*
* PROPAGATE CARRY/BORROW INTO DIGITS F-1 DOWN TO 0
* Y AND DBLK ALREADY POINT AT INDEX F-1
        TST     CY
        BEQ     ASEXIT
        LDD     FF
        BEQ     ASEXIT          NOTHING ABOVE INDEX 0
        STD     CNT
*
PRLOOP  LDA     DBLK
        STA     PAGREG
        LDB     ,Y
        TST     SUBF
        BNE     PRSUB
        INCB                    ADD CARRY
        CMPB    #10
        BLO     PRLAST
        CLRB                    9+1 = 0, CARRY ON
        BRA     PRNEXT
PRSUB   DECB                    SUBTRACT BORROW
        BPL     PRLAST
        LDB     #9              0-1 = 9, BORROW ON
PRNEXT  STB     ,Y
        LEAY    -1,Y
        CMPY    #WINDOW-1
        BNE     PR1
        LDY     #WINEND-1
        DEC     DBLK
PR1     LDD     CNT
        SUBD    #1
        STD     CNT
        BNE     PRLOOP
        BRA     ASEXIT          RAN OFF THE TOP - IGNORE
*
PRLAST  STB     ,Y              CARRY/BORROW ABSORBED
*
ASEXIT  LDA     #NATIVE         RESTORE NATIVE BLOCK
        STA     PAGREG
        PULS    D,X,Y,U,PC

*******************************************************
* MESSAGES
PROMPT  FCC     'NUMBER OF DIGITS? '
        FCB     4
MSG5    FCC     'ARCTAN(1/5)'
        FCB     4
MSG239  FCC     'ARCTAN(1/239)'
        FCB     4

*******************************************************
* PARAMETERS FOR DIVIDE AND ADDSUB
SRC     RMB     2               SOURCE BUFFER FIRST BLOCK
DST     RMB     2               DEST BUFFER FIRST BLOCK
NN      RMB     2               N, DIGITS IN EACH BUFFER
FF      RMB     2               F, FIRST DIGIT TO PROCESS
VV      RMB     2               V, DIVISOR
SS      RMB     2               0 = ADD, 1 = SUBTRACT
RES     RMB     2               RESULT FROM DIVIDE (F1)

* WORKING STORAGE
N1      RMB     2               DIGITS WANTED
X2      RMB     2               X*X FOR THE CURRENT SERIES
ZBUF    RMB     1               ACCUMULATOR BUFFER FOR ARCTAN
MM      RMB     2               TERM NUMBER
SGN     RMB     2               0 = ADD, 1 = SUBTRACT
CBLK    RMB     1               CURRENT BLOCK (CLEAR/FILL/MUL/PRINT)
MULT    RMB     1               MULTIPLIER FOR MULSM
CARRYO  RMB     1               CARRY OUT OF MULSM
MIDX    RMB     2               INDEX FOR MULSM
LINCNT  RMB     1               DIGITS LEFT ON THIS LINE
GNVAL   RMB     2               GETNUM VALUE
GNTMP   RMB     2
GNDIG   RMB     1
GNCNT   RMB     1
CNT     RMB     2               DIGITS LEFT TO DO
F1      RMB     2               FIRST NON-ZERO QUOTIENT INDEX
SBLK    RMB     1               CURRENT SOURCE BLOCK
DBLK    RMB     1               CURRENT DEST BLOCK
DIG     RMB     1               DIGIT JUST FETCHED
QQ      RMB     1               QUOTIENT DIGIT
FOUND   RMB     1               NON-ZERO DIGIT SEEN FLAG
RH      RMB     1               24-BIT REMAINDER
RM      RMB     1
RL      RMB     1
TH      RMB     1               24-BIT TEMPORARY
TM      RMB     1
TL      RMB     1
CY      RMB     1               CARRY OR BORROW (0/1)
SUBF    RMB     1               SUBTRACT FLAG
IDX     RMB     2               WORKING DIGIT INDEX
V5      RMB     2               5 * V FOR THE FAST PATH
TT2     RMB     2               R * 10 TEMPORARY
RR2     RMB     2               SAVED REMAINDER

        END     START

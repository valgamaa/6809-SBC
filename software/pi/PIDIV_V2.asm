* PIDIV - MACHINE CODE DIVIDE FOR THE MACHIN PI PROGRAM
*
* DIVIDES A DIGIT BUFFER BY A 16-BIT INTEGER, ONE DECIMAL
* DIGIT PER BYTE IN PAGED RAM. REPLACES BASIC LINES 8000-8220.
*
*   DST(F..N-1) = SRC(F..N-1) / V
*
* SRC AND DST MAY BE THE SAME BUFFER (IN-PLACE DIVIDE).
* RETURNS F1, THE INDEX OF THE FIRST NON-ZERO QUOTIENT
* DIGIT (N IF THE QUOTIENT IS ALL ZERO), IN RES.
*
* PAGING: 4K WINDOW AT $E000-$EFFF, BLOCK SELECTED BY
* WRITING $F280. $F280 MUST NEVER BE READ - A READ LATCHES
* THE DATA BUS INTO THE PAGE REGISTER. BLOCK 14 (THE NATIVE
* $E000 RAM) IS MAPPED BACK IN BEFORE RETURNING TO BASIC.
*
* CALLED FROM XBASIC WITH X=USR(0), VECTOR AT $BFFD.

PAGREG  EQU     $F280           PAGE SELECT REGISTER (WRITE ONLY)
WINDOW  EQU     $E000           START OF 4K WINDOW
WINEND  EQU     $F000           FIRST ADDRESS PAST THE WINDOW
NATIVE  EQU     14              BLOCK THAT IS NORMALLY AT $E000
USRARG  EQU     $BFFB           USR ARGUMENT/RESULT (MEMEND-4)

        ORG     $C100

* PARAMETER BLOCK - FILLED BY BASIC WITH DPOKE
SRC     RMB     2               $C100 SOURCE BUFFER FIRST BLOCK
DST     RMB     2               $C102 DEST BUFFER FIRST BLOCK
NN      RMB     2               $C104 N, DIGITS IN BUFFER
FF      RMB     2               $C106 F, FIRST DIGIT TO PROCESS
VV      RMB     2               $C108 V, DIVISOR
SS      RMB     2               $C10A S, ADD/SUB (NOT USED HERE)
RES     RMB     2               $C10C RESULT (F1)
        RMB     2               $C10E SPARE

* START OF CODE AT $C110
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
* MAIN LOOP - ONE DIGIT PER PASS
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
DVEXIT  LDA     #NATIVE         RESTORE NATIVE BLOCK FOR BASIC
        STA     PAGREG
        LDD     F1
        STD     RES
        STD     USRARG          ALSO RETURN IT AS THE USR VALUE
        PULS    D,X,Y,U,PC      RESTORE REGISTERS AND RETURN

* WORKING STORAGE
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

        END

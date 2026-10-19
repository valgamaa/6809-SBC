* DESFILE - ENCRYPT OR DECRYPT A TEXT FILE WITH THE MC6859 DSD
*
* FLEX 9 COMMAND, A MACHINE-CODE VERSION OF DESFILE.BAS.
* ASKS FOR E OR D, THE INPUT FILE, THE OUTPUT FILE AND A KEY
* OF UP TO 8 CHARACTERS (DEFAULT EXTENSION .TXT).
*
* CIPHERTEXT IS WRITTEN AS HEX TEXT, 64 HEX DIGITS PER LINE,
* DES ECB MODE, LAST BLOCK PADDED WITH $00 BYTES - THE SAME
* FORMAT AS DESFILE.BAS, SO FILES CAN GO BETWEEN THE TWO.
*
* THE MC6859 IS RATED AT 1 MHZ: USE THE 1 MHZ BOARD.
*
* MC6859 REGISTERS (BASE $F278, CS LINES ON A3-A5)
*   $F278 W  WRITE DATA (BYTES 1-7)
*   $F279 W  RESET
*   $F27A W  ENTER MAJOR KEY       R  STATUS (D7 PARITY ERR, D6 BUSY)
*   $F27C W  DECIPHER (BYTE 8)     R  READ DATA
*   $F27D W  ENCIPHER (BYTE 8)
* ONLY PLAIN LOADS AND STORES ARE USED ON THESE REGISTERS:
* CLR, INC AND THE LIKE READ BEFORE THEY WRITE.

* FLEX ENTRY POINTS
WARMS   EQU     $CD03           RETURN TO FLEX
PUTCHR  EQU     $CD18           OUTPUT CHARACTER IN A
INBUFF  EQU     $CD1B           INPUT A LINE TO THE LINE BUFFER
PSTRNG  EQU     $CD1E           CR/LF THEN STRING AT X TO $04
PCRLF   EQU     $CD24           OUTPUT CR/LF
GETFIL  EQU     $CD2D           FILE SPEC FROM LINE BUFFER TO FCB X
SETEXT  EQU     $CD33           DEFAULT EXTENSION A INTO FCB X
RPTERR  EQU     $CD3F           REPORT THE ERROR IN FCB X
LBPTR   EQU     $CC14           LINE BUFFER POINTER
FMSCLS  EQU     $D403           CLOSE ALL FILES
FMS     EQU     $D406           FILE MANAGEMENT SYSTEM CALL

* FMS FUNCTION CODES AND ERRORS
FRWBYT  EQU     0               READ OR WRITE NEXT BYTE
FOPENR  EQU     1               OPEN FOR READ
FOPENW  EQU     2               OPEN FOR WRITE
FCLOSE  EQU     4               CLOSE FILE
ERREOF  EQU     8               READ PAST END OF FILE
EXTTXT  EQU     1               SETEXT CODE FOR .TXT

* MC6859
DSDDAT  EQU     $F278           WRITE DATA BYTES 1-7
DSDRST  EQU     $F279           RESET
DSDKEY  EQU     $F27A           WRITE: ENTER MAJOR KEY
DSDSTA  EQU     $F27A           READ: STATUS
DSDDEC  EQU     $F27C           WRITE: DECIPHER TRIGGER
DSDRD   EQU     $F27C           READ: RESULT DATA
DSDENC  EQU     $F27D           WRITE: ENCIPHER TRIGGER

HEXLIN  EQU     64              HEX DIGITS PER OUTPUT LINE
CR      EQU     $0D

        ORG     $0100

*******************************************************
* MAIN PROGRAM
START   LDX     #MSGMOD         ENCRYPT OR DECRYPT?
        JSR     PSTRNG
        JSR     INBUFF
        LDX     LBPTR
ST1     LDA     ,X+             FIRST NON-SPACE CHARACTER
        CMPA    #$20
        BEQ     ST1
        ANDA    #$DF            UPPER CASE
        CMPA    #'E
        BEQ     ST2
        CMPA    #'D
        BNE     START
ST2     STA     MODE
*
GETIN   LDX     #MSGIN          INPUT FILE
        JSR     PSTRNG
        JSR     INBUFF
        LDX     #FCBIN
        JSR     GETFIL
        BCS     GETIN
        LDA     #EXTTXT
        JSR     SETEXT
*
GETOUT  LDX     #MSGOUT         OUTPUT FILE
        JSR     PSTRNG
        JSR     INBUFF
        LDX     #FCBOUT
        JSR     GETFIL
        BCS     GETOUT
        LDA     #EXTTXT
        JSR     SETEXT
*
        LDX     #MSGKEY         KEY
        JSR     PSTRNG
        JSR     INBUFF
        JSR     LOADKY          BUILD AND LOAD THE KEY
*
        LDX     #FCBIN          OPEN THE FILES
        LDA     #FOPENR
        STA     ,X
        JSR     FMS
        LBNE    FERR
        CLR     ,X              FUNCTION 0 FROM NOW ON
        LDX     #FCBOUT
        LDA     #FOPENW
        STA     ,X
        JSR     FMS
        LBNE    FERR
        CLR     ,X
*
        CLR     NBLK            BYTES IN THE CURRENT BLOCK
        CLR     LINCNT          HEX DIGITS ON THE CURRENT LINE
        LDA     #CR
        STA     LASTWR          NOTHING WRITTEN YET
        LDA     MODE
        CMPA    #'D
        LBEQ    DECRYP

*******************************************************
* ENCRYPT: TEXT BYTES -> 8-BYTE BLOCKS -> HEX TEXT
ENCRYP  JSR     RDBYTE          NEXT PLAINTEXT BYTE
        BCS     EN2             END OF FILE
        LDB     NBLK
        LDX     #BLOCK
        STA     B,X
        INCB
        STB     NBLK
        CMPB    #8
        BNE     ENCRYP
        JSR     ENCBLK
        BRA     ENCRYP
*
EN2     LDB     NBLK            PAD THE LAST BLOCK WITH ZEROS
        BEQ     EN4
        LDX     #BLOCK
EN3     CLR     B,X
        INCB
        CMPB    #8
        BNE     EN3
        JSR     ENCBLK
EN4     TST     LINCNT          FINISH A PART LINE
        BEQ     EN5
        LDA     #CR
        JSR     WRBYTE
EN5     JMP     FINISH

* ENCBLK - ENCIPHER BLOCK, WRITE THE RESULT AS HEX
ENCBLK  LDX     #BLOCK
        LDB     #7
EB1     LDA     ,X+             BYTES 1-7 TO WRITE DATA
        STA     DSDDAT
        DECB
        BNE     EB1
        LDA     ,X              BYTE 8 TO THE ENCIPHER TRIGGER
        STA     DSDENC
        JSR     RESULT          READ THE 8 RESULT BYTES
        LDX     #RESBUF
        LDB     #8
EB2     LDA     ,X+
        PSHS    A,B,X
        LSRA                    HIGH DIGIT
        LSRA
        LSRA
        LSRA
        JSR     WRHEX
        LDA     ,S              LOW DIGIT
        ANDA    #$0F
        JSR     WRHEX
        LDA     LINCNT
        ADDA    #2
        STA     LINCNT
        CMPA    #HEXLIN
        BNE     EB3
        CLR     LINCNT          END OF LINE
        LDA     #CR
        JSR     WRBYTE
EB3     PULS    A,B,X
        DECB
        BNE     EB2
        CLR     NBLK
        RTS

* WRHEX - WRITE THE HEX DIGIT FOR THE LOW NIBBLE OF A
WRHEX   ADDA    #'0
        CMPA    #'9
        BLS     WH1
        ADDA    #7              'A' TO 'F'
WH1     JMP     WRBYTE

*******************************************************
* DECRYPT: HEX TEXT -> 8-BYTE BLOCKS -> TEXT BYTES
DECRYP  CLR     HALF            NO HIGH DIGIT WAITING
DE1     JSR     RDBYTE
        BCS     DE5             END OF FILE
        JSR     HEXVAL          A = 0-15, OR CARRY SET IF NOT HEX
        BCS     DE1             SKIP CR, SPACES AND ANYTHING ELSE
        TST     HALF
        BNE     DE2
        ASLA                    FIRST DIGIT OF A PAIR
        ASLA
        ASLA
        ASLA
        STA     HIGH
        INC     HALF
        BRA     DE1
DE2     ORA     HIGH            SECOND DIGIT - A WHOLE BYTE
        CLR     HALF
        LDB     NBLK
        LDX     #BLOCK
        STA     B,X
        INCB
        STB     NBLK
        CMPB    #8
        BNE     DE1
        JSR     DECBLK
        BRA     DE1
*
DE5     LDA     LASTWR          END THE LAST LINE IF IT HAS NO CR
        CMPA    #CR
        BEQ     DE6
        LDA     #CR
        JSR     WRBYTE
DE6     TST     NBLK            LEFTOVER BYTES?
        BEQ     DE7
        LDX     #MSGPRT
        JSR     PSTRNG
DE7     JMP     FINISH

* DECBLK - DECIPHER BLOCK, WRITE THE TEXT BYTES (DROPPING $00)
DECBLK  LDX     #BLOCK
        LDB     #7
DB1     LDA     ,X+             BYTES 1-7 TO WRITE DATA
        STA     DSDDAT
        DECB
        BNE     DB1
        LDA     ,X              BYTE 8 TO THE DECIPHER TRIGGER
        STA     DSDDEC
        JSR     RESULT
        LDX     #RESBUF
        LDB     #8
DB2     LDA     ,X+
        BEQ     DB3             $00 IS PADDING
        JSR     WRBYTE
DB3     DECB
        BNE     DB2
        CLR     NBLK
        RTS

* HEXVAL - CONVERT HEX CHARACTER IN A TO 0-15, CARRY SET IF NOT HEX
HEXVAL  CMPA    #'0
        BLO     HVBAD
        CMPA    #'9
        BLS     HV1
        ANDA    #$DF            UPPER CASE
        CMPA    #'A
        BLO     HVBAD
        CMPA    #'F
        BHI     HVBAD
        SUBA    #7
HV1     SUBA    #'0
        ANDCC   #$FE
        RTS
HVBAD   ORCC    #$01
        RTS

*******************************************************
* LOADKY - BUILD AN 8-BYTE ODD-PARITY KEY FROM THE LINE BUFFER
* AND LOAD IT AS THE MAJOR KEY. EACH CHARACTER'S 7 BITS GO IN
* D7-D1 AND D0 MAKES THE PARITY ODD. SHORT KEYS ARE PADDED
* WITH SPACES, AS IN DESFILE.BAS.
LOADKY  LDX     LBPTR
        LDY     #KEY
        LDB     #8
LK1     LDA     ,X
        CMPA    #CR
        BEQ     LK2             END OF THE TYPED KEY
        LEAX    1,X
        BRA     LK3
LK2     LDA     #$20            PAD WITH SPACES
LK3     ANDA    #$7F            7 BITS
        STA     KTMP
        ASLA                    INTO D7-D1
        STA     ,Y
        CLR     KCNT            COUNT THE ONE BITS
        LDA     #7
        STA     KLOOP
LK4     LSR     KTMP
        BCC     LK5
        INC     KCNT
LK5     DEC     KLOOP
        BNE     LK4
        LDA     KCNT            EVEN COUNT - SET D0 FOR ODD PARITY
        BITA    #1
        BNE     LK6
        LDA     ,Y
        ORA     #1
        STA     ,Y
LK6     LEAY    1,Y
        DECB
        BNE     LK1
*
        LDA     #0              RESET THE CHIP
        STA     DSDRST
        LDX     #KEY            ENTER THE MAJOR KEY
        LDB     #8
LK7     LDA     ,X+
        STA     DSDKEY
        DECB
        BNE     LK7
        JSR     WAITRD          WAIT FOR NOT BUSY, CHECK PARITY
        RTS

* WAITRD - WAIT UNTIL THE CHIP IS NOT BUSY. ABORTS ON A PARITY
* ERROR OR A TIMEOUT.
WAITRD  LDX     #2000
WR1     LDA     DSDSTA
        BMI     PARERR          D7 SET - PARITY ERROR
        BITA    #$40
        BEQ     WR2             D6 CLEAR - READY
        LEAX    -1,X
        BNE     WR1
        LDX     #MSGTIM
        BRA     ABORT
WR2     RTS
PARERR  LDX     #MSGPAR
        BRA     ABORT

* RESULT - WAIT, THEN READ THE 8 RESULT BYTES INTO RESBUF
RESULT  BSR     WAITRD
        LDX     #RESBUF
        LDB     #8
RS1     LDA     DSDRD
        STA     ,X+
        DECB
        BNE     RS1
        RTS

*******************************************************
* FILE I/O
* RDBYTE - READ THE NEXT BYTE OF THE INPUT FILE INTO A.
* CARRY SET AT END OF FILE. ANY OTHER ERROR ABORTS.
RDBYTE  PSHS    B,X
        LDX     #FCBIN
        JSR     FMS
        BNE     RB1
        PULS    B,X
        ANDCC   #$FE
        RTS
RB1     LDB     1,X             ERROR NUMBER
        CMPB    #ERREOF
        BNE     FERR
        PULS    B,X
        ORCC    #$01
        RTS

* WRBYTE - WRITE A TO THE OUTPUT FILE. ERRORS ABORT.
WRBYTE  PSHS    B,X
        STA     LASTWR
        LDX     #FCBOUT
        JSR     FMS
        BNE     FERR
        PULS    B,X
        RTS

* FERR - REPORT THE FMS ERROR FOR THE FCB AT X, CLOSE EVERYTHING
FERR    JSR     RPTERR
        JSR     FMSCLS
        LDA     #0
        STA     DSDRST
        JMP     WARMS

* ABORT - PRINT THE MESSAGE AT X, CLOSE EVERYTHING
ABORT   JSR     PSTRNG
        JSR     FMSCLS
        LDA     #0
        STA     DSDRST
        JMP     WARMS

* FINISH - CLOSE BOTH FILES, RESET THE CHIP, SAY DONE
FINISH  LDX     #FCBIN
        LDA     #FCLOSE
        STA     ,X
        JSR     FMS
        BNE     FERR
        LDX     #FCBOUT
        LDA     #FCLOSE
        STA     ,X
        JSR     FMS
        BNE     FERR
        LDA     #0
        STA     DSDRST
        LDX     #MSGDON
        JSR     PSTRNG
        JSR     PCRLF
        JMP     WARMS

*******************************************************
* MESSAGES
MSGMOD  FCC     'ENCRYPT OR DECRYPT (E/D)? '
        FCB     4
MSGIN   FCC     'INPUT FILE? '
        FCB     4
MSGOUT  FCC     'OUTPUT FILE? '
        FCB     4
MSGKEY  FCC     'KEY (UP TO 8 CHARS): '
        FCB     4
MSGPAR  FCC     'DES PARITY ERROR'
        FCB     4
MSGTIM  FCC     'DES BUSY TIMEOUT'
        FCB     4
MSGPRT  FCC     'WARNING: INPUT WAS NOT WHOLE 8-BYTE BLOCKS'
        FCB     4
MSGDON  FCC     'DONE'
        FCB     4

*******************************************************
* WORKING STORAGE
MODE    RMB     1               'E' OR 'D'
NBLK    RMB     1               BYTES IN THE CURRENT BLOCK
LINCNT  RMB     1               HEX DIGITS ON THE CURRENT LINE
LASTWR  RMB     1               LAST BYTE WRITTEN TO THE OUTPUT
HALF    RMB     1               1 = HIGH HEX DIGIT WAITING
HIGH    RMB     1               THE WAITING HIGH DIGIT, SHIFTED
KTMP    RMB     1               KEY BUILDING
KCNT    RMB     1
KLOOP   RMB     1
KEY     RMB     8               THE 8 KEY BYTES WITH PARITY
BLOCK   RMB     8               BLOCK TO ENCIPHER OR DECIPHER
RESBUF  RMB     8               RESULT FROM THE CHIP
FCBIN   RMB     320             INPUT FILE CONTROL BLOCK
FCBOUT  RMB     320             OUTPUT FILE CONTROL BLOCK

        END     START

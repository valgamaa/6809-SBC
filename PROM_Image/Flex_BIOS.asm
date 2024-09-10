********************************************
* MC68681 REGISTER EQUATES
********************************************
PORTA		EQU		$F340
PORTB		EQU		$F348
* Read registers
ModeReg		EQU     0           	; Mode Register 
Status		EQU     1         		; Status Register 
RxBuff		EQU     3         		; Receiver Buffer 
PortCR		EQU     4         		; Input Port Change Register
IntReg		EQU     5         		; Interrupt Staus Register
CounterMSBA	EQU     6         		; Counter Mode: MSB
CounterLSBA	EQU     7         		; Counter Mode: LSB
StartCount1	EQU     14        		; Start-counter command
StartCount2	EQU     15        		; Start-counter command

* Write registers
ClkSel		EQU     1          		; Clock-Select Register 
Command		EQU     2          		; Command register 
TxBuff		EQU     3          		; Transmitter buffer 
AuxCont		EQU     4          		; Auxillary control register
IntMask		EQU     5          		; Interrupt mask register
CTUpper		EQU     6          		; Counter/timer upper register
CTLower		EQU     7          		; Counter/timer lower register
OPSet		EQU     14         		; Output port set bits
OPReset		EQU     15         		; Output port reset bits
*******************************************
* CF REGS
*******************************************
CFADDRESS1	EQU 	$F300
CFADDRESS2	EQU 	$F2C0
CFDATA		EQU		$00		; DATA PORT
CFERROR		EQU		$01		; ERROR CODE (READ)
CFFEATURE	EQU		$01		; FEATURE SET (WRITE)
CFSECCNT	EQU		$02		; NUMBER OF SECTORS TO TRANSFER
CFLBA0		EQU		$03		; SECTOR ADDRESS LBA 0 [0:7]
CFLBA1		EQU		$04		; SECTOR ADDRESS LBA 1 [8:15]
CFLBA2		EQU		$05		; SECTOR ADDRESS LBA 2 [16:23]
CFLBA3		EQU		$06		; SECTOR ADDRESS LBA 3 [24:27 (LSB)]
CFSTATUS	EQU		$07		; STATUS (READ)
CFCOMMAND	EQU		$07		; COMMAND SET (WRITE)

CFSTATUSL1	EQU		CFADDRESS1+CFSTATUS
CFSTATUSL2	EQU		CFADDRESS2+CFSTATUS
*******************************************
* Console I/O vector table
	ORG	$D3E5
INCHNE_T 	FDB	INCHNE
IHNDLR_T	FDB	IHNDLR
SWIVEC_T	FDB	SWIVEC
IRQVEC_T	FDB	IRQVEC
TMOFF_T		FDB	TMOFF
TMON_T		FDB	TMON
TMINT_T		FDB	TMINT
MONITR_T	FDB	MONITR
TINIT_T		FDB	TINIT
STAT_T		FDB	STAT
OUTCH_T		FDB	OUTCH
INCH_T		FDB	INCH
*******************************************
* DISK I/O vector table
	ORG	$DE00
READ_T 		FDB	READ
WRITE_T		FDB	WRITE
VERIFY_T	FDB	VERIFY
RESTORE_T	FDB	RESTORE
DRIVE_T		FDB	DRIVE
CHKRDY_T	FDB	CHKRDY
QUICK_T		FDB	QUICK
INIT_T		FDB	INIT
WARM_T		FDB	WARM
SEEK_T		FDB	SEEK
*******************************************

MONITOR		EQU		$E03C			; Monitor entry point
*******************************************
* Flex I/O routines 
*******************************************
	ORG	$F800
********************************
* PROGRAM VARIABLES
********************************
CFADDCURNT	FCB		$00, $00
CFDRVCURNT	FCB		$00
*******************************************
* Console routines 
*******************************************
* Input character w/o echo *
INCHNE	PSHS	U				; Preserve the U register
INWAIT	LDU     #PORTA			; Load 68681 base address
        LDA     Status,U		; Load STATUS register
        LSRA					; Test receiver register flag
        BCC		INWAIT			; Wait if nothing
        LDA		RxBuff,U		; Load DATA byte
		PULS	U				; Restore 'U'
   		RTS                     ; Return with received character in 'A'

* interrupt handler *		
IHNDLR	RTS						; Empty stub
				
* SWI interrupt handler *		
SWIVEC	RTS						; Empty stub
				
* IRQ interrupt handler *		
IRQVEC	RTS						; Empty stub
				
* Timer OFF routine *
TMOFF	RTS						; Empty stub
		
* Timer ON routine *
TMON	RTS						; Empty stub
		
* Timer initialisation *
TMINT	RTS						; Empty stub
		
* Return to the Assist09 monitor *
MONITR	LDU     #PORTA			; Load 68681 base address					; 
        LDA		#$80			; Re-enable the ROM
        STA		OPSet,U
		LBRA	MONITOR			; and jump into the monitor

* Terminal initialisation *
TINIT 	PSHS	A, X
		LDX		#PORTA
		LDA		#$10			; Reset MR pointer
		STA		Command, X
        LDA		#$93			; Configure the selected port as
        STA		ModeReg, X		; 8 bits & no parity & RTR
		LDA		#$34			; Set MR2 for 1 stop-bit
        						; Set bits 5, 4 to enable flow control
        STA		ModeReg, X
        LDA		#%01110000
        STA		AuxCont, X
        LDA		#$CC			; Set Rx & Tx speed to 38.4k
        STA		ClkSel, X
        LDA		#$20			; Reset the Rx
        STA		Command, X
        LDA		#$30			; Reset the Tx
        STA		Command, X
		LDA		#$45			; Enable Rx & Tx
        STA		Command, x
		LDA 	#$01			; Set the RTR Output
		STA		OPSet, X
		PULS A, X
       	RTS
		
* Check terminal status *
STAT	PSHS	A,U				; Preserve the A & U registers
		LDU     #PORTA			; Load 68681 base address
        LDA     Status,U		; Load STATUS register
        LSRA					; Test receiver register flag
		PULS	A,U				; Restore 'A' & 'U'
   		RTS                     ; Return with received character in 'A'

* Output character *		
OUTCH	PSHS    B,U         		; Save registers & work byte
		LDU     #PORTA			; Load 68681 base address
OUTWAIT LDB     Status,U		; Load STATUS register
		BITB    #$04            ; Check if the port is ready to send
        BEQ		OUTWAIT			; Wait if not ready
        LDB		#$41
		STA     TxBuff,U        ; Write to the output buffer
		PULS	B,U				; Restore 'U'
   		RTS                     ; Return with received character in 'A'

* Input character with echo *		
INCH	PSHS	B,U				; Preserve the U register
WAITIN	LDU     #PORTA			; Load 68681 base address
        LDA     Status,U		; Load STATUS register
        LSRA					; Test receiver register flag
        BCC		WAITIN			; Wait if nothing
        LDA		RxBuff,U		; Load received character
        PSHS	A				; Save the received character on the stack
WAITOUT LDB     Status,U		; Load STATUS register
		BITB    #$04            ; Check if the port is ready to send
        BEQ		WAITOUT			; Wait if not ready
		STA     TxBuff,U        ; Write to the output buffer
		PULS	A,B,U				; Restore the received character in 'A' and 'U'
   		RTS                     ; Return with received character in 'A'
        

*******************************************
* Disk driver routines 
*******************************************
* CF Cards have more capacity than Flex can address, so one card can represent two
* drives. Flex supports a maximum of four drives, so two CF Cards satisfy that.
* The structure on the CF Card is -
* LBA 0 - Sector
* LBA 1 - Track
* LBA 2 - Drive 0/1 or 2/3
* LBA 3 - Set to 0
* LBA 4 - Set to 0
*
* LBA 1 needs to be saved for each drive so that Flex 'knows' where the 'read head' is.

*******************************************
* CF CARD VARIABLES
*******************************************
CFADDRESS 	FCB		$F300
DRIVEID		EQU		$EC
LBA01		FCB		$00
LBA11		FCB		$00
LBA21		FCB		$00
LBA31		FCB		$00
DRIVENO		FCB		$00
DATABLK		EQU		$1000
*******************************************

******************************************
* Read a single sector *
*ENTRY - (X) = Address in memory where sector is to be placed.
*        (A) = Track Number
*        (B) = Sector Number
*EXIT  - (X) May be destroyed
*        (A) May be destroyed
*        (B) = Error condition
*        (Z) = 1 if no error
*            = 0 if an error
READ	PSHS	Y
		LDY		#CFADDRESS2			; Load the base address of the current active CF Card
		STB		CFLBA0,Y			; Store the Sector number
		JSR		DATWAIT
		STA		CFLBA1,Y			; Store the Track number
		JSR		DATWAIT
		LDA		#$00				; Loads 00 now, needs to be changed to set the drive
		STA		CFLBA2, Y			; Load the drive number
		JSR		DATWAIT
		LDA		#$E0
		STA		CFLBA3, Y		
		JSR		DATWAIT				; The wanted sector is selected, and can now be read.	
		LDB		#$01
		STB		CFSECCNT,Y
		JSR		DATWAIT		
		LDB		#$20				; Send read command to the CF Card
		STB		CFCOMMAND,Y
		JSR		DATWAIT
		LDA		#$00				; Set a loop counter to read the first 256 bytes of DATA
FLEXLP	JSR		DATWAIT
		LDB		CFDATA, Y			; Read the data byte
		STB		,X+					; Write it to the buffer	
		INCA
		BNE		FLEXLP				; Count to 256 - a Flex sector
RDTAIL	JSR		DATWAIT
		LDB		CFDATA, Y			; Now read and discard the rest of the data		
		LDA		CFSTATUS, Y		
		BITA	#$08
		BNE		RDTAIL
		PULS	Y	
		CLRB		
		RTS
******************************************
		
******************************************
* Write a single sector *
*ENTRY - (X) = Address of 256 memory buffer containing data
*              to be written to disk
*        (A) = Track Number
*        (B) = Sector Number
*EXIT  - (X) May be destroyed
*        (A) May be destroyed
*        (B) = Error condition
*        (Z) = 1 if no error
*            = 0 if an error
WRITE	PSHS	A,Y				; Save A for internal working
		LDA		DRIVENO
		LDY		#CFADDRESS2		; Address CF card 2.
		BITA	#$02			; Check Bit-2 to see which CF card is selected
		PULS	A				; Continue with original contents of A
		BNE		WRITE1			; Branch if 2nd CF card is selected
		LDY		#CFADDRESS1		; Address CF card 1.
WRITE1	STA		CFLBA1, Y		; Load the Track number
		JSR		CMDWAIT
		STB		CFLBA0, Y		; Load the Sector number
		JSR		CMDWAIT
		LDA		DRIVENO
		ANDA	#$01			; First or second drive on the Card?
		STA		CFLBA2, Y		; Load the drive number
		JSR		CMDWAIT			; The wanted sector is selected, and can now be read.	
		LDB		#$20			; Send read command to the CF Card
		STB		CFCOMMAND, Y
		JSR		DATWAIT
		LDA		#$00			; Set a loop counter to read the first 256 bytes of DATA
WRLOOP	LDB		CFDATA, Y		; Read the data byte
		STB		,X+				; Write it to the buffer
		JSR		DATWAIT
		INCA
		BNE		WRLOOP			; Count to 256 - a Flex sector
WRTAIL	LDB		CFDATA, Y		; Now read and discard the rest of the data
		JSR		DATWAIT
		LDA		CFSTATUS, Y		
		BITA	#$08
		BNE		WRTAIL	
		PULS	Y			
		RTS
******************************************
		
******************************************
* Verify last sector written *
*ENTRY - No entry parameters
*EXIT  - (X) May be destroyed
*        (A) May be destroyed
*        (B) = Error condition
*		 (Z) = 1 if no error
*           = 0 if an error
VERIFY	NOP						; 
		RTS
******************************************
		
******************************************
* Restore head to track #0 *
*ENTRY - (X) = FCB address (3,X contains drive number)
*EXIT  - (X) May be destroyed
*        (A) May be destroyed
*        (B) = Error condition
*        (Z) = 1 if no error
*			 = 0 if an error
RESTORE	LDA		$03, X				; Get drive Number
		BITA	#$02				; Drive 2 or 3 selected if set.
		BNE		RESTOR1				; Set the base address for the CF Card.
		LDX		#CFADDRESS1
		BRA		RESTOR2
RESTOR1	LDX		#CFADDRESS2
RESTOR2	ANDA	#$01
		STA		CFLBA2,X
		CLRB						; And set the status bits before returning from this subroutine.
		RTS
******************************************
		
******************************************
* Select the specified drive *
* This can be combined with CHKRDY as the drive needs to be chacked once selected. 
*ENTRY - (X) = FCB address (3,X contains drive number)
*EXIT  - (X) May be destroyed
*        (A) May be destroyed
*        (B) = $0F if non-existent drive
*            = Error condition otherwise
*        (Z) =1 if no error
*            =0 if an error
*        (C) =0 if no error
*            =1 if an error
*
* Keep track of the current Drive with the variable DRIVENO, and use it
* to set the base address for the CF Card, and the value written to LBA 2.
*
DRIVE	LDA		$03, X				; Get drive Number & save it for future use (CF Cards
		STA		DRIVENO				; don't know which drive is selected).
		BITA	#$02				; Drive 2 or 3 selected if set.
		BNE		DRIVE1				; Set the base address for the CF Card.
		LDX		#CFADDRESS1
		STX		CFADDCURNT
		BRA		DRIVE2
DRIVE1	LDX		#CFADDRESS2
		STX		CFADDCURNT
DRIVE2	ANDA	#$01
		STA		CFLBA2,X
		STA		CFDRVCURNT
		CLRB						; And set the status bits before returning from this subroutine.
		RTS
******************************************
		
******************************************
* Check for drive ready *
* Wait for CF Card ready when reading/writing to CF Card
*ENTRY - (X) = FCB address (3,X contains drive number)
*EXIT  - (X) May be destroyed
*        (A) May be destroyed
*        (B) = Error condition
*        (Z) = 1 if drive ready
*            = 0 if not ready
*        (C) = 0 if drive ready
*            = 1 if not ready
* Check for RDY = 0 (bit 6)
CHKRDY	LDA		$03, X				; Get drive Number
		BITA	#$02				; Drive 1 or 3 selected if set.
		BNE		CHKRDY1				; Set the base address for the CF Card.
		LDX		#CFADDRESS1
		BRA		CHKRDY2
CHKRDY1	LDX		#CFADDRESS2
CHKRDY2	LDA		CFSTATUS,X
		ANDA	#$01
		STA		CFLBA2,X
		BITA	#$C0				; Isolate the ready bit
		BNE		CHKRDY3				; CF card not ready
		CLRB						; And set the status bits before returning from this subroutine.
		RTS
CHKRDY3 LDB		#$FF
		RTS
******************************************
		
******************************************
* Quick check for drive ready *
* ENTRY - (X) = FCB address (3,X contains drive number)
* EXIT  - (X) May be destroyed
*         (A) May be destroyed
*         (B) = Error condition
*         (Z) = 1 if drive ready
*             = 0 if not ready
*         (C) = 0 if drive ready
*             = 1 if not ready
* The same code can be used as for CHKRDY as for CF Cards it is the same operation.
QUICK	BRA		CHKRDY
		RTS	
		
******************************************
*  Driver initialise (cold start) *
*ENTRY - No parameters
*EXIT  - A, B, X, Y, and U may be destroyed
* Assume there are two CF cards fitted, to allow for future expansion, as writing
* to non-existant hardware does no harm. CMDWAIT must be modified with a time-out.
INIT	LDX		#CFADDRESS1		; Address CF card 1.
		BSR		INIT2			; Initialise it
		LDX		#CFADDRESS2		; Address CF card 2.
		BSR		INIT2			; Initialise it
		RTS						; Cards configured, return.

INIT2	JSR		CMDWAIT
		LDB		#$04			; Reset the CF Card
		STB		CFCOMMAND, X
		JSR		CMDWAIT
		LDB		#$E0			; Clear LBA3, set Master & LBA mode
		STB		CFLBA3, X
		JSR		CMDWAIT
		LDB		#$01			; Set 8-bit bus-width
		STB		CFFEATURE, X
		JSR		CMDWAIT
		LDB		#$01			; Read only one sector at a time.
		STB		CFSECCNT, X
		JSR		CMDWAIT
		LDB		#$EF			; Enable features 
		STB		CFCOMMAND, X
		JSR		CMDWAIT
		LDB		#$00
		STB		CFLBA0, X
		JSR		CMDWAIT
		LDB		#$00
		STB		CFLBA1, X
		JSR		CMDWAIT
		LDB		#$00
		STB		CFLBA2, X
		JSR		CMDWAIT
		LDB		#$E0
		STB		CFLBA3, X
		JSR		CMDWAIT
		LDA		#$00			; Set a loop counter to read the first 256 bytes of DATA
DELAY	INCA
		BNE		DELAY			; Count to 256 
		RTS
******************************************

******************************************
* Driver initialise (warm start) *
*ENTRY - No parameters
*EXIT  - A, B, X, Y, and U may be destroyed
WARM	BRA		INIT			; 
		RTS
		
******************************************
* Seek to specified track *
*ENTRY - (A) = Track Number
*        (B) = Sector Number
*EXIT -  (X) May be destroyed (See text)
*        (A) May be destroyed (See text)
*        (B) = Error condition
*        (Z) = 1 if no error
*			 = 0 if an error
SEEK	PSHS	A				; Save A for internal working
		LDA		[DRIVENO]
		LDX		#CFADDRESS2		; Address CF card 2.
		BITA	#$02			; Check Bit-2 to see which CF card is selected
		PULS	A				; Continue with original contents of A
		BNE		SEEK2			; Branch if 2nd CF card is selected
		LDX		#CFADDRESS1		; Address CF card 1.
SEEK2	STA		CFLBA1, X		; Load the Track number
		JSR		CMDWAIT
		STB		CFLBA0, X		; Load the Sector number
		JSR		CMDWAIT
		LDA		[DRIVENO]
		ANDA	#$01			; First or second drive on the Card?
		STA		CFLBA2, X		; Load the drive number
		JSR		CMDWAIT						
		RTS
******************************************
		
****************************************************
* Wait for CF Card ready when reading/writing to CF Card
* Check for Busy = 0 (bit 7)
****************************************************
DATWAIT	PSHS	A, B, X
		LDX		[CFADDCURNT]
		LDA		#$00			; Reset time-out counter
DATWT	LDB		CFSTATUS,X	 	; Read the status register
		INCA
		BITA	#$00
		BEQ 	WTEXIT
		BITB	#$80			; Isolate the ready bit
		BNE		DATWT			; Wait for the bit to clear
WTEXIT	PULS	A, B, X
		RTS        
	ORG		$4200

****************************************************
* Wait for CF Card ready when reading/writing to CF Card
* Check for RDY = 0 (bit 6)
****************************************************
CMDWAIT	PSHS	A, B, X
		LDX		[CFADDCURNT]
		LDA		#$00			; Reset time-out counter
CMDWT	LDB		CFSTATUS,X	 	; Read the status register
		INCA
		BITA	#$00
		BEQ		CMDEXIT
		BITB	#$C0			; Isolate the ready bit
		BEQ		CMDWT			; Wait for the bit to clear
CMDEXIT	PULS	A, B, X
		RTS       

****************************************************
* Wait for CF Card ready when reading/writing to CF Card
* Check for RDY = 0 (bit 6) and Busy = 0 (bit 7)
****************************************************
CFWAITF	PSHS	A, B, X
		LDX		[CFADDCURNT]
		LDB		CFSTATUSL1	 	; Read the status register
		BITB	#$80			; Isolate the ready bit
		BNE		CFWAITF			; Wait for the bit to clear
CFWAIT1	LDB		CFSTATUSL1, X	; Read the status register
		BITB	#$40			; Isolate the ready bit
		BEQ		CFWAIT1			; Wait for the bit to clear
		PULS	A, B, X
		RTS        
 


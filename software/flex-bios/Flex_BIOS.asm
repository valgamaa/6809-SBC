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
CFADDRESS1	EQU 	$F2C0
CFADDRESS2	EQU 	$F300
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
CFTIMEOUT	EQU		$FFFF		; Busy/ready poll timeout for DATWAIT/CMDWAIT/
CMDTIMEOUT	EQU		$0800		; Poll timeout for CMDWAIT only (about 47ms at a 1MHz
							; E clock). A present card answers at once; this just
							; stops an EMPTY slot costing ~1.5s per CMDWAIT, which
							; made Flex boot very slow with a single CF card fitted.
CFBYTETO	EQU		$0200		; Much smaller timeout for DRQWAITB, the
							; per-byte DRQ recheck inside READ's transfer
							; loop -- that's meant to catch a brief, one-
							; off drop (a shallow FIFO refill), not wait as
							; long as a fresh command issue. Using the full
							; CFTIMEOUT there let a single stuck sector burn
							; through up to 256 full-length timeouts (one per
							; byte), which is what actually hung -- not a true
							; infinite loop, just a very long one. Raise this
							; if a real, present card ever times out here.
							; DRQWAIT -- counts down once per poll rather
							; than looping forever, so a card that never
							; responds (e.g. an empty CF slot) doesn't hang
							; the driver. Not calibrated against real clock
							; timing (none found in this project) -- lower it
							; if an absent drive stalls boot too long, raise
							; it if a real, present card ever times out.
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
* DISK I/O vector table -- FLEX's own core calls into this with a plain
* JSR straight to the fixed address (e.g. "JSR $DE00"), NOT an indirect
* jump through a pointer -- see TSC's FLEX Advanced Programmer's Manual:
* "All routines are entered with a JSR instruction" to fixed, 3-byte-
* spaced addresses, each containing an actual JMP instruction. This used
* to be a table of FDB pointers (2 bytes apart) instead of real JMP
* instructions (3 bytes apart) -- which meant a real "JSR $DE00" from
* FLEX executed the raw address BYTES of READ as if they were an opcode
* (e.g. $F8 = LDB extended) instead of ever reaching READ at all. That
* silently broke every single disk driver entry point for FLEX itself,
* while our own test tools (which called through here with JSR [READ_T]
* etc., matching the old pointer format) worked fine and masked it.
	ORG	$DE00
READ_T 		JMP	READ
WRITE_T		JMP	WRITE
VERIFY_T	JMP	VERIFY
RESTORE_T	JMP	RESTORE
DRIVE_T		JMP	DRIVE
CHKRDY_T	JMP	CHKRDY
QUICK_T		JMP	QUICK
INIT_T		JMP	INIT
WARM_T		JMP	WARM
SEEK_T		JMP	SEEK
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
		NOP						; Bus recovery margin -- same fix as OUTCH:
		NOP						; reading RxBuff immediately after Status
								; gave the DUART no recovery time between
								; back-to-back accesses
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
        ANDA    #$01		; Z=1 if no character waiting (RxRDY clear)
		PULS	A,U				; Restore 'A' & 'U'
   		RTS                     ; Return with received character in 'A'

* Output character *
OUTCH	PSHS    B,U         		; Save registers & work byte
		LDU     #PORTA			; Load 68681 base address
OUTWAIT LDB     Status,U		; Load STATUS register
		BITB    #$04            ; Check if the port is ready to send
        BEQ		OUTWAIT			; Wait if not ready
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
DRIVENO		FCB		$00
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
READ	PSHS	A,Y				; Save A (Track number) for internal working
		LDA		DRIVENO
		LDY		#CFADDRESS1			; Default: drive bit set -> card 1
		BITA	#$02				; Check Bit-2 to see which CF card is
									; selected. Drive 0 (the default,
									; DRIVENO=0, bit clear) must select
									; CFADDRESS2 -- that's the only real,
									; populated card on this board -- so the
									; bit-clear case below overrides Y to
									; CFADDRESS2, not CFADDRESS1
		PULS	A					; Continue with original contents of A
		BNE		READ1				; Branch if bit set (keep CFADDRESS1)
		LDY		#CFADDRESS2			; Bit clear (drive 0): the real card
READ1	STB		CFLBA0,Y			; Store the Sector number
		JSR		DATWAIT
		STA		CFLBA1,Y			; Store the Track number
		JSR		DATWAIT
		LDA		DRIVENO
		ANDA	#$01				; First or second drive on the Card?
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
		JSR		DRQWAIT				; Wait for Busy=0 AND DRQ=1 before the
									; first data byte
		LDA		#$00				; Set a loop counter to read the first 256 bytes of DATA
FLEXLP	JSR		DRQWAITB		; Re-check DRQ before every byte, not just
							; the first -- this board's CF interface
							; appears to drop DRQ momentarily partway
							; through a sector (a shallow FIFO refill?),
							; and DATWAIT alone (Busy only) never caught
							; that, so the tail of the sector could be read
							; as stale/floating bus values. Same fix already
							; applied to CF_Test_4.asm's READFLX earlier this
							; project -- this is the real driver's own copy
							; of that loop, which never got the same fix.
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
		CLRB					; No error -- (A)'s status byte read above was
							; only ever inspected for debugging (see the
							; project notes on why a genuine ERR-bit check
							; here previously froze FLEX); still not wired
							; into (B), so this remains "no error" as before.
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
		LDY		#CFADDRESS1		; Default: drive bit set -> card 1
		BITA	#$02			; Check Bit-2 -- drive 0 (bit clear) must
								; select CFADDRESS2, the only real,
								; populated card (see READ)
		PULS	A				; Continue with original contents of A
		BNE		WRITE1			; Branch if bit set (keep CFADDRESS1)
		LDY		#CFADDRESS2		; Bit clear (drive 0): the real card
WRITE1	STA		CFLBA1, Y		; Load the Track number
		JSR		CMDWAIT
		STB		CFLBA0, Y		; Load the Sector number
		JSR		CMDWAIT
		LDA		DRIVENO
		ANDA	#$01			; First or second drive on the Card?
		STA		CFLBA2, Y		; Load the drive number
		JSR		CMDWAIT
		LDA		#$E0			; Set LBA mode, IDE master -- was missing
		STA		CFLBA3, Y		; entirely, leaving the drive in whatever
		JSR		CMDWAIT			; addressing mode it last had
		LDA		#$01			; One sector -- CFSECCNT was never set here
		STA		CFSECCNT, Y		; either
		JSR		CMDWAIT			; The wanted sector is selected, and can now be written.
		LDB		#$30			; Send WRITE command to the CF Card -- this
								; was $20 (Read Sector), so this routine
								; never actually wrote anything: it issued a
								; read and pulled data INTO the buffer
		STB		CFCOMMAND, Y
		JSR		DRQWAIT			; Wait for Busy=0 AND DRQ=1 before the
								; first data byte
		LDA		#$00			; Set a loop counter to write the first 256 bytes of DATA
WRLOOP	LDB		,X+				; Read the byte from the buffer
		STB		CFDATA, Y		; Write it to the CF Card
		JSR		DATWAIT
		INCA
		BNE		WRLOOP			; Count to 256 - a Flex sector
		LDB		#$00			; Zero-pad the remaining 256 bytes of the
								; underlying 512-byte CF sector (this loop
								; used to read and discard instead, which
								; only made sense for the erroneous read)
WRTAIL	STB		CFDATA, Y
		JSR		DATWAIT
		INCA
		BNE		WRTAIL
		JSR		CMDWAIT
		PULS	Y
		CLRB					; No error
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
VERIFY	CLRB					; No verify pass actually happens -- this used
							; to be a bare NOP/RTS, leaving (B) as whatever
							; the previous call left it, which could report a
							; stale error (e.g. from a not-ready CHKRDY or a
							; non-existent-drive DRIVE) as VERIFY's own result
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
		BITA	#$02				; Drive 2 or 3 selected if set. Drive 0/1
									; (bit clear) selects CFADDRESS2, the
									; only real, populated card (see READ)
		BNE		RESTOR1				; Set the base address for the CF Card.
		LDX		#CFADDRESS2
		BRA		RESTOR2
RESTOR1	LDX		#CFADDRESS1
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
		BITA	#$02				; Drive 2 or 3 selected if set. Drive 0/1
									; (bit clear) selects CFADDRESS2, the
									; only real, populated card (see READ)
		BNE		DRIVE1				; Set the base address for the CF Card.
		LDX		#CFADDRESS2
		STX		CFADDCURNT
		BRA		DRIVE2
DRIVE1	LDX		#CFADDRESS1
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
CHKRDY	LDA		$03, X				; Get drive Number -- BITA below only tests
									; it, so it's still here in A afterwards
		BITA	#$02			; Drive 1 or 3 selected if set. Drive 0/1
									; (bit clear) selects CFADDRESS2, the
									; only real, populated card (see READ)
		BNE		CHKRDY1				; Set the base address for the CF Card.
		LDX		#CFADDRESS2
		BRA		CHKRDY2
CHKRDY1	LDX		#CFADDRESS1
CHKRDY2	ANDA	#$01			; Bank bit, from the drive number still in
									; A -- same computation DRIVE does. This used
									; to run AFTER 'LDA CFSTATUS,X' below, which
									; clobbered the drive number with the status
									; register's value first, so CFLBA2 got the
									; card's ERR bit instead of the intended bank
									; -- corrupting the bank selection on every
									; CHKRDY/QUICK call, including ones issued
									; between a DRIVE and the READ/WRITE it was
									; selecting for.
		STA		CFLBA2,X
		LDA		CFSTATUS,X		; Now safe to overwrite A with the status
		BITA	#$C0			; Isolate Busy/Ready -- same bits, same
									; sense as CMDWAIT: set means ready. (The
									; old code tested this against the corrupted
									; 0-or-1 value above, which can never have bits
									; 6/7 set -- so BNE CHKRDY3 could never fire,
									; and CHKRDY always reported "ready" regardless
									; of the card's real state.)
		BEQ		CHKRDY3				; Neither bit set -- not ready
		CLRB						; And set the status bits before returning from this subroutine.
		RTS
CHKRDY3	LDB		#$FF
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

* INIT2 is private to INIT -- its only caller, via BSR, twice
* (once per card). It's fine for it to set CFADDCURNT below:
* nothing else in this file calls INIT2, and INIT/INIT2 only
* ever run once, at cold boot, before FLEX has made its first
* real DRIVE call.
INIT2	STX		CFADDCURNT		; CMDWAIT reads the base address from here,
							; not from X -- this was missing, so at cold
							; boot (before any DRIVE call has ever set
							; CFADDCURNT) both INIT2 passes polled status
							; at whatever garbage CFADDCURNT held (its
							; power-on default), not the card actually
							; being initialised
		JSR		CMDWAIT
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
WARM	RTS						; was BRA INIT, which re-ran the (slow) CF init on every
								; warm start; nothing here needs re-initialising
								; 
		
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
		LDA		DRIVENO			; Plain extended load -- the bracket form
								; used here previously performed a genuine
								; 6809 indirect fetch (reading A from the
								; address STORED at DRIVENO) rather than
								; loading DRIVENO's own byte value
		LDX		#CFADDRESS1		; Default: drive bit set -> card 1
		BITA	#$02			; Check Bit-2 -- drive 0 (bit clear) must
								; select CFADDRESS2, the only real,
								; populated card (see READ)
		PULS	A				; Continue with original contents of A
		BNE		SEEK2			; Branch if bit set (keep CFADDRESS1)
		LDX		#CFADDRESS2		; Bit clear (drive 0): the real card
SEEK2	STA		CFLBA1, X		; Load the Track number
		JSR		CMDWAIT
		STB		CFLBA0, X		; Load the Sector number
		JSR		CMDWAIT
		LDA		DRIVENO
		ANDA	#$01			; First or second drive on the Card?
		STA		CFLBA2, X		; Load the drive number
		JSR		CMDWAIT						
		RTS
******************************************
		
****************************************************
* Wait for CF Card ready when reading/writing to CF Card
* Check for Busy = 0 (bit 7)
****************************************************
DATWAIT	PSHS	A, B, X, U
		LDX		CFADDCURNT		; Plain extended load -- CFADDCURNT holds
								; the card base address itself; the bracket
								; form used here previously performed a
								; genuine 6809 indirect fetch (reading X from
								; the address STORED there, i.e. from the
								; card's own registers) instead of loading
								; that address into X
		LDU		#CFTIMEOUT		; Bail out after CFTIMEOUT polls instead of
							; hanging forever if the card never clears Busy
DATWT	LDB		CFSTATUS,X	 	; Read the status register
		BITB	#$80			; Isolate the busy bit
		BEQ		DATDONE			; Busy clear -- card responded
		LEAU	-1,U			; Otherwise count down the timeout...
		CMPU	#$0000			; ...LEAU doesn't touch the Z flag, so test
		BNE		DATWT			; polling until it reaches zero
DATDONE	PULS	A, B, X, U
		RTS
****************************************************
* Wait for CF Card ready when reading/writing to CF Card
* Check for RDY = 0 (bit 6)
****************************************************
CMDWAIT	PSHS	A, B, X, U
		LDX		CFADDCURNT		; Plain extended load -- see DATWAIT
		LDU		#CMDTIMEOUT		; Bail out after CFTIMEOUT polls instead of
							; hanging forever if the card never sets Ready
CMDWT	LDB		CFSTATUS,X	 	; Read the status register
		BITB	#$C0			; Isolate the ready bit
		BNE		CMDDONE			; Ready bit set -- card responded
		LEAU	-1,U			; Otherwise count down the timeout...
		CMPU	#$0000			; ...LEAU doesn't touch the Z flag, so test
		BNE		CMDWT			; polling until it reaches zero
CMDDONE	PULS	A, B, X, U
		RTS

****************************************************
* Wait for the CF Card to be ready to transfer data --
* Busy (bit 7) clear AND DRQ (bit 3) set. Needed once,
* right after issuing a read/write command and before
* the first data byte: DATWAIT/CMDWAIT never check DRQ
* at all, and pushing/pulling data before the drive
* actually asserts DRQ can corrupt a transfer or wedge
* a real CF card's data state machine.
*ENTRY - (Y) = CF Card base address
****************************************************
DRQWAIT	PSHS	A, B, U
		LDU		#CFTIMEOUT		; Bail out after CFTIMEOUT polls instead of
							; hanging forever if the card never responds
DRQWT	LDB		CFSTATUS,Y
		BITB	#$80			; Isolate the busy bit
		BEQ		DRQWT2			; Busy clear -- move on to the DRQ check
		LEAU	-1,U			; Otherwise count down the timeout...
		CMPU	#$0000			; ...LEAU doesn't touch the Z flag, so test
		BNE		DRQWT			; polling until it reaches zero
		BRA		DRQDONE			; Timed out waiting for Busy to clear
DRQWT2	LDB		CFSTATUS,Y
		BITB	#$08			; Isolate DRQ
		BNE		DRQDONE			; DRQ set -- card ready to transfer
		LEAU	-1,U			; Otherwise count down the timeout...
		CMPU	#$0000			; ...LEAU doesn't touch the Z flag, so test
		BNE		DRQWT2			; polling until it reaches zero
DRQDONE	PULS	A, B, U
		RTS

****************************************************
* Same as DRQWAIT, but with CFBYTETO's much smaller budget -- used for
* the per-byte DRQ recheck inside a sector transfer (see FLEXLP), where
* a drop is expected to clear almost immediately, not the once-per-
* sector wait right after a command is issued.
*ENTRY - (Y) = CF Card base address
****************************************************
DRQWAITB	PSHS	A, B, U
		LDU		#CFBYTETO
DRQWTB	LDB		CFSTATUS,Y
		BITB	#$80			; Isolate the busy bit
		BEQ		DRQWTB2			; Busy clear -- move on to the DRQ check
		LEAU	-1,U
		CMPU	#$0000
		BNE		DRQWTB			; polling until it reaches zero
		BRA		DRQDONEB		; Timed out waiting for Busy to clear
DRQWTB2	LDB		CFSTATUS,Y
		BITB	#$08			; Isolate DRQ
		BNE		DRQDONEB		; DRQ set -- card ready to transfer
		LEAU	-1,U
		CMPU	#$0000
		BNE		DRQWTB2			; polling until it reaches zero
DRQDONEB	PULS	A, B, U
		RTS

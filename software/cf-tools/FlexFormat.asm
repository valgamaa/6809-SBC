********************************
* FlexFormat -- standalone FLEX disk formatter for the CF Card
*
* Hard-coded geometry (see below): lays down a System Information
* Record, an empty directory chain filling the rest of Track 0, and
* a fully-linked free-space chain covering Track 1 through the last
* track. Sector-to-LBA mapping matches Flex_BIOS.asm exactly: LBA0 =
* sector number (direct, unshifted -- FLEX sectors are 1..MAXSECT,
* so LBA0 = 0 is simply never used), LBA1 = track number (direct,
* 0-based). Lives above Assist09 (relocated from $8000 so all of
* $8000-$DFFF stays free for user FLEX programs); launched with the
* monitor's 'F' command (no need to type an address). Returns to the
* monitor via RTS when done, the same convention CF_Test_4.asm uses.
*
* This is a NEW, standalone program -- it shares no code or state
* with CF_Test_4.asm, though the low-level CF register access and
* the Flex-sector read/write convention (256 real bytes + 256
* zero-padded/discarded bytes per 512-byte CF sector) are the same,
* since that's what Flex_BIOS.asm itself expects on the card.
********************************

********************************
* MONITOR LABELS (Assist09 SWI calls)
********************************
INCHP		EQU		$00		; INPUT CHAR FROM CONSOLE AND ECHO
OUTCH		EQU		$01		; OUTPUT CHAR ON CONSOLE
PDATA		EQU		$03		; PRINT TEXT STRING @ X ENDED BY $04

********************************
* CF CARD REGISTERS (8-bit mode -- matches Flex_BIOS.asm/CF_Test_4.asm)
********************************
CFADDRESS1	EQU		$F300		; Second physical CF card slot (drives 2-3)
CFADDRESS2	EQU		$F2C0		; First physical CF card slot (drives 0-1) --
							; matches Flex_BIOS.asm's convention exactly:
							; DRIVENO bit 1 picks the card, bit 0 picks
							; which of that card's two LBA2 banks
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

********************************
* DISK GEOMETRY & VOLUME DEFAULTS (hard-coded for now)
*
* Tracks are 0-based (0..MAXTRACK); sectors are 1-based (1..MAXSECT).
* LBA0/LBA1 map directly, unshifted, so LBA0 = 0 on every track goes
* permanently unused -- accepted trade-off, no DECB adjustment.
********************************
MAXTRACK		EQU		$FF		; Tracks 0..255 (256 tracks)
MAXSECT			EQU		$FF		; Sectors 1..255 (255 usable/track)
FIRSTUSERTRACK	EQU		$01		; Free space starts at Track 1...
FIRSTUSERSECT	EQU		$01		; ...Sector 1
DIRSTARTSECT	EQU		$05		; Directory starts at Track 0, Sector 5
									; and runs to Track 0, Sector MAXSECT

VOLNUM_HI		EQU		$00
VOLNUM_LO		EQU		$01
TOTFREE_HI		EQU		$FE		; Total free sectors = MAXTRACK*MAXSECT
TOTFREE_LO		EQU		$01		;   = 255*255 = 65025 = $FE01
CREATEMONTH		EQU		$01		; Placeholder creation date --
CREATEDAY		EQU		$01		; volume label/number/date can be
CREATEYEAR		EQU		$26		; made interactive later (26 = 2026)

DATABLK		EQU		$1000		; 256-byte sector staging buffer

********************************
* START OF PROGRAM
********************************
		ORG		$E900
		JMP		START

********************************
* WORKING VARIABLES
********************************
LBA0		FCB		$00			; Current sector number for WRITESEC
LBA1		FCB		$00			; Current track number for WRITESEC
LBA2		FCB		$00			; Drive-select bank bit (0 or 1) for the
							; chosen drive -- set by GETDRIVE
LBA3		FCB		$E0
CFBASE		FDB		$0000			; Selected card base address (CFADDRESS1 or
							; CFADDRESS2), set by GETDRIVE
DRIVENO		FCB		$00			; Chosen drive number, 0-3
CURTRK		FCB		$00			; Loop variable -- current track
CURSECT		FCB		$00			; Loop variable -- current sector

VOLLABEL	FCC		"FLEXDISK   "	; 11 bytes; the 9th byte is overwritten
							; with the drive digit in BUILDSIR

********************************
* MESSAGE TEXT
********************************
BANNER	FCC		"FLEX Disk Formatter"
		FCB		$0D,$0A,$04
DRVTXT	FCC		"Drive number to format (0-3): "
		FCB		$04
BADDRVTXT FCB	$0D,$0A
		FCC		"Please enter 0, 1, 2 or 3."
		FCB		$0D,$0A,$04
DRVSELTXT FCB	$0D,$0A
		FCC		"Formatting Drive "
		FCB		$04
DRVSELNL FCB	$0D,$0A,$04
WARNTXT	FCC		"This will ERASE ALL DATA on the CF Card."
		FCB		$0D,$0A
		FCC		"Press Y to format, any other key to abort: "
		FCB		$04
ABORTTXT FCB	$0D,$0A
		FCC		"Aborted -- nothing was written."
		FCB		$0D,$0A,$04
SIRTXT	FCC		"Writing System Information Record..."
		FCB		$0D,$0A,$04
RESVTXT	FCC		"Clearing reserved Track 0 sectors..."
		FCB		$0D,$0A,$04
DIRTXT	FCC		"Writing empty directory chain..."
		FCB		$0D,$0A,$04
FREETXT	FCC		"Writing free-space chain (one dot per track)..."
		FCB		$0D,$0A,$04
DONETXT	FCB		$0D,$0A
		FCC		"Format complete."
		FCB		$0D,$0A,$04
ERRTXT	FCC		"CF Card error during initialisation."
		FCB		$0D,$0A,$04

********************************
* MAIN PROGRAM
********************************
START	LDX		#BANNER
		SWI
		FCB		PDATA
		JSR		GETDRIVE
		LDX		#DRVSELTXT
		SWI
		FCB		PDATA
		LDA		DRIVENO
		ADDA	#'0
		SWI
		FCB		OUTCH
		LDX		#DRVSELNL
		SWI
		FCB		PDATA
		LDX		#WARNTXT
		SWI
		FCB		PDATA
		SWI
		FCB		INCHP			; Wait for a key press
		ANDA	#$DF			; Fold lower-case to upper-case
		CMPA	#'Y
		BEQ		DOFMT
		LDX		#ABORTTXT
		SWI
		FCB		PDATA
		RTS

DOFMT	JSR		INITCF
		LDX		CFBASE
		LDB		CFSTATUS,X
		BITB	#$01			; Isolate the error bit
		BEQ		FMT1
		LDX		#ERRTXT
		SWI
		FCB		PDATA
		RTS

FMT1	LDX		#SIRTXT
		SWI
		FCB		PDATA
		JSR		BUILDSIR

		LDX		#RESVTXT
		SWI
		FCB		PDATA
		JSR		CLEARRESV

		LDX		#DIRTXT
		SWI
		FCB		PDATA
		JSR		BUILDDIR

		LDX		#FREETXT
		SWI
		FCB		PDATA
		JSR		FREEFMT

		LDX		#DONETXT
		SWI
		FCB		PDATA
		RTS

****************************************************
* Prompt for a drive number (0-3) and set DRIVENO,
* CFBASE and LBA2 from it. Matches Flex_BIOS.asm's own
* convention exactly: DRIVENO bit 0 selects which of a
* card's two LBA2 banks (each a full, independent
* 256-track x 255-sector address space); bit 1 selects
* the physical card -- clear -> CFADDRESS2 (the one
* populated slot right now), set -> CFADDRESS1.
****************************************************
GETDRIVE	PSHS	A,B,X
GDLOOP	LDX		#DRVTXT
		SWI
		FCB		PDATA
		SWI
		FCB		INCHP			; Wait for a key press
		CMPA	#'0
		BLO		GDBAD
		CMPA	#'3
		BHI		GDBAD
		SUBA	#'0				; ASCII digit -> binary 0-3
		STA		DRIVENO
		BRA		GDOK
GDBAD	LDX		#BADDRVTXT
		SWI
		FCB		PDATA
		BRA		GDLOOP
GDOK	LDA		DRIVENO
		ANDA	#$01
		STA		LBA2			; Bit 0 -> LBA2 bank
		LDA		DRIVENO
		ANDA	#$02
		BEQ		GDCARD2			; Bit clear -> CFADDRESS2 (populated)
		LDX		#CFADDRESS1
		BRA		GDSETB
GDCARD2	LDX		#CFADDRESS2
GDSETB	STX		CFBASE
		PULS	A,B,X
		RTS

****************************************************
* Initialise the CF Card for 8-bit LBA-mode transfers
****************************************************
INITCF	LDX		CFBASE
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
		LDB		#$01			; One sector at a time
		STB		CFSECCNT, X
		JSR		CMDWAIT
		LDB		#$EF			; Enable features
		STB		CFCOMMAND, X
		JSR		CMDWAIT
		LDB		LBA0			; Trailing LBA0-3 writes + CFERR check,
		STB		CFLBA0, X		; kept identical to CF_Test_4.asm's
		JSR		CMDWAIT			; proven-on-hardware INITCF sequence
		LDB		LBA1
		STB		CFLBA1, X
		JSR		CMDWAIT
		LDB		LBA2
		STB		CFLBA2, X
		JSR		CMDWAIT
		LDB		LBA3
		ANDB	#$0F			; Mask the lower nibble
		ORB		#$E0			; Set LBA mode, IDE master
		STB		CFLBA3, X
		JSR		CMDWAIT
		RTS

****************************************************
* Build the System Information Record and write it
* to Track 0, Sector 3.
****************************************************
BUILDSIR	PSHS	A,B,X,Y
			JSR		CLRBUF
			LDX		#DATABLK

			LEAX	$10,X			; Volume Label (11 bytes) @ $10
			LDY		#VOLLABEL
			LDB		#11
SIRVOL		LDA		,Y+
			STA		,X+
			DECB
			BNE		SIRVOL

			LDX		#DATABLK
			LDA		DRIVENO
			ADDA	#'0
			STA		$18,X			; Stamp the drive digit into the label (9th byte)
			LDA		#VOLNUM_HI
			STA		$1B,X
			LDA		DRIVENO			; VOLNUM_LO = drive number, not the fixed
							; constant, so each drive's SIR differs
			STA		$1C,X
			LDA		#FIRSTUSERTRACK
			STA		$1D,X
			LDA		#FIRSTUSERSECT
			STA		$1E,X
			LDA		#MAXTRACK
			STA		$1F,X
			LDA		#MAXSECT
			STA		$20,X
			LDA		#TOTFREE_HI
			STA		$21,X
			LDA		#TOTFREE_LO
			STA		$22,X
			LDA		#CREATEMONTH
			STA		$23,X
			LDA		#CREATEDAY
			STA		$24,X
			LDA		#CREATEYEAR
			STA		$25,X
			LDA		#MAXTRACK
			STA		$26,X
			LDA		#MAXSECT
			STA		$27,X

			LDA		#$00			; Track 0
			STA		LBA1
			LDA		#$03			; Sector 3
			STA		LBA0
			JSR		WRITESEC
			PULS	A,B,X,Y
			RTS

****************************************************
* Zero-fill the reserved Track 0 sectors that are
* neither the SIR (Sector 3) nor part of the
* directory chain (Sectors 5..MAXSECT): that leaves
* Sectors 1, 2 and 4 unused, per the SIR layout.
****************************************************
CLEARRESV	PSHS	A,B,X,Y
			LDA		#$00			; Track 0
			STA		LBA1

			JSR		CLRBUF
			LDA		#$01
			STA		LBA0
			JSR		WRITESEC

			JSR		CLRBUF
			LDA		#$02
			STA		LBA0
			JSR		WRITESEC

			JSR		CLRBUF
			LDA		#$04
			STA		LBA0
			JSR		WRITESEC
			PULS	A,B,X,Y
			RTS

****************************************************
* Write an empty directory chain from Track 0,
* Sector DIRSTARTSECT through Track 0, Sector
* MAXSECT. Each sector's first two bytes link to
* the next directory sector (track, sector); the
* last one links to (0,0). The 240 entry bytes are
* left zeroed, i.e. all ten entries per sector are
* empty/unused.
****************************************************
BUILDDIR	PSHS	A,B,X,Y
			LDA		#DIRSTARTSECT
			STA		CURSECT
DIRLOOP		JSR		CLRBUF
			LDA		CURSECT
			CMPA	#MAXSECT
			BEQ		DIRLAST
			LDB		#$00			; Next track = 0 (still on Track 0)
			LDA		CURSECT
			INCA					; Next sector = CURSECT+1
			BRA		DIRLINK
DIRLAST		LDB		#$00			; Terminator: (0,0)
			LDA		#$00
DIRLINK		LDX		#DATABLK
			STB		,X				; Byte 0 = next track
			STA		1,X				; Byte 1 = next sector
			LDA		#$00			; Track 0
			STA		LBA1
			LDA		CURSECT
			STA		LBA0
			JSR		WRITESEC
			LDA		CURSECT
			CMPA	#MAXSECT
			BEQ		DIRDONE
			INC		CURSECT
			BRA		DIRLOOP
DIRDONE		PULS	A,B,X,Y
			RTS

****************************************************
* Write the free-space chain covering every sector
* from (FIRSTUSERTRACK, FIRSTUSERSECT) through
* (MAXTRACK, MAXSECT). Each sector's first two bytes
* link to the next free sector (track, sector); the
* very last sector on the disk links to (0,0). Prints
* one "." per completed track as a progress indicator.
****************************************************
FREEFMT		PSHS	A,B,X,Y
			LDA		#FIRSTUSERTRACK
			STA		CURTRK
TRKLOOP		LDA		#FIRSTUSERSECT
			STA		CURSECT
SECLOOP		JSR		CLRBUF
			LDA		CURSECT
			CMPA	#MAXSECT
			BEQ		TRKEND
			LDB		CURTRK			; Next track = same track
			LDA		CURSECT
			INCA					; Next sector = CURSECT+1
			BRA		SETLINK
TRKEND		LDA		CURTRK
			CMPA	#MAXTRACK
			BEQ		DISKEND
			LDB		CURTRK
			INCB					; Next track = CURTRK+1
			LDA		#FIRSTUSERSECT	; Next sector = 1
			BRA		SETLINK
DISKEND		LDB		#$00			; Terminator: (0,0)
			LDA		#$00
SETLINK		LDX		#DATABLK
			STB		,X				; Byte 0 = next track
			STA		1,X				; Byte 1 = next sector
			LDA		CURTRK
			STA		LBA1
			LDA		CURSECT
			STA		LBA0
			JSR		WRITESEC
			LDA		CURSECT
			CMPA	#MAXSECT
			BEQ		TRKDONE
			INC		CURSECT
			BRA		SECLOOP
TRKDONE		LDA		#'.				; Progress dot, once per completed track
			SWI
			FCB		OUTCH
			LDA		CURTRK
			CMPA	#MAXTRACK
			BEQ		FREEDONE
			INC		CURTRK
			BRA		TRKLOOP
FREEDONE	PULS	A,B,X,Y
			RTS

****************************************************
* Zero-fill the 256-byte sector staging buffer.
****************************************************
CLRBUF	PSHS	A,X,Y
		LDA		#$00
		LDX		#$0100
		LDY		#DATABLK
CLRLOOP	STA		,Y+
		LEAX	-1,X
		BNE		CLRLOOP
		PULS	A,X,Y
		RTS

****************************************************
* Write the 256-byte buffer at DATABLK to the Flex
* sector (LBA1=track, LBA0=sector) on CF Card 1,
* zero-padding the upper 256 bytes of the underlying
* 512-byte CF sector -- the same convention
* CF_Test_4.asm's WRTFLX and Flex_BIOS.asm's WRITE
* use.
****************************************************
WRITESEC	PSHS	Y,X,B,A
			LDY		CFBASE
			JSR		CFWAIT
			LDB		LBA0
			STB		CFLBA0, Y		; Sector number
			JSR		CFWAIT
			LDB		LBA1
			STB		CFLBA1, Y		; Track number
			JSR		CFWAIT
			LDB		LBA2			; Drive-select bank -- was hardcoded to
							; $00, so a drive-1 write always landed
							; back on drive 0's own sectors
			STB		CFLBA2, Y
			JSR		CFWAIT
			LDB		#$E0			; LBA mode, IDE master
			STB		CFLBA3, Y
			JSR		CFWAIT
			LDB		#$01
			STB		CFSECCNT, Y
			JSR		CMDWAIT
			LDB		#$30			; Write command
			STB		CFCOMMAND, Y
			JSR		DRQWAIT			; Wait for Busy=0 AND DRQ=1 before the
									; first data byte -- CFWAIT alone only
									; confirms Busy/RDY, never DRQ, and
									; pushing data before the drive
									; actually asserts DRQ can wedge a
									; real CF card's write state machine
			LDA		#$00			; Write the first 256 bytes from the buffer
			LDX		#DATABLK
WSLOOP		JSR		DATWAIT
			LDB		,X+
			STB		CFDATA, Y
			INCA
			BNE		WSLOOP
			LDA		#$00			; Zero-pad the remaining 256 bytes of
			LDB		#$00			; the underlying 512-byte CF sector
WSTAIL		JSR		DATWAIT
			STB		CFDATA, Y
			INCA
			BNE		WSTAIL
			JSR		CFWAIT
			PULS	Y,X,B,A
			RTS

****************************************************
* Wait for CF Card ready -- Busy = 0 (bit 7), then
* RDY = 1 (bit 6)
****************************************************
CFWAIT	PSHS	A, B, X
		LDX		CFBASE
CFW0	LDB		CFSTATUS,X
		BITB	#$80
		BNE		CFW0
CFWAIT1	LDB		CFSTATUS,X
		BITB	#$40
		BEQ		CFWAIT1
		PULS	A, B, X
		RTS

****************************************************
* Wait for the CF Card's Busy bit (bit 7) to clear
****************************************************
DATWAIT	PSHS	A, X
		LDX		CFBASE
DATWT	LDB		CFSTATUS,X
		BITB	#$80
		BNE		DATWT
		PULS	A, X
		RTS

****************************************************
* Wait for the CF Card to be ready to accept/deliver
* data -- Busy (bit 7) clear AND DRQ (bit 3) set.
* Needed once, right after issuing a data-transfer
* command (read or write) and before the first byte,
* since CFWAIT/CMDWAIT never check DRQ at all.
*ENTRY - (Y) = CF Card base address (already loaded by
*              WRITESEC, the only caller)
****************************************************
DRQWAIT	LDB		CFSTATUS,Y
		BITB	#$80
		BNE		DRQWAIT
		LDB		CFSTATUS,Y
		BITB	#$08
		BEQ		DRQWAIT
		RTS

****************************************************
* Wait for CF Card ready -- Busy or RDY clear (bits 7:6)
****************************************************
CMDWAIT	PSHS	A, X
		LDX		CFBASE
CMDWT	LDB		CFSTATUS,X
		BITB	#$C0
		BEQ		CMDWT
		PULS	A, X
		RTS

		END

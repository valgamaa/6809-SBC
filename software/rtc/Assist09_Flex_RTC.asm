********************************
* ASSIST09_FLEX_RTC.ASM - RTC date sync + 1-minute interrupt for FLEX
*
* Called from the monitor's F (boot Flex) command via JSR $FB00:
*   1) reads the RTC (HOLD/BUSY protocol, bounded retries)
*   2) prints "DD/MM/YY HH:MM:SS"
*   3) writes FLEX's date bytes (MONTH $CC0E, DAY $CC0F, YEAR $CC10)
*   4) installs RTCIRQ in the hardware IRQ vector ($FFF8, RAM) and
*      enables the RTC's 1-minute interrupt (CE=$0A) so the date stays
*      current without anyone typing DATE
* RTCIRQ re-reads the RTC each minute and refreshes the same bytes.
* If the RTC can't be read, or holds an impossible date, the interrupt
* is left masked (CE stays $01) and FLEX starts with whatever it had.
********************************
PDATA		EQU	$03			; monitor: CR/LF then string ended by $04
RTCADDRESS	EQU	$F230
CONTD_REG	EQU	$0D
CONTE_REG	EQU	$0E
MONTH		EQU	$CC0E		; FLEX system date
DAY			EQU	$CC0F
YEAR		EQU	$CC10

		ORG	$FB00

********************************
* RTCSYNC - entry point, preserves all registers
********************************
RTCSYNC	PSHS	D,X,Y,U
		LDU		#RTCADDRESS
		LDA		#$01			; FIRST: mask the RTC interrupt output. After a cold
		STA		CONTE_REG,U		; power-up (no battery backup) CE is undefined and
								; STD.P may already be active.
		LDX		#RTCIRQ
		STX		$FFF8			; ALWAYS point the hardware IRQ vector at our handler,
								; so any interrupt that does arrive is acknowledged
								; quietly instead of reaching the monitor's default
								; handler (register dump)
		LDA		#$01			; HOLD only (no IRQ-flag bit)
		BSR		GETRTC
		BCS		RS_FAIL
		CLRA
		STA		CONTD_REG,U		; release HOLD, clear any stale IRQ flag
		BSR		UPDDATE
		BCS		RS_BAD
		JSR		MKTEXT
		LDX		#TIMETXT
		SWI
		FCB		PDATA
		LDU		#RTCADDRESS		; don't rely on U surviving the SWI
		LDA		#$0A			; CE: 1-minute, interrupt mode, unmasked
		STA		CONTE_REG,U
		BSR		TXWAIT
		PULS	D,X,Y,U,PC

RS_FAIL	CLRA
		STA		CONTD_REG,U		; make sure HOLD is off
		LDX		#FAILTXT
		BRA		RS_MSG
RS_BAD	LDX		#BADTXT
RS_MSG	SWI
		FCB		PDATA
		BSR		TXWAIT
		PULS	D,X,Y,U,PC

********************************
* GETRTC - in: U = RTC base, A = value that sets HOLD ($01, or $05 in
*          the IRQ handler so the IRQ flag stays set until we ack)
*          out: carry clear = RTCBUF holds the 12 digits, HOLD LEFT SET
*               carry set   = BUSY never cleared (HOLD released)
********************************
GETRTC	PSHS	A				; 1,S = hold-set value
		LDB		#$40
		PSHS	B				; 0,S = tries left
GR1		LDA		1,S
		STA		CONTD_REG,U		; set HOLD
		LDA		CONTD_REG,U
		BITA	#$02			; BUSY?
		BEQ		GR2
		LDA		1,S
		ANDA	#$FE
		STA		CONTD_REG,U		; release HOLD and try again
		BSR		SHORTDLY
		DEC		0,S
		BNE		GR1
		LEAS	2,S
		ORCC	#$01
		RTS
GR2		LDY		#RTCBUF
		TFR		U,X
		LDB		#12
GR3		LDA		,X+
		ANDA	#$0F
		STA		,Y+
		DECB
		BNE		GR3
		LEAS	2,S
		ANDCC	#$FE
		RTS

********************************
* TXWAIT - wait (bounded) until DUART channel A has sent everything.
* FLEX's console init resets the transmitter as soon as it starts, which
* clipped the end of the date/time line when we jumped straight in.
* SR bit 3 = TxEMT.
********************************
TXWAIT	LDX		#$FFFF
TXW1	LDA		$F341
		BITA	#$08
		BNE		TXW2
		LEAX	-1,X
		BNE		TXW1
TXW2	RTS

SHORTDLY	LDB	#$FF
SD1		DECB
		BNE		SD1
		RTS

********************************
* UPDDATE - convert RTCBUF month/day/year to binary and store in FLEX.
*           carry set = invalid date, nothing stored
* RTCBUF: 0 S1,1 S10,2 M1,3 M10,4 H1,5 H10,6 D1,7 D10,8 MO1,9 MO10,10 Y1,11 Y10
********************************
UPDDATE	LDA		RTCBUF+9
		LDB		#10
		MUL
		ADDB	RTCBUF+8
		BEQ		UD_BAD
		CMPB	#12
		BHI		UD_BAD
		STB		NEWMON
		LDA		RTCBUF+7
		LDB		#10
		MUL
		ADDB	RTCBUF+6
		BEQ		UD_BAD
		CMPB	#31
		BHI		UD_BAD
		STB		NEWDAY
		LDA		RTCBUF+11
		LDB		#10
		MUL
		ADDB	RTCBUF+10
		STB		MINYEAR
		LDA		NEWMON
		STA		MONTH
		LDA		NEWDAY
		STA		DAY
		LDA		MINYEAR
		STA		YEAR
		ANDCC	#$FE
		RTS
UD_BAD	ORCC	#$01
		RTS

********************************
* MKTEXT - build "DD/MM/YY HH:MM:SS" + $04 at TIMETXT from RTCBUF
********************************
MKTEXT	PSHS	U
		LDU		#RTCBUF
		LDX		#TIMETXT
		LDY		#TXTMAP
MT1		LDB		,Y+
		CMPB	#$FF
		BEQ		MT3
		TSTB
		BMI		MT2
		LDA		B,U
		ADDA	#$30
		STA		,X+
		BRA		MT1
MT2		ANDB	#$7F
		STB		,X+
		BRA		MT1
MT3		LDA		#$04
		STA		,X
		PULS	U,PC

TXTMAP	FCB		7,6,'/+$80,9,8,'/+$80,11,10,' +$80
		FCB		5,4,':+$80,3,2,':+$80,1,0,$FF

********************************
* RTCIRQ - 1-minute interrupt. The CPU has already stacked everything,
* so any register may be used. Refresh FLEX's date, then acknowledge.
********************************
RTCIRQ	LDU		#RTCADDRESS
		LDA		#$05			; HOLD, keep IRQ flag set until ack
		JSR		GETRTC
		BCS		RI_ACK
		JSR		UPDDATE
RI_ACK	CLRA
		STA		CONTD_REG,U		; release HOLD + clear IRQ flag
		RTI

FAILTXT	FCC		"RTC not responding - FLEX date left unchanged."
		FCB		$04
BADTXT	FCC		"RTC date invalid - FLEX date left unchanged."
		FCB		$04

RTCBUF	FCB		0,0,0,0,0,0,0,0,0,0,0,0
TIMETXT	FCB		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
NEWMON	FCB		0
NEWDAY	FCB		0
MINYEAR	FCB		0
********************************
* FLEXDATE - called (via JMP) from a patch at $CA50 in FLEX's cold-start
* init, where it would print "DATE (MM,DD,YY)?" and read the answer.
* If RTCSYNC has already stored the date (MONTH <> 0), skip the prompt
* and carry on at $CA6E; otherwise do exactly what the original code did.
********************************
		ORG		$FD00
FLEXDATE	LDA		MONTH
		BEQ		FD_ASK
		JMP		$CA6E			; date already set - skip the prompt
FD_ASK	LDX		#$CAD0			; original: LDX #$CAD0
		JSR		$CE82			;           JSR PSTRNG
		JMP		$CA56			; carry on with the original code

END

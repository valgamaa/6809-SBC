********************************
* MONITOR LABLES
********************************
INCHP	EQU	$00		; INPUT CHAR FROM CONSOLE AND ECHO
OUTCH	EQU	$01		; OUTPUT CHAR ON CONSOLE
PDATA	EQU	$03		; PRINT TEXT STRING @ X ENDED BY $04
OUT2HS	EQU	$04		; PRINT 2 HEX CHARS @ X
OUT4HS	EQU	$05		; PRINT 4 HEX CHARS @ X

********************************
* RTC REGS
********************************
RTCADDRESS	EQU 	$F230
SEC_1_REG	EQU		$00		; 1-second digit register
SEC_10_REG	EQU		$01		; 10-second digit register
MIN_1_REG	EQU		$02		; 1-minute digit register
MIN_10_REG	EQU		$03		; 10-minute digit register
HOUR_1_REG	EQU		$04		; 1-hour digit register
HOUR_10_REG	EQU		$05		; 10-hour digit register
DAY_1_REG	EQU		$06		; 1-day digit register
DAY_10_REG	EQU		$07		; 10-day digit register
MON_1_REG	EQU		$08		; 1-month digit register
MON_10_REG	EQU		$09		; 10-month digit register
YEAR_1_REG	EQU		$0A		; 1-year digit register
YEAR_10_REG	EQU		$0B		; 10-year digit register
D_O_W_REG	EQU		$0C		; Day of week register
CONTD_REG	EQU		$0D		; Control Register D
CONTE_REG	EQU		$0E		; Control Register E
CONTF_REG	EQU		$0F		; Control Register F

********************************
* START OF PROGRAM
********************************
	ORG	$2000
********************************
* Configure the RTC using the sequence shown in the datasheet
********************************
		LDX		#RTCADDRESS
		LDA		#$01			; FIRST: mask the RTC interrupt output (CE register).
		STA		CONTE_REG,X		; After a cold power-up it is undefined and STD.P may
								; already be active.
		CLR		IRQON
		JSR 	STEP_A

		JSR		STEP_B		; Per datasheet p.15: HOLD must be set (and BUSY
							; confirmed clear) BEFORE stopping/resetting the
							; counter and writing the initial time - this was
							; previously skipped, leaving HOLD=0 (undefined
							; access) during RTCZERO's writes.

		JSR		STEP_C

		JSR		RTCZERO

		LDA		#$04
		STA		CONTD_REG,X
		LDA		#$04
		STA		CONTF_REG,X

		LDX		#RTCIRQ			; Install the IRQ handler into the RAM
		STX		$FFF8			; vector table. Safe to do now, before
								; interrupts are ever unmasked - this just
								; points the vector, it doesn't arm the
								; RTC's own interrupt or clear the CPU's I
								; bit (both still happen only when I is
								; pressed, deliberately, after S).

		LDX		#PROMPT
        SWI
        FCB     PDATA
		LDX		#RTCADDRESS
		JMP		START

********************************
* MENU HELP TEXT
********************************
HHELP	FCC		"? - List the commands available."
		FCB		$0D,$0A
		FCC		"D - Display the current date."
		FCB		$0D,$0A
		FCC		"S - Set time (HH MM SS)."
		FCB		$0D,$0A
		FCC		"E - Set date (DD MM YY)."
		FCB		$0D,$0A
		FCC		"T - Display the current time."
		FCB		$0D,$0A
		FCC		"I - Toggle the RTC's 1-minute interrupt (prints HH:MM each minute)."
		FCB		$0D,$0A
		FCC		"Q - Quit the program."
		FCB		$0D,$0A,$04

********************************
* MENU OPTION TEXT
********************************
NEWLINE	FCB		$0D,$0A,$04
PROMPT	FCB		">",$04

********************************
* SUBROUTINE TEXT STRINGS
********************************
TIMETXT	FCC		"XXXXXXXX"
*		FCB		$04
		FCB		$0D,$04

SETPROMPT	FCC		"Enter time as 6 hex digits, HH MM SS: "
			FCB		$04







IRQTXT		FCC		"XXXXX"
			FCB		$0D,$0A,$04


********************************

START	LDX		#NEWLINE		; Get a new line and print the input prompt
        SWI
        FCB     PDATA
		LDX		#PROMPT
        SWI
        FCB     PDATA
		LDA		IRQON
		BNE		POLLKEY			; interrupt armed: poll the DUART, no SWI
        SWI
		FCB		INCHP			; Wait for a key to be pressed on the keyboard
		BRA		GOTKEY
POLLKEY	ANDCC	#$EF			; Unmask IRQ for the duration of the wait
POLL1	LDA		$F341			; DUART channel A status
		ANDA	#$01			; RxRDY?
		BEQ		POLL1
		LDA		$F343			; Receive buffer
		STA		KEYSAVE
		SWI
		FCB		OUTCH			; Echo it, as INCHP would have done
		LDA		KEYSAVE
GOTKEY	CMPA	#'?				; Print the list of available commands
		BNE		NEXT
		JSR		HELP
		BRA		START
NEXT	ANDA	#$DF			; Make sure the character is upper-case
		CMPA	#'D				; Display the date
		BNE		NEXT1
		JSR		DATE
		BRA		START
NEXT1	CMPA	#'S				; Set the time
		BNE		NEXT2
		JSR		SET
		BRA		START
NEXT2	CMPA	#'E				; Set the date
		BNE		NEXT3
		JSR		SETDATE
		BRA		START
NEXT3	CMPA	#'T				; Display the time
		BNE		NEXT4
		JSR		TIME
		BRA		START
NEXT4	CMPA	#'I				; Toggle the RTC's 1-minute interrupt
		BNE		NEXT5
		JSR		IRQTOGGLE
		BRA		START
NEXT5	CMPA	#'Q				; Exit the program
		BNE		START
		JMP		QUIT


****************************************************
* Print the list of available commands
****************************************************
HELP	LDX		#HHELP
        SWI
        FCB     PDATA
		RTS

****************************************************
* Print the current date.
****************************************************
DATE	LDX		#RTCADDRESS
		LDB		#$01
		STB		CONTD_REG,X		; Set the HOLD bit
		LDB		CONTD_REG,X
		BITB	#$02			; Read the BUSY bit
		BEQ		DATE1
		LDB		#$00
		STB		CONTD_REG,X		; Reset the HOLD bit,
		JSR		PAUSE			; Wait,
		BRA		DATE			; and try again.

DATE1	LDY		#TIMETXT
		LDB		DAY_10_REG,X	; Read the Ten's of day.
		ANDB	#$0F			; Mask the upper bits
		ADDB	#$30			; Convert to ASCII
		STB		,Y+				; Add the digit to the text buffer.

		LDB		DAY_1_REG,X		; Read the One's of day.
		ANDB	#$0F
		ADDB	#$30
		STB		,Y+

		LDB		#'/				; Add the separator character
		STB		,Y+

		LDB		MON_10_REG,X	; Read the Ten's of month.
		ANDB	#$0F
		ADDB	#$30
		STB		,Y+

		LDB		MON_1_REG,X		; Read the One's of month.
		ANDB	#$0F
		ADDB	#$30
		STB		,Y+

		LDB		#'/				; Add the separator character
		STB		,Y+

		LDB		YEAR_10_REG,X	; Read the Ten's of year.
		ANDB	#$0F
		ADDB	#$30
		STB		,Y+

		LDB		YEAR_1_REG,X	; Read the One's of year.
		ANDB	#$0F
		ADDB	#$30
		STB		,Y

		LDB		#$00
		STB		CONTD_REG,X		; Reset the HOLD bit when complete.

		LDX		#TIMETXT
        SWI
        FCB     PDATA
		RTS

****************************************************
* Set the time to an arbitrary value entered as 6 hex digits
* (HH MM SS, each digit 0-9 expected since the chip is BCD).
* This lets us write a known, distinctive value (e.g. 20 seconds,
* SEC_10=2) and read it straight back with 'T' to tell apart:
*   - a stuck/OR'd bit on one nibble (readback = written VALUE | mask)
*   - a write that isn't taking at all (readback unrelated to input)
*   - a write that works fine (readback matches exactly)
****************************************************
SET		LDX		#SETPROMPT
        SWI
        FCB     PDATA

		JSR		HEXDIG			; Hour tens
		STB		HOURBUF10
		JSR		HEXDIG			; Hour ones
		STB		HOURBUF1
		JSR		HEXDIG			; Min tens
		STB		MINBUF10
		JSR		HEXDIG			; Min ones
		STB		MINBUF1
		JSR		HEXDIG			; Sec tens
		STB		SECBUF10
		JSR		HEXDIG			; Sec ones
		STB		SECBUF1

		LDX		#RTCADDRESS
SETW	LDB		#$01
		STB		CONTD_REG,X		; Set the HOLD bit
		LDB		CONTD_REG,X
		BITB	#$02			; Read the BUSY bit
		BEQ		SET1
		LDB		#$00
		STB		CONTD_REG,X		; Reset the HOLD bit,
		JSR		PAUSE			; Wait,
		BRA		SETW			; and try again.

SET1	LDB		HOURBUF10
		STB		HOUR_10_REG,X
		LDB		HOURBUF1
		STB		HOUR_1_REG,X
		LDB		MINBUF10
		STB		MIN_10_REG,X
		LDB		MINBUF1
		STB		MIN_1_REG,X
		LDB		SECBUF10
		STB		SEC_10_REG,X
		LDB		SECBUF1
		STB		SEC_1_REG,X

		LDB		#$00
		STB		CONTD_REG,X		; Reset the HOLD bit when complete.
		RTS

****************************************************
* Set the date: DD MM YY typed as six decimal digits (same style
* as the S command's HH MM SS). Same HOLD/BUSY protocol as SET.
****************************************************
SETDATE	LDX		#DATEPROMPT
        SWI
        FCB     PDATA

		JSR		HEXDIG			; Day tens
		STB		DAYBUF10
		JSR		HEXDIG			; Day ones
		STB		DAYBUF1
		JSR		HEXDIG			; Month tens
		STB		MONBUF10
		JSR		HEXDIG			; Month ones
		STB		MONBUF1
		JSR		HEXDIG			; Year tens
		STB		YRBUF10
		JSR		HEXDIG			; Year ones
		STB		YRBUF1

		LDX		#RTCADDRESS
SDW		LDB		#$01
		STB		CONTD_REG,X		; Set the HOLD bit
		LDB		CONTD_REG,X
		BITB	#$02			; Read the BUSY bit
		BEQ		SD1
		LDB		#$00
		STB		CONTD_REG,X		; Reset the HOLD bit,
		JSR		PAUSE			; Wait,
		BRA		SDW				; and try again.

SD1		LDB		DAYBUF10
		STB		DAY_10_REG,X
		LDB		DAYBUF1
		STB		DAY_1_REG,X
		LDB		MONBUF10
		STB		MON_10_REG,X
		LDB		MONBUF1
		STB		MON_1_REG,X
		LDB		YRBUF10
		STB		YEAR_10_REG,X
		LDB		YRBUF1
		STB		YEAR_1_REG,X

		LDB		#$00
		STB		CONTD_REG,X		; Reset the HOLD bit when complete.
		RTS

DATEPROMPT	FCC		"Enter date as 6 digits, DD MM YY: "
			FCB		$04
DAYBUF10	FCB		0
DAYBUF1		FCB		0
MONBUF10	FCB		0
MONBUF1		FCB		0
YRBUF10		FCB		0
YRBUF1		FCB		0

****************************************************
* Print the current time.
****************************************************
TIME	LDX		#RTCADDRESS
		LDB		#$01
		STB		CONTD_REG,X		; Set the HOLD bit
		LDB		CONTD_REG,X
		BITB	#$02			; Read the BUSY bit
		BEQ		TIME1
		LDB		#$00
		STB		CONTD_REG,X		; Reset the HOLD bit,
		JSR		PAUSE			; Wait,
		BRA		TIME			; and try again.


* Registers are read seconds first, hours last (all while HOLD is set).
* The ASCII digits are written into TIMETXT in HH:MM:SS display order.
TIME1	LDY		#TIMETXT

		LDB		SEC_1_REG,X		; Read the One's of seconds (first, right after HOLD).
		ANDB	#$0F
		ADDB	#$30
		STB		SECBUF1

		LDB		SEC_10_REG,X	; Read the Ten's of seconds.
		ANDB	#$0F
		ADDB	#$30
		STB		SECBUF10

		LDB		MIN_1_REG,X		; Read the One's of minutes.
		ANDB	#$0F
		ADDB	#$30
		STB		MINBUF1

		LDB		MIN_10_REG,X	; Read the Ten's of minutes.
		ANDB	#$0F
		ADDB	#$30
		STB		MINBUF10

		LDB		HOUR_1_REG,X	; Read the One's of hours.
		ANDB	#$0F
		ADDB	#$30
		STB		HOURBUF1

		LDB		HOUR_10_REG,X	; Read the Ten's of hours (last).
		ANDB	#$0F
		ADDB	#$30
		STB		HOURBUF10

		LDB		#$00
		STB		CONTD_REG,X		; Reset the HOLD bit when complete.

		LDB		HOURBUF10		; Now assemble TIMETXT in HH:MM:SS order
		STB		,Y+
		LDB		HOURBUF1
		STB		,Y+
		LDB		#':
		STB		,Y+
		LDB		MINBUF10
		STB		,Y+
		LDB		MINBUF1
		STB		,Y+
		LDB		#':
		STB		,Y+
		LDB		SECBUF10
		STB		,Y+
		LDB		SECBUF1
		STB		,Y

		LDX		#TIMETXT
        SWI
        FCB     PDATA
		RTS

****************************************************
* I command: toggle the RTC's 1-minute interrupt on and off, then go
* straight back to the command loop.
*
* CE_REG bits: D3=t1, D2=t0, D1=ITRPT/STND, D0=MASK.
*   $0A = 1-minute period, interrupt mode, enabled
*   $01 = masked (output off)
*
* The monitor's SWI calls leave the CPU's I mask set on return, so
* while the interrupt is ON the main loop waits for each keystroke
* by polling the DUART directly (no SWI) after clearing I - see START.
* IRQON remembers whether it is currently on.
****************************************************
IRQTOGGLE	LDX		#RTCADDRESS
			CLRA
			STA		CONTD_REG,X		; release HOLD, acknowledge any stale IRQ flag
			LDA		IRQON
			BNE		IT_OFF
			LDB		#$0A
			STB		CONTE_REG,X		; arm the RTC (1-minute interrupt)
			LDA		#$01
			STA		IRQON
			LDX		#IRQONTXT
			BRA		IT_MSG
IT_OFF		LDB		#$01
			STB		CONTE_REG,X		; mask the RTC interrupt output
			CLR		IRQON
			LDX		#IRQOFFTXT
IT_MSG		SWI
			FCB		PDATA
			RTS

IRQONTXT	FCC		"Interrupt ON - time is printed each minute."
			FCB		$04
IRQOFFTXT	FCC		"Interrupt OFF."
			FCB		$04

****************************************************
* INTERRUPT HANDLER: intended to fire once a minute from the RTC's
* fixed-period interrupt armed by IRQTOGGLE above. Entered via a
* genuine hardware IRQ, so the 6809 has already stacked the full
* machine state (CC,A,B,DP,X,Y,PC) on entry - RTI at the end restores
* all of it, no manual register save/restore needed here.
*
* Reads and prints HH:MM (seconds are not shown).
*
* Note: while setting/releasing HOLD here, the IRQ FLAG bit (CD D2)
* is deliberately kept at 1 throughout (writing $05/$04, not $01/$00)
* so it is NOT accidentally cleared mid-sequence - per the datasheet,
* writing 0 to CD should leave IRQ FLAG alone unless you deliberately
* mean to clear it. Only the final write acknowledges it (clears it
* to 0 together with HOLD), which also releases STD.P so the RTC can
* raise the interrupt again next minute.
****************************************************
RTCIRQ	LDX		#RTCADDRESS
		LDB		#$05			; Set HOLD=1; keep IRQ FLAG=1 (not yet
		STB		CONTD_REG,X		; acknowledged).
		LDB		CONTD_REG,X
		BITB	#$02			; Read the BUSY bit
		BEQ		RIRQ1
		LDB		#$04			; Clear HOLD=0 to retry; still keep
		STB		CONTD_REG,X		; IRQ FLAG=1.
		JSR		PAUSE
		BRA		RTCIRQ

RIRQ1	LDY		#IRQTXT
		LDB		HOUR_10_REG,X
		ANDB	#$0F
		ADDB	#$30
		STB		,Y+
		LDB		HOUR_1_REG,X
		ANDB	#$0F
		ADDB	#$30
		STB		,Y+
		LDB		#':
		STB		,Y+
		LDB		MIN_10_REG,X
		ANDB	#$0F
		ADDB	#$30
		STB		,Y+
		LDB		MIN_1_REG,X
		ANDB	#$0F
		ADDB	#$30
		STB		,Y

		LDB		#$00
		STB		CONTD_REG,X		; Clear HOLD AND acknowledge/clear the
								; RTC's own IRQ FLAG in the same write -
								; releases STD.P and re-arms the
								; interrupt for next minute.

		LDX		#IRQTXT
        SWI
        FCB     PDATA
		RTI

****************************************************
* Quit the application
****************************************************
QUIT	LDA		#$01
		STA		$F23E			; mask the RTC interrupt before leaving
		LDX		#NEWLINE
        SWI
        FCB     PDATA
		JMP		$E03C			; FLEX BIOS's MON entry point - we got here
								; via JMP QUIT (not JSR), so there's no
								; matching call frame for an RTS to return
								; through; jump straight to the monitor
								; instead of trying to "return" from one.

****************************************************
* Read a single-digit hex number from the console
****************************************************
HEXDIG	SWI
		FCB		INCHP			; Wait for a key to be pressed on the keyboard
		CMPA	#'0				; Brute force search for hex characters
		BNE		DIGIT
		LDB		#$00
		RTS
DIGIT	CMPA	#'1				; Brute force search for hex characters
		BNE		DIGIT1
		LDB		#$01
		RTS
DIGIT1	CMPA	#'2
		BNE		DIGIT2
		LDB		#$02
		RTS
DIGIT2	CMPA	#'3
		BNE		DIGIT3
		LDB		#$03
		RTS
DIGIT3	CMPA	#'4
		BNE		DIGIT4
		LDB		#$04
		RTS
DIGIT4	CMPA	#'5
		BNE		DIGIT5
		LDB		#$05
		RTS
DIGIT5	CMPA	#'6
		BNE		DIGIT6
		LDB		#$06
		RTS
DIGIT6	CMPA	#'7
		BNE		DIGIT7
		LDB		#$07
		RTS
DIGIT7	CMPA	#'8
		BNE		DIGIT8
		LDB		#$08
		RTS
DIGIT8	CMPA	#'9
		BNE		DIGIT9
		LDB		#$09
		RTS
DIGIT9	ANDA	#$DF
		CMPA	#'A
		BNE		DIGIT10
		LDB		#$0A
		RTS
DIGIT10	CMPA	#'B
		BNE		DIGIT11
		LDB		#$0B
		RTS
DIGIT11	CMPA	#'C
		BNE		DIGIT12
		LDB		#$0C
		RTS
DIGIT12	CMPA	#'D
		BNE		DIGIT13
		LDB		#$0D
		RTS
DIGIT13	CMPA	#'E
		BNE		DIGIT14
		LDB		#$0E
		RTS
DIGIT14	CMPA	#'F
		BNE		DIGIT15
		LDB		#$0F
		RTS
DIGIT15	LDB		#$F0			; If we get here, a wrong key has been pressed
		RTS

********************************
* Step 'a'
********************************
STEP_A	LDA		#$04
		STA		CONTF_REG,X
		LDA		#$04
		STA		CONTD_REG,X
		RTS
********************************
* Step 'b'
********************************
STEP_B	LDA		#$40
		STA		B_RETRY			; bounded: ~64 tries, then give up and report
SB_LOOP	LDB		#$01
		STB		CONTD_REG,X		; Set the HOLD bit
		LDB		CONTD_REG,X
		BITB	#$02			; Read the BUSY bit
		BEQ		B_EXIT
		LDB		#$00
		STB		CONTD_REG,X		; Reset the HOLD bit,
		JSR		PAUSE			; Wait,
		DEC		B_RETRY
		BNE		SB_LOOP			; and try again.
		LDX		#BUSYSTUCKTXT	; BUSY never cleared - say so, carry on
		SWI
		FCB		PDATA
		LDX		#RTCADDRESS
B_EXIT	RTS
B_RETRY	FCB		$00
BUSYSTUCKTXT	FCC		"RTC BUSY stuck set (CONTD bit1) - STEP_B gave up."
		FCB		$0D,$0A,$04

********************************
* Step 'c'
********************************
STEP_C	LDA		#$07
		STA		CONTF_REG,X
		BSR		PAUSE
		LDA		#$07
		STA		CONTF_REG,X
		RTS

PAUSE	LDA		#$FF
PAUSE1	DECA
		BNE		PAUSE1
		RTS

RTCZERO	LDA		#$00
		STA		SEC_1_REG,X
		STA		SEC_10_REG,X
		STA		MIN_1_REG,X
		STA		MIN_10_REG,X
		STA		HOUR_1_REG,X
		STA		HOUR_10_REG,X
		STA		DAY_1_REG,X
		STA		DAY_10_REG,X
		STA		MON_1_REG,X
		STA		MON_10_REG,X
		STA		YEAR_1_REG,X
		STA		YEAR_10_REG,X
		STA		D_O_W_REG,X
		RTS

********************************
* PROGRAM VARIABLES
* Moved here (inside the $2000+ program area) from before ORG $2000,
* where they defaulted to addresses $0000-$0006 - zero page. This
* program calls SWI constantly (every text print, every HEXDIG
* keypress); if the monitor's SWI handler uses any of that low
* memory as its own scratch space, every SWI call between one of
* our buffer writes and its later read-back would silently corrupt
* it. Keeping these in our own program space rules that out.
********************************
HEXCHAR		FCB		$00
IRQON		FCB		$00
KEYSAVE		FCB		$00
SECBUF1		FCB		$00
SECBUF10	FCB		$00
MINBUF1		FCB		$00
MINBUF10	FCB		$00
HOURBUF1	FCB		$00
HOURBUF10	FCB		$00

END


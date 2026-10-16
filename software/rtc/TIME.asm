********************************
* TIME.ASM - print the real-time clock for 6809 FLEX
*
*   TIME
*
* Reads the Epson RTC at $F230 and prints "DD/MM/YY HH:MM:SS".
* It only reads: the clock and FLEX's date are not changed. (The
* clock is kept in step with FLEX's date by the 1-minute interrupt;
* use K in the monitor to set it.)
*
* Uses the same HOLD/BUSY read protocol as the monitor's RTC code. The
* RTC interrupt flag is left as it was found, and interrupts are masked
* while HOLD is set so the 1-minute handler cannot interfere.
*
* Build:  a09 -F TIME.asm   (writes TIME.CMD, a FLEX binary)
********************************

* FLEX 6809 entry points
WARMS		EQU		$CD03		; warm start (return to FLEX)
PSTRNG		EQU		$CD1E		; print string at X, ends with $04
PCRLF		EQU		$CD24		; print CR/LF

* RTC (Epson, registers at $F230..$F23F; low nibble significant)
RTC		EQU		$F230
CONTD		EQU		$0D		; bit0 HOLD, bit1 BUSY, bit2 IRQ flag

		ORG		$C100

START		PSHS		CC
		ORCC		#$10		; mask IRQ while HOLD is set
		LDU		#RTC
		LDB		#$40		; tries
		PSHS		B
TM1		LDA		#$05		; HOLD, keep IRQ flag as it is
		STA		CONTD,U
		LDA		CONTD,U
		BITA		#$02		; BUSY?
		BEQ		TM2
		LDA		#$04		; release HOLD and try again
		STA		CONTD,U
		LDB		#$FF
TM1A		DECB
		BNE		TM1A
		DEC		0,S
		BNE		TM1
		LEAS		1,S
		LDA		#$04
		STA		CONTD,U
		PULS		CC
		LDX		#FAILTXT
		BRA		SHOW

TM2		LEAS		1,S
		LDY		#BUF
		TFR		U,X
		LDB		#12
TM3		LDA		,X+
		ANDA		#$0F
		STA		,Y+
		DECB
		BNE		TM3
		LDA		#$04		; release HOLD
		STA		CONTD,U
		PULS		CC		; interrupts back as they were

		LDA		BUF+5
		ANDA		#$03		; hour tens (ignore AM/PM flag bit)
		STA		BUF+5
		LDU		#BUF
		LDX		#TEXT
		LDY		#MAP
TM4		LDB		,Y+
		CMPB		#$FF
		BEQ		TM6
		TSTB
		BMI		TM5
		LDA		B,U
		ADDA		#$30
		STA		,X+
		BRA		TM4
TM5		ANDB		#$7F
		STB		,X+
		BRA		TM4
TM6		LDA		#$04
		STA		,X
		LDX		#TEXT
SHOW		PSHS		X
		JSR		PCRLF
		PULS		X
		JSR		PSTRNG
		JSR		PCRLF
		JMP		WARMS

* Buffer order: 0 S1, 1 S10, 2 M1, 3 M10, 4 H1, 5 H10, 6 D1, 7 D10,
*               8 MO1, 9 MO10, 10 Y1, 11 Y10
MAP		FCB		7,6,'/+$80,9,8,'/+$80,11,10,' +$80
		FCB		5,4,':+$80,3,2,':+$80,1,0,$FF

FAILTXT		FCC		"RTC not responding"
		FCB		$04

BUF		FCB		0,0,0,0,0,0,0,0,0,0,0,0
TEXT		FCB		0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

		END		START

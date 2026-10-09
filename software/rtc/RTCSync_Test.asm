********************************
* RTCSYNC_TEST - exercises Flex_RTC.asm from RAM, no PROM burn needed.
* Load Flex_RTC.s19 (at $FB00) first, then this (at $2000), then G 2000.
*  1) JSR RTCSYNC       -> prints the RTC date/time, sets Flex date bytes,
*                          arms the 1-minute interrupt
*  2) zeroes MONTH/DAY/YEAR ($CC0E-$CC10) so a refresh by the interrupt
*     handler is visible
*  3) unmasks IRQ and waits ~95 s (always spans a minute rollover)
*  4) prints MONTH DAY YEAR in hex - should be the real date again
*  5) returns via $E03C, which re-masks the RTC interrupt
********************************
PDATA	EQU	$03
PDATA1	EQU	$02
OUT2HS	EQU	$04
		ORG	$2000
		JSR		$FB00
		CLR		$CC0E
		CLR		$CC0F
		CLR		$CC10
		ANDCC	#$EF			; allow IRQ
		LDY		#$00CD			; ~205 x 0.46 s
OUTER	LDX		#$FFFF
INNER	LEAX	-1,X
		BNE		INNER
		LEAY	-1,Y
		BNE		OUTER
		ORCC	#$10
		LDX		#MSG
		SWI
		FCB		PDATA			; CR/LF, then the header text
		LDX		#$CC0E
		SWI
		FCB		OUT2HS			; month
		LDX		#SPC
		SWI
		FCB		PDATA1			; PDATA1 = no CR/LF
		LDX		#$CC0F
		SWI
		FCB		OUT2HS			; day
		LDX		#SPC
		SWI
		FCB		PDATA1
		LDX		#$CC10
		SWI
		FCB		OUT2HS			; year
		LDX		#NL
		SWI
		FCB		PDATA
		LDX		#$FFFF			; let the serial port finish sending before the
WAITTX	LEAX	-1,X			; monitor restarts (about half a second)
		BNE		WAITTX
		JMP		$E03C
MSG		FCC		"Flex date bytes MONTH DAY YEAR (hex): "
		FCB		$04
SPC		FCC		" "
		FCB		$04
NL		FCB		$0D,$0A,$04
END

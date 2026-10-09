********************************************
* Standalone INCH/OUTCH test -- exercises Flex_BIOS's console I/O
* directly through its own vector table, with FLEX completely out of
* the loop. Download this into RAM (via Assist09/the Terminal tab)
* alongside or after Flex_BIOS, then jump to whichever entry you want
* to test from Assist09.
********************************************
INCH_T		EQU	$D3FB		; Flex_BIOS's own console vector slots
OUTCH_T		EQU	$D3F9

		ORG	$2000

* Entry 1 (G 2000): INCH loopback. INCH already echoes internally, so
* this is the minimal end-to-end test of both read and echo/write in
* a single call -- type characters and watch them come back. If this
* behaves perfectly (one keystroke in, one character out, every time,
* no double-Return needed) then INCH/OUTCH are cleared and the bug is
* somewhere in FLEX's own console handling or the jump into it.
INCHTST	JSR	[INCH_T]
		BRA	INCHTST

* Entry 2 (G 2010): OUTCH-only, no input at all -- sends a fixed
* banner once to confirm OUTCH works in isolation, independent of
* whatever INCH is doing.
		ORG	$2010
OUTCHTST	LDX	#MSG
OUTLOOP	LDA	,X+
		CMPA	#$04		; sentinel marks end of string
		BEQ	OUTDONE
		JSR	[OUTCH_T]
		BRA	OUTLOOP
OUTDONE	RTS

MSG		FCC	"OUTCH TEST OK"
		FCB	$0D,$04

		END	INCHTST

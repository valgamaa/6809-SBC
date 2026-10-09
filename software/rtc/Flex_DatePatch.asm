********************************
* FLEX_DATEPATCH.ASM - one-off patch to FLEX's cold-start init so it does
* not ask for the date when ASSIST09_FLEX_RTC.ASM has already set it.
* Original bytes at $CA50:  8E CA D0  BD CE 82   (LDX #$CAD0 / JSR PSTRNG)
* Patched to:               7E FD 00  12 12 12   (JMP FLEXDATE / NOP x3)
* FLEXDATE ($FD00, in Assist09_Flex_RTC.asm) runs the original two
* instructions itself when the date has not been set.
********************************
		ORG	$CA50
		JMP	$FD00
		NOP
		NOP
		NOP
END

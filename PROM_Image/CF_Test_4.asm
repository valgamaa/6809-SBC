********************************
* MONITOR LABLES
********************************
INCHP	EQU	$00		; INPUT CHAR FROM CONSOLE AND ECHO
OUTCH	EQU	$01		; OUTPUT CHAR ON CONSOLE
PDATA	EQU	$03		; PRINT TEXT STRING @ X ENDED BY $04
OUT2HS	EQU	$04		; PRINT 2 HEX CHARS @ X
OUT4HS	EQU	$05		; PRINT 4 HEX CHARS @ X
HSDTA	EQU	$E436

********************************
* CF REGS
********************************
CFADDRESS	EQU 	$F2C0
*CFADDRESS	EQU 	$F300
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

CFSTATUSL	EQU		CFADDRESS+CFSTATUS
********************************
* START OF PROGRAM
********************************
	ORG	$8000
		JMP		START
********************************
* PROGRAM VARIABLES
********************************
HEXCHAR		FCB		$00
DRIVEID		EQU		$EC
LBA0		FCB		$00
LBA1		FCB		$00
LBA2		FCB		$00
LBA3		FCB		$E0
BUFFPNTR	FCB		$00
DATABLK		EQU		$1000
********************************

********************************
* MENU HELP TEXT
********************************
HHELP	FCC		"? - List the commands available."
		FCB		$0D,$0A
		FCC		"B - Load the CF Card buffer with following 256 hex values."
		FCB		$0D,$0A
		FCC		"D - Display the RAM buffer contents."
		FCB		$0D,$0A
		FCC		"F - Fill CF Card buffer with a constant."
		FCB		$0D,$0A
		FCC		"I - Initialise the CF Card."
		FCB		$0D,$0A
		FCC		"L - Set the LBA address."
		FCB		$0D,$0A
		FCC		"r - Read a data block from theCF Card."
		FCB		$0D,$0A
		FCC		"R - Read a Flex sector from theCF Card."
		FCB		$0D,$0A
		FCC		"w - Write a data block to the CF Card."
		FCB		$0D,$0A
		FCC		"W - Write a Flex sector to the CF Card."
		FCB		$0D,$0A
		FCC		"v - Verify the data block written to the CF Card."		
		FCB		$0D,$0A
		FCC		"V - Verify the Flex sector written to the CF Card."		
		FCB		$0D,$0A
		FCC		"P - Print the properties of the CF Card."		
		FCB		$0D,$0A
		FCC		"S - Set the current Flex sector."		
		FCB		$0D,$0A
		FCC		"T - Set the current Flex track."		
		FCB		$0D,$0A
		FCC		"Q - Exit this application & return to the monitor."		
		FCB		$0D,$0A,$04
		
********************************
* MENU OPTION TEXT
********************************
NEWLINE	FCB		$0D,$0A,$04
PROMPT	FCB		">",$04
INIT	FCC		"Initialise CF Card."
		FCB		$0D,$04
READ	FCC		"Read From CF Card."
		FCB		$0D,$04
WRITE	FCC		"Write to CF Card."
		FCB		$0D,$04
INFO	FCC		"Read CF Card Info."
		FCB		$0D,$04

********************************
* SUBROUTINE TEXT STRINGS
********************************
ERROR	FCC		"Error initialising the CF Card"
		FCB		$0D,$04
WAIT	FCC		"Waiting for CF Card"
		FCB		$0D,$04
MARKER	FCC		"*"
		FCB		$0D,$04
INHEX	FCC		"Enter hex code: "
		FCB		$04 
********************************

START	LDX		#NEWLINE		; Get a new line and print the input prompt
        SWI 
        FCB     PDATA 
		LDX		#PROMPT 
        SWI 
        FCB     PDATA
        SWI 
		FCB		INCHP			; Wait for a key to be pressed on the keyboard
		CMPA	#'?				; Print the list of available commands
		BNE		NEXT
		JSR		HELP
NEXT	CMPA	#'B				; Fill CF Card buffer with user-data.
		BNE		NEXT1
		JSR		BUFDATA
NEXT1	CMPA	#'D				; Display the RAM buffer contents.
		BNE		NEXT2
		JSR		DISPCF
NEXT2	CMPA	#'F				; Fill CF Card buffer with a constant
		BNE		NEXT3
		JSR		CFFILL
NEXT3	CMPA	#'I				; Initialise the CF Card
		BNE		NEXT4
		JSR		INITCF
NEXT4	CMPA	#'L				; Set the LBA addresses for the card
		BNE		NEXT4A
		JSR		LBACF
NEXT4A	CMPA	#'l				; Set the LBA addresses for the card, without prompts
		BNE		NEXT5
		JSR		LBACFS	
NEXT5	CMPA	#'R				; Read a block of data from the CF Card to memory
		BNE		NEXT6
		JSR		READCF
NEXT6	CMPA	#'r				; Read a block of data from the CF Card to memory
		BNE		NEXT7
		JSR		READFLX
NEXT7	CMPA	#'w				; Write a block of data to the memory toCF Card
		BNE		NEXT8
		JSR		WRITECF
NEXT8	CMPA	#'W				; Write a sector of data to the memory toCF Card
		BNE		NEXT9
		JSR		WRTFLX
NEXT9	CMPA	#'v				; Print the properties of the CF Card
		BNE		NEXT10
		JSR		CFVERIF
NEXT10	CMPA	#'V				; Verify the Flex sector
		BNE		NEXT11
		JSR		FVERIF
NEXT11	CMPA	#'P				; Print the properties of the CF Card
		BNE		NEXT12
		JSR		CFINFO
NEXT12	CMPA	#'S				; Set the Flex sector number (LBA0)
		BNE		NEXT13
		JSR		FSECTOR
NEXT13	CMPA	#'T				; Set the Flex track number (LBA1)
		BNE		NEXT14
		JSR		FTRACK
NEXT14	CMPA	#'Q				; Exit the program
		LBNE	START
		JMP		QUIT
		JMP		START

****************************************************
* Load the CF Card buffer with user-sent data.
* 256 bytes must be sent co complete this function &
* return to the menu.
****************************************************
BUFDATA	PSHS	Y,X,B,A
		LDB		#$00			; Set a loop counter to read 256 bytes of DATA from the serial port
		LDX		#DATABLK		; Point to the start of the memory block
BUFLOOP	PSHS	X,B
		JSR		GETHEXB			; Get the hex address value
		PULS	X,B
		STA		, X+			; Write the data byte to the buffer.
		INCB
		BNE		BUFLOOP
		JSR		WRTFLX
		PULS	Y,X,B,A
		RTS




****************************************************
* Display the contents of the RAM buffer
****************************************************
DISPCF	PSHS	Y,X,B,A
		LDX		#DATABLK
		PSHS	X
		LDX		#DATABLK+$0200
		PSHS	X
		JSR		HSDTA
		PULS	Y,X,B,A
		PULS	X
		PULS	X
		RTS

****************************************************
* Set the LBA values used for reading a block of data from the CF Card
****************************************************
LBATXT0	FCB		"LBA 0 value (hex): ",$04
LBATXT1	FCB		"LBA 1 value (hex): ",$04
LBATXT2	FCB		"LBA 2 value (hex): ",$04
LBACF	PSHS	A, B
		LDY		#LBATXT0
		JSR		GETHEX			; Get the hex address value
		STA		LBA0
		
		LDY		#LBATXT1
		JSR		GETHEX
		STA		LBA1
		
		LDY		#LBATXT2
		JSR		GETHEX
		STA		LBA2
		
		PULS	A, B
		RTS

****************************************************
* Set the LBA values used for reading a block of data from the CF Card,
* without sending text to the terminal.
****************************************************
LBACFS	PSHS	A, B
		JSR		GETHEX			; Get the hex address value
		STA		LBA0
		JSR		GETHEX
		STA		LBA1
		JSR		GETHEX
		STA		LBA2		
		PULS	A, B
		RTS


****************************************************
* Initialise the CF Card
****************************************************
INITCF	LDX		#CFADDRESS
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
		LDB		LBA0
		STB		CFLBA0, X
		JSR		CMDWAIT
		LDB		LBA1
		STB		CFLBA1, X
		JSR		CMDWAIT
		LDB		LBA2
		STB		CFLBA2, X
		JSR		CMDWAIT
		LDB		#LBA3
		ANDB	#$0F			; Mask the lower nibble
		ORB		#$E0			; Set LBA mode, IDE master
		STB		CFLBA3, X
		JSR		CMDWAIT
		JSR		CFERR
		RTS


****************************************************
* Print CF Card information
****************************************************
SERNO	FCC		"   Serial No.: "		
		FCB		$04
FIRMREV	FCC		"Firmware Rev.: "		
		FCB		$04
MODELNO	FCC		"    Model No.: "		
		FCB		$04
LBAHEAD	FCC		"                1  2  3  4"		
		FCB		$04
LBASIZE	FCC		"    LBA Size : "		
		FCB		$04

CFINFO	PSHS	Y,X,B,A
		JSR		CMDWAIT
		LDX		#CFADDRESS
		LDB		#DRIVEID			; Issue Drive ID command
		STB		CFCOMMAND, X
		
		LDY		#DATABLK			; Point to the start of the memory block
INFOCF	JSR		DATWAIT
		LDB		CFSTATUS, X			; Check the Drq bit for available data
		BITB	#$08
		BEQ		INFNEXT
		LDB		CFDATA, X			; Read the data byte
		STB		,Y+					; Write it te the buffer
		BRA		INFOCF
		
INFNEXT	LDX		#MODELNO
		SWI
		FCB		PDATA
		LDY 	#DATABLK+54
		LDB		#20
MODNO	LDA		1,Y
		SWI
		FCB		OUTCH
		LDA		,Y++
		SWI
		FCB		OUTCH
		DECB	
		BNE MODNO

		LDX		#FIRMREV
		SWI
		FCB		PDATA
		LDY 	#DATABLK+46
		LDB		#4
FIRM	LDA		1,Y
		SWI
		FCB		OUTCH
		LDA		,Y++
		SWI
		FCB		OUTCH
		DECB	
		BNE FIRM

		LDX		#SERNO
		SWI
		FCB		PDATA
		LDY 	#DATABLK+20
		LDB		#10
SERIAL	LDA		1,Y
		SWI
		FCB		OUTCH
		LDA		,Y++
		SWI
		FCB		OUTCH
		DECB	
		BNE 	SERIAL

		LDX		#LBASIZE
		SWI
		FCB		PDATA
		LDY 	#DATABLK+107
		LDB		#$02
LBACNT	LEAX	,Y
		SWI
		FCB		OUT2HS
		LEAX	-1,Y
		SWI
		FCB		OUT2HS
		LEAY	-2,Y
		DECB	
		BNE 	LBACNT

		PULS	Y,X,B,A
		RTS		

****************************************************
* Read a block of data from the CF Card to memory
* Loop until the Drq bit = 0 (bit 3)
****************************************************

READCF	PSHS	Y,X,B,A
		LDX		#CFADDRESS		
		JSR		DATWAIT
		LDB		LBA0				; Load the LBA addresses with the current
		STB		CFLBA0, X			; settings before issuing the read command.
		JSR		DATWAIT
		LDB		LBA1
		STB		CFLBA1, X
		JSR		DATWAIT
		LDB		LBA2
		STB		CFLBA2, X
		JSR		DATWAIT
		LDB		LBA3
		ANDB	#$0F				; Mask the lower nibble
		ORB		#$E0				; Set LBA mode, IDE master
		STB		CFLBA3, X
		JSR		DATWAIT
		LDB		#$01
		STB		CFSECCNT, X
		JSR		DATWAIT

		LDB		#$20				; Send read command to the CF Card
		STB		CFCOMMAND, X
		JSR		DATWAIT

		LDY		#DATABLK			; Point to the start of the memory block
RDLOOP	JSR		DATWAIT
		LDA		CFDATA, X			; Read the data byte
		STA		,Y+					; Write it to the buffer
		JSR		DATWAIT
		LDA		CFSTATUS, X		
		BITA	#$08
		BNE		RDLOOP

RDEXIT	PULS	Y,X,B,A
		RTS

****************************************************
* Read a Flex sector from the CF Card to memory
* Loop until the Drq bit = 0 (bit 3)
****************************************************
READFLX	PSHS	Y,X,B,A
		LDY		#CFADDRESS		; Address CF card 1.
		JSR		CFWAIT
		LDA		LBA0
		STA		CFLBA0, Y		; Load the Sector number
		JSR		CFWAIT
		LDA		LBA1
		STA		CFLBA1, Y		; Load the Track number
		JSR		CFWAIT
		LDA		LBA2
		STA		CFLBA2, Y		; Load the drive number
		JSR		CFWAIT
		LDA		#$E0
		STA		CFLBA3, Y		
		ANDA	#$0F			; Mask the lower nibble
		ORA		#$E0			; Set LBA mode, IDE master
		JSR		CFWAIT			; The wanted sector is selected, and can now be read.	
		LDA		#$20			; Send read command to the CF Card
		STA		CFCOMMAND, Y
		JSR		CFWAIT		
		LDA		#$00			; Set a loop counter to read the first 256 bytes of DATA
		LDX		#DATABLK		
FLEXLP	JSR		DATWAIT
		LDA		CFDATA, Y		; Read the data byte
		STA		,X+				; Write it to the buffer	
		INCA
		BNE		FLEXLP			; Count to 256 - a Flex sector
RDTAIL	JSR		DATWAIT
		LDB		CFDATA, Y		; Now read and discard the rest of the data		
		LDA		CFSTATUS, Y		
		BITA	#$08
		BNE		RDTAIL	
		PULS	Y,X,B,A
		RTS


****************************************************
* Write a block of data from the memory to CF Card
****************************************************
WRITECF	PSHS	Y,X,B,A	
		JSR		CMDWAIT
		LDX		#CFADDRESS		
		LDA		LBA0				; Load the LBA addresses with the current
		STA		CFLBA0, X			; settings before issuing the write command.
		JSR		CMDWAIT
		LDA		LBA1
		STA		CFLBA1, X
		JSR		CMDWAIT
		LDA		LBA2
		STA		CFLBA2, X
		JSR		CMDWAIT
		LDA		LBA3
		STA		CFLBA3, X
		ANDA	#$0F			; Mask the lower nibble
		ORA		#$E0			; Set LBA mode, IDE master
		JSR		CMDWAIT
		LDA		#$01
		STA		CFSECCNT, X

		JSR		CMDWAIT
		LDA		#$30				; Send write command to the CF Card
		STA		CFCOMMAND, X
		JSR		CMDWAIT

		LDY		#DATABLK			; Point to the start of the memory block
WRLOOP	LDA		,Y+					; Read the byte from the buffer
		STA		CFDATA, X			; Write the data byte to the CF Card.
		JSR		DATWAIT
		LDA		CFSTATUS, X		
		BITA	#$08
		BNE		WRLOOP
		PULS	Y,X,B,A
		RTS

****************************************************
* Write a Flex sector to the CF Card from memory
* Loop until the Drq bit = 0 (bit 3)
****************************************************
WRTFLX	PSHS	Y,X,B,A
		LDY		#CFADDRESS		; Address CF card 1.
		JSR		CFWAIT
		LDB		LBA0
		STB		CFLBA0, Y		; Load the Sector number
		JSR		CFWAIT
		LDB		LBA1
		STB		CFLBA1, Y		; Load the Track number
		JSR		CFWAIT
		LDB		LBA2
		STB		CFLBA2, Y		; Load the drive number
		JSR		CFWAIT
		LDB		#$E0
		STB		CFLBA3, Y
		ANDB	#$0F			; Mask the lower nibble
		ORB		#$E0			; Set LBA mode, IDE master
		JSR		CFWAIT			; The wanted sector is selected, and can now be written to.	
		LDB		#$01
		STB		CFSECCNT, X
		JSR		CMDWAIT
		LDB		#$30			; Send read command to the CF Card
		STB		CFCOMMAND, Y
		JSR		CFWAIT		
		LDA		#$00			; Set a loop counter to write the first 256 bytes of DATA
		LDX		#DATABLK		; Point to the start of the memory block
WRFLOOP	JSR		DATWAIT
		LDB		,X+				; Read the byte from the buffer
		STB		CFDATA, Y		; Write the data byte to the CF Card.
		INCA
		BNE		WRFLOOP
		LDA		#$00			; Set a loop counter to write the next 256 bytes of DATA
		LDB		#$00

WRTAIL	JSR		DATWAIT
		STB		CFDATA, Y		; Write the data byte to the CF Card.
		INCA
		BNE		WRTAIL
		JSR		CFWAIT
		PULS	Y,X,B,A
		RTS

****************************************************
* Fill the CF Card buffer memory with a constant
****************************************************
CFFILL	PSHS	A
		LDY		#INHEX				; Get the fill character in A
		JSR		GETHEX				; Load the value to be written to the memory block
		LDX		#$0200				; Initialise the counter to 512
		LDY		#DATABLK			; Point to the start of the memory block
LFILL	STA		,Y+					; Write the data
		LEAX	-1,X				; Decrement the loop counter
		BNE		LFILL				; Repeat until counter = 0
		PULS	A
		RTS

****************************************************
* Verify the data Flex sector written to the CF Card
****************************************************
FVERIF	RTS

****************************************************
* Verify the data written to the CF Card
****************************************************
VERTXT	FCC		"Verify error at "		
		FCB		$04
VDATC	FCC		"  Card data value : "		
		FCB		$04
VDATM	FCC		"Buffer data value : "		
		FCB		$04
CFVERIF	LDX		#VERTXT
        SWI 
        FCB     PDATA 
		RTS

****************************************************
* Print the list of available commands
****************************************************
HELP	LDX		#HHELP
        SWI 
        FCB     PDATA 
		RTS 

****************************************************
* Set the current Flex sector 
****************************************************
SECTTXT	FCB		"Sector number (hex): ",$04
FSECTOR	PSHS	A,B,Y
		LDY		#SECTTXT
		JSR		GETHEX			; Get the hex sector number
		STA		LBA0
				PULS	A,B,Y
		RTS

****************************************************
* Set the current Flex track 
****************************************************
TRCKTXT	FCB		"Track number (hex): ",$04
FTRACK	PSHS	A,B,Y
		LDY		#TRCKTXT
		JSR		GETHEX			; Get the hex track number
		STA		LBA1
		PULS	A,B,Y
		RTS

****************************************************
* Quit the application
****************************************************
QUIT	LDX		#NEWLINE
        SWI 
        FCB     PDATA 
		RTS        
        
****************************************************
* Wait for CF Card ready when reading/writing to CF Card
* Check for Busy = 0 (bit 7)
****************************************************
CFWAIT	PSHS	A, B
X		LDB		CFSTATUSL	 	; Read the status register
		BITB	#$80			; Isolate the ready bit
		BNE		X				; Wait for the bit to clear
CFWAIT1	LDB		CFSTATUSL	 	; Read the status register
		BITB	#$40			; Isolate the ready bit
		BEQ		CFWAIT1			; Wait for the bit to clear
		PULS	A, B
		RTS        

****************************************************
* Wait for CF Card ready when reading/writing to CF Card
* Check for Busy = 0 (bit 7)
****************************************************
*DATWAIT	PSHS	A, B
*		LDA		#$00			; Reset time-out counter
*DATWT	LDB		CFSTATUS,X	 	; Read the status register
*		INCA
*		BITA	#$00
*		BEQ 	WTEXIT
*		BITB	#$80			; Isolate the ready bit
*		BNE		DATWT			; Wait for the bit to clear
*WTEXIT	PULS	A, B
*		RTS        

****************************************************
* Wait for CF Card ready when reading/writing to CF Card
* Check for Busy = 0 (bit 7)
****************************************************
DATWAIT	LDB		CFSTATUSL	 	; Read the status register
		BITB	#$80			; Isolate the ready bit
		BNE		DATWAIT			; Wait for the bit to clear
		RTS        

****************************************************
* Wait for CF Card ready when reading/writing to CF Card
* Check for RDY = 0 (bit 6)
****************************************************
CMDWAIT	LDB		CFSTATUSL	 	; Read the status register
		BITB	#$C0			; Isolate the ready bit
		BEQ		CMDWAIT			; Wait for the bit to clear
		RTS        

****************************************************
* Error Initialising the CF Card
****************************************************
CFERR	LDB		CFSTATUSL
		BITB	#$01			; Isolate the error bit
		BEQ		EREXIT			
		SWI 
		FCB     PDATA 
EREXIT	RTS

****************************************************
* Read a 2-digit hex number from the console
****************************************************	
GETHEX	LDX		#NEWLINE		; Get a new line and print the input prompt
        SWI 
        FCB     PDATA 
		LEAX	,Y
        SWI 
        FCB     PDATA
        JSR		HEXDIG			; Get first digit
        BITB	#$F0
        BNE		GETHEX			; An incorrect key was pressed, try again
        LSLB
        LSLB
        LSLB
        LSLB
        LDX		#HEXCHAR
        STB		,X
        JSR		HEXDIG			; Get second digit
        ADDB	,X
        STB		,X
        LDA		,X
		RTS

****************************************************
* Read a 2-digit hex number from the console without prompt
****************************************************	
GETHEXB	JSR		HEXDIG			; Get first digit
        BITB	#$F0
        BNE		GETHEXB			; An incorrect key was pressed, try again
        LSLB
        LSLB
        LSLB
        LSLB
        LDX		#HEXCHAR
        STB		,X
        JSR		HEXDIG			; Get second digit
        ADDB	,X
        STB		,X
        LDA		,X
		RTS

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
		
END
       

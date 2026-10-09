********************************************
* Flex_BIOS disk-image loader -- receives FLEX disk-image sectors over the
* serial link and writes them onto a CF-card "drive" via Flex_BIOS.asm's
* real DRIVE_T/WRITE_T entries (the same fixed $DE00 disk vector table
* READ_T etc. use), so a whole vintage FLEX .DSK image can be cloned onto
* the SBC's CF card sector-for-sector without FLEX itself being involved.
*
* Download Flex_BIOS.asm first (as always). Lives above Assist09
* (relocated from $9000 so all of $8000-$DFFF stays free for user
* FLEX programs); launched with the monitor's 'U' (Upload) command.
* On startup it calls INIT_T once (this
* program bypasses FLEX entirely, so nothing else does that) and sends a
* single ACK byte to say it's ready. From then on it loops receiving
* packets of the form:
*
*   [SOH=$01][DRIVE][TRACK][SECTOR][256 data bytes][8-bit checksum]
*
* and writes each one, replying with a single status byte per packet:
*
*   ACK=$06                      -- written successfully
*   NAK=$15 then one error byte  -- failed; the byte is either the
*                                   driver's own WRITE_T error code, or
*                                   CKERR=$FF for a checksum mismatch
*                                   (nothing was written -- resend the
*                                   SAME packet)
*
* A packet whose sync byte is EOT=$04 instead of SOH means "all done":
* the receiver ACKs it and returns cleanly to the Assist09 monitor.
*
* This program is deliberately self-contained (its own local EQUs for
* the disk vector addresses and its own minimal, non-echoing serial I/O)
* rather than depending on Flex_BIOS.asm's internal layout, matching the
* convention already used by Flex_BIOS_ReadTest.asm/inch_outch_test.asm.
********************************************

********************************
* Flex_BIOS's disk I/O vector table -- fixed addresses. These are real JMP
* instructions (not address pointers), so they're called with a plain,
* direct JSR -- see Flex_BIOS.asm's disk vector table comment for why.
********************************
WRITE_T		EQU	$DE03
DRIVE_T		EQU	$DE0C
INIT_T		EQU	$DE15

********************************
* Flex_BIOS's console vector table -- these ARE address pointers (FLEX's
* console/SCF convention differs from its disk/RDF convention), so
* MONITR_T is called indirectly, matching Flex_BIOS.asm's own usage.
********************************
MONITR_T	EQU	$D3F3

********************************
* This program's OWN minimal, self-contained serial I/O -- deliberately
* NOT using Assist09's SWI console services (which echo every input byte,
* which would spam the terminal with 256 raw binary bytes per sector) and
* NOT using Flex_BIOS.asm's own console routines either, to keep this
* program fully self-contained like the other standalone test tools.
* Same 68681 DUART register layout and the same bus-recovery NOPs already
* proven necessary elsewhere in this project.
********************************
PORTA		EQU	$F340
Status		EQU	1
RxBuff		EQU	3
TxBuff		EQU	3

********************************
* Protocol constants
********************************
SOH		EQU	$01
EOT		EQU	$04
ACK		EQU	$06
NAK		EQU	$15
CKERR		EQU	$FF				; Synthetic "error code" sent after a NAK
							; that was actually a checksum mismatch,
							; not a real WRITE_T failure

********************************
* START OF PROGRAM
********************************
	ORG	$EE00
		JMP	START
********************************
* PROGRAM VARIABLES
********************************
DRVFCB		FCB	$00,$00,$00,$00	; Minimal FCB for DRIVE_T -- only byte 3
						; (the drive number) is ever read
PKTDRV		FCB	$00
PKTTRACK	FCB	$00
PKTSECT		FCB	$00
BYTECNT		FCB	$00
CKSUM		FCB	$00
DATABLK		EQU	$1000			; 256-byte sector buffer -- same address
						; Flex_BIOS_ReadTest.asm uses for the same
						; purpose (never both resident at once)
********************************

START	JSR		INIT_T			; Configure both CF cards
		LDA		#ACK			; Ready signal -- the host should wait for
		JSR		SENDCH			; this before streaming any packets

****************************************************
* Main packet loop
****************************************************
LOOP	JSR		RECVCH			; Get the sync byte
		CMPA	#EOT
		BEQ		ALLDONE
		CMPA	#SOH
		BNE		LOOP			; Resync: silently ignore anything that
							; isn't a valid sync byte
		JSR		RECVCH			; Drive number
		STA		PKTDRV
		JSR		RECVCH			; Track
		STA		PKTTRACK
		JSR		RECVCH			; Sector
		STA		PKTSECT
		LDX		#DATABLK
		CLR		BYTECNT
		CLR		CKSUM
RECVLP	JSR		RECVCH			; One data byte
		STA		,X+
		ADDA	CKSUM
		STA		CKSUM
		INC		BYTECNT
		LDA		BYTECNT
		BNE		RECVLP			; Loops exactly 256 times (0->1->...->
							; 255->0, wrapping back to zero)
		JSR		RECVCH			; Sender's checksum byte
		CMPA	CKSUM
		BEQ		CKOK
		LDA		#NAK			; Checksum mismatch -- nothing written,
		JSR		SENDCH			; host should resend this same packet
		LDA		#CKERR
		JSR		SENDCH
		BRA		LOOP
CKOK	LDA		PKTDRV
		STA		DRVFCB+3
		LDX		#DRVFCB
		JSR		DRIVE_T			; Select the drive (direct JSR)
		TSTB
		BNE		WRERR
		LDA		PKTTRACK
		LDB		PKTSECT
		LDX		#DATABLK
		JSR		WRITE_T			; Write the sector (direct JSR)
		TSTB
		BNE		WRERR
		LDA		#ACK
		JSR		SENDCH
		BRA		LOOP
WRERR	PSHS	B				; Save the driver's own error code
		LDA		#NAK
		JSR		SENDCH
		PULS	A
		JSR		SENDCH
		BRA		LOOP
ALLDONE	LDA		#ACK
		JSR		SENDCH
		JSR		[MONITR_T]		; Return cleanly to Assist09
		RTS

****************************************************
* Minimal self-contained serial I/O (no echo, no monitor SWI dependency).
* Identical polling logic to Flex_BIOS.asm's INCHNE/OUTCH, including the
* bus-recovery NOPs already proven necessary on this hardware.
****************************************************
RECVCH	PSHS	U				; Preserve the U register
RECVWT	LDU		#PORTA			; Load 68681 base address
		LDA		Status,U		; Load STATUS register
		LSRA					; Test receiver register flag
		BCC		RECVWT			; Wait if nothing
		NOP						; Bus recovery margin -- same fix as
		NOP						; elsewhere in this project: reading
								; RxBuff immediately after Status gave
								; the DUART no recovery time
		LDA		RxBuff,U		; Load DATA byte
		PULS	U				; Restore 'U'
		RTS						; Return with received character in 'A'

SENDCH	PSHS	B,U				; Save registers & work byte
		LDU		#PORTA			; Load 68681 base address
SENDWT	LDB		Status,U		; Load STATUS register
		BITB	#$04			; Check if the port is ready to send
		BEQ		SENDWT			; Wait if not ready
		STA		TxBuff,U		; Write to the output buffer
		PULS	B,U				; Restore 'U'
		RTS

END

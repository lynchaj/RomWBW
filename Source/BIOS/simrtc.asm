;
;==================================================================================================
; SIMH RTC DRIVER
;==================================================================================================
;
SIMRTC_IO	.EQU	$FE	; SIMH IO PORT
SIMRTC_CLKREAD	.EQU	7	; READ CLOCK COMMAND
SIMRTC_CLKWRITE	.EQU	8	; WRITE CLOCK COMMAND
SIMRTC_BUFSIZ	.EQU	6	; SIX BYTE BUFFER (YYMMDDHHMMSS)
;
; RTC DEVICE INITIALIZATION ENTRY
;
SIMRTC_INIT:
	PRTS("SIMRTC: $")
;
	; DISPLAY CURRENT TIME
	LD	HL,SIMRTC_BUF
	PUSH	HL
	CALL	SIMRTC_GETTIM0
	POP	HL
	CALL	PRTDT
;
	XOR	A		; SIGNAL SUCCESS
	RET
;
; RTC DEVICE FUNCTION DISPATCH ENTRY
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERR
;   B: FUNCTION (IN)
;
SIMRTC_DISPATCH:
	LD	A,B		; GET REQUESTED FUNCTION
	AND	$0F		; ISOLATE SUB-FUNCTION
	JP	Z,SIMRTC_GETTIM	; GET TIME
	DEC	A
	JP	Z,SIMRTC_SETTIM	; SET TIME
	DEC	A
	JP	Z,SIMRTC_GETBYT	; GET NVRAM BYTE VALUE
	DEC	A
	JP	Z,SIMRTC_SETBYT	; SET NVRAM BYTE VALUE
	DEC	A
	JP	Z,SIMRTC_GETBLK	; GET NVRAM DATA BLOCK VALUES
	DEC	A
	JP	Z,SIMRTC_SETBLK	; SET NVRAM DATA BLOCK VALUES 
	CALL	PANIC
;
; NVRAM FUNCTIONS ARE NOT AVAILABLE IN SIMULATOR
;
SIMRTC_GETBYT:
SIMRTC_SETBYT:
SIMRTC_GETBLK:
SIMRTC_SETBLK:
	CALL	PANIC
;
; RTC GET TIME
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERR
;   HL: DATE/TIME BUFFER (OUT)
; BUFFER FORMAT IS BCD: YYMMDDHHMMSS
; 24 HOUR TIME FORMAT IS ASSUMED
;
SIMRTC_GETTIM:
	; GET THE TIME INTO TEMP BUF
	PUSH	HL			; SAVE PTR TO CALLS BUFFER
	CALL	SIMRTC_GETTIM0		; GET TIME TO WORK BUFFER
;
	; NOW COPY TO REAL DESTINATION (INTERBANK SAFE)
	LD	A,BID_BIOS		; COPY FROM BIOS BANK
	LD	(HB_SRCBNK),A		; SET IT
	LD	A,(HBX_INVBNK)		; COPY TO CURRENT USER BANK
	LD	(HB_DSTBNK),A		; SET IT
	LD	HL,SIMRTC_BUF		; SOURCE ADR
	POP	DE			; DEST ADR
	LD	BC,SIMRTC_BUFSIZ	; LENGTH
	CALL	BNKCPY			; COPY THE CLOCK DATA
;
	LD	DE,100			; DELAY 100 * 25uS
	CALL	VDELAY			; SLOW DOWN SIMH FOR CLOCK TICKING TEST
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
SIMRTC_GETTIM0:
	LD	HL,SIMRTC_BUF
	LD	A,SIMRTC_CLKREAD	; READ CLOCK COMMAND
	OUT     (SIMRTC_IO),A		; SEND IT TO SIMH
	LD	B,SIMRTC_BUFSIZ		; SETUP TO GET 6 BYTES
	LD	C,SIMRTC_IO		; FROM SIMH PORT
	INIR				; GET BYTES TO (HL)
	RET
;
; RTC SET TIME
;   A: RESULT (OUT), 0=OK, Z=OK, NZ=ERR
;   HL: DATE/TIME BUFFER (IN)
; BUFFER FORMAT IS BCD: YYMMDDHHMMSSWW
; 24 HOUR TIME FORMAT IS ASSUMED
;
SIMRTC_SETTIM:
	; COPY TO TEMP BUF
	LD	A,(HBX_INVBNK)		; COPY FROM CURRENT USER BANK
	LD	(HB_SRCBNK),A		; SET IT
	LD	A,BID_BIOS		; COPY TO BIOS BANK
	LD	(HB_DSTBNK),A		; SET IT
	LD	DE,SIMRTC_BUF		; DEST ADR
	LD	BC,SIMRTC_BUFSIZ	; LENGTH
	CALL	BNKCPY			; COPY THE CLOCK DATA
;
	LD	HL,SIMRTC_BUF		; POINT TO TEMP BUF
	LD	A,SIMRTC_CLKWRITE	; WRITE CLOCK COMMAND
	OUT     (SIMRTC_IO),A		; SEND COMMAND TO SIMH
	LD      A,L			; LOW BYTE OF BUFFER ADDRESS
	OUT     (SIMRTC_IO),A		; SEND IT
	LD      A,H			; HIGH BYTE OF BUFFER ADDRESS
	OUT     (SIMRTC_IO),A		; SEND IT
;
	XOR	A			; SIGNAL SUCCESS
	RET				; AND RETURN
;
; WORKING VARIABLES
;
SIMRTC_BUF:	; ALL IN BCD!!!
SIMRTC_YR	.DB	0
SIMRTC_MO	.DB	0
SIMRTC_DT	.DB	0
SIMRTC_HH	.DB	0
SIMRTC_MM	.DB	0
SIMRTC_SS	.DB	0
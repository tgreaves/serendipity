* Serendipity
* Coded by Mercenary of Perception
* © 1994 Tristan Greaves.  All Rights Reserved.
*
* System legal, so should be compatable with ALL Amigas.
* Multitasking.
*
* Not optimised in any way at the moment for maximum clarity.
*
* Assembled with Devpac 3.04 using the 3.0 Include Files
* Tested on an A1200 (2 Megs/2 Drives) - Kickstart 3
*	       A1200 (2 Megs/2 Drives) - Relokick 1.3
*              A500  (1 Meg)           - Kickstart 1.3 (Not enough memory)
*
* 1 Meg Chip required to run this production.
* 
* Last updated 2nd May 1994
*
* Last changes:		Mouse wraparound bug fixed.
*
* -------------------------------------------------------------------------
* -                       SYSTEM INCLUDE FILES                            -
* -------------------------------------------------------------------------

		include	exec/types.i
		include	exec/libraries.i
		include	exec/exec_lib.i
		include	exec/memory.i
		include	intuition/intuition.i
		include	intuition/screens.i
		include	intuition/intuition_lib.i
		include	graphics/graphics_lib.i
		include	dos/dos.i
		include	dos/dos_lib.i
		include	libraries/dosextens.i
		include	powerpacker_lib.i
		include	ppbase.i
		
* -------------------------------------------------------------------------
* -                             MACROS                                    -
* -------------------------------------------------------------------------

CALLSYS		MACRO
		LINKLIB	_LVO\1,\2
		ENDM

* -------------------------------------------------------------------------
* -                            EQUATES                                    -
* -------------------------------------------------------------------------

_AbsExecBase	EQU	4

NULL		EQU	0
TRUE		EQU	1

LF		EQU	10

NO_INTUITION	EQU	1
NO_GRAPHICS	EQU	2
NO_PP		EQU	3
NO_RESOURCES	EQU	4
NO_MEM		EQU	11

* -------------------------------------------------------------------------
* -                          PROGRAM CODE                                 -
* -------------------------------------------------------------------------
			
		SECTION	"Code",CODE

* CLI/WB Startup Code.

	movem.l	d0/a0,-(sp)		save initial values
	clr.l	returnMsg

	sub.l	a1,a1
	CALLEXEC FindTask		find us
	move.l	d0,a4

	tst.l	pr_CLI(a4)
	beq.s	fromWorkbench

* we were called from the CLI
	movem.l	(sp)+,d0/a0		restore regs
	bra.s	end_startup		and run the user prog

* we were called from the Workbench
fromWorkbench
	lea	pr_MsgPort(a4),a0
	CALLEXEC WaitPort		wait for a message
	lea	pr_MsgPort(a4),a0
	CALLEXEC GetMsg			then get it
	move.l	d0,returnMsg		save it for later reply
	move.l	#1,fromwb		for opening a console later

* do some other stuff here like the command line etc
	nop

	movem.l	(sp)+,d0/a0		restore
end_startup
	bsr.s	_main			call our program

* returns to here with exit code in d0
	move.l	d0,-(sp)		save it

	tst.l	returnMsg
	beq.s	exitToDOS		if I was a CLI

	CALLEXEC Forbid
	move.l	returnMsg,a1
	CALLEXEC ReplyMsg

exitToDOS
	move.l	(sp)+,d0		exit code
	rts

* startup code variable

* the program starts here
	even
_main
		
		move.l	#0,error_flag
		move.l	_AbsExecBase,_SysBase

		lea	dos_name,a1
		moveq	#0,d0
		CALLSYS	OpenLibrary,_SysBase
		move.l	d0,_DosBase
		beq	EXIT

; Check that at least 600k of chip memory is available.
; (Minimum to run the production)

		move.l	#MEMF_CHIP,d1		; chip memory
		CALLSYS	AvailMem,_SysBase	; do it.

		cmpi.l	#600000,d0		; compare it.		

; d0 is subtracted from 600000 (Whoops!)

; Enough:   800000 - 600000    = POSITIVE NUMBER when enough chip memory
;           600000 - 600000    =     ZERO NUMBER when enough chip memory
;
; N-Enough: 200000 - 6000000   = NEGATIVE NUMBER when n-enough chip memory

		bge	DOS_OK		; branch if greater or equal.

; If here, not enough chip memory. Generate the error.

		move.b	#NO_MEM,error_flag	; error code 11
		jsr	ErrorMsg
		jmp	CLOSEDOS1	; and kill dos and exit.

; Open libraries

DOS_OK		pea	CLOSEDOS	; return address on stack.
		jsr	OpenIntuition	; failure ... zero flag = clear
		beq	INTUITION_OPEN	; next subroutine level
DOS_OK1		rts		

CLOSEDOS	tst.b	error_flag	; an error?
		beq	CLOSEDOS1	; no - don't report it.
		jsr	ErrorMsg

CLOSEDOS1	move.l	_DosBase,a1
		CALLSYS	CloseLibrary,_SysBase	; kill DOS
		
EXIT		move.l	#0,d0		; no return code
		rts

* -----------------------------------------------------------------------

INTUITION_OPEN	pea	INTUITION_OPEN1		; return address
		jsr	OpenGraphics
		beq	GRAPHICS_OPEN
		rts
INTUITION_OPEN1	jsr	CloseIntuition
		rts		
		
* -----------------------------------------------------------------------				

GRAPHICS_OPEN	pea	GRAPHICS_OPEN1
		jsr	OpenPP
		beq	PP_OPEN
		rts
GRAPHICS_OPEN1	jsr	CloseGraphics
		rts		
		
* -----------------------------------------------------------------------

PP_OPEN		pea	PP_OPEN1
		jsr	OpenOM
		beq	OM_OPEN
		rts
PP_OPEN1	jsr	ClosePP
		rts
		
* -----------------------------------------------------------------------		
		
* Main code.

OM_OPEN		pea	OM_OPEN1

		lea	module1,a0	; first module (naturally).
		jsr	LoadData	; fingers crossed...

		tst.b	error_flag		; was there an error??
		bne	NOKILL_MEM		

OPEN_SCREEN	lea	screen,a0
		CALLSYS	OpenScreen,_IntuitionBase
		move.l	d0,screen_p
		beq	KILL_MUSIC_MEM

OPEN_WINDOW	lea	window,a0
		move.l	screen_p,nw_Screen(a0)
		CALLSYS	OpenWindow,_IntuitionBase
		move.l	d0,window_p
		beq	CLOSE_SCREEN

SET_COLS	move.l	screen_p,d0
		add.l	#sc_ViewPort,d0
		move.l	d0,a0
		lea	seren_col,a1		; colour map
		move.w	#seren_col_SIZEOF,d0	; size
		CALLSYS	LoadRGB4,_GfxBase

DRAW_IMAGE	move.l	window_p,a1
		move.l	wd_RPort(a1),a0
		lea	image1,a1
		move.l	#0,d0
		move.l	#0,d1
		CALLSYS	DrawImage,_IntuitionBase
	
		move.l	music_p,a2	; where module is.
		jsr	_RelocModule    ; relocate it for player.

		move.l	music_p,a0
		jsr	_PlayModule	; and start it playing....
		
		move.w	#1,playing	; number of module playing.
		move.l	#0,readme_on

		jsr	FADE_COL

SLEEP		move.l	window_p,a0
		move.l	wd_UserPort(a0),a2
		jsr	MessageHandler

CLOSE_WINDOW	move.l	window_p,a0
		CALLSYS	CloseWindow,_IntuitionBase
		
CLOSE_SCREEN	move.l	screen_p,a0
		CALLSYS	CloseScreen,_IntuitionBase

		tst.b	error_flag		; was exit caused by error?
		bne	NOKILL_MEM		; yes - no music buffer

KILL_MUSIC_MEM	move.l	music_p,a1   ; a1=Buffer
		move.l	size,d0   ; d0=Length
		CALLSYS	FreeMem,_SysBase		    ; Free buffer

NOKILL_MEM	rts						

OM_OPEN1	jsr	CloseOM
		rts
		
* -------------------------------------------------------------------------		

; If OpenIntuition() routine fails the zero flag will be CLEAR.

OpenIntuition	lea	intuition_name,a1
		moveq	#0,d0
		CALLSYS	OpenLibrary,_SysBase
		move.l	d0,_IntuitionBase
		beq	OpenIntuition1		; failure!
		
		move.l	#0,d0			; OK = set zero flag
		rts
		
OpenIntuition1	move.b	#NO_INTUITION,error_flag	; CLEAR Z flag
		rts		
		
* -------------------------------------------------------------------------

OpenGraphics	lea	graphics_name,a1
		moveq	#0,d0
		CALLSYS	OpenLibrary,_SysBase
		move.l	d0,_GfxBase
		beq	OpenGraphics1		; failure!
		
		move.l	#0,d0			; OK = set zero flag
		rts

OpenGraphics1	move.b	#NO_GRAPHICS,error_flag
		rts
		
* ------------------------------------------------------------------------		

OpenPP		lea	powerpacker_name,a1
		moveq	#0,d0
		CALLSYS	OpenLibrary,_SysBase
		move.l	d0,_PPBase
		beq	OpenPP1
		
		move.l	#0,d0
		rts
		
OpenPP1		move.b	#NO_PP,error_flag
		rts		

* ------------------------------------------------------------------------

OpenOM		jsr	_InitPlayer		; octamed call.
		bne	OpenOM1			; failure! (OM does things differently)

		move.l	#0,d0
		rts

OpenOM1		move.b	#NO_RESOURCES,error_flag
		rts
		
* ------------------------------------------------------------------------

CloseIntuition	move.l	_IntuitionBase,a1
		CALLSYS	CloseLibrary,_SysBase
		rts
		
CloseGraphics	move.l	_GfxBase,a1
		CALLSYS	CloseLibrary,_SysBase
		rts
		
ClosePP		move.l	_PPBase,a1
		CALLSYS	CloseLibrary,_SysBase
		rts				

CloseOM		jsr	_RemPlayer
		rts

* ------------------------------------------------------------------------

; Uses error_flag to get correct address of error message.
; (Same method for music filename table)

ErrorMsg	move.l	fromwb,d0
		cmpi.l	#1,d0			; workbench?
		bne	ErrorMsg2		; no....
		
		move.l	#console_name,d1
		move.l	#MODE_OLDFILE,d2
		CALLSYS	Open,_DosBase		; Open window for output
		move.l	d0,_stdout		; store handle

		jmp	ErrorMsg25		; no need to do Output.

ErrorMsg2	CALLSYS	Output,_DosBase
		move.l	d0,_stdout	; output handle
		
ErrorMsg25      move.l	#0,d0
		move.b	error_flag,d0
		lsl.l	#2,d0
		move.l	#error_table,a0
		move.l	0(a0,d0.l),d2		; filename
		move.l	#length_table,a0
		move.l	0(a0,d0.l),d3		; length
		move.l	_stdout,d1		; handle
		
		CALLSYS	Write,_DosBase		; write it.
		
		move.l	fromwb,d0
		cmpi.l	#1,d0			workbench?
		bne	ErrorMsg3

		move.l	#250,d1			; three seconds
		CALLSYS	Delay,_DosBase

		move.l	_stdout,d1
		CALLSYS	Close,_DosBase		; shut down window
		
ErrorMsg3	rts
	
* ------------------------------------------------------------------------

* Message Handler Routine

MessageHandler	movem.l	d0-d4/a0-a2,-(sp)	; preserve registers
		clr.l	d4
MessageHandler2	clr.l	gadget_p
		move.l	a2,a0
		CALLSYS	WaitPort,_SysBase
		jsr	GetMessage
		tst.l	gadget_p		; gadget hit?
		beq	MessageHandler2		; no - go round again
		jsr	GadgetHandler		; yes - do stuff
		cmpi.l	#TRUE,d4
		beq	MessageHandler3
		bra	MessageHandler2		; repeat
MessageHandler3	movem.l	(sp)+,d0-d4/a0-a2	; restore
		rts

GetMessage	move.l	a2,a0
		CALLSYS	GetMsg,_SysBase
		tst.l	d0
		beq	GetMessageExit		; exists?
		move.l	d0,a1			; pointer
		
		move.l	readme_on,d0
		cmpi.l	#1,d0			; readme screen on?
		bne	GetMessage05		; no - do not respond
		
		cmpi.l	#GADGETUP,im_Class(a1)
		beq	GetMessageRM

GetMessage01	cmpi.l	#MOUSEBUTTONS,im_Class(a1)  ; mouse clicked.
		bne	GetMessage1
		
; Check for gadgets because come higher than mouse buttons in IDCMP chain. ^

GetMessageRM	jsr	MENU_BACK

		jmp	GetMessage1

GetMessage05    cmpi.l	#GADGETUP,im_Class(a1)
		bne	GetMessage1
		move.l	im_IAddress(a1),gadget_p	; gadget address
		
GetMessage1	CALLSYS	ReplyMsg,_SysBase
		bra	GetMessage
		
GetMessageExit	rts

* Menuback routine

MENU_BACK	movem.l	a0-a2,-(sp)
		jsr	FADE_COL2	; fade to black

		move.l	window_p,a1
		move.l	wd_RPort(a1),a0
		lea	image1,a1
		move.l	#0,d0
		move.l	#0,d1
		CALLSYS	DrawImage,_IntuitionBase	; Draw the image

		jsr	FADE_COL	; fade to menu colours

		move.l	#0,readme_on	; readme screen now off.

		movem.l	(sp)+,a0-a2
		rts
		
* Gadget Handler Routine
* BUG FIXED: a2 register preserved to prevent WaitPort lock up.

GadgetHandler	movem.l	a0-a2,-(sp)		; preserve registers

		move.l	gadget_p,a0		; junk.
;		move.l	gg_GadgetID(a0),d0	; debugging
		
		cmpi.w	#7,gg_GadgetID(a0)
		beq	ReadMe

		cmpi.w	#8,gg_GadgetID(a0)
		beq	Exit

; A music icon has been selected. First, check that it isn't the same one
; that is already playing. If it is, ignore the click!

		move.w	gg_GadgetID(a0),d5	; gadget number
		move.w	playing,d0		; current module
		cmp.w	d0,d5			; compare the two
		beq	Exit_Gadget		; no deal!

		move.w	d5,playing		; new module number

; Stop music playing and deallocate its PP buffer.
		
		jsr	_StopPlayer		; stop music
		move.l	music_p,a1  
		move.l	size,d0   
		CALLSYS	FreeMem,_SysBase	; Free PP buffer

; Determine filename of new tune to load.

		lsl.w	#2,d5			; multiply by 4
		move.l	#music_table,a0		; table address
		move.l	0(a0,d5.w),a0		; music address
		
; Filename now in a0 for PP loading routine. Tell it to load....

		jsr	LoadData

		tst.b	error_flag		; was there an error??
		bne	Exit			; yes - exit
		
; Now have module uncrunched (Address pointer: music_p). Relocate it and
; play!

NoPPError	move.l	music_p,a2	; where module is.
		jsr	_RelocModule    ; relocate it for player.

		move.l	music_p,a0
		jsr	_PlayModule	; and start it playing....
		
		jmp	Exit_Gadget

ReadMe		jsr	FADE_COL2	; fade to black

		move.l	window_p,a1
		move.l	wd_RPort(a1),a0
		lea	image2,a1
		move.l	#0,d0
		move.l	#0,d1
		CALLSYS	DrawImage,_IntuitionBase	; Draw the image

		jsr	FADE_COL3	; fade to readme colours

		move.l	#1,readme_on	; readme screen now on.

		jmp	Exit_Gadget	; let's leave this nowhere city!

Exit		move.l	#TRUE,d4
		
Exit_Gadget	movem.l	(sp)+,a0-a2
		rts

* Load data (In this case, the music module)
* Now sorts out PP error codes.
	
LoadData	moveq	#DECR_NONE,d0		; Decrunch type
		moveq	#MEMF_CHIP,d1	
		lea	music_p,a1		; Where to store pointer?
		lea	size,a2			; store size here....
		move.l	#-1,a3			; No encryption handling.
		CALLSYS	ppLoadData,_PPBase	; do it......		
			
		cmpi.l	#PP_OPENERR,d0
		bne	PPError2
		move.b	#5,error_flag		; new error code.

PPError2	cmpi.l	#PP_READERR,d0
		bne	PPError3
		move.b	#6,error_flag		; new error code.	
		
PPError3	cmpi.l	#PP_NOMEMORY,d0
		bne	PPError4
		move.b	#7,error_flag
		
PPError4	cmpi.l	#PP_CRYPTED,d0
		bne	PPError5
		move.b	#8,error_flag
		
PPError5	cmpi.l	#PP_UNKNOWNPP,d0
		bne	PPError6
		move.b	#9,error_flag		; we miss out password				

PPError6	cmpi.l  #PP_EMPTYFILE,d0
		bne	PPError7
		move.b	#10,error_flag	

PPError7	rts
		
* Fade_Col
* Prepares addresses for fade routine. 

FADE_COL	move.l	#20,d7

FADE_COLS	move.l	#1,d1
		CALLSYS	Delay,_DosBase

		lea	seren_col,a0		; current colours
		lea	ac_pal,a1		; workspace
		lea	normal_colours,a2
		lea	palette,a3		; workspace/piccy colours

		jsr	DO_FADE

		dbra	d7,FADE_COLS
		
		rts

FADE_COL2	move.l	#20,d7

FADE_COLS2	move.l	#1,d1
		CALLSYS	Delay,_DosBase

		lea	seren_col,a0		; current colours
		lea	ac_pal,a1		; workspace
		lea	black_colours,a2
		lea	palette,a3		; workspace/piccy colours

		jsr	DO_FADE

		dbra	d7,FADE_COLS2
		
		rts

FADE_COL3	move.l	#20,d7

FADE_COLS3	move.l	#1,d1
		CALLSYS	Delay,_DosBase

		lea	seren_col,a0		; current colours
		lea	ac_pal,a1		; workspace
		lea	readme_colours,a2
		lea	palette,a3		; workspace/piccy colours

		jsr	DO_FADE

		dbra	d7,FADE_COLS3
		
		rts

* Do_Fade
* Copy colours around for fade and call fading routine.

DO_FADE		move.w	#31,d6
		
DO_FADE2	move.w	(a0)+,(a1)+		; colours -> workspace
		move.w	(a2)+,(a3)+		; piccy cols -> workspace		
		dbra	d6,DO_FADE2		; for all colours

		move.w	#31,d0		
		bsr.s	palchange		; fade it!
		
		lea	ac_pal,a0		; workspace
		lea	seren_col,a1		; current colours
		move.w	#31,d6

DO_FADE3	move.w	(a0)+,(a1)+		; copy colour
		dbra	d6,DO_FADE3

DO_FADE4	move.l	screen_p,d0
		add.l	#sc_ViewPort,d0
		move.l	d0,a0
		lea	seren_col,a1
		move.w	#seren_col_SIZEOF,d0
		CALLSYS	LoadRGB4,_GfxBase
		
		rts

* palchange
* Changes colour registers to achieve a smooth fade (One step is made every
* time the routine is called).
* Not coded by Mercenary/Perception - real author unknown.

palchange:
        movem.l d0-d7/a0-a6,-(SP)       ; Preserve registers
        move.w  #0,done_pal
        sub.w   #1,CurSpeed
        beq.s   PalOK

        bra.s   Pal006
PalOK:
        move.w  #1,done_pal
        move.w  PalSpeed,CurSpeed
        lea     palette(pc),a0  ; User's Palette
        lea     ac_pal(pc),a1   ; Actual (current) palette

Pal001:
* D1 holds red pigment, d2 holds green, d3 holds blue
        move.w  (a0)+,d1        ; Load user's color
        move.w  d1,d2
        move.w  d1,d3
        and.w   #$f00,d1
        and.w   #$0f0,d2
        and.w   #$00f,d3
        
* Now for the Actual Palette.
        move.w  (a1),d4 ; Don't incr., we re-write d4 later
        move.w  d4,d5
        move.w  d4,d6
        and.w   #$f00,d4
        and.w   #$0f0,d5
        and.w   #$00f,d6
        
* OK let's convert that color!
        cmp.w   d1,d4
        blt.s   .Rless  ; if D4 is less than D1
        bgt.s   .Rmore
        bra.s   .Rfin
        
.Rless:
        add.w   #$100,d4
        bra.s   .Rfin
.Rmore:
        sub.w   #$100,d4
.Rfin:
        cmp.w   d2,d5
        blt.s   .Gless  ; if D5 is less than D2
        bgt.s   .Gmore
        bra.s   .Gfin
        
.Gless:
        add.w   #$010,d5
        bra.s   .Gfin
.Gmore:
        sub.w   #$010,d5
.Gfin:
        cmp.w   d3,d6
        blt.s   .Bless  ; if D6 is less than D3
        bgt.s   .Bmore
        bra.s   .Bfin
        
.Bless:
        add.w   #$001,d6
        bra.s   .Bfin
.Bmore:
        sub.w   #$001,d6
.Bfin:  
* Now to convert Actual Palette base colors back again,
        or.w    d5,d4
        or.w    d6,d4   ; D4 holds new color
        move.w  d4,(a1)+
        
        dbf     d0,Pal001
        
* Note, ChangePal.ASM Doesn't do anything with Ac_Pal, It's
* up to you to do what you want to do with it to allow
*greater flexibility.

Pal006:
        movem.l (SP)+,d0-d7/a0-a6       ; restore registers
        RTS
        
        
palette ds.w    32
ac_pal  ds.w    32

PalSpeed:       dc.w    1       ; Default speed : every OTHER frame
CurSpeed:       dc.w    1       ; (This to be the best speed)
        
done_pal:       dc.w    0


* OctaMED player, by Teijo Kinnunen.

MIDI		EQU 0	;1 = include MIDI code
AUDDEV		EQU 1	;1 = allocate channels using audio.device
SYNTH		EQU 1	;1 = include synth-sound handler
CHECK		EQU 1	;1 = do range checkings (track, sample in mem etc.)
RELVOL		EQU 1	;1 = include relative volume handling code
IFFMOCT		EQU 1	;1 = play IFF multi-octave samples correctly
HOLD		EQU 1	;1 = handle hold/decay
PLAYMMD0	EQU 1	;1 = play old MMD0 modules
;****** Timing control ******
VBLANK	EQU	0	;1 = use VBlank interrupt (when absolutely necessary)
CIAB	EQU	1	;1 = use CIAB timers (default)
; Please use CIAB whenever possible to avoid problems with variable
; VBlank speeds and to allow the use of command F01 - FF0 (set tempo)
; If both are set to 0, the timing is left for you (never set both to 1!!),
; then you just call _IntHandler for each timing pulse.

;============================================================================

EASY	EQU	0

;the MMD0 structure offsets
mmd_id		EQU	0
mmd_modlen	EQU	4
mmd_songinfo	EQU	8
mmd_blockarr	EQU	16
mmd_smplarr	EQU	24
mmd_expdata	EQU	32
mmd_pstate	EQU	40 ; <0 = play song, 0 = don't play, >0 = play block
mmd_pblock	EQU	42
mmd_pline	EQU	44
mmd_pseqnum	EQU	46
mmd_actplayline	EQU	48
mmd_counter	EQU	50
mmd_songsleft	EQU	51

;the MMD0song structure
;Instrument data here (504 bytes = 63 * 8)
msng_numblocks	EQU	504
msng_songlen	EQU	506
msng_playseq	EQU	508
msng_deftempo	EQU	764
msng_playtransp	EQU	766
msng_flags	EQU	767
msng_flags2	EQU	768
msng_tempo2	EQU	769
msng_trkvol	EQU	770
msng_mastervol	EQU	786
msng_numsamples	EQU	787

;Instrument data
inst_repeat	EQU	0
inst_replen	EQU	2
inst_midich	EQU	4
inst_midipreset	EQU	5
inst_svol	EQU	6
inst_strans	EQU	7

;Audio hardware offsets
ac_ptr	EQU	$00
ac_len	EQU	$04
ac_per	EQU	$06
ac_vol	EQU	$08

;Trackdata sizes
T03SZ	EQU	98
T415SZ	EQU	20

		SECTION	"text",CODE

	IFNE	EASY

		XDEF	_startmusic,_endmusic

_startmusic	lea	easymod,a2
		bsr.s	_RelocModule
		bsr.w	_InitPlayer
		lea	easymod,a0
		bra.w	_PlayModule

_endmusic	bra.w	_RemPlayer

	ENDC

; ***** The relocation routine *****
reloci		move.l	24(a2),d0
		beq.s	xloci
		movea.l	d0,a0
		moveq   #0,d0
		move.b  787(a1),d0	;number of samples
		subq.b  #1,d0
relocs:		bsr.s   relocentr
		move.l	-4(a0),d3	;sample ptr
		beq.s	nosyn
		move.l	d3,a3
		tst.w	4(a3)
		bpl.s	nosyn		;type >= 0
		move.w	20(a3),d2	;number of waveforms
		lea	278(a3),a3	;ptr to wf ptrs
		subq.w	#1,d2
relsyn		add.l	d3,(a3)+
		dbf	d2,relsyn
nosyn		dbf     d0,relocs
xloci		rts
norel		addq.l	#4,a0
		rts
relocentr	tst.l   (a0)
		beq.s   norel
		add.l   d1,(a0)+
		rts
	
_RelocModule	movem.l	a2-a3/d2-d3,-(sp)
		move.l  a2,d1		;d1 = ptr to start of module
		bsr.s	relocp
		movea.l 8(a2),a1
		bsr.s	reloci
rel_lp		bsr.s	relocb
		move.l	32(a2),d0	;extension struct
		beq.s	rel_ex
		move.l	d0,a0
		bsr.s	relocentr	;ptr to next module
		bsr.s	relocentr	;InstrExt...
		addq.l	#4,a0		;skip sizes of InstrExt
		bsr.s	relocentr	;annotxt
		addq.l	#4,a0		;annolen
		bsr.s	relocentr	;InstrInfo
		addq.l	#8,a0
		bsr.s	relocentr	;rgbtable (not useful for most people)
		addq.l	#4,a0		;skip channelsplit
		bsr.s	relocentr	;NotationInfo
		bsr.s	relocentr	;songname
		addq.l	#4,a0		;skip song name length
		bsr.s	relocentr	;MIDI dumps
		bsr.s	relocmdd
		move.l	d0,a0
		move.l	(a0),d0
		beq.s	rel_ex
		move.l	d0,a2
		bsr.s	relocp
		movea.l 8(a2),a1
		bra.s	rel_lp
rel_ex		movem.l	(sp)+,d2-d3/a2-a3
		rts
relocp		lea	8(a2),a0
		bsr.s	relocentr
		addq.l	#4,a0
		bsr.s	relocentr
		addq.l	#4,a0
		bsr.s	relocentr
		addq.l	#4,a0
		bra.s	relocentr
relocb		move.l	16(a2),d0
		beq.s	xlocb
		movea.l	d0,a0
		move.w  504(a1),d0
		subq.b  #1,d0
rebl		bsr.s   relocentr
		dbf     d0,rebl
		cmp.b	#'1',3(a2)	;test MMD type
		beq.s	relocbi
xlocb		rts
relocmdd	tst.l	-(a0)
		beq.s	xlocmdd
		movea.l	(a0),a0
		move.w	(a0),d0		;# of msg dumps
		addq.l	#8,a0
mddloop		beq.s	xlocmdd
		bsr	relocentr
		bsr.s	relocdmp
		subq.w	#1,d0
		bra.s	mddloop
xlocmdd		rts
relocdmp	move.l	-4(a0),d3
		beq.s	xlocdmp
		exg.l	a0,d3		;save
		addq.l	#4,a0
		bsr	relocentr	;reloc data pointer
		move.l	d3,a0		;restore
xlocdmp		rts
relocbi		move.w	504(a1),d0
		move.l	a0,a3
biloop		subq.w	#1,d0
		bmi.s	xlocdmp
		move.l	-(a3),a0
		addq.l	#4,a0
		bsr	relocentr	;BlockInfo ptr
		tst.l	-(a0)
		beq.s	biloop
		move.l	(a0),a0
		bsr	relocentr	;hldata
		bsr	relocentr	;block name
		bra.s	biloop
	
_ChannelOff:	;d0 = channel #
		lea	DB,a0
		lea	trackdataptrs-DB(a0),a1
		lsl.b	#2,d0
		adda.w	d0,a1
		lsr.b	#2,d0
		movea.l	(a1),a1
	IFNE	MIDI
		move.b	trk_prevmidin(a1),d1	;first: is it MIDI??
		beq.s	notcomidi	;not a midi note
		lea	noteondata-DB(a0),a0
choff_midi:	clr.b	trk_prevmidin(a1)
		move.b	d1,1(a0)
		bmi.s	notamigatrk
		move.b	trk_prevmidich(a1),(a0)	;prev midi channel
		clr.b	2(a0)
		or.b	#$90,(a0)		;note off
		moveq	#3,d0
		bra.w	_AddMIDIData
	ENDC
notcomidi:	cmp.b	#4,d0
		bge.s	notamigatrk
	IFNE	SYNTH
		clr.l	trk_synthptr(a1)
		clr.b	trk_synthtype(a1)
	ENDC
		moveq	#1,d1
		lsl.w	d0,d1
		move.w	d1,$dff096
notamigatrk:	rts

SoundOff:	move.l	d2,-(sp)
		moveq	#15,d2
SO_loop0	move.l	d2,d0
		bsr.s	_ChannelOff
		dbf	d2,SO_loop0
		clr.l	_module		;play nothing
		move.l	(sp)+,d2
SO_rts		rts

_PlayNote:	;d7(w) = trk #, d1 = note #, d3(w) = instr # a3 = addr of instr
		move.l	a3,d4
		beq.s	SO_rts
		moveq	#0,d4
		bset	d7,d4	;d4 is mask for this channel
		movea.l	mmd_smplarr(a2),a0
		add.w	d3,d3			;d3 = instr.num << 2
		add.w	d3,d3
		move.l	0(a0,d3.w),d5		;get address of instrument
	IFNE	MIDI
		bne.s	inmem
		tst.b	inst_midich(a3)		;is MIDI channel set
	ENDC
	IFNE	CHECK
		beq.w	pnote_rts		; NO!!!
	ENDC
inmem:		add.b	msng_playtransp(a4),d1	;add play transpose
		add.b	inst_strans(a3),d1	;and instr. transpose
		cmp.b	#4,d7
		bge.s	nodmaoff	;track # >= 4: not an Amiga channel
		move.l	d5,a1
	IFNE	SYNTH
		tst.l	d5
		beq.s	stpdma
		tst.b	trk_synthtype(a5)
		ble.s	stpdma		;prev. type = sample/hybrid
		cmp.w	#-1,4(a1)	;type == SYNTHETIC??
		beq.s	nostpdma
	ENDC
stpdma:		move.w	d4,$dff096		;stop this channel (dmacon)
nostpdma:
	IFNE	SYNTH
		clr.l	trk_synthptr(a5)
	ENDC
nodmaoff:	subq.b	#1,d1
	IFNE	MIDI
		move.b	trk_prevmidin(a5),d3	;get prev. midi note
		beq.s	noprevmidi
		clr.b	trk_prevmidin(a5)
		lea	noteondata+2-DB(a6),a0
		clr.b	(a0)
		move.b	d3,-(a0)
		bmi.s	noprevmidi
		move.b	trk_prevmidich(a5),-(a0) ;prev midi channel
		or.b	#$90,(a0)		 ;note off
		move.w	d1,-(sp)
		moveq	#3,d0
		bsr.w	_AddMIDId
		move.w	(sp)+,d1
noprevmidi:
		tst.b	inst_midich(a3)
		bne.w	handleMIDInote
	ENDC
	IFNE	CHECK
		cmp.w	#4,d7		;track > 3???
		bge.w	pnote_rts	;no Amiga instruments here!!!
	ENDC
; handle decay (for tracks 0 - 3 only!!)
	IFNE	HOLD
		clr.b	trk_fadespd(a5)		;no fade yet..
		move.b	trk_initdecay(a5),trk_decay(a5)	;set decay
	ENDC
		clr.w	trk_vibroffs(a5)	;clr vibrato/tremolo offset
		or.w	d4,dmaonmsk-DB(a6)
		move.l	d5,a0
	IFNE	SYNTH
		tst.w	4(a0)
		bmi.w	handleSynthnote
		clr.b	trk_synthtype(a5)
	ENDC
tlwtst0:	tst.b	d1
		bpl.s	notenot2low
		add.b	#12,d1	;note was too low, octave up
		bra.s	tlwtst0
notenot2low:	cmp.b	#62,d1
		ble.s	endpttest
		sub.b	#12,d1	;note was too high, octave down
endpttest
		moveq	#0,d2
		moveq	#0,d3
	IFNE	IFFMOCT
		move.w	4(a0),d0	;Soitin-struct in a0
		bne.s	iff5or3oct	;note # in d1 (0 - ...)
	ENDC
		lea	_periodtable+32-DB(a6),a1
		move.b	trk_finetune(a5),d2	;finetune value
		add.b	d2,d2
		add.b	d2,d2		;multiply by 4...
		ext.w	d2		;extend
		movea.l	0(a1,d2.w),a1	;period table address
		move.l	a1,trk_periodtbl(a5)
		add.b	d1,d1
		move.w	0(a1,d1.w),d5 ;put period to d5
		move.l	a0,d0
		addq.l	#6,d0		;Skip structure
		move.l	(a0),d1		;length
		add.l	d0,d1		;sample end pointer
		move.w	inst_repeat(a3),d2
		move.w	inst_replen(a3),d3
	IFNE	IFFMOCT
		bra	gid_setrept
gid_addtable	dc.b	0,6,12,18,24,30
gid_divtable	dc.b	31,7,3,15,63,127
iff5or3oct:	move.l	d7,-(sp)
		moveq	#0,d7
		move.w	d1,d7
		divu	#12,d7	;octave #
		move.l	d7,d5
		cmp.w	#6,d7	;if oct > 5, oct = 5
		blt.s	nohioct
		moveq	#5,d7
nohioct		swap	d5	;note number in this oct (0-11) is in d5
		move.l	(a0),d1
		cmp.w	#6,d0
		ble.s	nounrecit
		moveq	#6,d0
nounrecit	add.b	gid_addtable-1(pc,d0.w),d7
		move.b	gid_divtable-1(pc,d0.w),d0
		divu	d0,d1	;get length of the highest octave
		swap	d1
		clr.w	d1
		swap	d1
		move.l	d1,d0		;d0 and d1 = length of the 1st oct
		move.w	inst_repeat(a3),d2
		move.w	inst_replen(a3),d3
		moveq	#0,d6
		move.b	shiftcnt(pc,d7.w),d6
		lsl.w	d6,d2
		lsl.w	d6,d3
		lsl.w	d6,d1
		move.b	mullencnt(pc,d7.w),d6
		mulu	d6,d0		;offset of this oct from 1st oct
		add.l	a0,d0		;add base address to offset
		addq.l	#6,d0		;skip structure
		add.l	d0,d1
		lea	_periodtable+32-DB(a6),a1
		move.b	trk_finetune(a5),d6
		add.b	d6,d6
		add.b	d6,d6
		ext.w	d6
		movea.l	0(a1,d6.w),a1
		move.l	a1,trk_periodtbl(a5)
		add.b	octstart(pc,d7.w),d5
		add.b	d5,d5
		move.w	0(a1,d5.w),d5
		move.l	(sp)+,d7
		bra.s	gid_setrept
shiftcnt:	dc.b	4,3,2,1,1,0,2,2,1,1,0,0,1,1,0,0,0,0
		dc.b	3,3,2,2,1,0,5,4,3,2,1,0,6,5,4,3,2,1
mullencnt:	dc.b	15,7,3,1,1,0,3,3,1,1,0,0,1,1,0,0,0,0
		dc.b	7,7,3,3,1,0,31,15,7,3,1,0,63,31,15,7,3,1
octstart:	dc.b	12,12,12,12,24,24,0,12,12,24,24,36,0,12,12,24,36,36
		dc.b	0,12,12,24,24,24,12,12,12,12,12,12,12,12,12,12,12,12
	ENDC
gid_setrept	add.l	d2,d2
		add.l	d0,d2		;rep. start pointer
		cmp.w	#1,d3
		bhi.s	gid_noreplen2
		moveq	#0,d3		;no repeat
		bra.s	gid_cont
gid_noreplen2	add.l	d3,d3
		add.l	d2,d3		;rep. end pointer

gid_cont	moveq	#0,d4
		move.w	trk_soffset(a5),d4
		add.l	d4,d0
		cmp.l	d0,d1
		bhi.s	pn_nooffsovf
		sub.l	d4,d0
pn_nooffsovf	movea.l	trk_audioaddr(a5),a1 ;base of this channel's regs
		move.l	d0,(a1)+		;put it in ac_ptr
		cmp.l	d0,d3
		bhi.s	repeat
		
		move.l	#_chipzero,trk_sampleptr(a5) ;pointer of zero word
		move.w	#1,trk_samplelen(a5)	;length: 1 word
		sub.l	d0,d1
		lsr.l	#1,d1			;shift length right
		move.w	d1,(a1)+			;and put to ac_len
		bra.s	retsn1

repeat:		move.l	d2,trk_sampleptr(a5)
		move.l	d3,d1
		sub.l	d0,d1
		lsr.l	#1,d1
		move.w	d1,(a1)+	;ac_len
		sub.l	d2,d3
		lsr.l	#1,d3
		move.w	d3,trk_samplelen(a5)
				
retsn1		move.w	d5,trk_prevper(a5)
	IFNE	SYNTH
		tst.b	trk_synthtype(a5)
		bne.w	hSn2
	ENDC
pnote_rts	rts

	IFNE	MIDI
handleMIDInote:
	IFNE	PLAYMMD0
		cmp.b	#'1',3(a2)
		beq.s	plr_mmd1_3
		add.b	#24,d1
plr_mmd1_3
	ENDC
		move.b	trk_prevvol(a5),d2 ;temporarily save the volume
		add.b	d2,d2		;volume 0 - 63 => 0 - 127
		subq.b	#1,d2		;if 128 => 127
		bpl.s	hmn_notvolu0
		moveq	#0,d2
hmn_notvolu0
		moveq	#0,d5
		move.b	inst_midich(a3),d5 ;get midi chan of this instrument
		bpl.s	hmn_nosmof	;bit 7 clear
		clr.b	trk_prevmidin(a5)	;suppress note off!
		and.b	#$1F,d5		;clear all flag bits etc...
		bra.s	hmn_smof
hmn_nosmof	move.b	d1,trk_prevmidin(a5)
hmn_smof	subq.b	#1,d5		;from 1-16 to 0-15
		move.b	d5,trk_prevmidich(a5)	;save to prev midi channel

		move.b	inst_midipreset(a3),d0	;get preset #
		beq.s	nochgpres	;zero = no preset
		lea	prevmidicpres-DB(a6),a1
		adda.w	d5,a1
		cmp.b	(a1),d0		;is this previous preset ??
		beq.s	nochgpres	;yes...no need to change
		move.b	d0,(a1)		;save preset to prevmidicpres
		subq.b	#1,d0		;sub 1 to get 0 - 127
		lea	preschgdata+1-DB(a6),a0
		move.b	d0,(a0)		;push the number to second byte
		move.b	#$c0,-(a0)	;command: $C
		or.b	d5,(a0)		;"or" midi channel
		moveq	#2,d0
		move.w	d1,-(sp)
		bsr.w	_AddMIDId
		move.w	(sp)+,d1
		tst.b	d2
		beq.s	hmn_suppress	;vol = 0, don't send NOTE ON

nochgpres	lea	bytesinnotebuff-DB(a6),a0
		movea.l	a0,a1
		adda.w	(a0)+,a0
		or.b	#$90,d5		;MIDI: Note on
		move.b	d5,(a0)+	;MIDI msg Note on & channel
		move.b	d1,(a0)+	;MIDI msg note #
		move.b	d2,(a0)		;MIDI msg volume
		beq.s	hmn_suppress	;vol = 0 -> no note
		addq.w	#3,(a1)
		rts
hmn_suppress	st	trk_prevmidin(a5)
		rts
	ENDC

	IFNE	SYNTH
handleSynthnote:
		move.b	d1,trk_prevnote2(a5)
		move.l	a0,trk_synthptr(a5)
		cmp.w	#-2,4(a0)	;HYBRID??
		bne.s	hSn_nossn
		st	trk_synthtype(a5)
		movea.l	278(a0),a0	;yep, get the waveform pointer
		bra.w	tlwtst0		;go and play it
hSn_nossn:	move.b	#1,trk_synthtype(a5)
		lea	_periodtable+32-DB(a6),a1
		move.b	trk_finetune(a5),d0	;finetune value
		add.b	d0,d0
		add.b	d0,d0		;multiple by 4...
		ext.w	d0		;extend
		movea.l	0(a1,d0.w),a1	;period table address
		suba.w	#48,a1
		move.l	a1,trk_periodtbl(a5) ;save table ptr for synth periods
		add.w	d1,d1
		move.w	0(a1,d1.w),d1
		move.w	d1,trk_prevper(a5)
		clr.l	trk_sampleptr(a5)
hSn2:		lea	trk_arpgoffs(a5),a1
		clr.l	(a1)+
		clr.l	(a1)+
		clr.l	(a1)+
		clr.l	(a1)+
		clr.l	(a1)+
		clr.l	(a1)+
		move.l	#sinetable,(a1)+
		clr.w	(a1)+
		movea.l	trk_synthptr(a5),a0
                move.w	18(a0),(a1)+
                clr.b	(a1)
                cmp.b	#$E,trk_cmd(a5)
                bne.s	hSn_nocmdE
                move.b	trk_cmdqual(a5),trk_wfcmd+1(a5)
hSn_nocmdE	moveq	#64,d4
		rts

synth_start	move.w	trk_prevper(a5),d5
synth_start2	move.l	a3,-(sp)	;d0 = SynthPtr
		move.l	d0,a0
		movea.l	trk_audioaddr(a5),a3	;audio channel base address
		subq.b	#1,trk_volxcnt(a5)	;decrease execute counter..
		bgt.w	synth_wftbl		;not 0...go to waveform
		move.b	trk_initvolxspd(a5),trk_volxcnt(a5) ;reset counter
		move.b	trk_volchgspd(a5),d0	;volume change??
		beq.s	synth_nochgvol		;no.
		add.b	trk_synvol(a5),d0	;add previous volume
		bpl.s	synth_voln2l		;not negative
		moveq	#0,d0			;was negative => 0
synth_voln2l	cmp.b	#$40,d0			;too high??
		ble.s	synth_voln2h		;not 2 high.
		moveq	#$40,d0			;was 2 high => 64
synth_voln2h	move.b	d0,trk_synvol(a5)	;remember new...
synth_nochgvol	move.l	trk_envptr(a5),d1	;envelope pointer
		beq.s	synth_novolenv
		movea.l	d1,a1
		move.b	(a1)+,d0
		add.b	#128,d0
		lsr.b	#2,d0
		move.b	d0,trk_synvol(a5)
		addq.b	#1,trk_envcount(a5)
		bpl.s	synth_endenv
		clr.b	trk_envcount(a5)
		move.l	trk_envrestart(a5),a1
synth_endenv	move.l	a1,trk_envptr(a5)
synth_novolenv	move.w	trk_volcmd(a5),d0	;get table position ptr
		tst.b	trk_volwait(a5)		;WAI(t) active
		beq.s	synth_getvolcmd		;no
		subq.b	#1,trk_volwait(a5)	;yep, decr wait ctr
		ble.s	synth_getvolcmd		;0 => continue
		bra.w	synth_wftbl		;> 0 => still wait
synth_inccnt	addq.b	#1,d0
synth_getvolcmd	addq.b	#1,d0			;advance pointer
		move.b	21(a0,d0.w),d1		;get command
		bmi.s	synth_cmd		;negative = command
		move.b	d1,trk_synvol(a5)	;set synthvol
		bra.w	synth_endvol		;end of volume executing
synth_cmd	and.w	#$000f,d1
		add.b	d1,d1
		move.w	synth_vtbl(pc,d1.w),d1
		jmp	syv(pc,d1.w)
synth_vtbl	dc.w	syv_f0-syv,syv_f1-syv,syv_f2-syv,syv_f3-syv
		dc.w	syv_f4-syv,syv_f5-syv,syv_f6-syv
		dc.w	synth_endvol-syv,synth_endvol-syv,synth_endvol-syv
		dc.w	syv_fa-syv,syv_ff-syv,synth_endvol-syv
		dc.w	synth_endvol-syv,syv_fe-syv,syv_ff-syv
syv
syv_fe		move.b	22(a0,d0.w),d0		;JMP
		bra.s	synth_getvolcmd
syv_f0		move.b	22(a0,d0.w),trk_initvolxspd(a5) ;change volume ex. speed
		bra.s	synth_inccnt
syv_f1		move.b	22(a0,d0.w),trk_volwait(a5)	;WAI(t)
		addq.b	#1,d0
		bra.s	synth_endvol
syv_f3		move.b	22(a0,d0.w),trk_volchgspd(a5) ;set volume slide up
		bra.s	synth_inccnt
syv_f2		move.b	22(a0,d0.w),d1
		neg.b	d1
		move.b	d1,trk_volchgspd(a5) ;set volume slide down
		bra.s	synth_inccnt
syv_fa		move.b	22(a0,d0.w),trk_wfcmd+1(a5) ;JWS (jump wform sequence)
		clr.b	trk_wfwait(a5)
		bra.s	synth_inccnt
syv_f4		move.b	22(a0,d0.w),d1
		bsr.s	synth_getwf
		clr.l	trk_envrestart(a5)
syv_f4end	move.l	a1,trk_envptr(a5)
		clr.b	trk_envcount(a5)
		bra.w	synth_inccnt
syv_f5		move.b	22(a0,d0.w),d1
		bsr.s	synth_getwf
		move.l	a1,trk_envrestart(a5)
		bra.s	syv_f4end
syv_f6		clr.l	trk_envptr(a5)
		bra.w	synth_getvolcmd
synth_getwf	ext.w	d1	;d1 = wform number, returns ptr in a1
		add.w	d1,d1	;create index
		add.w	d1,d1
		lea	278(a0),a1
		adda.w	d1,a1
		movea.l	(a1),a1		;get wform address
		addq.l	#2,a1		;skip length
		rts
syv_ff		subq.b	#1,d0
synth_endvol	move.w	d0,trk_volcmd(a5)
synth_wftbl	move.b	trk_synvol(a5),trk_prevvol(a5)
		adda.w	#158,a0
		subq.b	#1,trk_wfxcnt(a5)	;decr. wf speed counter
		bgt.w	synth_arpeggio		;not yet...
		move.b	trk_initwfxspd(a5),trk_wfxcnt(a5) ;restore speed counter
		move.w	trk_wfcmd(a5),d0	;get table pos offset
		move.w	trk_wfchgspd(a5),d1	;CHU/CHD ??
		beq.s	synth_tstwfwai		;0 = no change
wytanwet	add.w	trk_perchg(a5),d1	;add value to current change
		move.w	d1,trk_perchg(a5)	;remember amount of change
synth_tstwfwai	tst.b	trk_wfwait(a5)		;WAI ??
		beq.s	synth_getwfcmd		;not waiting...
		subq.b	#1,trk_wfwait(a5)	;decr wait counter
		beq.s	synth_getwfcmd		;waiting finished
		bra.w	synth_arpeggio		;still sleep...
synth_incwfc	addq.b	#1,d0
synth_getwfcmd	addq.b	#1,d0			;advance position counter
		move.b	-9(a0,d0.w),d1		;get command
		bmi.s	synth_wfcmd		;negative = command
		ext.w	d1
		add.w	d1,d1
		add.w	d1,d1
		movea.l	120(a0,d1.w),a1
		move.w	(a1)+,ac_len(a3)	;push waveform length
		move.l	a1,ac_ptr(a3)		;and the new pointer
		bra.w	synth_wfend		;no new commands now...
synth_wfcmd	and.w	#$000f,d1		;get the right nibble
		add.b	d1,d1			;* 2
		move.w	synth_wfctbl(pc,d1.w),d1
		jmp	syw(pc,d1.w)		;jump to command
synth_wfctbl	dc.w	syw_f0-syw,syw_f1-syw,syw_f2-syw,syw_f3-syw,syw_f4-syw
		dc.w	syw_f5-syw,syw_f6-syw,syw_f7-syw,synth_wfend-syw
		dc.w	synth_wfend-syw,syw_fa-syw,syw_ff-syw
		dc.w	syw_fc-syw,synth_getwfcmd-syw,syw_fe-syw,syw_ff-syw
syw
syw_f7		move.b	-8(a0,d0.w),d1
		ext.w	d1
		add.w	d1,d1
		add.w	d1,d1
		movea.l	120(a0,d1.w),a1
		addq.l	#2,a1
		move.l	a1,trk_synvibwf(a5)
		bra.s	synth_incwfc
syw_fe		move.b	-8(a0,d0.w),d0		;jump (JMP)
		bra.s	synth_getwfcmd
syw_fc		move.w	d0,trk_arpsoffs(a5)	;new arpeggio begin
		move.w	d0,trk_arpgoffs(a5)
synth_findare	addq.b	#1,d0
		tst.b	-9(a0,d0.w)
		bpl.s	synth_findare
		bra.s	synth_getwfcmd
syw_f0		move.b	-8(a0,d0.w),trk_initwfxspd(a5)	;new waveform speed
		bra	synth_incwfc
syw_f1		move.b	-8(a0,d0.w),trk_wfwait(a5)	;wait waveform
		addq.b	#1,d0
		bra.s	synth_wfend
syw_f4		move.b	-8(a0,d0.w),trk_synvibdep+1(a5)	;set vibrato depth
		bra.w	synth_incwfc
syw_f5		move.b	-8(a0,d0.w),trk_synthvibspd+1(a5) ;set vibrato speed
		addq.b	#1,trk_synthvibspd+1(a5)
		bra.w	synth_incwfc
syw_f2		moveq	#0,d1			;set slide down
		move.b	-8(a0,d0.w),d1
synth_setsld	move.w	d1,trk_wfchgspd(a5)
		bra.w	synth_incwfc
syw_f3		move.b	-8(a0,d0.w),d1		;set slide up
		neg.b	d1
		ext.w	d1
		bra.s	synth_setsld
syw_f6		clr.w	trk_perchg(a5)		;reset period
		move.w	trk_prevper(a5),d5
		bra.w	synth_getwfcmd
syw_fa		move.b	-8(a0,d0.w),trk_volcmd+1(a5) ;JVS (jump volume sequence)
		clr.b	trk_volwait(a5)
		bra.w	synth_incwfc
syw_ff		subq.b	#1,d0		;pointer = END - 1
synth_wfend	move.w	d0,trk_wfcmd(a5)
synth_arpeggio	move.w	trk_arpgoffs(a5),d0
		beq.s	synth_vibrato
		moveq	#0,d1
		move.b	-8(a0,d0.w),d1
		add.b	trk_prevnote2(a5),d1
		movea.l	trk_periodtbl(a5),a1	;get period table
		add.w	d1,d1
		move.w	0(a1,d1.w),d5
		addq.b	#1,d0
		tst.b	-8(a0,d0.w)
		bpl.s	synth_noarpres
		move.w	trk_arpsoffs(a5),d0
synth_noarpres	move.w	d0,trk_arpgoffs(a5)
synth_vibrato	move.w	trk_synvibdep(a5),d1	;get vibrato depth
		beq.s	synth_rts		;0 => no vibrato
		move.w	trk_synviboffs(a5),d0	;get offset
		lsr.w	#4,d0			;/ 16
		and.w	#$1f,d0			;sinetable offset (0-31)
		movea.l trk_synvibwf(a5),a0
		move.b	0(a0,d0.w),d0   	;get a byte
		ext.w	d0			;to word
		muls	d1,d0			;amplify (* depth)
		asr.w	#8,d0			;and divide by 64
		add.w	d0,d5			;add vibrato...
		move.w	trk_synthvibspd(a5),d0	;vibrato speed
		add.w	d0,trk_synviboffs(a5)	;add to offset
synth_rts	add.w	trk_perchg(a5),d5
		cmp.w	#113,d5			;overflow??
		bge.s	synth_pern2h
		moveq	#113,d1
synth_pern2h	move.l	(sp)+,a3
		rts
	ENDC
sinetable	dc.b	0,25,49,71,90,106,117,125,127,125,117,106,90,71,49
		dc.b	25,0,-25,-49,-71,-90,-106,-117,-125,-127,-125,-117
		dc.b	-106,-90,-71,-49,-25,0

_IntHandler:	movem.l	d2-d7/a2-a6,-(sp)
		movea.l	a1,a6		;get data base address
		tst.b	bpmcounter-DB(a6)
		bmi.s	plr_nobpm
		subq.b	#1,bpmcounter-DB(a6)
		ble.s	plr_bpmcnt0
		bra.w	plr_exit
plr_bpmcnt0	move.b	#4,bpmcounter-DB(a6)
plr_nobpm	movea.l	_module-DB(a6),a2
		move.l	a2,d0
		beq.w	plr_exit
	IFNE	MIDI
		clr.b	lastcmdbyte-DB(a6)	;no MIDI optimization
	ENDC
		tst.w	mmd_pstate(a2)
		beq.w	plr_exit
	IFNE	MIDI
		clr.l	dmaonmsk-DB(a6)
	ENDC
	IFEQ	MIDI
		clr.w	dmaonmsk-DB(a6)
	ENDC
		movea.l	mmd_songinfo(a2),a4
		moveq	#0,d3
		move.b	mmd_counter(a2),d3
		addq.b	#1,d3
		cmp.b	msng_tempo2(a4),d3
		bge.s	plr_pnewnote	;play new note
		move.b	d3,mmd_counter(a2)
		bne.w	plr_fxtime	;do just fx
; --- new note!!
plr_pnewnote:	clr.b	mmd_counter(a2)
		tst.w	blkdelay-DB(a6)
		beq.s	plr_noblkdelay
		subq.w	#1,blkdelay-DB(a6)
		bne.w	nonewnote
; --- now start to play it
plr_noblkdelay	move.w	mmd_pblock(a2),d0
		movea.l	mmd_blockarr(a2),a0
		add.w	d0,d0
		add.w	d0,d0
		movea.l	0(a0,d0.w),a1	;block...
		move.w	mmd_pline(a2),d0
	IFNE	PLAYMMD0
		cmp.b	#'1',3(a2)	;check ID type
		beq.s	plr_mmd1_0
		move.w	d0,d1
		add.w	d0,d0
		add.w	d1,d0		;d0 = d0 * 3
		clr.l	numtracks-DB(a6)
		move.b	(a1)+,numtracks+1-DB(a6)
		move.b	(a1),numlines+1-DB(a6)
		mulu	numtracks-DB(a6),d0
		pea	1(a1,d0.w)
		bra.s	plr_begloop
plr_mmd1_0
	ENDC
		add.w	d0,d0
		add.w	d0,d0		;d0 = d0 * 4
		mulu	(a1),d0		;numtracks * d0
		pea	8(a1,d0.l)	;address of the current note
		move.w	(a1)+,numtracks-DB(a6)
		move.w	(a1),numlines-DB(a6)
plr_begloop	moveq	#0,d7		;number of track
		moveq	#0,d4
		pea	trackdataptrs-DB(a6)
plr_loop0:	moveq	#0,d5
		move.l	(sp),a1
		movea.l	(a1)+,a5	;get address of this track's struct
		move.l	a1,(sp)
; ---------------- get the note numbers
		moveq	#0,d3
		move.l	4(sp),a1
	IFNE	PLAYMMD0
		cmp.b	#'1',3(a2)
		beq.s	plr_mmd1_1
		move.b	(a1)+,d5
		move.b	(a1)+,d6
		move.b	(a1)+,trk_cmdqual(a5)
		move.b	d6,d3
		and.w	#$0F,d6
		lsr.b	#4,d3
		bclr	#7,d5
		beq.s	plr_bseti4
		bset	#4,d3
plr_bseti4	bclr	#6,d5
		beq.s	plr_bseti5
		bset	#5,d3
plr_bseti5	bra.s	plr_nngok
plr_mmd1_1
	ENDC
		move.b	(a1)+,d5	;get the number of this note
		bpl.s	plr_nothinote
		moveq	#0,d5
plr_nothinote	move.b	(a1)+,d3	;instrument number
		move.b	(a1)+,d6	;cmd number
		and.w	#$1F,d6		;recognize only cmds 00 - 1F
		move.b	(a1)+,trk_cmdqual(a5)	;databyte (qualifier)
plr_nngok	move.l	a1,4(sp)
; ---------------- check if there's an instrument number
		and.w	#$3F,d3
		beq.s	noinstnum
; ---------------- finally, save the number
		subq.b	#1,d3
		move.b	d3,trk_previnstr(a5) ;remember instr. number!
	IFNE	HOLD
		lea	holdvals-DB(a6),a0
		adda.w	d3,a0
		move.b	(a0),trk_inithold(a5)
		move.b	63(a0),trk_initdecay(a5)
		move.b	126(a0),trk_finetune(a5)
	ENDC
		asl.w	#3,d3
		lea	0(a4,d3.w),a3	;a3 contains now address of it
		move.l	a3,trk_previnstra(a5)
		moveq	#0,d0
; ---------------- get volume and make it relative (1 - 100 %)
	IFNE	RELVOL
		move.b	inst_svol(a3),d0
		mulu	trk_trackvol(a5),d0
		lsr.w	#8,d0
		move.b	d0,trk_prevvol(a5) ;vol of this instr
	ENDC
	IFEQ	RELVOL
		move.b	inst_svol(a3),trk_prevvol(a5)
	ENDC
; ---------------- remember transpose
		move.b	inst_strans(a3),trk_stransp(a5)
		clr.w	trk_soffset(a5)		;sample offset
; ---------------- check the commands
noinstnum	move.b	d6,trk_cmd(a5)	;save the effect number
		beq.w	fx	;no effect
		move.b	trk_cmdqual(a5),d4	;get qualifier...
		add.b	d6,d6	;* 2
		move.w	f_table(pc,d6.w),d0
		jmp	fst(pc,d0.w)
f_table		dc.w	fx-fst,fx-fst,fx-fst,f_03-fst,fx-fst,fx-fst,fx-fst,fx-fst
		dc.w	f_08-fst,f_09-fst,fx-fst,f_0b-fst,f_0c-fst,fx-fst,f_0e-fst,f_0f-fst
		dc.w	fx-fst,fx-fst,fx-fst,fx-fst,fx-fst,f_15-fst,f_16-fst,fx-fst
		dc.w	fx-fst,f_19-fst,fx-fst,fx-fst,f_1c-fst,f_1d-fst,fx-fst,f_1f-fst
fst
; ---------------- tempo (F)
f_0f		tst.b	d4		;test effect qual..
		beq	fx0fchgblck	;if effect qualifier (last 2 #'s)..
		cmp.b	#$f0,d4		;..is zero, go to next block
		bhi.s	fx0fspecial	;if it's F1-FF something special
; ---------------- just an ordinary "change tempo"-request
	IFNE	CIAB
		moveq	#0,d0		;will happen!!!
		move.b	d4,d0
		move.w	d0,msng_deftempo(a4)
		bsr	_SetTempo	;change The Tempo
	ENDC
		bra.w	fx
; ---------------- no, it was FFx, something special will happen!!
fx0fspecial:	cmp.b	#$f2,d4
		bne.s	isfxfe
; ---------------- FF2 (or 1Fxx)
f_1f		move.b	d5,(a5)	; save the note number
		moveq	#0,d5	; clear the number for awhile
	IFNE	HOLD
		move.b	trk_inithold(a5),trk_noteoffcnt(a5) ;initialize hold
		bne.w	plr_endloop0		;not 0 -> OK
		st	trk_noteoffcnt(a5)	;0 -> hold = 0xff (-1)
	ENDC
		bra.w	plr_endloop0
isfxfe:		cmp.b	#$fe,d4
		bne.s	notcmdfe
; ---------------- it was FFE, stop playing
		clr.w	mmd_pstate(a2)
	IFNE	CIAB
		movea.l	craddr-DB(a6),a0
		bclr	#0,(a0)
	ENDC
		bsr.w	SoundOff
		addq.l	#8,sp
		bra.w	plr_exit
notcmdfe:	cmp.b	#$fd,d4 ;change period
		bne.s	isfxff
; ---------------- FFD, change the period, don't replay the note
	IFNE	CHECK
		cmp.w	#4,d7
		bge.w	fx
	ENDC
		movea.l	trk_periodtbl(a5),a0
		subq.b	#1,d5
		bmi.w	plr_endloop0
		add.b	d5,d5
		move.w	0(a0,d5.w),trk_prevper(a5)
		moveq	#0,d5
		bra.w	fx
isfxff:		cmp.b	#$ff,d4
		bne.w	fx
		move.w	d7,d0
		bsr.w	_ChannelOff
		bra.w	fx
; ---------------- F00, called Pattern Break in ST
fx0fchgblck:	move.b	#1,nextblock-DB(a6)
		bra.w	fx
; ---------------- was not Fxx
f_0e		cmp.b	#3,d7
		bgt.w	fx
		move.b	d4,trk_wfcmd+1(a5) ;set waveform command position ptr
		bra.w	fx
; ---------------- change volume
f_0c		move.b	d4,d0
		bpl.s	plr_nosetdefvol
		and.b	#$7F,d0
	IFNE	CHECK
		cmp.b	#64,d0
		bgt.s	go_nocmd
	ENDC
		moveq	#0,d1
		move.b	trk_previnstr(a5),d1
		asl.w	#3,d1
		move.b	d0,inst_svol(a4,d1.w)
		bra.s	plr_setvol
plr_nosetdefvol	btst	#4,msng_flags(a4)	;look at flags
		bne.s	volhex
		lsr.b	#4,d0		;get number from left
		mulu	#10,d0		;number of tens
		move.b	d4,d1		;get again
		and.b	#$0f,d1		;this time don't get tens
		add.b	d1,d0		;add them
volhex:
	IFNE	CHECK
		cmp.b	#64,d0
		bhi.s	go_nocmd
	ENDC
plr_setvol
	IFNE	RELVOL
		mulu	trk_trackvol(a5),d0
		lsr.w	#8,d0
	ENDC
		move.b	d0,trk_prevvol(a5)
go_nocmd	bra.w	fx
; ---------------- tempo2 change??
f_09
	IFNE	CHECK
		and.b	#$1F,d4
		bne.s	fx9chk
		moveq	#$20,d4
	ENDC
fx9chk:		move.b	d4,msng_tempo2(a4)
		bra	fx
; ---------------- finetune
f_15
	IFNE	CHECK
		cmp.b	#7,d4
		bgt	fx
		cmp.b	#-8,d4
		blt	fx
	ENDC
		move.b	d4,trk_finetune(a5)
		bra	fx
; ---------------- repeat loop
f_16		tst.b	d4
		bne.s	plr_dorpt
		move.w	mmd_pline(a2),rptline-DB(a6)
		bra	fx
plr_dorpt	tst.w	rptcounter-DB(a6)
		beq.s	plr_newrpt
		subq.w	#1,rptcounter-DB(a6)
		beq	fx
		bra.s	plr_setrptline
plr_newrpt	move.b	d4,rptcounter+1-DB(a6)
plr_setrptline	move.w	rptline-DB(a6),d0
		addq.w	#1,d0
		move.w	d0,nextblockline-DB(a6)
		bra	fx
; ---------------- preset change
f_1c
	IFNE	CHECK
		cmp.b	#$80,d4
		bhi	fx
	ENDC
		moveq	#0,d1
		move.b	trk_previnstr(a5),d1
		asl.w	#3,d1
		move.b	d4,inst_midipreset(a4,d1.w)	;set MIDI preset
		bra.s	fx
; ---------------- note off time set??
f_08
	IFNE	HOLD
		move.b	d4,d0
		lsr.b	#4,d4		;extract left  nibble
		and.b	#$0f,d0		; "   "  right  "  "
		move.b	d4,trk_initdecay(a5)	;left = decay
		move.b	d0,trk_inithold(a5)	;right = hold
	ENDC
		bra.s	fx
; ---------------- sample begin offset
f_19		lsl.w	#8,d4
		move.w	d4,trk_soffset(a5)
		bra.s	fx
; ---------------- cmd Bxx, "position jump"
f_0b
	IFNE	CHECK
		cmp.w	msng_songlen(a4),d4
		bhi.s	fx
	ENDC
		move.w	d4,mmd_pseqnum(a2)
		st	nextblock-DB(a6)	; = 1
		bra.s	fx
; ---------------- cmd 1Dxx, jump to next seq, line # specified
f_1d		move.w	#$1ff,nextblock-DB(a6)
		addq.w	#1,d4
		move.w	d4,nextblockline-DB(a6)
		bra.s	fx
; ---------------- try portamento (3)
f_03
	IFNE	CHECK
		cmp.w	#4,d7
		bge.s	plr_endloop0
	ENDC
		subq.b	#1,d5		;subtract note number
		bmi.s	plr_setfx3spd	;0 -> set new speed
plr_fx3note:	movea.l	trk_periodtbl(a5),a0
		add.b	msng_playtransp(a4),d5	;play transpose
		add.b	trk_stransp(a5),d5	;and instrument transpose
		bmi.s	plr_endloop0
		add.w	d5,d5
		move.w	0(a0,d5.w),trk_porttrgper(a5) ;period of this note is the target
plr_setfx3spd:	tst.b	d4		;qual??
		beq.s	plr_endloop0	;0 -> do nothing
		move.b	d4,trk_prevportspd(a5)	;store speed
		bra.s	plr_endloop0		;don't play this one
; ---------------- play or not to play??
fx		tst.b	d5			;play a note?
		beq.s	plr_endloop0		;no.
; ---------------- play
		move.b	d5,(a5)
		move.w	d5,d1
		moveq	#0,d3
		move.b	trk_previnstr(a5),d3	;instr #
		movea.l	trk_previnstra(a5),a3	;instr data address
	IFNE	HOLD
		move.b	trk_inithold(a5),trk_noteoffcnt(a5) ;initialize hold
		bne.s	plr_nohold0		;not 0 -> OK
		st	trk_noteoffcnt(a5)	;0 -> hold = 0xff (-1)
	ENDC
; ---------------- and finally:
plr_nohold0	bsr	_PlayNote
; ---------------- end of loop: handle next track, or quit
plr_endloop0:	addq.b	#1,d7
		cmp.w	numtracks-DB(a6),d7
		blt.w	plr_loop0
		addq.l	#8,sp			;trackdataptrs / note ptr
; and advance song pointers
		lea	nextblock-DB(a6),a3
		move.w	nextblockline-DB(a6),d1
		beq.s	plr_advlinenum
		clr.w	nextblockline-DB(a6)
		subq.w	#1,d1
		bra.s	plr_linenumset
plr_advlinenum	move.w	mmd_pline(a2),d1	;get current line #
		addq.w	#1,d1			;advance line number
plr_linenumset	cmp.w	numlines-DB(a6),d1 	;advance block?
		bhi.s	plr_chgblock		;yes.
		tst.b	(a3)			;command F00/1Dxx?
		beq.s	plr_nochgblock		;no, don't change block
plr_chgblock	tst.b	nxtnoclrln-DB(a6)
		bne.s	plr_noclrln
		moveq	#0,d1			;clear line number
plr_noclrln	tst.w	mmd_pstate(a2)		;play block or play song
		bpl.s	plr_nonewseq		;play block only...
		move.w	mmd_pseqnum(a2),d0	;get play sequence number
		tst.b	(a3)
		bmi.s	plr_noadvseq		;Bxx sets nextblock to -1
		addq.w	#1,d0			;advance sequence number
plr_noadvseq	cmp.w	msng_songlen(a4),d0	;is this the highest seq number??
		blt.s	plr_notagain		;no.
		moveq	#0,d0			;yes: restart song
plr_notagain	move.b	d0,mmd_pseqnum+1(a2)	;remember new playseq-#
		lea	msng_playseq(a4),a0	;offset of sequence table
		move.b	0(a0,d0.w),d0		;get number of the block
	IFNE	CHECK
		cmp.w	msng_numblocks(a4),d0	;beyond last block??
		blt.s	plr_nolstblk		;no..
		moveq	#0,d0			;play block 0
	ENDC
plr_nolstblk	move.b	d0,mmd_pblock+1(a2)	;store block number
plr_nonewseq	clr.w	(a3)		 	;clear this if F00 set it
plr_nochgblock	move.w	d1,mmd_pline(a2)	;set new line number

	IFNE	HOLD
		lea	trackdataptrs-DB(a6),a5
		movea.l	mmd_blockarr(a2),a0
		move.w	mmd_pblock(a2),d0
		add.w	d0,d0
		add.w	d0,d0
		movea.l	0(a0,d0.w),a1	;block...
		move.w	mmd_pline(a2),d0
		move.b	msng_tempo2(a4),d3	;interrupts/note
	IFNE	PLAYMMD0
		cmp.b	#'1',3(a2)
		beq.s	plr_mmd1_2
		move.b	(a1),d7			;# of tracks
		move.w	d0,d1
		add.w	d0,d0	;d0 * 2
		add.w	d1,d0	;+ d0 = d0 * 3
		mulu	d7,d0
		lea	2(a1,d0.w),a3
		subq.b	#1,d7
plr_chkholdb	movea.l	(a5)+,a1		;track data
		tst.b	trk_noteoffcnt(a1)	;hold??
		bmi.s	plr_holdendb		;no.
		move.b	(a3),d1			;get the 1st byte..
		bne.s	plr_hold1b
		move.b	1(a3),d1
		and.b	#$f0,d1
		beq.s	plr_holdendb		;don't hold
		bra.s	plr_hold2b
plr_hold1b	and.b	#$3f,d1			;note??
		beq.s	plr_hold2b		;no, cont hold..
		move.b	1(a3),d1
		and.b	#$0f,d1			;get cmd
		subq.b	#3,d1			;is there command 3 (slide)
		bne.s	plr_holdendb		;no -> end holding
plr_hold2b	add.b	d3,trk_noteoffcnt(a1)	;continue holding...
plr_holdendb	addq.l	#3,a3		;next note
		dbf	d7,plr_chkholdb
		bra.s	nonewnote
plr_mmd1_2
	ENDC
		move.w	(a1),d7		;# of tracks
		add.w	d0,d0
		add.w	d0,d0	;d0 = d0 * 4
		mulu	d7,d0
		lea	8(a1,d0.l),a3
		subq.b	#1,d7
plr_chkhold	movea.l	(a5)+,a1		;track data
		tst.b	trk_noteoffcnt(a1)	;hold??
		bmi.s	plr_holdend		;no.
		move.b	(a3),d1			;get the 1st byte..
		bne.s	plr_hold1
		move.b	1(a3),d0
		and.b	#$3F,d0
		beq.s	plr_holdend		;don't hold
		bra.s	plr_hold2
plr_hold1	and.b	#$7f,d1			;note??
		beq.s	plr_hold2		;no, cont hold..
		move.b	2(a3),d1
		subq.b	#3,d1			;is there command 3 (slide)
		bne.s	plr_holdend		;no -> end holding
plr_hold2	add.b	d3,trk_noteoffcnt(a1)	;continue holding...
plr_holdend	addq.l	#4,a3		;next note
		dbf	d7,plr_chkhold
	ENDC	
nonewnote	moveq	#0,d3
		move.b	mmd_counter(a2),d3
plr_fxtime	lea	trackdataptrs-DB(a6),a3
		moveq	#0,d7	;clear track count
plr_loop1	movea.l	(a3)+,a5
		moveq	#0,d4
		moveq	#0,d5
		moveq	#0,d6
		move.b	trk_cmd(a5),d6	;get the fx number
		move.b	trk_cmdqual(a5),d4	;and the last 2 #'s
	IFNE	MIDI
		tst.b	trk_prevmidin(a5)	;is it MIDI??
		bne.w	midicmds
	ENDC
		cmp.w	#4,d7
	IFNE	MIDI
		bge.w	midicmds	;no non-MIDI effects in tracks 4 - 15
	ENDC
	IFEQ	MIDI
		bge.w	endl
	ENDC
	IFNE	HOLD
		tst.b	trk_noteoffcnt(a5)
		bmi.s	plr_nowaitoff
		subq.b	#1,trk_noteoffcnt(a5)
		bpl.s	plr_nowaitoff
	IFNE	SYNTH
		tst.b	trk_synthtype(a5)		;synth/hybrid??
		beq.s	plr_nosyndec
		move.b	trk_decay(a5),trk_volcmd+1(a5)	;set volume command pointer
		clr.b	trk_volwait(a5)			;abort WAI
		bra.s	plr_nowaitoff
	ENDC
plr_nosyndec:	move.b	trk_decay(a5),trk_fadespd(a5)	;set fade...
		bne.s	plr_nowaitoff			;if > 0, don't stop sound
		bset	d7,d5
		move.w	d5,$dff096			;shut DMA...
		moveq	#0,d5
	ENDC
plr_nowaitoff:	
	IFNE	HOLD
		move.b	trk_fadespd(a5),d0	;fade??
		beq.s	plr_nofade	;no.
		sub.b	d0,trk_prevvol(a5)
		bpl.s	plr_nofade
		clr.b	trk_prevvol(a5)
		clr.b	trk_fadespd(a5)		;fade no more
	ENDC
plr_nofade	add.b	d6,d6	;* 2
		move.w	fx_table(pc,d6.w),d0
		jmp	fxs(pc,d0.w)
fx_table	dc.w	fx_00-fxs,fx_01-fxs,fx_02-fxs,fx_03-fxs,fx_04-fxs
		dc.w	fx_05-fxs,fx_06-fxs,fx_07-fxs,fx_xx-fxs,fx_xx-fxs
		dc.w	fx_0a-fxs,fx_xx-fxs,fx_xx-fxs,fx_0d-fxs,fx_xx-fxs
		dc.w	fx_0f-fxs
		dc.w	fx_10-fxs,fx_11-fxs,fx_12-fxs,fx_13-fxs,fx_14-fxs
		dc.w	fx_xx-fxs,fx_xx-fxs,fx_xx-fxs,fx_18-fxs,fx_xx-fxs
		dc.w	fx_1a-fxs,fx_1b-fxs,fx_xx-fxs,fx_xx-fxs,fx_1e-fxs
		dc.w	fx_1f-fxs
fxs:
;	**************************************** Effect 01 ******
fx_01:		tst.b	d3
		bne.s	fx_01nocnt0
		btst	#5,msng_flags(a4)	;FLAG_STSLIDE??
		bne	fx_xx
fx_01nocnt0	sub.w	d4,trk_prevper(a5)
		move.w	trk_prevper(a5),d5
		cmp.w	#113,d5
		bge	plr_newper
		move.w	#113,d5
		move.w	d5,trk_prevper(a5)
		bra	plr_newper
;	**************************************** Effect 11 ******
fx_11		tst.b	d3
		bne	fx_xx
		sub.w	d4,trk_prevper(a5)
		move.w	trk_prevper(a5),d5
		bra	plr_newper
;	**************************************** Effect 02 ******
fx_02:		tst.b	d3
		bne.s	fx_02nocnt0
		btst	#5,msng_flags(a4)
		bne	fx_xx
fx_02nocnt0	add.w	d4,trk_prevper(a5)
		move.w	trk_prevper(a5),d5
		bra.w	plr_newper
;	**************************************** Effect 12 ******
fx_12		tst.b	d3
		bne	fx_xx
		add.w	d4,trk_prevper(a5)
		move.w	trk_prevper(a5),d5
		bra	plr_newper
;	**************************************** Effect 00 ******
fx_00:		tst.b	d4	;both fxqualifiers are 0s: no arpeggio
		beq.w	fx_xx
		move.l	d3,d0
		divu	#3,d0
		swap	d0
		tst.w	d0
		bne.s	fx_arp12
		and.b	#$0f,d4
		add.b	(a5),d4
		bra.s	fx_doarp
fx_arp12:	subq.b	#1,d0
		bne.s	fx_arp2
		lsr.b	#4,d4
		add.b	(a5),d4
		bra.s	fx_doarp
fx_arp2:	move.b	(a5),d4
fx_doarp:	subq.b	#1,d4		;-1 to make it 0 - 127
		add.b	msng_playtransp(a4),d4	;add play transpose
		add.b	trk_stransp(a5),d4	;add instrument transpose
		add.b	d4,d4
		movea.l	trk_periodtbl(a5),a1
		move.w	0(a1,d4.w),d5
		bra.w	plr_newtmp
;	**************************************** Effect 04 ******
fx_14		move.b	#6,trk_vibshift(a5)
		bra.s	vib_cont
fx_04		move.b	#5,trk_vibshift(a5)
vib_cont	tst.b	d3
		bne.s	nonvib
		move.b	d4,d1
		beq.s	nonvib
		and.w	#$0f,d1
		beq.s	plr_chgvibspd
		move.w	d1,trk_vibrsz(a5)
plr_chgvibspd:	and.b	#$f0,d4
		beq.s	nonvib
		lsr.b	#3,d4
		and.b	#$3e,d4
		move.b	d4,trk_vibrspd(a5)
nonvib:		move.b	trk_vibroffs(a5),d0
		lsr.b	#2,d0
		and.w	#$1f,d0
		moveq	#0,d1
		lea	sinetable(pc),a0
		move.b	0(a0,d0.w),d5
		ext.w	d5
		muls	trk_vibrsz(a5),d5
		move.b	trk_vibshift(a5),d1
		asr.w	d1,d5
		add.w	trk_prevper(a5),d5
		move.b	trk_vibrspd(a5),d0
		add.b	d0,trk_vibroffs(a5)
		bra.w	plr_newtmp
;	**************************************** Effect 06 ******
fx_06:		tst.b	d3
		bne.s	fx_06nocnt0
		btst	#5,msng_flags(a4)
		bne	fx_xx
fx_06nocnt0	bsr.s	plr_volslide		;Volume slide
		bra.s	nonvib			;+ Vibrato
;	**************************************** Effect 07 ******
fx_07		tst.b	d3
		bne.s	nontre
		move.b	d4,d1
		beq.s	nontre
		and.w	#$0f,d1
		beq.s	plr_chgtrespd
		move.w	d1,trk_tremsz(a5)
plr_chgtrespd	and.b	#$f0,d4
		beq.s	nonvib
		lsr.b	#2,d4
		and.b	#$3e,d4
		move.b	d4,trk_tremspd(a5)
nontre		move.b	trk_tremoffs(a5),d0
		lsr.b	#3,d0
		and.w	#$1f,d0
		moveq	#0,d1
		lea	sinetable(pc),a0
		move.b	0(a0,d0.w),d5
		ext.w	d5
		muls	trk_tremsz(a5),d5
		asr.w	#7,d5
		move.b	trk_tremspd(a5),d0
		add.b	d0,trk_tremoffs(a5)
		move.b	trk_prevvol(a5),d1
		add.b	d5,d1
		bpl.s	tre_pos
		moveq	#0,d1
tre_pos		cmp.b	#64,d1
		ble.s	tre_no2hi
		moveq	#64,d1
tre_no2hi	move.b	d1,trk_tempvol(a5)
		bra.w	fx_xx
;	**************************************** Effect 0D/0A ***
fx_0a:
fx_0d:		tst.b	d3
		bne.s	fx_0dnocnt0
		btst	#5,msng_flags(a4)
		bne	fx_xx
fx_0dnocnt0	bsr.s	plr_volslide
		bra	fx_xx
;	********* VOLUME SLIDE FUNCTION *************************
plr_volslide	move.b	d4,d0
		moveq	#0,d1
		move.b	trk_prevvol(a5),d1 ;move previous vol to d1
		and.b	#$f0,d0
		bne.s	crescendo
		sub.b	d4,d1	;sub from prev. vol
voltest0	bpl.s	novolover64
		moveq	#0,d1	;volumes under zero not accepted!!!
		bra.s	novolover64
crescendo:	lsr.b	#4,d0
		add.b	d0,d1
voltest		cmp.b	#64,d1
		ble.s	novolover64
		moveq	#64,d1
novolover64	move.b	d1,trk_prevvol(a5)
		rts
;	**************************************** Effect 1A ******
fx_1a		tst.b	d3
		bne	fx_xx
		move.b	trk_prevvol(a5),d1
		add.b	d4,d1
		bsr.s	voltest
		bra	fx_xx
;	**************************************** Effect 1B ******
fx_1b		tst.b	d3
		bne	fx_xx
		move.b	trk_prevvol(a5),d1
		sub.b	d4,d1
		bsr.s	voltest0
		bra	fx_xx
;	**************************************** Effect 05 ******
fx_05:		tst.b	d3
		bne.s	fx_05nocnt0
		btst	#5,msng_flags(a4)
		bne	fx_xx
fx_05nocnt0	bsr.s	plr_volslide		;Volume slide
		bra.s	fx_03nocnt0
;	**************************************** Effect 03 ******
fx_03:		tst.b	d3
		bne.s	fx_03nocnt0
		btst	#5,msng_flags(a4)
		bne	fx_xx
fx_03nocnt0	move.w	trk_porttrgper(a5),d0	;d0 = target period
		beq.w	fx_xx	;no target period specified
		move.w	trk_prevper(a5),d1	;d1 = curr. period
		move.b	trk_prevportspd(a5),d4	;get prev. speed
		cmp.w	d0,d1
		bhi.s	subper	;curr. period > target period
		add.w	d4,d1	;add the period
		cmp.w	d0,d1
		bge.s	targreached
		bra.s	targnreach
subper:		sub.w	d4,d1	;subtract
		cmp.w	d0,d1	;compare current period to target period
		bgt.s	targnreach
targreached:	move.w	trk_porttrgper(a5),d1 ;eventually push target period
		clr.w	trk_porttrgper(a5) ;now we can forget everything
targnreach:	move.w	d1,trk_prevper(a5)
		move.w	d1,d5
		bra.s	plr_newper
;	**************************************** Effect 13 ******
fx_13:		move.w	trk_prevper(a5),d5 ;this is very simple: get the old period
		cmp.b	#3,d3		;and..
		bge.s	plr_newper	;if counter < 3
		sub.w	d4,d5	;subtract effect qualifier
		bra.s	plr_newper
;	**************************************** Effect 10 ******
fx_10:
	IFNE	MIDI
		tst.b	d3
		bne.s	fx_xx
		move.w	d4,d0
		bsr.w	_InitMIDIDump
	ENDC
		bra.s	fx_xx
;	**************************************** Effect 1E ******
fx_1e		tst.w	blkdelay-DB(a6)
		bne.s	fx_xx
		addq.w	#1,d4
		move.w	d4,blkdelay-DB(a6)
		bra.s	fx_xx
;	**************************************** Effect 18 ******
fx_18		cmp.b	d4,d3
		bne.s	fx_xx
		clr.b	trk_prevvol(a5)
		bra.s	fx_xx
;	**************************************** Effect 1F ******
fx_1f		move.b	d4,d1
		lsr.b	#4,d4		;note delay
		beq.s	nonotedelay
		cmp.b	d4,d3		;compare to counter
		blt.s	fx_xx		;tick not reached
		bne.s	nonotedelay
		bsr	playfxnote	;trigger note
nonotedelay	and.w	#$0f,d1		;retrig?
		beq.s	fx_xx
		moveq	#0,d0
		move.b	d3,d0
		divu	d1,d0
		swap	d0		;get modulo of counter/tick
		tst.w	d0
		bne.s	fx_xx
		bsr	playfxnote	;retrigger
		bra.s	fx_xx
;	**************************************** Effect 0F ******
fx_0f		bsr	cmd_F
;	*********************************************************
plr_newper
fx_xx
	IFNE	SYNTH
		move.l	trk_synthptr(a5),d0
		beq.s	plr_nosynth
		bsr.w	synth_start
		bra.s	plr_tmpper
plr_newtmp	move.l	trk_synthptr(a5),d0
		beq.s	plr_tmpper
		bsr.w	synth_start2
		bra.s	plr_tmpper
	ENDC
plr_nosynth	move.w	trk_prevper(a5),d5
	IFEQ	SYNTH
plr_newtmp
	ENDC
plr_tmpper	movea.l	trk_audioaddr(a5),a1	;get channel address
		move.w	d5,ac_per(a1)		;push period
		beq.s	endl
		move.b	trk_tempvol(a5),d0
		bmi.s	plr_notmpvol
		move.b	d0,ac_vol+1(a1)
		st	trk_tempvol(a5)
		bra.s	endl
plr_notmpvol	move.b	trk_prevvol(a5),ac_vol+1(a1)	;get volume & push it
endl:		addq.b	#1,d7	;increment channel number
		cmp.w	numtracks-DB(a6),d7	;all channels done???
		blt.w	plr_loop1	;not yet!!!
plr_endfx:	;turn on DMA
		move.w	dmaonmsk-DB(a6),d0	;dmaonmsk contains the mask of
	IFNE	MIDI
		beq.s	sdma_nodmaon	;the channels that must be turned on
	ENDC
	IFEQ	MIDI
		beq.s	plr_exit
	ENDC	
		bset	#15,d0	;DMAF_SETCLR: set these bits in dmacon
		moveq	#80,d1
; The following line makes the playroutine one scanline slower. If your
; song works well without the following instruction, you can leave it out.
	IFNE	SYNTH
		add.w	d1,d1	;sometimes double wait time is required
	ENDC
		bsr.s	_Wait1line
		move.w	d0,$dff096	;do that!!!
		moveq	#80,d1
		bsr.s	_Wait1line
		lea	trackdataptrs-DB(a6),a1
		bsr.s	pushnewvals
		bsr.s	pushnewvals
		bsr.s	pushnewvals
		bsr.s	pushnewvals
	IFNE	MIDI
sdma_nodmaon	lea	bytesinnotebuff-DB(a6),a0
		move.w	(a0)+,d0
		beq.s	plr_exit
		bsr.w	_AddMIDId
	ENDC
plr_exit:	movem.l	(sp)+,d2-d7/a2-a6
		moveq	#1,d0
		rts

_Wait1line:	move.w	d0,-(sp)	;d1 = vsync counters to wait - 1
wl0:		move.b	$dff007,d0
wl1:		cmp.b	$dff007,d0
		beq.s	wl1
		dbf	d1,wl0
		move.w	(sp)+,d0
		rts
pushnewvals:	movea.l	(a1)+,a5
		lsr.b	#1,d0
		bcc.s	rpnewv
		move.l	trk_sampleptr(a5),d1
		beq.s	rpnewv
		movea.l	trk_audioaddr(a5),a0
		move.l	d1,ac_ptr(a0)
		move.w	trk_samplelen(a5),ac_len(a0)
rpnewv:		rts

cmd_F		cmp.b	#$f1,d4
		bne.s	no0ff1
		cmp.b	#3,d3
		beq.s	playfxnote
		rts
no0ff1:		cmp.b	#$f2,d4
		bne.s	no0ff2
		cmp.b	#3,d3
		beq.s	playfxnote
		rts
no0ff2:		cmp.b	#$f3,d4
		bne.s	no0ff3
		move.b	d3,d0
		and.b	#2+4,d0		;is 2 or 4
		beq.s	cF_rts
playfxnote:	moveq	#0,d1
		move.b	(a5),d1		;get note # of previous note
		beq.s	cF_rts
		move.b	trk_noteoffcnt(a5),d0	;get hold counter
		bmi.s	pfxn_nohold		;no hold, or hold over
		add.b	d3,d0			;increase by counter val
		bra.s	pfxn_hold
pfxn_nohold	move.b	trk_inithold(a5),d0	;get initial hold
		bne.s	pfxn_hold
		st	d0
pfxn_hold	move.b	d0,trk_noteoffcnt(a5)
		movem.l	d3/a3,-(sp)
		moveq	#0,d3
		move.b	trk_previnstr(a5),d3	;and prev. sample #
		movea.l	trk_previnstra(a5),a3
		bsr	_PlayNote
		movem.l	(sp)+,d3/a3
		rts
no0ff3:		cmp.b	#$f8,d4		;f8 = filter off
		beq.s	plr_filteroff
		cmp.b	#$f9,d4		;f9 = filter on
		bne.s	cF_rts
		bclr	#1,$bfe001
		rts
plr_filteroff:	bset	#1,$bfe001
cF_rts		rts

_SetTempo:
	IFNE	CIAB
		move.l	_module-DB(a6),d1
		beq.s	ST_x
		move.l	d1,a0
		movea.l	mmd_songinfo(a0),a0
		btst	#5,msng_flags2(a0)
		bne.s	ST_bpm
		cmp.w	#10,d0	;If tempo <= 10, use SoundTracker tempo
		bhi.s	calctempo
		subq.b	#1,d0
		add.w	d0,d0
		move.w	sttempo+2(pc,d0.w),d1
		bra.s	pushtempo
calctempo:	move.l	timerdiv-DB(a6),d1
		divu	d0,d1
pushtempo:	movea.l	craddr+4-DB(a6),a0
		move.b	d1,(a0)		;and set the CIA timer
		lsr.w	#8,d1
		movea.l	craddr+8-DB(a6),a0
		move.b	d1,(a0)
	ENDC
ST_x		rts ;   vv-- These values are the SoundTracker tempos (approx.)
sttempo:	dc.w	$0f00
	IFNE	CIAB
		dc.w	2417,4833,7250,9666,12083,14500,16916,19332,21436,24163
ST_bpm		move.b	msng_flags2(a0),d1
		and.w	#$1F,d1
		addq.b	#1,d1
		mulu	d1,d0
		move.l	bpmdiv-DB(a6),d1
		divu	d0,d1
		bra.s	pushtempo
	ENDC

	IFNE	MIDI
midicmds
	IFNE	HOLD
		tst.b	trk_noteoffcnt(a5)
		bmi.s	midi_nowaitoff
		subq.b	#1,trk_noteoffcnt(a5)
		bpl.s	midi_nowaitoff
		move.l	a5,a1
		move.b	trk_prevmidin(a5),d1
		beq.s	midi_nowaitoff	;no note
		lea	noteondata-DB(a6),a0
		bsr.w	choff_midi
midi_nowaitoff:
	ENDC
		add.b	d6,d6	;* 2
		move.w	midicmd_table(pc,d6.w),d0
		jmp	midifx(pc,d0.w)
midicmd_table:	dc.w	mfx_00-midifx,mfx_01-midifx,mfx_02-midifx,mfx_03-midifx,mfx_04-midifx
		dc.w	mfx_05-midifx,endl-midifx,endl-midifx,endl-midifx,endl-midifx
		dc.w	mfx_0a-midifx,endl-midifx,endl-midifx,mfx_0d-midifx,mfx_0e-midifx
		dc.w	mfx_0f-midifx
		dc.w	mfx_10-midifx,endl-midifx,endl-midifx,endl-midifx
		dc.w	endl-midifx,endl-midifx,endl-midifx,mfx_17-midifx
		dc.w	endl-midifx,endl-midifx,endl-midifx,endl-midifx
		dc.w	endl-midifx,endl-midifx,endl-midifx,mfx_1f-midifx
midifx		
mfx_01		lea	prevmidipbend-DB(a6),a0
		moveq	#0,d1
		move.b	trk_prevmidich(a5),d1	;get previous midi channel
		add.b	d1,d1		;UWORD index
		tst.b	d4		;x100??
		beq.s	resetpbend
		move.w	0(a0,d1.w),d0	;get previous pitch bend
		lsl.w	#3,d4		;multiply bend value by 8
		add.w	d4,d0
		cmp.w	#$3fff,d0
		bls.s	bendpitch
		move.w	#$3fff,d0
bendpitch:	move.w	d0,0(a0,d1.w)	;save current pitch bend
		lsr.b	#1,d1		;back to UBYTE
		or.b	#$e0,d1
		lea	noteondata-DB(a6),a0
		move.b	d1,(a0)		;midi command & channel
		move.b	d0,1(a0)	;lower value
		and.b	#$7f,1(a0)	;clear bit 7
		lsr.w	#7,d0
		and.b	#$7f,d0		;clr bit 7
		move.b	d0,2(a0)	;higher 7 bits
		moveq	#3,d0
		bsr.w	_AddMIDId
		bra.w	endl

mfx_02		lea	prevmidipbend-DB(a6),a0
		moveq	#0,d1
		move.b	trk_prevmidich(a5),d1
		add.b	d1,d1
		tst.b	d4
		beq.s	resetpbend	;x200??
		move.w	0(a0,d1.w),d0
		lsl.w	#3,d4
		sub.w	d4,d0
		bpl.s	bendpitch	;not under 0
		moveq	#0,d0
		bra.s	bendpitch
resetpbend:	tst.b	d3		;d3 = counter (remember??)
		bne.w	endl
		move.w	#$2000,d0
		bra.s	bendpitch

mfx_03		tst.b	d3
		bne.w	endl
		lea	prevmidipbend-DB(a6),a0
		moveq	#0,d1
		move.b	trk_prevmidich(a5),d1
		add.b	d1,d1
		move.b	d4,d0
		add.b	#128,d0
		lsl.w	#6,d0
		bra.s	bendpitch

mfx_0d		tst.b	d3
		bne.w	endl
		lea	noteondata+1-DB(a6),a0	;CHANNEL AFTERTOUCH
		move.b	d4,(a0)	;value
		bmi.w	endl
		move.b	trk_prevmidich(a5),-(a0)
		or.b	#$d0,(a0)
		moveq	#2,d0
		bsr.w	_AddMIDId
		bra.w	endl

mfx_0a		tst.b	d3
		bne.w	endl
		lea	noteondata+2-DB(a6),a0	;POLYPHONIC AFTERTOUCH
		and.b	#$7f,d4
		move.b	d4,(a0)
		move.b	trk_prevmidin(a5),-(a0)
		ble.w	endl
		move.b	trk_prevmidich(a5),-(a0)
		or.b	#$A0,(a0)
		moveq	#3,d0
		bsr.w	_AddMIDId
		bra.w	endl

mfx_17		moveq	#$07,d0		;07 = VOLUME
		bra.s	pushctrldata

mfx_04		moveq	#$01,d0		;01 = MODULATION WHEEL
		bra.s	pushctrldata

mfx_0e		moveq	#$0a,d0
pushctrldata	tst.b	d3		;do it only once in a note
		bne.w	endl		;(when counter = 0)
		lea	noteondata+2-DB(a6),a0 ;push "control change" data,
		move.b	d4,(a0)		;second databyte
		bmi.w	endl		;$0 - $7F only
		move.b	d0,-(a0)	;1st databyte
		move.b	trk_prevmidich(a5),-(a0)	;MIDI channel
		or.b	#$b0,(a0)	;command (B)
		moveq	#3,d0
		bsr.w	_AddMIDId
		bra.w	endl

mfx_05		and.b	#$7f,d4		;set contr. value of curr. MIDI ch.
		move.b	trk_prevmidich(a5),d6
		lea	midicontrnum-DB(a6),a0
		adda.w	d6,a0
		move.b	d4,(a0)
		bra.w	endl

mfx_0f		cmp.b	#$fa,d4		;hold pedal ON
		bne.s	nomffa
		moveq	#$40,d0
		moveq	#$7f,d4
		bra.s	pushctrldata
nomffa		cmp.b	#$fb,d4		;hold pedal OFF
		bne.s	mfx_0f_2
		moveq	#$40,d0
		moveq	#$00,d4
		bra.s	pushctrldata
mfx_0f_2	bsr.w	cmd_F
		bra.w	endl

mfx_00		tst.b	d4
		beq.w	endl
		and.b	#$7f,d4
		move.b	trk_prevmidich(a5),d6
		lea	midicontrnum-DB(a6),a0
		move.b	0(a0,d6.w),d0
		bra.s	pushctrldata

mfx_10		tst.b	d3
		bne.w	endl
		move.w	d4,d0
		bsr.w	_InitMIDIDump
		bra.w	endl

mfx_1f		move.b	d4,d1
		lsr.b	#4,d4		;note delay
		beq.s	nonotedelay_m
		cmp.b	d4,d3		;compare to counter
		blt	endl		;tick not reached
		bne.s	nonotedelay_m
		bsr	playfxnote	;trigger note
nonotedelay_m	and.w	#$0f,d1		;retrig?
		beq	endl
		moveq	#0,d0
		move.b	d3,d0
		divu	d1,d0
		swap	d0		;get modulo of counter/tick
		tst.w	d0
		bne	endl
		bsr	playfxnote	;retrigger
		bra	endl

_ResetMIDI:	movem.l	d2/a2/a6,-(sp)
		movea.l	4,a6		;ExecBase
		jsr	-$78(a6)	;Disable()
		lea	DB,a6
; Clear preset memory
		lea	prevmidicpres-DB(a6),a0
		clr.l	(a0)+	;force presets to be set again
		clr.l	(a0)+	;(clear prev. preset numbers)
		clr.l	(a0)+
		clr.l	(a0)
		clr.b	lastcmdbyte
; Reset pitchbenders & modulation wheels
		lea	midiresd-DB(a6),a2
		move.b	#$e0,(a2)
		move.b	#$b0,3(a2)
		moveq	#15,d2
respbendl:	movea.l	a2,a0
		moveq	#6,d0
		bsr.w	_AddMIDId
		addq.b	#1,(a2)
		addq.b	#1,3(a2)
		dbf	d2,respbendl
		lea	prevmidipbend-DB(a6),a2
		moveq	#15,d2
resprevpbends:	move.w	#$2000,(a2)+
		dbf	d2,resprevpbends
; Clear dump variables
		clr.b	sysx-DB(a6)
		lea	dumpqueue-DB(a6),a0
		move.l	a0,dqreadptr-DB(a6)
		move.l	a0,dqwriteptr-DB(a6)
		clr.w	dqentries-DB(a6)
; Enable & exit
		movea.l	4,a6
		jsr	-$7e(a6)	;Enable()
		movem.l	(sp)+,d2/a2/a6
		rts
	ENDC

; *************************************************************************
; *************************************************************************
; ***********          P U B L I C   F U N C T I O N S          ***********
; *************************************************************************
; *************************************************************************

	IFEQ	EASY
		XDEF	_InitModule,_PlayModule
		XDEF	_InitPlayer,_RemPlayer,_StopPlayer
		XDEF	_ContModule
	ENDC

; *************************************************************************
; InitModule(a0 = module) -- extract expansion data etc.. from V3.xx module
; *************************************************************************

_InitModule:	movem.l	a2-a3/d2,-(sp)
		move.l	a0,d0
		beq	IM_exit			;0 => xit
	IFNE	RELVOL
		movea.l	mmd_songinfo(a0),a1	;MMD0song
		move.b	msng_mastervol(a1),d0	;d0 = mastervol
		ext.w	d0
		lea	msng_trkvol(a1),a1	;a1 = trkvol
		lea	trackdataptrs,a2
		moveq	#15,d1
IM_loop0	move.b	(a1)+,d2	;get vol...
		ext.w	d2
		move.l	(a2)+,a3	;pointer to track data
		mulu	d0,d2		;mastervol * trackvol
		lsr.w	#4,d2
		move.w	d2,trk_trackvol(a3)
		dbf	d1,IM_loop0
	ENDC
		lea	holdvals,a2
		movea.l	a0,a3
		move.l	mmd_expdata(a0),d0	;expdata...
		beq.s	IM_clrhlddec		;none here
		move.l	d0,a1
		move.l	4(a1),d0		;exp_smp
		beq.s	IM_clrhlddec	;again.. nothing
		move.l	d0,a0		;InstrExt...
		move.w	8(a1),d2	;# of entries
		beq.s	IM_clrhlddec
		subq.w	#1,d2		;- 1 (for dbf)
		move.w	10(a1),d0	;entry size
	IFNE	MIDI
		movea.l	mmd_songinfo(a3),a3	;MMD0song
	ENDC
IM_loop1	cmp.w	#3,d0
		ble.s	IM_noftune
		move.b	3(a0),126(a2)	;InstrExt.finetune -> finetune
IM_noftune
	IFNE	MIDI
		cmp.w	#2,d0
		ble.s	IM_nsmnoff
		tst.b	2(a0)		;suppress MIDI note off?
		beq.s	IM_nsmnoff
		bset	#7,inst_midich(a3)
IM_nsmnoff	addq.l	#8,a3		;next instr
	ENDC
		move.b	1(a0),63(a2)	;InstrExt.decay -> decay
		move.b	(a0),(a2)+	;InstrExt.hold -> holdvals
		adda.w	d0,a0		;ptr to next InstrExt
		dbf	d2,IM_loop1
		bra.s	IM_exit
IM_clrhlddec	move.w	#3*63-1,d0	;no InstrExt => clear holdvals/decays
IM_loop2	clr.b	(a2)+
		dbf	d0,IM_loop2
IM_exit		movem.l	(sp)+,a2-a3/d2
		rts
; *************************************************************************
; InitPlayer() -- allocate interrupt, audio, serial port etc...
; *************************************************************************
_InitPlayer:
	IFNE	MIDI
		bsr.w	_GetSerial
		tst.l	d0
		bne.s	IP_error
	ENDC
		bsr.w	_AudioInit
		tst.l	d0
		bne.s	IP_error
		rts
IP_error	bsr.s	_RemPlayer
		moveq	#-1,d0
		rts
; *************************************************************************
; RemPlayer() -- free interrupt, audio, serial port etc..
; *************************************************************************
_RemPlayer:	move.b	_timeropen,d0
		beq.s	RP_notimer	;timer is not ours
		bsr.s	_StopPlayer
RP_notimer:	bsr.w	_AudioRem
	IFNE	MIDI
		bsr.w	_FreeSerial
	ENDC
		rts
; *************************************************************************
; StopPlayer() -- stop music
; *************************************************************************
_StopPlayer:	lea	DB,a1
		move.b	_timeropen-DB(a1),d0
		beq.s	SP_end		;res. alloc fail.
	IFNE	CIAB
		movea.l	craddr-DB(a1),a0
		bclr	#0,(a0)		;stop timer
	ENDC
		move.l	_module-DB(a1),d0
		beq.s	SP_nomod
		move.l	d0,a0
		clr.w	mmd_pstate(a0)
		clr.l	_module-DB(a1)
SP_nomod
	IFNE	MIDI
		clr.b	lastcmdbyte-DB(a1)
	ENDC
		bsr.w	SoundOff
SP_end		rts


_ContModule	tst.b	_timeropen
		beq.s	SP_end
		movea.l	craddr,a1
		bclr	#0,(a1)
		move.l	a0,-(sp)
		bsr.w	SoundOff
		move.l	(sp)+,a0
		moveq	#0,d0
		bra.s	contpoint
; *************************************************************************
; PlayModule(a0 = module)  -- initialize & play it!!
; *************************************************************************
_PlayModule:	st	d0
contpoint	movem.l	a0/d0,-(sp)
		bsr	_InitModule
		movem.l	(sp)+,a0/d0
		move.l	a6,-(sp)
		lea	DB,a6
		tst.b	_timeropen-DB(a6)
		beq	PM_end		;resource allocation failure
		move.l	a0,d1
		beq	PM_end		;module failure
	IFNE	CIAB
		movea.l	craddr-DB(a6),a1
		bclr	#0,(a1)		;stop timer...
	ENDC
		clr.l	_module-DB(a6)
	IFNE	MIDI
		clr.b	lastcmdbyte-DB(a6)
	ENDC
		move.w	_modnum,d1
		beq.s	PM_modfound
PM_nextmod	tst.l	mmd_expdata(a0)
		beq.s	PM_modfound
		move.l	mmd_expdata(a0),a1
		tst.l	(a1)
		beq.s	PM_modfound		;no more modules here!
		move.l	(a1),a0
		subq.w	#1,d1
		bgt.s	PM_nextmod
PM_modfound	movea.l	mmd_songinfo(a0),a1		;song
		move.b	msng_tempo2(a1),mmd_counter(a0)	;init counter
		btst	#0,msng_flags(a1)
		bne.s	PM_filon
		bset	#1,$bfe001
		bra.s	PM_filset
PM_filon	bclr	#1,$bfe001
PM_filset	tst.b	d0
		beq.s	PM_noclr
		clr.l	mmd_pline(a0)
		clr.l	rptline-DB(a6)
		clr.w	blkdelay-DB(a6)
PM_noclr	move.w	mmd_pseqnum(a0),d1
		add.w	#msng_playseq,d1
		move.b	0(a1,d1.w),d1		;get first playseq entry
		move.b	d1,mmd_pblock+1(a0)
		move.w	#-1,mmd_pstate(a0)
		move.l	a0,_module-DB(a6)
		btst	#5,msng_flags2(a1)	;BPM?
		seq	bpmcounter-DB(a6)
	IFNE	CIAB
		move.w	msng_deftempo(a1),d0	;get default tempo
		movea.l	craddr-DB(a6),a1
		bsr.w	_SetTempo	;set default tempo
		bset	#0,(a1)		;start timer => PLAY!!
	ENDC
PM_end		move.l	(sp)+,a6
		rts
; *************************************************************************

_AudioInit:	movem.l	a4/a6/d2-d3,-(sp)
		lea	DB,a4
		moveq	#0,d2
		movea.l	4,a6
;	+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+ alloc signal bit
	IFNE	AUDDEV
		moveq	#1,d2
		moveq	#-1,d0
		jsr	-$14a(a6)	;AllocSignal()
		tst.b	d0
		bmi.w	initerr
		move.b	d0,sigbitnum-DB(a4)
;	+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+ prepare IORequest
		lea	allocport-DB(a4),a1
		move.b	d0,15(a1)	;set mp_SigBit
		move.l	a1,-(sp)
		suba.l	a1,a1
		jsr	-$126(a6)	;FindTask(0)
		move.l	(sp)+,a1
		move.l	d0,16(a1)	;set mp_SigTask
		lea	reqlist-DB(a4),a0
		move.l	a0,(a0)		;NEWLIST begins...
		addq.l	#4,(a0)
		clr.l	4(a0)
		move.l	a0,8(a0)	;NEWLIST ends...
;	+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+ open audio.device
		moveq	#2,d2
		lea	allocreq-DB(a4),a1
		lea	audiodevname-DB(a4),a0
		moveq	#0,d0
		moveq	#0,d1
		movea.l	4,a6
		jsr	-$1bc(a6)	;OpenDevice()
		tst.b	d0
		bne.w	initerr
		st.b	audiodevopen-DB(a4)
;	+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+ open cia resource
		moveq	#3,d2
	ENDC
	IFNE	CIAB
		cmp.b	#50,$212(a6)	;ExecBase->VBlankFrequency
		beq.s	init_pal
		move.l	#474326,timerdiv-DB(a4) ;Assume that CIA freq is 715 909 Hz
		move.l	#3579545/2,bpmdiv-DB(a4)
init_pal	moveq	#0,d3
		lea	cianame-DB(a4),a1
		move.b	#'a',3(a1)
open_ciares	moveq	#0,d0
		jsr	-$1f2(a6)	;OpenResource()
		move.l	d0,_ciaresource
		beq.s	try_CIAB
		moveq	#4,d2
		move.l	d0,a6
		lea	timerinterrupt-DB(a4),a1
		moveq	#0,d0		;Timer A
		jsr	-$6(a6)		;AddICRVector()
		tst.l	d0
		beq.s	got_timer
		addq.l	#4,d3		;add base addr index
		lea	timerinterrupt-DB(a4),a1
		moveq	#1,d0		;Timer B
		jsr	-$6(a6)		;AddICRVector()
		tst.l	d0
		beq.s	got_timer
try_CIAB	lea	cianame-DB(a4),a1
		cmp.b	#'a',3(a1)
		bne.s	initerr
		addq.b	#1,3(a1)
		moveq	#8,d3		;CIAB base addr index = 8
		bra.w	open_ciares
;	+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+ attach interrupt
got_timer	lea	craddr+8-DB(a4),a6
		move.l	cia_addr(pc,d3.w),d0
		move.l	d0,(a6)
		sub.w	#$100,d0
		move.l	d0,-(a6)
		moveq	#2,d3		;assume timer B
		btst	#9,d0		;timer A or B ?
		bne.s	got_timerB
		subq.b	#1,d3		;not timer B -> subtract 1
		add.w	#$100,d0	;calc offset to timer control reg
got_timerB	add.w	#$900,d0
		move.l	d0,-(a6)
		move.l	d0,a0			;get Control Register
		and.b	#%10000000,(a0)		;clear CtrlReg bits 0 - 6
		move.b	d3,_timeropen-DB(a4)	;d3: 1 = TimerA 2 = TimerB
	ENDC
	IFNE	VBLANK
		moveq	#5,d0		;INTB_VERTB
		lea	timerinterrupt-DB(a4),a1
		jsr	-$a8(a6)	;AddIntServer
		st	_timeropen-DB(a4)
	ENDC
		moveq	#0,d0
initret:	movem.l	(sp)+,a4/a6/d2-d3
		rts
initerr:	move.l	d2,d0
		bra.s	initret

cia_addr:	dc.l	$BFE501,$BFE701,$BFD500,$BFD700

_AudioRem:	movem.l	a5-a6,-(sp)
		lea	DB,a5
		moveq	#0,d0
		move.b	_timeropen,d0
		beq.s	rem1
;	+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+ remove interrupt
		move.l	_ciaresource,a6
		lea	timerinterrupt-DB(a5),a1
		subq.b	#1,d0
		jsr	-$c(a6)		;RemICRVector
rem1:
	IFNE	AUDDEV
		movea.l	4,a6
		tst.b	audiodevopen-DB(a5)
		beq.s	rem2
		move.w	#$000f,$dff096	;stop audio DMA
;	+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+ close audio.device
		lea	allocreq-DB(a5),a1
		jsr	-$1c2(a6)	;CloseDevice()
		clr.b	audiodevopen-DB(a5)
rem2:		moveq	#0,d0
		move.b	sigbitnum-DB(a5),d0
		bmi.s	rem3
;	+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+=+ free signal bit
		jsr	-$150(a6)	;FreeSignal()
		st	sigbitnum-DB(a5)
rem3:
	ENDC
		movem.l	(sp)+,a5-a6
		rts

	IFNE	MIDI
_GetSerial:	movem.l	a5-a6,-(sp)	;Get serial port for MIDI
		lea	DB,a5
		bsr.s	GetSer2
		tst.l	d0		;got the port??
		beq.s	rgser		;yes
		movea.l	4,a6		;no..try to flush serial.device:
		jsr	-$84(a6)		;Forbid
		lea	$15e(a6),a0		;ExecBase->DeviceList
		lea	serdev-DB(a5),a1	;"serial.device"
		jsr	-$114(a6)		;FindName
		tst.l	d0
		beq.s	serdnotf		;no serial.device!!
		move.l	d0,a1
		jsr	-$1b6(a6)		;RemDevice
serdnotf:	jsr	-$8a(a6)		;and Permit
		bsr.s	GetSer2		;now try it again...
rgser:		movem.l	(sp)+,a5-a6
		rts

GetSer2:	movea.l	4,a6
		moveq	#0,d0
		lea	miscresname-DB(a5),a1
		jsr	-$1f2(a6)	;OpenResource()
		move.l	d0,miscresbase-DB(a5)
		tst.l	d0
		beq.s	gserror
		move.l	d0,a6
		lea	medname-DB(a5),a1
		moveq	#0,d0		;serial port
		jsr	-$6(a6)		;AllocMiscResource()
		tst.l	d0
		bne.s	gserror
		lea	medname-DB(a5),a1
		moveq	#1,d0		;serial bits
		jsr	-$6(a6)
		tst.l	d0
		beq.s	gs2_allocok
		moveq	#0,d0
		jsr	-$c(a6)		;bits failed -> Free serial port
		bra.s	gserror
gs2_allocok	move.w	$dff01c,d0
		btst	#0,d0
		sne	intrson-DB(a5)
		moveq	#0,d0		;TBE
		lea	serinterrupt-DB(a5),a1
		move.l	4,a6
		jsr	-$a2(a6)	;SetIntVector()
		move.l	d0,prevtbe-DB(a5)
		move.w	#$8001,$dff09a	;TBE on
		move.w	#114,$dff032	;set baud rate (SERPER)
		st	serportalloc-DB(a5)
		moveq	#0,d0
		rts
gserror:	moveq	#-1,d0
		rts

_FreeSerial:	movem.l	a5-a6,-(sp)
		lea	DB,a5
		tst.l	miscresbase-DB(a5)
		beq.s	retfs
		tst.b	serportalloc-DB(a5)
		beq.s	retfs
wmb_loop	move.w	$dff018,d0	;WAIT until all data sent
		btst	#12,d0		;test TSRE bit of SERDAT
		beq.s	wmb_loop
		move.w	#$0001,$dff09a	;disable TBE
		movea.l	4,a6
		move.l	prevtbe-DB(a5),a1
		moveq	#0,d0
		jsr	-$a2(a6)	;SetIntVector()
fs_noptbe	movea.l	miscresbase-DB(a5),a6
		moveq	#0,d0		;serial port
		jsr	-$c(a6)		;FreeMiscResource()
		moveq	#1,d0		;serial bits
		jsr	-$c(a6)
		clr.b	serportalloc-DB(a5)
		clr.b	lastcmdbyte-DB(a5)
retfs:		movem.l	(sp)+,a5-a6
		rts

; Message number in d0.
_InitMIDIDump:	tst.b	serportalloc
		beq.s	idd_rts
		movem.l	a5/a6,-(sp)	;a1 = data pointer, d1 = length
		lea	DB,a5
		movea.l	4,a6			;ExecBase
		jsr	-$78(a6)		;Disable()
		cmp.w	#16,dqentries-DB(a5)	;dump queue full?
		bge.s	idd_exit		;exit without doing anything
		lea	dqwriteptr-DB(a5),a1
		movea.l	(a1),a0
		move.w	d0,(a0)+		;store message number
		cmpa.l	a1,a0			;queue end?
		bne.s	idd_noresetbuff
		lea	dumpqueue-DB(a5),a0	;reset write pointer
idd_noresetbuff	move.l	a0,(a1)			;and write it back.
		addq.w	#1,dqentries-DB(a5)
		tst.b	sysx-DB(a5)		;already sending data?
		bne.s	idd_exit		;yes. Don't initiate new send.
		clr.b	lastcmdbyte-DB(a5)
		bsr	StartNewDump
		move.w	$dff018,d0		;SERDATR
		btst	#13,d0
		beq.s	idd_exit
		move.w	#$8001,$dff09c		;request TBE
idd_exit	jsr	-$7e(a6)		;Enable()
		movem.l	(sp)+,a5/a6
idd_rts		rts

SerIntHandler:	move.w	#$4000,$9a(a0)	;disable..(Interrupts are enabled anyway)
		move.w	#1,$9c(a0)			;clear intreq bit
		tst.b	sysx-buffptr(a1)		;sysx??
		bne.s	sih_sysx
		move.b	bytesinbuff-buffptr(a1),d0	;bytesinbuff
		beq.s	exsih				;buffer empty
		movea.l	readbuffptr-buffptr(a1),a5	;get buffer read pointer
		move.w	#$100,d1			;Stop bit
		move.b	(a5)+,d1			;get byte
		move.w	d1,$30(a0)			;and push it to SERDAT
		cmpa.l	a1,a5				;shall we reset ptr??
		bne.s	norrbuffptr			;not yet..
		lea	-128(a1),a5
norrbuffptr	subq.b	#1,d0				;one less bytes in buffer
		move.b	d0,bytesinbuff-buffptr(a1)	;remember it
		move.l	a5,readbuffptr-buffptr(a1)	;push new read ptr back
exsih		move.w	#$c000,$9a(a0)
		rts
sih_sysx	move.w	#$100,d1
		movea.l	sysxptr-buffptr(a1),a5	;data pointer
		move.b	(a5)+,d1
		move.l	a5,sysxptr-buffptr(a1)
		move.w	d1,$30(a0)		;-> SERDAT
		subq.l	#1,sysxleft-buffptr(a1)	;sub data left length
		bne.s	exsih		;not 0w
		lea	DB,a5
		clr.b	lastcmdbyte-DB(a5)
		bsr.s	StartNewDump
		bra.s	exsih

StartNewDump:	tst.w	dqentries-DB(a5)	;queue empty?
		beq.s	snd_exit2
		movea.l	dqreadptr-DB(a5),a1	;get read pointer
		move.w	(a1)+,d0		;get message number (D0)
		cmpa.l	#dqwriteptr,a1		;queue end?
		bne.s	snd_noresetbuff
		lea	dumpqueue-DB(a5),a1	;reset write pointer
snd_noresetbuff	move.l	a1,dqreadptr-DB(a5)	;and write it back.
		subq.w	#1,dqentries-DB(a5)
; then attempt to search the given message (# in D0)
		move.l	_module-DB(a5),d1
		beq.s	StartNewDump
		move.l	d1,a1
		move.l	mmd_expdata(a1),d1
		beq.s	StartNewDump
		move.l	d1,a1
		move.l	52(a1),d1		;exp_dump
		beq.s	StartNewDump
		move.l	d1,a1
		cmp.w	(a1),d0
		bge.s	StartNewDump
		addq.l	#8,a1			;points to MMDDump ptr table
		add.w	d0,d0
		add.w	d0,d0			;number *= 4
		adda.w	d0,a1
		movea.l	(a1),a1
; initialize send variables (msg addr. in A0)
snd_found	move.l	(a1)+,sysxleft-DB(a5)	;length
		move.l	(a1),sysxptr-DB(a5)	;data pointer
		st	sysx-DB(a5)
		rts
snd_exit2	clr.b	sysx-DB(a5)		;finish dump
		rts

_AddMIDIData	move.l	a6,-(sp)
		lea	DB,a6
		bsr.s	_AddMIDId
		move.l	(sp)+,a6
		rts

_AddMIDId	movem.l	a2-a3/a5,-(sp)
		tst.b	serportalloc-DB(a6)
		beq.s	retamd1
		movea.l	4,a5
		lea	$dff09a,a3
		move.w	#$4000,(a3)	;Disable interrupts
		addq.b	#1,$126(a5)	;ExecBase->IDNestCnt
		lea	buffptr-DB(a6),a2	;end of buffer (ptr)
		move.w	-130(a3),d1	;-130(a3) = $dff018 (SERDATR)
		btst	#13,d1
		beq.s	noTBEreq
		move.w	#$8001,2(a3)	;request TBE [2(a3) = $dff09c]
noTBEreq	movea.l	(a2),a1		;buffer pointer
adddataloop	move.b	(a0)+,d1	;get byte
		bpl.s	norscheck	;this isn't a status byte
		cmp.b	#$ef,d1		;ignore system messages
		bhi.s	norscheck
		cmp.b	lastcmdbyte-DB(a6),d1	;same as previos status byte?
		beq.s	samesb			;yes, skip
		move.b	d1,lastcmdbyte-DB(a6)	;no, don't skip but store.
norscheck	move.b	d1,(a1)+		;push to midi send buffer
		addq.b	#1,8(a2)
samesb		cmpa.l	a2,a1			;end of buffer??
		bne.s	noresbuffptr		;no.
		lea	sendbuffer-DB(a6),a1	;reset
noresbuffptr	subq.b	#1,d0
		bne.s	adddataloop
		move.l	a1,(a2)			;push back new buffer ptr
		subq.b	#1,$126(a5)
		bge.s	retamd1
		move.w	#$c000,(a3)	;enable interrupts again
retamd1		movem.l	(sp)+,a2-a3/a5
		rts
	ENDC

		DATA
DB:		;Data base pointer
	IFNE	MIDI
sendbuffer	ds.b	128
buffptr		dc.l	sendbuffer
readbuffptr	dc.l	sendbuffer
bytesinbuff	dc.b	0
		dc.b	0
sysx		dc.b	0
lastcmdbyte	dc.b	0
sysxptr		dc.l	0
sysxleft	dc.l	0
dumpqueue	ds.w	16
dqwriteptr	dc.l	dumpqueue
dqreadptr	dc.l	dumpqueue
dqentries	dc.w	0
	ENDC
miscresbase	dc.l	0
timerdiv	dc.l	470000
	IFNE	AUDDEV
audiodevopen	dc.b	0
sigbitnum	dc.b	-1
	ENDC
	IFNE	MIDI
serportalloc	dc.b	0
	ENDC
		even
	IFNE	MIDI
preschgdata	dc.w	0
noteondata	dc.l	0
	ENDC
_module		dc.l	0
dmaonmsk	dc.w	0 ;\_May not be
	IFNE	MIDI
bytesinnotebuff	dc.w	0 ;/ separated!
noteonbuff	ds.b	18*3
		even
intrson		dc.b	0,0
prevtbe		dc.l	0
	ENDC
	IFNE	CIAB
_ciaresource	dc.l	0
craddr		dc.l	0
		dc.l	0	;tloaddr
		dc.l	0	;thiaddr
	ENDC
timerinterrupt	dc.w	0,0,0,0,0
		dc.l	timerintname,DB
		dc.l	_IntHandler
	IFNE	MIDI
serinterrupt	dc.w	0,0,0,0,0
		dc.l	serintname,buffptr,SerIntHandler
	ENDC
	IFNE	AUDDEV
allocport	dc.l	0,0	;succ, pred
		dc.b	4,0	;NT_MSGPORT
		dc.l	0	;name
		dc.b	0,0	;flags = PA_SIGNAL
		dc.l	0	;task
reqlist		dc.l	0,0,0	;list head, tail and tailpred
		dc.b	5,0
allocreq	dc.l	0,0
		dc.b	0,127	;NT_UNKNOWN, use maximum priority (127)
		dc.l	0,allocport	;name, replyport
		dc.w	68		;length
		dc.l	0	;io_Device
		dc.l	0	;io_Unit
		dc.w	0	;io_Command
		dc.b	0,0	;io_Flags, io_Error
		dc.w	0	;ioa_AllocKey
		dc.l	sttempo	;ioa_Data
		dc.l	1	;ioa_Length
		dc.w	0,0,0	;ioa_Period, Volume, Cycles
		dc.w	0,0,0,0,0,0,0,0,0,0	;ioa_WriteMsg
audiodevname	dc.b	'audio.device',0
	ENDC
	IFNE	CIAB
cianame		dc.b	'ciax.resource',0
_timeropen	dc.b	0
	ENDC
timerintname	dc.b	'OMEDTimerInterrupt',0
	IFNE	MIDI
serintname	dc.b	'OMEDSerialInterrupt',0
miscresname	dc.b	'misc.resource',0
serdev		dc.b	'serial.device',0
medname		dc.b	'OctaMED Pro modplayer',0
	ENDC
		even
	IFNE	MIDI
midiresd	dc.b	$e0,$00,$40,$b0,$01,$00

midicontrnum	ds.b	16

prevmidicpres	dc.l	0,0,0,0 ; 16 bytes

prevmidipbend	dc.w	$2000,$2000,$2000,$2000,$2000,$2000,$2000,$2000
		dc.w	$2000,$2000,$2000,$2000,$2000,$2000,$2000,$2000
	ENDC
; TRACK-data structures (see definitions at the end of this file)
t03d		ds.b	22
		dc.l	$dff0a0
		ds.b	71
		dc.b	$ff
		ds.b	22
		dc.l	$dff0b0
		ds.b	71
		dc.b	$ff
		ds.b	22
		dc.l	$dff0c0
		ds.b	71
		dc.b	$ff
		ds.b	22
		dc.l	$dff0d0
		ds.b	71
		dc.b	$ff
t415d		ds.b	4*T415SZ
t815d		ds.b	8*T415SZ	;8 bytes * 12 tracks = 96 bytes
trackdataptrs	dc.l	t03d,t03d+T03SZ,t03d+2*T03SZ,t03d+3*T03SZ
		dc.l	t415d,t415d+T415SZ,t415d+2*T415SZ,t415d+3*T415SZ
		dc.l	t815d,t815d+T415SZ,t815d+2*T415SZ,t815d+3*T415SZ
		dc.l	t815d+4*T415SZ,t815d+5*T415SZ,t815d+6*T415SZ
		dc.l	t815d+7*T415SZ

nextblock	dc.b	0 ;\ DON'T SEPARATE
nxtnoclrln	dc.b	0 :/
numtracks	dc.w	0 ;\ DON'T SEPARATE
numlines	dc.w	0 ;/
nextblockline	dc.w	0
rptline		dc.w	0 ;\ DON'T SEPARATE
rptcounter	dc.w	0 ;/
blkdelay	dc.w	0	;block delay (PT PatternDelay)
bpmcounter	dc.w	0
bpmdiv		dc.l	3546895/2

holdvals	ds.b 63
decays		ds.b 63
finetunes	ds.b 63

; Below are the period tables. There's one table for each finetune position.
	IFNE	SYNTH
	dc.w	3424,3232,3048,2880,2712,2560,2416,2280,2152,2032,1920,1812
	dc.w	1712,1616,1524,1440,1356,1280,1208,1140,1076,1016,960,906
	ENDC
per0	dc.w	856,808,762,720,678,640,604,570,538,508,480,453
	dc.w	428,404,381,360,339,320,302,285,269,254,240,226
	dc.w	214,202,190,180,170,160,151,143,135,127,120,113
	dc.w	214,202,190,180,170,160,151,143,135,127,120,113
	dc.w	214,202,190,180,170,160,151,143,135,127,120,113
	dc.w	214,202,190,180,170,160,151,143,135,127,120,113
	IFNE	SYNTH
	dc.w	3400,3209,3029,2859,2699,2547,2404,2269,2142,2022,1908,1801
	dc.w	1700,1605,1515,1430,1349,1274,1202,1135,1071,1011,954,901
	ENDC
per1	dc.w	850,802,757,715,674,637,601,567,535,505,477,450
	dc.w	425,401,379,357,337,318,300,284,268,253,239,225
	dc.w	213,201,189,179,169,159,150,142,134,126,119,113
	dc.w	213,201,189,179,169,159,150,142,134,126,119,113
	dc.w	213,201,189,179,169,159,150,142,134,126,119,113
	dc.w	213,201,189,179,169,159,150,142,134,126,119,113
	IFNE	SYNTH
	dc.w	3376,3187,3008,2839,2680,2529,2387,2253,2127,2007,1895,1788
	dc.w	1688,1593,1504,1419,1340,1265,1194,1127,1063,1004,947,894
	ENDC
per2	dc.w	844,796,752,709,670,632,597,563,532,502,474,447
	dc.w	422,398,376,355,335,316,298,282,266,251,237,224
	dc.w	211,199,188,177,167,158,149,141,133,125,118,112
	dc.w	211,199,188,177,167,158,149,141,133,125,118,112
	dc.w	211,199,188,177,167,158,149,141,133,125,118,112
	dc.w	211,199,188,177,167,158,149,141,133,125,118,112
	IFNE	SYNTH
	dc.w	3352,3164,2986,2819,2660,2511,2370,2237,2112,1993,1881,1776
	dc.w	1676,1582,1493,1409,1330,1256,1185,1119,1056,997,941,888
	ENDC
per3	dc.w	838,791,746,704,665,628,592,559,528,498,470,444
	dc.w	419,395,373,352,332,314,296,280,264,249,235,222
	dc.w	209,198,187,176,166,157,148,140,132,125,118,111
	dc.w	209,198,187,176,166,157,148,140,132,125,118,111
	dc.w	209,198,187,176,166,157,148,140,132,125,118,111
	dc.w	209,198,187,176,166,157,148,140,132,125,118,111
	IFNE	SYNTH
	dc.w	3328,3141,2965,2799,2641,2493,2353,2221,2097,1979,1868,1763
	dc.w	1664,1571,1482,1399,1321,1247,1177,1111,1048,989,934,881
	ENDC
per4	dc.w	832,785,741,699,660,623,588,555,524,495,467,441
	dc.w	416,392,370,350,330,312,294,278,262,247,233,220
	dc.w	208,196,185,175,165,156,147,139,131,124,117,110
	dc.w	208,196,185,175,165,156,147,139,131,124,117,110
	dc.w	208,196,185,175,165,156,147,139,131,124,117,110
	dc.w	208,196,185,175,165,156,147,139,131,124,117,110
	IFNE	SYNTH
	dc.w	3304,3119,2944,2778,2622,2475,2336,2205,2081,1965,1854,1750
		dc.w	1652,1559,1472,1389,1311,1238,1168,1103,1041,982,927,875
	ENDC
per5	dc.w	826,779,736,694,655,619,584,551,520,491,463,437
	dc.w	413,390,368,347,328,309,292,276,260,245,232,219
	dc.w	206,195,184,174,164,155,146,138,130,123,116,109
	dc.w	206,195,184,174,164,155,146,138,130,123,116,109
	dc.w	206,195,184,174,164,155,146,138,130,123,116,109
	dc.w	206,195,184,174,164,155,146,138,130,123,116,109
	IFNE	SYNTH
	dc.w	3280,3096,2922,2758,2603,2457,2319,2189,2066,1950,1841,1738
	dc.w	1640,1548,1461,1379,1302,1229,1160,1095,1033,975,920,869
	ENDC
per6	dc.w	820,774,730,689,651,614,580,547,516,487,460,434
	dc.w	410,387,365,345,325,307,290,274,258,244,230,217
	dc.w	205,193,183,172,163,154,145,137,129,122,115,109
	dc.w	205,193,183,172,163,154,145,137,129,122,115,109
	dc.w	205,193,183,172,163,154,145,137,129,122,115,109
	dc.w	205,193,183,172,163,154,145,137,129,122,115,109
	IFNE	SYNTH
	dc.w	3256,3073,2901,2738,2584,2439,2302,2173,2051,1936,1827,1725
	dc.w	1628,1537,1450,1369,1292,1220,1151,1087,1026,968,914,862
	ENDC
per7	dc.w	814,768,725,684,646,610,575,543,513,484,457,431
	dc.w	407,384,363,342,323,305,288,272,256,242,228,216
	dc.w	204,192,181,171,161,152,144,136,128,121,114,108
	dc.w	204,192,181,171,161,152,144,136,128,121,114,108
	dc.w	204,192,181,171,161,152,144,136,128,121,114,108
	dc.w	204,192,181,171,161,152,144,136,128,121,114,108
	IFNE	SYNTH
	dc.w	3628,3424,3232,3051,2880,2718,2565,2421,2285,2157,2036,1922
	dc.w	1814,1712,1616,1525,1440,1359,1283,1211,1143,1079,1018,961
	ENDC
per_8	dc.w	907,856,808,762,720,678,640,604,570,538,508,480
	dc.w	453,428,404,381,360,339,320,302,285,269,254,240
	dc.w	226,214,202,190,180,170,160,151,143,135,127,120
	dc.w	226,214,202,190,180,170,160,151,143,135,127,120
	dc.w	226,214,202,190,180,170,160,151,143,135,127,120
	dc.w	226,214,202,190,180,170,160,151,143,135,127,120
	IFNE	SYNTH
	dc.w	3588,3387,3197,3017,2848,2688,2537,2395,2260,2133,2014,1901
	dc.w	1794,1693,1598,1509,1424,1344,1269,1197,1130,1067,1007,950
	ENDC
per_7	dc.w	900,850,802,757,715,675,636,601,567,535,505,477
	dc.w	450,425,401,379,357,337,318,300,284,268,253,238
	dc.w	225,212,200,189,179,169,159,150,142,134,126,119
	dc.w	225,212,200,189,179,169,159,150,142,134,126,119
	dc.w	225,212,200,189,179,169,159,150,142,134,126,119
		dc.w	225,212,200,189,179,169,159,150,142,134,126,119
	IFNE	SYNTH
	dc.w	3576,3375,3186,3007,2838,2679,2529,2387,2253,2126,2007,1894
	dc.w	1788,1688,1593,1504,1419,1339,1264,1193,1126,1063,1003,947
	ENDC
per_6	dc.w	894,844,796,752,709,670,632,597,563,532,502,474
	dc.w	447,422,398,376,355,335,316,298,282,266,251,237
	dc.w	223,211,199,188,177,167,158,149,141,133,125,118
	dc.w	223,211,199,188,177,167,158,149,141,133,125,118
	dc.w	223,211,199,188,177,167,158,149,141,133,125,118
	dc.w	223,211,199,188,177,167,158,149,141,133,125,118
	IFNE	SYNTH
	dc.w	3548,3349,3161,2984,2816,2658,2509,2368,2235,2110,1991,1879
	dc.w	1774,1674,1580,1492,1408,1329,1254,1184,1118,1055,996,940
	ENDC
per_5	dc.w	887,838,791,746,704,665,628,592,559,528,498,470
	dc.w	444,419,395,373,352,332,314,296,280,264,249,235
	dc.w	222,209,198,187,176,166,157,148,140,132,125,118
	dc.w	222,209,198,187,176,166,157,148,140,132,125,118
	dc.w	222,209,198,187,176,166,157,148,140,132,125,118
	dc.w	222,209,198,187,176,166,157,148,140,132,125,118
	IFNE	SYNTH
	dc.w	3524,3326,3140,2963,2797,2640,2492,2352,2220,2095,1978,1867
	dc.w	1762,1663,1570,1482,1399,1320,1246,1176,1110,1048,989,933
	ENDC
per_4	dc.w	881,832,785,741,699,660,623,588,555,524,494,467
	dc.w	441,416,392,370,350,330,312,294,278,262,247,233
	dc.w	220,208,196,185,175,165,156,147,139,131,123,117
	dc.w	220,208,196,185,175,165,156,147,139,131,123,117
	dc.w	220,208,196,185,175,165,156,147,139,131,123,117
	dc.w	220,208,196,185,175,165,156,147,139,131,123,117
	IFNE	SYNTH
	dc.w	3500,3304,3118,2943,2778,2622,2475,2336,2205,2081,1964,1854
	dc.w	1750,1652,1559,1472,1389,1311,1237,1168,1102,1041,982,927
	ENDC
per_3	dc.w	875,826,779,736,694,655,619,584,551,520,491,463
	dc.w	437,413,390,368,347,328,309,292,276,260,245,232
	dc.w	219,206,195,184,174,164,155,146,138,130,123,116
	dc.w	219,206,195,184,174,164,155,146,138,130,123,116
	dc.w	219,206,195,184,174,164,155,146,138,130,123,116
	dc.w	219,206,195,184,174,164,155,146,138,130,123,116
	IFNE	SYNTH
	dc.w	3472,3277,3093,2920,2756,2601,2455,2317,2187,2064,1949,1839
	dc.w	1736,1639,1547,1460,1378,1301,1228,1159,1094,1032,974,920
	ENDC
per_2	dc.w	868,820,774,730,689,651,614,580,547,516,487,460
	dc.w	434,410,387,365,345,325,307,290,274,258,244,230
	dc.w	217,205,193,183,172,163,154,145,137,129,122,115
	dc.w	217,205,193,183,172,163,154,145,137,129,122,115
	dc.w	217,205,193,183,172,163,154,145,137,129,122,115
	dc.w	217,205,193,183,172,163,154,145,137,129,122,115
	IFNE	SYNTH
	dc.w	3448,3254,3072,2899,2737,2583,2438,2301,2172,2050,1935,1827
	dc.w	1724,1627,1536,1450,1368,1292,1219,1151,1086,1025,968,913
	ENDC
per_1	dc.w	862,814,768,725,684,646,610,575,543,513,484,457
	dc.w	431,407,384,363,342,323,305,288,272,256,242,228
	dc.w	216,203,192,181,171,161,152,144,136,128,121,114
	dc.w	216,203,192,181,171,161,152,144,136,128,121,114
	dc.w	216,203,192,181,171,161,152,144,136,128,121,114
	dc.w	216,203,192,181,171,161,152,144,136,128,121,114

_periodtable
	dc.l	per_8,per_7,per_6,per_5,per_4,per_3,per_2,per_1,per0
	dc.l	per1,per2,per3,per4,per5,per6,per7

	IFND	__G2
		section "datachip",data,chip ;for A68k
	ENDC
	IFD	__G2
		section "datachip",data_c ;this is for Devpac 2
	ENDC
		XDEF	_modnum
	IFNE	EASY
easymod		INCBIN	"module"	;<<<<< MODULE NAME HERE!
	ENDC
_chipzero	dc.l	0
_modnum		dc.w	0	;number of module to play

; the track-data structure definition:
trk_prevnote	EQU	0	;previous note number
trk_previnstr	EQU	1	;previous instrument number
trk_prevvol	EQU	2	;previous volume
trk_prevmidich	EQU	3	;previous MIDI channel
trk_cmd		EQU	4	;command (the 3rd number from right)
trk_cmdqual	EQU	5	;command qualifier (infobyte, databyte..)
trk_prevmidin	EQU	6	;previous MIDI note
trk_noteoffcnt	EQU	7	;note-off counter (hold)
trk_inithold	EQU	8	;default hold for this instrument
trk_initdecay	EQU	9	;default decay for....
trk_stransp	EQU	10	;instrument transpose
trk_finetune	EQU	11	;finetune
trk_soffset	EQU	12	;new sample offset
trk_previnstra	EQU	14	;address of the previous instrument data
trk_trackvol	EQU	18
;	the following data only on tracks 0 - 3
trk_prevper	EQU	20	;previous period
trk_audioaddr	EQU	22	;hardware audio channel base address
trk_sampleptr	EQU	26	;pointer to sample
trk_samplelen	EQU	30	;length (>> 1)
trk_porttrgper	EQU	32	;portamento (cmd 3) target period
trk_vibshift	EQU	34	;vibrato shift for ASR instruction
trk_vibrspd	EQU	35	;vibrato speed/size (cmd 4 qualifier)
trk_vibrsz	EQU	36	;vibrato size
trk_synthptr	EQU	38	;pointer to synthetic/hybrid instrument
trk_arpgoffs	EQU	42	;SYNTH: current arpeggio offset
trk_arpsoffs	EQU	44	;SYNTH: arpeggio restart offset
trk_volxcnt	EQU	46	;SYNTH: volume execute counter
trk_wfxcnt	EQU	47	;SYNTH: waveform execute counter
trk_volcmd	EQU	48	;SYNTH: volume command pointer
trk_wfcmd	EQU	50	;SYNTH: waveform command pointer
trk_volwait	EQU	52	;SYNTH: counter for WAI (volume list)
trk_wfwait	EQU	53	;SYNTH: counter for WAI (waveform list)
trk_synthvibspd	EQU	54	;SYNTH: vibrato speed
trk_wfchgspd	EQU	56	;SYNTH: period change
trk_perchg	EQU	58	;SYNTH: curr. period change from trk_prevper
trk_envptr	EQU	60	;SYNTH: envelope waveform pointer
trk_synvibdep	EQU	64	;SYNTH: vibrato depth
trk_synvibwf    EQU	66       ;SYNTH: vibrato waveform
trk_synviboffs	EQU	70	;SYNTH: vibrato pointer
trk_initvolxspd	EQU	72	;SYNTH: volume execute speed
trk_initwfxspd	EQU	73	;SYNTH: waveform execute speed
trk_volchgspd	EQU	74	;SYNTH: volume change
trk_prevnote2	EQU	75	;SYNTH: previous note
trk_synvol	EQU	76	;SYNTH: current volume
trk_synthtype	EQU	77	;>0 = synth, -1 = hybrid, 0 = no synth
trk_periodtbl	EQU	78	;pointer to period table
trk_prevportspd	EQU	82	;portamento (cmd 3) speed
trk_decay	EQU	84	;decay
trk_fadespd	EQU	85	;decay speed
trk_envrestart	EQU	86	;SYNTH: envelope waveform restart point
trk_envcount	EQU	90	;SYNTH: envelope counter
trk_split	EQU	91	;0 = this channel not splitted (OctaMED V2)
trk_vibroffs	EQU	92	;vibrato table offset \ DON'T SEPARATE
trk_tremoffs	EQU	93	;tremolo table offset /
trk_tremsz	EQU	94	;tremolo size
trk_tremspd	EQU	96	;tremolo speed
trk_tempvol	EQU	97	;temporary volume (for tremolo)

* -------------------------------------------------------------------------
* -                             VARIABLES                                 -
* -------------------------------------------------------------------------					
				
* Pointers

		SECTION	"Unit_Data",BSS
		
_GfxBase	ds.l	1
_IntuitionBase	ds.l	1
_SysBase	ds.l	1
_DosBase	ds.l	1
_PPBase		ds.l	1
_stdout		ds.l	1
screen_p	ds.l	1
window_p	ds.l	1
gadget_p	ds.l	1
file_p		ds.l	1
music_p		ds.l	1
size		ds.l	1
playing		ds.w	1
readme_on	ds.l	1
error_flag	ds.l	1

		SECTION	"Init_Data",DATA

intuition_name	dc.b	'intuition.library',0
graphics_name	dc.b	'graphics.library',0
dos_name	dc.b	'dos.library',0		
powerpacker_name	dc.b	'powerpacker.library',0
console_name	dc.b	'CON:30/100/560/50/Serendipity © 1994 Perception',0
returnMsg	dc.l	0
fromwb		dc.l	0

* Error table

error_table	dc.l	error0,error1,error2,error3,error4,error5,error6,error7,error8,error9,error10,error11
length_table	dc.l	error0_len,error1_len,error2_len,error3_len,error4_len,error5_len,error6_len,error7_len,error8_len,error9_len,error10_len,error11_len

error0		dc.b	'No Errors',LF,0
error0_len	EQU	*-error0

error1		dc.b	'Could not open Intuition library.',LF,0
error1_len	EQU	*-error1

error2		dc.b	'Could not open Graphics library.',LF,0
error2_len	EQU	*-error2

error3		dc.b	'Could not open Powerpacker library.',LF,0
error3_len	EQU	*-error3

error4		dc.b	'Could not open music resources.',LF,0
error4_len	EQU	*-error4

error5		dc.b	'Could not open music module.',LF,0
error5_len	EQU	*-error5
		
error6		dc.b	'Error while reading music module.',LF,0
error6_len	EQU	*-error6

error7		dc.b	'Insufficient memory to load music module.',LF,0
error7_len	EQU	*-error7

error8		dc.b	'Music module has been encrypted. Unable to load.',LF,0
error8_len	EQU	*-error8

error9		dc.b	'Music module crunched with an unsupported version of Powerpacker.',LF,0
error9_len	EQU	*-error9

error10		dc.b	'Music module is an empty file. Unable to load.',LF,0
error10_len	EQU	*-error10		

error11		dc.b	'Serendipity requires at least 600k of free Chip memory to run.',LF,0
error11_len	EQU	*-error11

* Music filename table

music_table	dc.l	module0,module1,module2,module3,module4,module5,module6

module0		dc.b	'Impossible_Error',0	; << can NOT be selected!
module1		dc.b	'progdir:mod.oppertune.pp',0
module2		dc.b	'progdir:mod.rellowmush.pp',0
module3		dc.b	'progdir:mod.septic child.pp',0
module4		dc.b	'progdir:mod.spacetrip3.pp',0
module5		dc.b	'progdir:mod.tangled in reins.pp',0
module6		dc.b	'progdir:mod.technic dreams.pp',0
		EVEN		

* Screen definition

screen		dc.w	0,0
		dc.w	320,256
		dc.w	5
		dc.b	0,0
		dc.w	NULL
		dc.w	CUSTOMSCREEN+SCREENQUIET
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		
* Window definition

window		dc.w	0,0
		dc.w	320,256
		dc.b	0,0
		dc.l	GADGETUP+MOUSEBUTTONS
		dc.l	SMART_REFRESH+ACTIVATE+BORDERLESS+RMBTRAP
		dc.l	Gadget1
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.w	0,0
		dc.w	0,0
		dc.w	CUSTOMSCREEN
		EVEN

* Screen colours for SERENDIPITY.BM (32)

seren_col	dc.w	$000,$000,$000,$000,$000,$000,$000,$000
		dc.w	$000,$000,$000,$000,$000,$000,$000,$000
		dc.w	$000,$000,$000,$000,$000,$000,$000,$000
		dc.w	$000,$000,$000,$000,$000,$000,$000,$000
seren_col_SIZEOF	EQU	*-seren_col

normal_colours	dc.w	$303,$EFF,$CEE,$ADD,$9CC,$7BB,$6AA,$599
		dc.w	$488,$387,$227,$226,$155,$144,$033,$000
		dc.w	$001,$EEB,$EB7,$DC4,$CA3,$B83,$A62,$952
		dc.w	$831,$721,$610,$500,$400,$300,$EEE,$FFF

black_colours	dc.w	$000,$000,$000,$000,$000,$000,$000,$000
		dc.w	$000,$000,$000,$000,$000,$000,$000,$000
		dc.w	$000,$000,$000,$000,$000,$000,$000,$000
		dc.w	$000,$000,$000,$000,$000,$000,$000,$000

readme_colours	dc.w	$203,$fff,$bdd,$8ab,$689,$468,$256,$134
		dc.w	$000,$952,$b83,$fca,$fe0,$ccc,$888,$444
		dc.w	$eeb,$eb7,$dc4,$ca3,$b83,$a62,$952,$831
		dc.w	$721,$610,$500,$400,$300,$eee,$ddd,$ccc

* Gadget Definitions

Gadget1		dc.l	Gadget2
		dc.w	46,84
		dc.w	154-46,124-84
		dc.w	GADGHNONE
		dc.w	RELVERIFY
		dc.w	BOOLGADGET
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.w	1
		dc.l	NULL		

Gadget2		dc.l	Gadget3
		dc.w	46,127
		dc.w	154-46,167-127
		dc.w	GADGHNONE
		dc.w	RELVERIFY
		dc.w	BOOLGADGET
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.w	2
		dc.l	NULL

Gadget3		dc.l	Gadget4
		dc.w	46,171
		dc.w	154-46,207-171
		dc.w	GADGHNONE
		dc.w	RELVERIFY
		dc.w	BOOLGADGET
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.w	3
		dc.l	NULL

Gadget4		dc.l	Gadget5
		dc.w	164,84
		dc.w	272-164,124-84
		dc.w	GADGHNONE
		dc.w	RELVERIFY
		dc.w	BOOLGADGET
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.w	4
		dc.l	NULL

Gadget5		dc.l	Gadget6
		dc.w	164,127
		dc.w	272-164,167-127
		dc.w	GADGHNONE
		dc.w	RELVERIFY
		dc.w	BOOLGADGET
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.w	5
		dc.l	NULL

Gadget6		dc.l	Gadget7
		dc.w	164,171
		dc.w	272-164,207-171
		dc.w	GADGHNONE
		dc.w	RELVERIFY
		dc.w	BOOLGADGET
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.w	6
		dc.l	NULL

Gadget7		dc.l	Gadget8		; This is the README gadget
		dc.w	111,213
		dc.w	207-111,253-213
		dc.w	GADGHNONE
		dc.w	RELVERIFY
		dc.w	BOOLGADGET
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.w	7
		dc.l	NULL

Gadget8		dc.l	NULL		; This is the close gadget.
		dc.w	0,0
		dc.w	1,1
		dc.w	GADGHNONE
		dc.w	RELVERIFY
		dc.w	BOOLGADGET
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.l	NULL
		dc.w	8
		dc.l	NULL

image1		dc.w	0,0
		dc.w	320,256
		dc.w	5
		dc.l	ImageData1
		dc.b	31,$0000
		dc.l	NULL
		
image2		dc.w	0,0
		dc.w	320,256
		dc.w	5
		dc.l	ImageData2
		dc.b	31,$0000
		dc.l	NULL

		SECTION	IMAGE,DATA_C
		
ImageData1	incbin	"bitmaps/serendipity.bm"
		EVEN		

ImageData2	incbin	"bitmaps/readme.bm"
		EVEN

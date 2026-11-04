IntroDone:	.dc	0
NextMode:	.dc	0

StartIntro:
	PUSH	$ra

	_JAL	PlayBeat

	_LI	$t0,MenuVal
	sw	$zero,0($t0)
	sw	$zero,1($t0)
	sw	$zero,2($t0)
	sw	$zero,3($t0)


	_STA	$zero,IntroDone

	_JAL	ClearScreen
	_JAL	Drawbackground
	_JAL	WaitNextFrame
	_JAL	ClearScreen
	_JAL	DrawBackground
	_JAL	WaitNextFrame

	_JAL	InitScroll
	_JAL	StartMorph

	_LI	$t0,JoyRepeatWait
	_LI	$t1,0x000601			; Filter = 00, RepeatVal = 06, Accelerate = 1 (0a, 2 at 50 Hz)
	nop
	nop
	sw	$t1,JOY_UP($t0)
	sw	$t1,JOY_LEFT($t0)
	sw	$t1,JOY_RIGHT($t0)
	sw	$t1,JOY_DOWN($t0)
	sw	$t1,JOY_BUTA($t0)
	sw	$t1,JOY_BUTB($t0)
	sw	$t1,JOY_BUTC($t0)
	sw	$t1,JOY_START($t0)

StartIntro_Loop:
	_JAL	IntroFrame
	_BEQZ	$v0,StartIntro_Loop

	_LDA	$t0,NextMode
	movi	$t1,VIEWHIGHSCOREMODE
	_BEQ	$t0,$t1,DontStopBeat
	_JAL	StopBeat
DontStopBeat:
	_JAL	IntroFadeOut
	_JAL	ScreenFadeOut
	POP	$ra
	_RTS

IntroFrame:
	PUSH	$ra
	_JAL	WaitNextFrame
	_JAL	FadeBeat
	_JAL	MenuJoyStick

	_JAL	ClearIntroScreen

	_JAL	DrawMenu
	movi	$a0,FADE_UP		; Dont fade out MorphFrame
	_JAL	MorphFrame
	movi	$a0,FADE_UP		; Dont fade out MorphFrame
	_JAL	Scroll

	_LDA	$v0,IntroDone
	POP	$ra
	_RTS

IntroFadeOut:
	PUSH	$ra
	PUSH	$s0
IntroFadeOut_Loop:
	clr	$s0
	_JAL	WaitNextFrame
	_JAL	FadeBeat
	_JAL	ClearIntroScreen
	_JAL	DrawMenu
	movi	$a0,FADE_DOWN		; Fade out MorphFrame
	_JAL	MorphFrame
	or	$s0,$s0,$v1		; 0 in v1 if Morpframe fade out done
	movi	$a0,FADE_DOWN		; Fade out Scroll
	_JAL	Scroll
	or	$s0,$s0,$v1		; 0 in v1 if Scroll fade out is done
	_BNEZ	$s0,IntroFadeOut_Loop
	POP	$s0
	POP	$ra
	_RTS

BLUEBLOCKHEIGHT = 30
BLUEBLOCKCOLOR = 0x0004
REDLINECOLOR = 0xf800

DrawBackground:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2

	moviu	$a0,BLUEBLOCKCOLOR
	_JAL	SetColor

	movi	$a0,0
	movi	$a1,0
	movi	$a2,320
	movi	$a3,BLUEBLOCKHEIGHT
	_JAL	FilledRect

	movi	$a0,0
	movi	$a1,255-BLUEBLOCKHEIGHT+1
	movi	$a2,320
	movi	$a3,BLUEBLOCKHEIGHT
	_JAL	FilledRect

	moviu	$a0,REDLINECOLOR
	_JAL	SetColor

	movi	$a0,0
	movi	$a1,BLUEBLOCKHEIGHT
	movi	$a2,319
	movi	$a3,BLUEBLOCKHEIGHT
	_JAL	Line

	movi	$a0,0
	movi	$a1,255-BLUEBLOCKHEIGHT
	movi	$a2,319
	movi	$a3,255-BLUEBLOCKHEIGHT
	_JAL	Line

	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

ClearIntroScreen:
	PUSH	$ra

	_JAL	GetWorkScreen
	mov	$t0,$v0

	addi	$t0,$t0,160*60
	movi	$t1,140
ClearIntroScreen_Loop:
	movi	$t2,5
ClearIntroScreen_Loop2:
	sw	$zero,0($t0)
	sw	$zero,1($t0)
	sw	$zero,2($t0)
	sw	$zero,3($t0)
	sw	$zero,4($t0)
	sw	$zero,5($t0)
	sw	$zero,6($t0)
	sw	$zero,7($t0)
	sw	$zero,8($t0)
	sw	$zero,9($t0)
	sw	$zero,10($t0)
	sw	$zero,11($t0)
	sw	$zero,12($t0)
	sw	$zero,13($t0)
	sw	$zero,14($t0)
	sw	$zero,15($t0)
	addi	$t0,$t0,16
	addi	$t2,$t2,-1
	_BNEZ	$t2,ClearIntroScreen_Loop2
	addi	$t0,$t0,80
	addi	$t1,$t1,-1
	_BNEZ	$t1,ClearIntroScreen_Loop

	POP	$ra
	_RTS

MenuJoystick:
	PUSH	$ra				; Store to stack

	_JAL	CheckJoystick
	mov	$t5,$v0

	_LI	$t1,MenuVal
	_LW	$t2,0($t1)
	_LW	$t3,1($t1)
	clr	$t4

	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noMenuUp			; Check LSB
	addi	$t2,$t2,-1			; Up
noMenuUp:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noMenuButA			; Check LSB
	movi	$t4,1				; ButA
noMenuButA:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noMenuDown			; Check LSB
	addi	$t2,$t2,1			; Down
noMenuDown:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noMenuRight			; Check LSB
	addi	$t3,$t3,1			; Right
noMenuRight:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noMenuButB			; Check LSB
	movi	$t4,1				; ButB
noMenuButB:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noMenuLeft			; Check LSB
	addi	$t3,$t3,-1			; Right
noMenuLeft:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noMenuStart			; Check LSB
	; Start
noMenuStart:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noMenuButC			; Check LSB
	movi	$t4,1				; ButC
noMenuButC:

	_SW	$t2,0($t1)
	_SW	$t3,1($t1)
	_SW	$t4,2($t1)

	POP	$ra
	_RTS				; Return from subroutine

MENU_XPOS = 130
MENU_YPOS = 70

DrawMenu:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4

	_LI	$s3,MenuVal
	_LW	$s4,0($s3)

	slt	$t0,$s4,$zero
	_BEQZ	$t0,Menu_ChoiceNotToLow
	addi	$s4,$s4,1
Menu_ChoiceNotToLow:
	_LI	$s0,Menu
	sll	$t0,$s4,2
	add	$s0,$s0,$t0
	_LW	$t0,0($s0)
	_BNEZ	$t0,Menu_ChoiceNotToHigh
	addi	$s4,$s4,-1
Menu_ChoiceNotToHigh:
	_LDA	$t9,MenuOldRow
	_SW	$s4,0($s3)
	_STA	$s4,MenuOldRow
	_BEQ	$s4,$t9,Menu_SameRow

	_LI	$s0,Menu
	sll	$t0,$s4,2
	add	$s0,$s0,$t0

	_LW	$t0,2($s0)
	_SW	$t0,1($s3)
	_STA	$t0,MenuOldVal

	movi	$a0,FX_MENU_CHANGEROW
	_JAL	PlaySampleCh1
	_J	DrawMenu_Draw

Menu_SameRow:
	_LW	$t1,1($s3)
	slt	$t0,$t1,$zero
	_BEQZ	$t0,Menu_ValNotToLow
	addi	$t1,$t1,1
Menu_ValNotToLow:
	_LW	$t2,3($s0)
	slt	$t0,$t2,$t1
	_BEQZ	$t0,Menu_ValNotToHigh
	addi	$t1,$t1,-1
Menu_ValNotToHigh:
	_SW	$t1,2($s0)
	_SW	$t1,1($s3)
	_LDA	$t0,MenuOldVal
	_STA	$t1,MenuOldVal
	_BEQ	$t0,$t1,DrawMenu_Draw

	_LI	$s0,Menu
	_LW	$a0,MENU_SFX($s0)
	_JAL	EnableFX		; Turn On/Off SFX
	_LW	$a0,MENU_MUSIC($s0)
	_JAL	EnableMusic		; Turn On/Off SFX

	movi	$a0,FX_MENU_CHANGEVALUE
	_JAL	PlaySampleCh1

DrawMenu_Draw:
	_LI	$s0,Menu
	movi	$s2,MENU_YPOS
	sll	$s4,$s4,2
	add	$s4,$s4,$s0
Menu_GetItem:
	_LW	$t0,0($s0)
	_BEQZ	$t0,Menu_Done
	moviu	$a3,0x7bef
	_BNE	$s4,$s0,Menu_NotHighlight
	moviu	$a3,0xffe0
Menu_NotHighlight:
	mov	$a0,$t0
	movi	$a1,MENU_XPOS
	mov	$a2,$s2
	_JAL	PrintString
	_LW	$t0,1($s0)
	_BEQZ	$t0,Menu_NextItem
	_LW	$t1,2($s0)
	add	$a0,$t0,$t1
	addi	$a1,$a1,18*8
	_JAL	PrintString
Menu_NextItem:
	addi	$s0,$s0,4
	addi	$s2,$s2,16
	_J	Menu_GetItem

Menu_Done:
	_LDA	$t0, IntroDone
	_BNEZ	$t0, Menu_NoNewMode

	_LW	$t0,0($s3)
	_LW	$t1,2($s3)
	_BEQZ	$t1,Menu_NoButton

	movi	$t1,PLAYGAMEROW
	movi	$t2,GAMEMODE
	_BEQ	$t0,$t1,Menu_ModeDone
	movi	$t1,HIGHSCOREROW
	movi	$t2,VIEWHIGHSCOREMODE
	_BEQ	$t0,$t1,Menu_ModeDone
	movi	$t2,INTROMODE
Menu_ModeDone:
	_STA	$t2,NextMode
	movi	$t0,INTROMODE
	_BEQ	$t0,$t2,Menu_NoNewMode

	movi	$a0,FX_MENU_BUTTON
	_JAL	PlaySampleCh1

	movi	$t0,1
	_STA	$t0,IntroDone
Menu_NoNewMode:

Menu_NoButton:
	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

GetNextMode:
	_LDA	$v0,NextMode
	_RTS

GetStartLevel:
	_LI	$t1,Menu
	_LW	$v0,MENU_STARTLEVEL($t1)
	_RTS

GetShowNextPiece:
	_LI	$t1,Menu
	_LW	$v0,MENU_SHOWNEXTPIECE($t1)
	_RTS

GameHeight:	.dc	0,4,10,14

GetStartHeight:
	_LI	$t1,Menu
	_LW	$t1,MENU_STARTHEIGHT($t1)
	_LW	$v0,GameHeight($t1)
	_RTS

MenuVal:	.dc	0,0,0
MenuOldRow:	.dc	0
MenuOldVal:	.dc	0

Menu:		.dc	PlayString,0,0,0
		.dc	LevelString,LevelList,5,9
		.dc	HeightString,HeightList,0,3
		.dc	ShowNextString,ShowNextList,1,1
		.dc	MusicString,MusicList,1,1
		.dc	SFXString,SFXList,1,1
		.dc	ShowHighString,0,0,0
		.dc	0,0,0,0
PLAYGAMEROW = 0
HIGHSCOREROW = 6

MENU_STARTLEVEL = 6
MENU_STARTHEIGHT = 10
MENU_SHOWNEXTPIECE = 14
MENU_MUSIC = 18
MENU_SFX = 22

TetrisString:	.ascii	"TetrIC 2002"
PlayString:	.ascii	"Play TetrIC"
LevelString:	.ascii	"Start Level"
LevelList:	.ascii	"0"
		.ascii	"1"
		.ascii	"2"
		.ascii	"3"
		.ascii	"4"
		.ascii	"5"
		.ascii	"6"
		.ascii	"7"
		.ascii	"8"
		.ascii	"9"
HeightString:	.ascii	"Start height"
HeightList:	.ascii	"0 "
		.ascii	"4 "
		.ascii	"10"
		.ascii	"14"
ShowNextString:	.ascii	"Show next piece"
ShowNextList:	.ascii	"Off"
		.ascii	"On "
MusicString:	.ascii	"Music"
MusicList:	.ascii	"Off"
		.ascii	"On "
SFXString:	.ascii	"SFX"
SFXList:	.ascii	"Off"
		.ascii	"On "
ShowHighString:	.ascii	"Show Highscore"

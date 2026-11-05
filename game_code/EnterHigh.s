EnterHighDone:	.dc	0

StartEnterHigh:
	PUSH	$ra
	_JAL	WaitNextFrame

	_JAL	InitStars
	_JAL	PlayBeat

	_JAL	GetScore
	mov	$a0,$v0
	_JAL	OnHighScoreList
	_BEQZ	$v0,StartEnterHigh_Done

	_LI	$t0,JoyRepeatWait
	_LI	$t1,0x000c00			; Filter = 00, RepeatVal = 0c, Accelerate = 0 (0a at 50 Hz)
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

	_LI	$t0,EnterHighName
	movi	$t1,8
EnterHigh_ClearNameLoop:
	sw	$zero,0($t0)
	addi	$t0,$t0,1
	addi	$t1,$t1,-1
	_BNEZ	$t1,EnterHigh_ClearNameLoop
	_STA	$zero,EnterHighName

	_STA	$zero,EnterHighValX
	_STA	$zero,EnterHighValY

	_STA	$zero,EnterHighPos
	_STA	$zero,CircleAngle
	_STA	$zero,EnterHighDone
	moviu	$t0,0x7bef
	_STA	$t0,EnterHighTextTarget
	moviu	$t0,0xffe0
	_STA	$t0,EnterHighNameTarget
	_STA	$t0,EnterHighNameColor
	_STA	$zero,EnterHighTextColor
	_STA	$zero,EnterHighCircleColor
	_JAL	EnterHighFade
	moviu	$t0,0x07e0
	_STA	$t0,EnterHighCircleTarget
StartEnterHigh_Loop:
	_JAL	EnterHighFrame
	_BEQZ	$v0,StartEnterHigh_Loop

	_STA	$zero,EnterHighCircleTarget
	_STA	$zero,EnterHighTextTarget
	_STA	$zero,EnterHighNameTarget
	_JAL	EnterHighFade

	_JAL	CopyNameToString

	_JAL	GetScore
	mov	$a1,$v0
	_JAL	GetLevel
	mov	$a2,$v0
	_LI	$a0,ListName
	_JAL	AddToHighScoreList

StartEnterHigh_Done:
	_J	StartViewHighFromEnterHigh

	POP	$ra
	_RTS

EnterHighFrame:
	PUSH	$ra
	_JAL	Rnd
	_JAL	WaitNextFrame
	_JAL	FadeBeat
	_JAL	EnterHighJoyStick

	_JAL	GetWorkScreen
	mov	$a0,$v0
	_JAL	ClearScreen

	_JAL	Stars
	_JAL	DrawEnterHighText
	_JAL	DrawEnterHighName
	_JAL	DrawSelectionBox

EnterHighFrame_DontDrawSelection:
	_LDA	$v0,EnterHighDone
	POP	$ra
	_RTS

EnterHighFade:
	PUSH	$ra
	PUSH	$s0
EnterHighFade_Loop:
	_JAL	WaitNextFrame
	_JAL	FadeBeat
	_JAL	GetWorkScreen
	mov	$a0,$v0
	_JAL	ClearScreen
	_JAL	Stars
	_JAL	DrawEnterHighText
	mov	$s0,$v0
	_JAL	DrawEnterHighName
	or	$s0,$s0,$v0
	_JAL	DrawSelectionBox
	or	$s0,$s0,$v0
	_BNEZ	$s0,EnterHighFade_Loop

	POP	$s0
	POP	$ra
	_RTS

EnterHighTextColor:	.dc	0
EnterHighTextTarget:	.dc	0

NOF_LETTERS = 8

ENTERHIGH_LEFT = 84
ENTERHIGH_TOP = 50
;ENTERHIGH_ROWSPACE = 20
ENTERHIGH_LETTERSPACEX = 16
ENTERHIGH_LETTERSPACEY = 20

DrawEnterHighText:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4
	PUSH	$s5

	_LDA	$t0,EnterHighTextColor
	nop			; hazard
	_BEQZ	$t0,DrawEnterHighText_BlackText

	lui	$s5,0xffff

	movi	$s0,ENTERHIGH_LEFT
	movi	$s1,ENTERHIGH_TOP
	_LI	$s2,EnterHighLetters
	movi	$s3,46
	movi	$s4,10
DrawEnterHighText_Loop:
	_LW	$a0,0($s2)
	addi	$s2,$s2,1
	mov	$a1,$s0
	mov	$a2,$s1
	_LDA	$a3,EnterHighTextColor
	nop			; hazard
	or	$a3,$a3,$s5
	_JAL	PrintASCII
	addi	$s0,$s0,ENTERHIGH_LETTERSPACEX
	addi	$s4,$s4,-1
	_BNEZ	$s4,DrawEnterHighText_NoChangeLine
	movi	$s4,10
	addi	$s0,$s0,-ENTERHIGH_LETTERSPACEX*10
	addi	$s1,$s1,ENTERHIGH_LETTERSPACEY
DrawEnterHighText_NoChangeLine:
	addi	$s3,$s3,-1
	_BNEZ	$s3,DrawEnterHighText_Loop

	_LI	$a0,EnterHighSpecialText
	mov	$a1,$s0
	mov	$a2,$s1
	_LDA	$a3,EnterHighTextColor
	nop			; hazard
	or	$a3,$a3,$s5
	_JAL	PrintString

DrawEnterHighText_BlackText:
	_LDA	$a0,EnterHighTextColor
	_LDA	$a1,EnterHighTextTarget
	_JAL	FadeSourceToDest
	mov	$s0,$v0
	mov	$s1,$v1
	_JAL	GetFrameCount
	sll	$v0,$v0,31			; fade every 2nd 50 Hz tick
	_BNEZ	$v0,DrawEnterHighText_DontFade
	_STA	$s0,EnterHighTextColor
DrawEnterHighText_DontFade:
	mov	$v0,$s1
	POP	$s5
	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS


EnterHighNameColor:	.dc	0
EnterHighNameTarget:	.dc	0

ENTERHIGH_NAMELEFT = 160

DrawEnterHighName:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1

	_LDA	$t0,EnterHighNameColor
	nop			; hazard
	_BEQZ	$t0,DrawEnterHighName_BlackText

	clr	$s0
	movi	$s1,160
	_LDA	$t0,EnterHighPos
	nop			; hazard
	addi	$t0,$t0,1
	sll	$t0,$t0,2
	sub	$s1,$s1,$t0
DrawEnterHighName_Loop:
	_LDO	$a0,EnterHighName,$s0
	nop			; hazard
	_BEQZ	$a0,EnterHighName_Done
	mov	$a1,$s1
	sll	$t0,$s0,3
	add	$a1,$a1,$t0
	movi	$a2,ENTERHIGH_TOP+6*ENTERHIGH_LETTERSPACEY
	_LDA	$a3,EnterHighNameColor
	lui	$t0,0xffff
	or	$a3,$a3,$t0
	_JAL	PrintASCII
	addi	$s0,$s0,1
	_J	DrawEnterHighName_Loop

EnterHighName_Done:
DrawEnterHighName_BlackText:
	_LDA	$a0,EnterHighNameColor
	_LDA	$a1,EnterHighNameTarget
	_JAL	FadeSourceToDest
	mov	$s0,$v0
	mov	$s1,$v1
	_JAL	GetFrameCount
	sll	$v0,$v0,31			; fade every 2nd 50 Hz tick
	_BNEZ	$v0,DrawEnterHighName_DontFade
	_STA	$s0,EnterHighNameColor
DrawEnterHighName_DontFade:
	mov	$v0,$s1
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS


NOF_DOTS = 64
CIRCLE_STEP = -0x9000/NOF_DOTS
CIRCLE_SPEED = 0x355		; 0x400 at 50 Hz

CIRCLE_COLOR = 0x07e0
CIRCLE_COLOR_STEP = 0x0020

EnterHighCircleColor:	.dc	0
EnterHighCircleTarget:	.dc	0
CircleAngle:	.dc	0

DrawSelectionBox:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4
	PUSH	$s5
	PUSH	$s6
	PUSH	$s7

	movi	$s0,ENTERHIGH_LEFT+4
	movi	$s1,ENTERHIGH_TOP+8

	_LDA	$t0,EnterHighValX
	nop			; hazard
	sll	$t1,$t0,4
	add	$s0,$s0,$t1

	_LDA	$t2,EnterHighValY
	nop			; hazard
	sll	$t3,$t2,2
	add	$s1,$s1,$t3
	sll	$t3,$t3,2
	add	$s1,$s1,$t3

	clr	$s4
	movi	$t1,4
	_BNE	$t1,$t2,DrawSelectionBox_NotWide
	slti	$t1,$t0,6
	_BNEZ	$t1,DrawSelectionBox_NotWide
	addi	$s0,$s0,8
	movi	$s4,0xffff
DrawSelectionBox_NotWide:
	_LDA	$s5,EnterHighCircleColor
	_LDA	$s2,CircleAngle
	movi	$s3,NOF_DOTS
DrawSelectionBox_Loop:
	mov	$a0,$s2
	_JAL	Cos
	sra	$v0,$v0,1
	and	$t1,$v0,$s4
	add	$v0,$v0,$t1
	sra	$t0,$v0,12
	add	$s6,$s0,$t0

	mov	$a0,$s2
	_JAL	Sin
	sra	$t0,$v0,13
	add	$s7,$s1,$t0

	mov	$a0,$s5
	_JAL	SetColor

	mov	$a0,$s6
	mov	$a1,$s7
	_JAL	Point


	addi	$s2,$s2,CIRCLE_STEP
	addi	$s3,$s3,-1

	addi	$s5,$s5,-CIRCLE_COLOR_STEP
	slt	$t0,$s5,$zero
	_BNEZ	$t0,DrawSelectionBox_Done
	_LI	$t0,0x07e0
	and	$s5,$s5,$t0
	_BNEZ	$s3,DrawSelectionBox_Loop

DrawSelectionBox_Done:
	_LI	$t0,CircleAngle
	_LW	$t1,0($t0)
	nop			; hazard
	addi	$t1,$t1,CIRCLE_SPEED
	nop			; hazard
	nop			; hazard
	_SW	$t1,0($t0)

	_LDA	$a0,EnterHighCircleColor
	_LDA	$a1,EnterHighCircleTarget
	_JAL	FadeSourceToDest
	mov	$s0,$v0
	mov	$s1,$v1
	_JAL	GetFrameCount
	sll	$v0,$v0,31			; fade every 2nd 50 Hz tick
	_BNEZ	$v0,DrawSelectionBox_DontFade
	_STA	$s0,EnterHighCircleColor
DrawSelectionBox_DontFade:
	mov	$v0,$s1
	POP	$s7
	POP	$s6
	POP	$s5
	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

EnterHighJoyStick:
	PUSH	$ra				; Store to stack
	PUSH	$s0
	_JAL	CheckJoystick
	mov	$s0,$v0

	movi	$t0,0x2d			; 00101101
	and	$t0,$t0,$s0
	_BEQZ	$t0,EnterHigh_NoMoveSound

	movi	$a0,FX_ENTERHIGH_MOVE
	_JAL	PlaySampleCh1
EnterHigh_NoMoveSound:
	movi	$t0,0xd2			; 11010010
	and	$t0,$t0,$s0
	_BEQZ	$t0,EnterHigh_NoButSound

	movi	$a0,FX_ENTERHIGH_BUTTON
	_JAL	PlaySampleCh1
EnterHigh_NoButSound:

	mov	$t5,$s0
	_LDA	$t2,EnterHighValX
	_LDA	$t3,EnterHighValY
	clr	$t4
	clr	$t6

	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noEnterHighUp		; Check LSB
	addi	$t3,$t3,-1			; Up
noEnterHighUp:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noEnterHighButA		; Check LSB
	movi	$t4,1				; ButA
noEnterHighButA:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noEnterHighDown		; Check LSB
	addi	$t3,$t3,1			; Down
noEnterHighDown:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noEnterHighRight		; Check LSB
	addi	$t2,$t2,1			; Right
	movi	$t6,1
noEnterHighRight:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noEnterHighButB		; Check LSB
	movi	$t4,1				; ButB
noEnterHighButB:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noEnterHighLeft		; Check LSB
	addi	$t2,$t2,-1			; Right
	movi	$t6,-1
noEnterHighLeft:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noEnterHighStart		; Check LSB
	; Start
noEnterHighStart:
	andi	$t0,$t5,1			; LSB to t0
	srl	$t5,$t5,1			; Shift out LSB
	_BEQZ	$t0,noEnterHighButC		; Check LSB
	movi	$t4,1				; ButC
noEnterHighButC:

	slt	$t0,$t2,$zero
	_BEQZ	$t0,noEnterHighLeftEdge
	addi	$t3,$t3,-1
	movi	$t2,9
noEnterHighLeftEdge:
	slti	$t0,$t2,10
	_BNEZ	$t0,noEnterHighRightEdge
	addi	$t3,$t3,1
	movi	$t2,0
noEnterHighRightEdge:
	slt	$t0,$t3,$zero
	_BEQZ	$t0,noEnterHighTopEdge
	movi	$t3,4
noEnterHighTopEdge:
	slti	$t0,$t3,5
	_BNEZ	$t0,noEnterHighDownEdge
	movi	$t3,0
noEnterHighDownEdge:
	sll	$t6,$t6,24
	sll	$t5,$t3,16
	or	$t6,$t6,$t5
	sll	$t5,$t2,8
	or	$t6,$t6,$t5

	_LI	$t5,0xff040900
	_BNE	$t5,$t6,noSpecialBut9to8
	movi	$t2,8
noSpecialBut9to8:
	_LI	$t5,0xff040700
	_BNE	$t5,$t6,noSpecialBut7to6
	movi	$t2,6
noSpecialBut7to6:
	_LI	$t5,0x01040700
	_BNE	$t5,$t6,noSpecialBut7to8
	movi	$t2,8
noSpecialBut7to8:
	_LI	$t5,0x01040900
	_BNE	$t5,$t6,noSpecialBut9to0
	movi	$t2,0
	movi	$t3,0
noSpecialBut9to0:
	_LI	$t5,0x00040900
	_BNE	$t5,$t6,noSpecialButUpDown1
	movi	$t2,8
noSpecialButUpDown1:
	_LI	$t5,0x00040700
	_BNE	$t5,$t6,noSpecialButUpDown2
	movi	$t2,6
noSpecialButUpDown2:
	_STA	$t2,EnterHighValX
	_STA	$t3,EnterHighValY

	_BEQZ	$t4,ButtonEnd
	sll	$t0,$t2,8
	or	$t0,$t0,$t3
	moviu	$t1,0x0604
	_BNE	$t0,$t1,NotDel
Del:
	_LDA	$t5,EnterHighPos
	nop			; hazard
	_BEQZ	$t5,ButtonEnd
	addi	$t5,$t5,-1
	_STA	$t5,EnterHighPos
	_STO	$zero,EnterHighName,$t5
	_J	ButtonEnd
NotDel:
End:
	moviu	$t1,0x0804
	_BNE	$t0,$t1,NotEnd
	_STA	$t4,EnterHighDone
	_J	ButtonEnd
NotEnd:
Letter:
	sll	$t5,$t3,3
	sll	$t6,$t3,1
	add	$t5,$t5,$t6
	add	$t5,$t5,$t2
	_LDO	$t7,EnterHighLetters,$t5
	_LDA	$t5,EnterHighPos
	nop			; hazard
	slti	$t0,$t5,NOF_LETTERS
	addi	$t0,$t0,-1
	add	$t5,$t5,$t0
	_STO	$t7,EnterHighName,$t5
	addi	$t5,$t5,1
	_STA	$t5,EnterHighPos
ButtonEnd:
	POP	$s0
	POP	$ra
	_RTS				; Return from subroutine

CopyNameToString:
	_LI	$t0,EnterHighName
	_LI	$t1,ListName

	movi	$t8,2
CopyNameToString_Loop:
	movi	$t9,4
	clr	$t2
CopyNameToString_WordLoop:
	addi	$t9,$t9,-1
	_LW	$t3,0($t0)
	sll	$t7,$t9,3
	sllv	$t3,$t3,$t7
	or	$t2,$t2,$t3
	addi	$t0,$t0,1
	_BNEZ	$t9,CopyNameToString_WordLoop
	_SW	$t2,0($t1)
	addi	$t1,$t1,1
	addi	$t8,$t8,-1
	_BNEZ	$t8,CopyNameToString_Loop
	_RTS

GetEnterHighName:
	_LI	$v0,ListName
	_RTS

EnterHighLetters:
	.dc	0x41,0x42,0x43,0x44,0x45,0x46,0x47,0x48,0x49,0x4a
	.dc	0x4b,0x4c,0x4d,0x4e,0x4f,0x50,0x51,0x52,0x53,0x54
	.dc	0x55,0x56,0x57,0x58,0x59,0x5a,0x2c,0x2e,0x21,0x3f
	.dc	0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37,0x38,0x39
	.dc	0x2d,0x2f,0x3c,0x3e,0x24,0x25

EnterHighSpecialText:
	.ascii	"Del End"

EnterHighName:	.dc	0,0,0,0,0,0,0,0,0
ListName:	.dc	0,0,0
EnterHighPos:	.dc	0

EnterHighValX:	.dc	0
EnterHighValY:	.dc	0

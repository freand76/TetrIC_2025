StartViewHigh:
	PUSH	$ra
	_JAL	PlayBeat

	_JAL	WaitNextFrame
	_JAL	InitStars

StartViewHighFromEnterHigh:
	_JAL	ColorTitleInit

	_STA	$zero,HighScoreListTextColor
	moviu	$t0,0xffff
	_STA	$t0,HighScoreListTargetColor
StartViewHigh_Loop:
	_JAL	Rnd
	_JAL	ViewHighFrame
	_JAL	CheckButton
	_BEQZ	$v0,StartViewHigh_Loop

	sw	$zero,HighScoreListTargetColor

	movi	$t0,NOF_CHARS
	_LI	$t1,HighScoreTitleTarget
StartViewHigh_ResetColors:
	sw	$zero,0($t1)
	addi	$t1,$t1,1
	addi	$t0,$t0,-1
	_BNEZ	$t0,StartViewHigh_ResetColors

	_JAL	StopStars

	_JAL	ViewHighFrame

	_JAL	WaitNextFrame
	_JAL	FadeBeat
	_JAL	GetWorkScreen
	mov	$a0,$v0
	_JAL	ClearScreen
	_JAL	WaitNextFrame

	POP	$ra
	_RTS

ViewHighFrame:
	PUSH	$ra
	PUSH	$s0
ViewHighFrame_Loop:
	_JAL	WaitNextFrame
	_JAL	FadeBeat
	_JAL	GetWorkScreen
	mov	$a0,$v0
	_JAL	ClearScreen
	_JAL	Stars
	mov	$s0,$v0
	_JAL	ColorTitle
	_JAL	PrintHighScoreList
	or	$s0,$s0,$v0
	_BNEZ	$s0,ViewHighFrame_Loop
	POP	$s0
	POP	$ra
	_RTS

HIGHSCORELIST_TOP = 50
HIGHSCORELIST_NAMELEFT = 70
HIGHSCORELIST_LEVELLEFT = 320-HIGHSCORELIST_NAMELEFT-70
HIGHSCORELIST_SCORERIGHT = 320-HIGHSCORELIST_NAMELEFT

HighScoreListTextColor: .dc	0
HighScoreListTargetColor: .dc	0

PrintHighScoreList:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3

	_LDA	$s2,HighScoreListTextColor
	_BEQZ	$s2,PrintHighScoreList_BlackText

	lui	$s3,0xffff

	movi	$s0,1
	movi	$s1,HIGHSCORELIST_TOP
PrintHighScoreList_Loop:
	mov	$a0,$s0
	_JAL	GetHighName
	mov	$a0,$v0
	movi	$a1,HIGHSCORELIST_NAMELEFT
	mov	$a2,$s1
	mov	$a3,$s2
	or	$a3,$a3,$s3
	_JAL	PrintString

	mov	$a0,$s0
	_JAL	GetHighLevel
	mov	$a0,$v0
	addi	$a0,$a0,0x30
	movi	$a1,HIGHSCORELIST_LEVELLEFT
	mov	$a2,$s1
	mov	$a3,$s2
	or	$a3,$a3,$s3
	_JAL	PrintASCII

	mov	$a0,$s0
	_JAL	GetHighScore
	mov	$a0,$v0
	movi	$a1,HIGHSCORELIST_SCORERIGHT
	mov	$a2,$s1
	mov	$a3,$s2
	or	$a3,$a3,$s3
	_JAL	PrintNumber16

	movi	$t9,0x1f
	and	$t0,$s2,$t9
	slti	$t3,$t0,0x04
	addi	$t3,$t3,-1
	sll	$t3,$t3,2
	add	$t0,$t0,$t3

	movi	$t9,0x07e0
	and	$t1,$s2,$t9
	slti	$t3,$t1,0x80
	addi	$t3,$t3,-1
	sll	$t3,$t3,6
	add	$t1,$t1,$t3

	movi	$t9,0xf800
	and	$t2,$s2,$t9
	slti	$t3,$t2,0x1000
	addi	$t3,$t3,-1
	sll	$t3,$t3,11
	add	$t2,$t2,$t3

	or	$s2,$t0,$t1
	or	$s2,$s2,$t2

	addi	$s1,$s1,16
	addi	$s0,$s0,1
	slti	$t0,$s0,11
	_BNEZ	$t0,PrintHighScoreList_Loop

PrintHighScoreList_BlackText:
	_LDA	$a0,HighScoreListTextColor
	_LDA	$a1,HighScoreListTargetColor
	_JAL	FadeSourceToDest
	mov	$s0,$v0
	mov	$s1,$v1
	_JAL	GetFrameCount
	clr	$v0				; fade every frame (every 2nd at 50 Hz)
	_BNEZ	$v0,PrintHighScoreList_DontFade
	_STA	$s0,HighScoreListTextColor
PrintHighScoreList_DontFade:
	mov	$v0,$s1

	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS


HIGHSCORETITLE_TOP = 20
HIGHSCORETITLE_LEFT = 160-76

NOF_CHARS = 16

HighScoreTitle:	.ascii	"TetrIC Hall of Fame"
HighScoreTitleColor:	.pad	NOF_CHARS,0
HighScoreTitleTarget:	.pad	NOF_CHARS,0

ColorTitleInit:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2

	movi	$s0, NOF_CHARS
	_LI	$s1, HighScoreTitleColor
	_LI	$s2, HighScoreTitleTarget

ColorTitleInit_Loop:
	_JAL	Rnd
	movi	$t0,0x3f
	and	$t0,$t0,$v0
	sll	$t0,$t0,5
	moviu	$t1,0xf800
	or	$t0,$t0,$t1
	_SW	$t0,0($s2)
	_SW	$zero,0($s1)
	addi	$s1,$s1,1
	addi	$s2,$s2,1

	addi	$s0,$s0,-1
	_BNEZ	$s0,ColorTitleInit_Loop

	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

ColorTitle:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4
	PUSH	$s6
	PUSH	$s7

	lui	$s7,0xffff

	; Update color
	_JAL	GetFrameCount
	movi	$t0,0x0f
	and	$t0,$t0,$v0
	_LI	$s1,HighScoreTitleTarget
	add	$s1,$s1,$t0
	_LW	$t1,0($s1)
	_BEQZ	$t1,ColorTitle_NoNewColor
	_JAL	Rnd
	movi	$t0,0x3f
	and	$t0,$t0,$v0
	sll	$t0,$t0,5
	movi	$t1,0xf800
	or	$t0,$t0,$t1
	_SW	$t0,0($s1)

ColorTitle_NoNewColor:
	; Print Text
	_LI	$s1,HighScoreTitleColor
	_LI	$s2,HighScoreTitleTarget
	_LI	$s3,HighScoreTitle

	movi	$s6,HIGHSCORETITLE_LEFT
ColorTitle_Loop:
	_LW	$s0,0($s3)
	; GetWord
	movi	$s4,4
ColorTitle_WordLoop:
	addi	$s4,$s4,-1

	sll	$t0,$s4,3
	srlv	$a0,$s0,$t0
	movi	$t1,0xff
	and	$a0,$a0,$t1

	movi	$t0,0x20
	_BEQ	$t0,$a0,ColorTitle_SkipChar
	_BEQZ	$a0,ColorTitle_Done

	mov	$a1,$s6
	movi	$a2,HIGHSCORETITLE_TOP
	_LW	$a3,0($s1)
	or	$a3,$a3,$s7
	_JAL	PrintASCII

	_LW	$a0,0($s1)
	_LW	$a1,0($s2)
	_JAL	FadeSourceToDest
	_SW	$v0,0($s1)

	addi	$s1,$s1,1
	addi	$s2,$s2,1
ColorTitle_SkipChar:
	addi	$s6,$s6,8
	_BNEZ	$s4,ColorTitle_WordLoop
	addi	$s3,$s3,1
	_J	ColorTitle_Loop

ColorTitle_Done:
	POP	$s7
	POP	$s6
	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

INTROMODE = 0
GAMEMODE = 1
ENTERHIGHSCOREMODE = 2
VIEWHIGHSCOREMODE = 3

Mode:		.dc	0

ModeJumpTable:	.dc	ModeSwitchIntro,ModeSwitchGame,ModeSwitchEnterHigh,ModeSwitchViewHighScore


PreMain:
	movi	$t0,INTROMODE
	_STA	$t0,Mode

Main:	_JAL	Randomize
	_LDA	$t0,Mode
	_LDO	$t0,ModeJumpTable,$t0
	_JALR	$t0,$ra
	_J	Main

ModeSwitchIntro:
	PUSH	$ra
	_JAL	StartIntro
	_JAL	GetNextMode
	_STA	$v0,Mode		; will we go to gamemode or view highscoremode ?
	POP	$ra
	_RTS

ModeSwitchGame:
	PUSH	$ra
	_JAL	StartGame
	movi	$t0,ENTERHIGHSCOREMODE
	_STA	$t0,Mode
	POP	$ra
	_RTS

ModeSwitchEnterHigh:
	PUSH	$ra
	_JAL	StartEnterHigh
	movi	$t0,INTROMODE		; We will go directly to intromode since enter high will go to ViewHigh
	_STA	$t0,Mode
	POP	$ra
	_RTS

ModeSwitchViewHighScore:
	PUSH	$ra
	_JAL	StartViewHigh
	movi	$t0,INTROMODE
	_STA	$t0,Mode
	POP	$ra
	_RTS

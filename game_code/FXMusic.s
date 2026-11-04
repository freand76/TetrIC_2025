GAME_MUSIC = 0

BEAT_TARGETVOL = 32

StartMusic:
	; a0 - 0 = silent , 1 = music
	; a1 - MUSICINDEX

	_LI	$t0,0x77775555			; High volume for samples and lower for module
	_SW	$t0,SFX_MASTERVOL($sfx)

	; ModuleIndex
	movi	$t0,0
	_SW	$t0,SFX_SONGSTATUS($sfx)	; stop current song

	_LI	$t0,SilentMod
	_BEQZ	$a0,StartMusic_Silent

	_LDA	$t1,Music_State
	_BEQZ	$t1,StartMusic_Silent

	_LI	$t0,TetricMod			; game music
StartMusic_Silent:
	_SW	$t0,SFX_OFFSET($sfx)		; offset to song

	movi	$t0,SONG_LOOP|SONG_PLAY
	_SW	$t0,SFX_SONGSTATUS($sfx)	; start playing (even if silent)

	_RTS

FX_MENU_CHANGEROW = 0
FX_MENU_CHANGEVALUE = 1
FX_MENU_BUTTON = 2
FX_ENTERHIGH_MOVE = 3
FX_ENTERHIGH_BUTTON = 4
FX_GAME_CHANGELEVEL = 5
FX_GAME_DROP = 6
FX_GAME_QUAD = 7
FX_GAME_ROTATE = 8
FX_GAME_ROW = 9
FX_GAME_WARNING = 10
FX_GAMEOVER_LAUGH = 11

SampleList:	.dc	MenuChangeRow
		.dc	MenuChangeValue
		.dc	MenuButton
		.dc	MenuChangeValue
		.dc	EnterHighButton
		.dc	GameChangeLevel
		.dc	GameDrop
		.dc	GameQuad
		.dc	GameRotate
		.dc	GameRow
		.dc	GameWarning
		.dc	GameOverLaugh

BeatVolume:		.dc	0
BeatTargetVolume:	.dc	0

FX_State:	.dc	1
Music_State:	.dc	1

EnableFX:
	_STA	$a0,FX_State
	_RTS

EnableMusic:
	clr	$t0
	_STA	$a0,Music_State
	_BEQZ	$a0,EnableMusic_Off
	movi	$t0,BEAT_TARGETVOL
EnableMusic_Off:
	_STA	$t0,BeatTargetVolume
	_RTS

PlaySampleCh1:
	; play a sample 11.025kHz
	; a0 - sample index

	_LDA	$t0,FX_State
	_BEQZ	$t0,PlaySample_NoFX

	movi	$t5,11025			; sample frequency
	_LDO	$t0,SampleList,$a0
	_LW	$t1,0($t0)
	_LW	$t2,1($t0)
	_LW	$t3,2($t0)
	_LW	$t4,3($t0)
	_LW	$t6,4($t0)
	sw	$zero,SFX_FX0_END($sfx)
	sw	$zero,SFX_FX1_END($sfx)
	sw	$t3,SFX_FX0_LSTART($sfx)
	sw	$t3,SFX_FX1_LSTART($sfx)
	sw	$t4,SFX_FX0_LEND($sfx)
	sw	$t4,SFX_FX1_LEND($sfx)
	sw	$t5,SFX_FX0_FREQ($sfx)
	sw	$t5,SFX_FX1_FREQ($sfx)
	sw	$t1,SFX_FX0_START($sfx)
	sw	$t1,SFX_FX1_START($sfx)
	sw	$t2,SFX_FX0_END($sfx)
	sw	$t2,SFX_FX1_END($sfx)
	sw	$t6,SFX_FX0_VOL($sfx)
	sw	$t6,SFX_FX1_VOL($sfx)
	_RTS

PlaySampleCh2:
	; play a sample 11.025kHz
	; a0 - sample index

	_LDA	$t0,FX_State
	_BEQZ	$t0,PlaySample_NoFX

	movi	$t5,11025			; sample frequency
	_LDO	$t0,SampleList,$a0
	_LW	$t1,0($t0)
	_LW	$t2,1($t0)
	_LW	$t3,2($t0)
	_LW	$t4,3($t0)
	_LW	$t6,4($t0)
	sw	$zero,SFX_FX2_END($sfx)
	sw	$zero,SFX_FX3_END($sfx)
	sw	$t3,SFX_FX2_LSTART($sfx)
	sw	$t3,SFX_FX3_LSTART($sfx)
	sw	$t4,SFX_FX2_LEND($sfx)
	sw	$t4,SFX_FX3_LEND($sfx)
	sw	$t5,SFX_FX2_FREQ($sfx)
	sw	$t5,SFX_FX3_FREQ($sfx)
	sw	$t1,SFX_FX2_START($sfx)
	sw	$t1,SFX_FX3_START($sfx)
	sw	$t2,SFX_FX2_END($sfx)
	sw	$t2,SFX_FX3_END($sfx)
	sw	$t6,SFX_FX2_VOL($sfx)
	sw	$t6,SFX_FX3_VOL($sfx)
PlaySample_NoFX:
	_RTS


PlayBeat:
	; play the beat in FX channel 1
	PUSH	$ra
	_LDA	$t0,BeatTargetVolume
	_BNEZ	$t0,PlayBeat_NoBeat		; already playing

	movi	$a0,0				; silent during intro
	_JAL	StartMusic


	_LI	$t0,Beat
	_LW	$t1,0($t0)
	_LW	$t2,1($t0)
	_LW	$t3,2($t0)
	_LW	$t4,3($t0)
	movi	$t5,11025			; sample frequency
	sw	$zero,SFX_FX2_END($sfx)
	sw	$zero,SFX_FX3_END($sfx)
	sw	$t5,SFX_FX2_FREQ($sfx)
	sw	$t5,SFX_FX3_FREQ($sfx)
	sw	$t1,SFX_FX2_START($sfx)
	sw	$t1,SFX_FX3_START($sfx)
	sw	$t3,SFX_FX2_LSTART($sfx)
	sw	$t3,SFX_FX3_LSTART($sfx)
	sw	$t4,SFX_FX2_LEND($sfx)
	sw	$t4,SFX_FX3_LEND($sfx)
	sw	$t2,SFX_FX2_END($sfx)
	sw	$t2,SFX_FX3_END($sfx)
	sw	$zero,SFX_FX2_VOL($sfx)
	sw	$zero,SFX_FX3_VOL($sfx)
	_STA	$zero,BeatVolume

	clr	$t0
	_LDA	$t1,Music_State
	_BEQZ	$t1,PlayBeat_Silent
	movi	$t0,BEAT_TARGETVOL
PlayBeat_Silent:
	_STA	$t0,BeatTargetVolume
PlayBeat_NoBeat:
	POP	$ra
	_RTS

FadeBeat:
	PUSH	$ra
	_JAL	GetFrameCount
	sll	$t0,$v0,30
	_BNEZ	$t0,FadeBeat_DontFade

	_LDA	$t0,BeatVolume
	_LDA	$t1,BeatTargetVolume
	slt	$t2,$t0,$t1
	add	$t0,$t0,$t2
	slt	$t2,$t1,$t0
	sub	$t0,$t0,$t2
	_STA	$t0,BeatVolume
	sw	$t0,SFX_FX2_VOL($sfx)
	sw	$t0,SFX_FX3_VOL($sfx)
FadeBeat_DontFade:
	POP	$ra
	_RTS

StopBeat:
	_STA	$zero,BeatTargetVolume
	_RTS

StopAllSamples:
	sw	$zero,SFX_FX0_END($sfx)
	sw	$zero,SFX_FX1_END($sfx)
	sw	$zero,SFX_FX2_END($sfx)
	sw	$zero,SFX_FX3_END($sfx)
	_RTS

StopSample:
	; a0 - channel (0  or 1)
	_BNEZ	$a0,StopSample_ChannelTwo
StopSample_ChannelOne:
	sw	$zero,SFX_FX0_END($sfx)
	sw	$zero,SFX_FX1_END($sfx)
	_RTS
StopSample_ChannelTwo:
	sw	$zero,SFX_FX2_END($sfx)
	sw	$zero,SFX_FX3_END($sfx)
	_RTS

Beat:
	.dc	Beat_Data
	.dc	Beat_End
	.dc	Beat_Data
	.dc	Beat_End
Beat_Data:	.file	Data/snd_beat.raw 8590
Beat_End:

MenuChangeRow:
	.dc	MenuChangeRow_Data
	.dc	MenuChangeRow_End
	.dc	0
	.dc	0
	.dc	16

MenuChangeRow_Data:	.file	Data/snd_menu_changerow.raw 227
MenuChangeRow_End:

MenuChangeValue:
	.dc	MenuChangeValue_Data
	.dc	MenuChangeValue_End
	.dc	0
	.dc	0
	.dc	32

MenuChangeValue_Data:	.file	Data/snd_menu_changevalue.raw 166
MenuChangeValue_End:

MenuButton:
	.dc	MenuButton_Data
	.dc	MenuButton_End
	.dc	0
	.dc	0
	.dc	64

MenuButton_Data:	.file	Data/snd_menu_button.raw 373
MenuButton_End:

EnterHighButton:
	.dc	EnterHighButton_Data
	.dc	EnterHighButton_End
	.dc	0
	.dc	0
	.dc	64

EnterHighButton_Data:	.file	Data/snd_enterhigh_button.raw 161
EnterHighButton_End:

GameChangeLevel:
	.dc	GameChangeLevel_Data
	.dc	GameChangeLevel_End
	.dc	0
	.dc	0
	.dc	64

GameChangeLevel_Data:	.file	Data/snd_game_changelevel.raw 1193
GameChangeLevel_End:

GameDrop:
	.dc	GameDrop_Data
	.dc	GameDrop_End
	.dc	0
	.dc	0
	.dc	20

GameDrop_Data:		.file	Data/snd_game_drop.raw 1346
GameDrop_End:

GameQuad:
	.dc	GameQuad_Data
	.dc	GameQuad_End
	.dc	0
	.dc	0
	.dc	64

GameQuad_Data:		.file	Data/snd_game_quad.raw 6292
GameQuad_End:

GameRotate:
	.dc	GameRotate_Data
	.dc	GameRotate_End
	.dc	0
	.dc	0
	.dc	40

GameRotate_Data:	.file	Data/snd_game_rotate.raw 589
GameRotate_End:

GameRow:
	.dc	GameRow_Data
	.dc	GameRow_End
	.dc	0
	.dc	0
	.dc	48

GameRow_Data:		.file	Data/snd_game_row.raw 2304
GameRow_End:

GameWarning:
	.dc	GameWarning_Data
	.dc	GameWarning_End
	.dc	0
	.dc	0
	.dc	64

GameWarning_Data:	.file	Data/snd_game_warning.raw 2424
GameWarning_End:

GameOverLaugh:
	.dc	GameOverLaugh_Data
	.dc	GameOverLaugh_End
	.dc	0
	.dc	0
	.dc	64

GameOverLaugh_Data:	.file	Data/snd_gameover_laugh.raw 11025
GameOverLaugh_End:

TetricMod:		.file	Data/mod_gamemusic.raw 49395

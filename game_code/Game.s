################
# Game Control #
################

StartGame:
	PUSH	$ra
	_JAL	StopAllSamples

	movi	$a0,1				; game music or no music
	_JAL	StartMusic


	_JAL	GetStartLevel
	_LI	$t0,Level
	_SW	$v0,0($t0)			; Store to Level

	_JAL	GetShowNextPiece
	_LI	$t0,ShowNextPiece
	_SW	$v0,0($t0)			; Store to ShowNextPiece

	_JAL	GetStartHeight
	mov	$a0,$v0				; Get StartHeight
	_JAL	InitBoard			; Init Board

	_LI	$t0,JoyRepeatWait
	; LEFT, RIGHT , SOFTDROP (DOWN) , ROTATE
	_LI	$t1,0x000500	; Filter = 00, RepeatVal = 05, Accelerate = 0 (08 at 50 Hz)
	; HARDDROP (UP)
	_LI	$t2,0x03ff00	; Filter = 03, RepeatVal = ff, Accelerate = 0 (05 at 50 Hz)
	nop
	sw	$t1,JOY_DOWN($t0)
	sw	$t1,JOY_LEFT($t0)
	sw	$t1,JOY_RIGHT($t0)
	sw	$t1,JOY_BUTA($t0)
	sw	$t1,JOY_BUTB($t0)
	sw	$t1,JOY_BUTC($t0)
	sw	$t1,JOY_START($t0)
	sw	$t2,JOY_UP($t0)

	_JAL	DrawGameBackground		; Draw background

	_LI	$t0,Score
	_SW	$zero,0($t0)			; Clear Score
	_LI	$t0,LineCount
	_SW	$zero,0($t0)			; Clear number of lines
	_LI	$t0,GameOver
	_SW	$zero,0($t0)

	movi	$a0,20				; Draw 20 Rows
	movi	$a1,0				; DeltaY = 0
	_JAL	DrawBoard			; Draw Playfield
	_JAL	GetRandomPiece			; Get First Piece

	_LI	$t0,Stat
	sw	$zero,0($t0)			; Clear Stat
	sw	$zero,1($t0)			; Clear Stat
	sw	$zero,2($t0)			; Clear Stat
	sw	$zero,3($t0)			; Clear Stat
	sw	$zero,4($t0)			; Clear Stat
	sw	$zero,5($t0)			; Clear Stat
	sw	$zero,6($t0)			; Clear Stat

	_JAL	GetRandomPiece			; Get Next Piece
	_JAL	DrawCurrentPiece		; Draw Current Piece
	_JAL	DrawNextPiece			; Draw Current Piece

StartGame_Loop:
	_JAL	TetrisFrame
	_BEQZ	$v0,StartGame_Loop

	movi	$a0,FX_GAMEOVER_LAUGH
	_JAL	PlaySampleCh1

	_JAL	WaitGameNextFrame		; Wait for next frame
	_JAL	DrawBoard			; Draw Board
	_JAL	DrawCurrentPiece		; Draw Piece at new X,Y
	_JAL	DrawNextPiece			; Draw NextPiece if cheat mode on
	_JAL	DrawStat			; Draw Statistics
	_JAL	DrawScore			; Print Score, Lines, Level

	_JAL	WaitGameNextFrame		; Wait for next frame
	_JAL	DrawBoard			; Draw Board
	_JAL	DrawCurrentPiece		; Draw Piece at new X,Y
	_JAL	DrawNextPiece			; Draw NextPiece if cheat mode on
	_JAL	DrawStat			; Draw Statistics
	_JAL	DrawScore			; Print Score, Lines, Level

	_JAL	WaitGameNextFrame		; Wait for next frame
	_JAL	WaitGameNextFrame		; Wait for next frame
	_JAL	WaitGameNextFrame		; Wait for next frame
	_JAL	WaitGameNextFrame		; Wait for next frame
	_JAL	WaitGameNextFrame		; Wait for next frame
	_JAL	WaitGameNextFrame		; Wait for next frame
	_JAL	WaitGameNextFrame		; Wait for next frame

	movi	$a0,FX_GAMEOVER_LAUGH
	_JAL	PlaySampleCh2

	_JAL	PrintGameOver			; Print GameOver and wait for button
	_JAL	ScreenFadeOut			; Fadeout screen

	POP	$ra
	_RTS


GameOver_Txt:	.ascii	"G A M E  O V E R";

GAMEOVER_X = 160-128
GAMEOVER_Y = 120

PrintGameOver:
	PUSH	$ra
	PUSH	$s0

	_LI	$a0,GameOver_Txt
	movi	$a1,GAMEOVER_X
	movi	$a2,GAMEOVER_Y
	movi	$a3,0xffff
	_JAL	PrintLargeString
	_JAL	WaitNextFrame
	movi	$a0,30			; 50 at 50 Hz
	_JAL	WaitFrames
PrintGameOver_Loop:
	movi	$s0,30			; 50 at 50 Hz
PrintGameOver_InnerLoop:
	_JAL	WaitNextFrameNoSwap
	_JAL	CheckButton
	_BNEZ	$v0,PrintGameOver_Done
	addi	$s0,$s0,-1
	_BNEZ	$s0,PrintGameOver_InnerLoop
	_JAL	WaitNextFrame
	_J	PrintGameOver_Loop

PrintGameOver_Done:
	POP	$s0
	POP	$ra
	_RTS

GameOver:	.dc	0

TetrisFrame:
	PUSH	$ra
	_JAL	WaitGameNextFrame		; Wait for next frame
	_JAL	PieceFall			; Gravity on the TetrisBlock
	movi	$a0,20				; Draw 20 Rows
	movi	$a1,0				; DeltaY = 0
	_JAL	DrawBoard			; Draw Board
	_JAL	DrawCurrentPiece		; Draw Piece at new X,Y
	_JAL	DrawNextPiece			; Draw NextPiece if cheat mode on
	_JAL	DrawStat			; Draw Statistics
	_JAL	DrawScore			; Print Score, Lines, Level
	_JAL	CheckWarning			; If high play warning
	_JAL	GameJoystick			; Read JoyStick
	_LI	$t0,GameOver
	_LW	$v0,0($t0)
	POP	$ra
	_RTS

WaitGameNextFrame:
	PUSH	$ra

	_JAL	WaitNextFrame
	_JAL	ShakeBoard

	POP	$ra
	_RTS

GameJoystick:
	PUSH	$ra				; Store to stack
	PUSH	$s0
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2
	_JAL	CheckJoystick
	mov	$s0,$v0
	andi	$t0,$s0,1			; LSB to t0
	srl	$s0,$s0,1			; Shift out LSB
	_BEQZ	$t0,noGameUp			; Check LSB
	_JAL	HardDrop			; Up: drop (gamepad; was soft drop)
noGameUp:
	andi	$t0,$s0,1			; LSB to t0
	srl	$s0,$s0,1			; Shift out LSB
	_BEQZ	$t0,noButA			; Check LSB
	_JAL	RotateCCW
noButA:
	andi	$t0,$s0,1			; LSB to t0
	srl	$s0,$s0,1			; Shift out LSB
	_BEQZ	$t0,noGameDown			; Check LSB
	_JAL	SoftDrop			; Down: move down (gamepad; was drop)
noGameDown:
	andi	$t0,$s0,1			; LSB to t0
	srl	$s0,$s0,1			; Shift out LSB
	_BEQZ	$t0,noGameRight			; Check LSB
	_JAL	MoveRight			; MoveRight
noGameRight:
	andi	$t0,$s0,1			; LSB to t0
	srl	$s0,$s0,1			; Shift out LSB
	_BEQZ	$t0,noGameButB			; Check LSB
	_JAL	RotateCW
noGameButB:
	andi	$t0,$s0,1			; LSB to t0
	srl	$s0,$s0,1			; Shift out LSB
	_BEQZ	$t0,noGameLeft			; Check LSB
	_JAL	MoveLeft			; MoveLeft
noGameLeft:
	andi	$t0,$s0,1			; LSB to t0
	srl	$s0,$s0,1			; Shift out LSB
	_BEQZ	$t0,noGameStart			; Check LSB
	; Start
noGameStart:
	andi	$t0,$s0,1			; LSB to t0
	srl	$s0,$s0,1			; Shift out LSB
	_BEQZ	$t0,noGameButC			; Check LSB
	_JAL	RotateCCW
noGameButC:
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$s0				; Get from stack
	POP	$ra
	_RTS				; Return from subroutine

###################
# TetrIC Game Snd #
###################

WARNING_TIME = 60		; 100 at 50 Hz

WarningCount:	.dc	WARNING_TIME

CheckWarning:
	PUSH	$ra

	clr	$t0			; Default no piece
	_LI	$t1,Tetris_Board	; Get Board
	addi	$t1,$t1,13		; Not visible top roof

	movi	$t9,8			; Check the top 5 rows
CheckWarning_RowLoop:
	movi	$t8,10
CheckWarning_ColLoop:
	_LW	$t2,0($t1)
	_BEQZ	$t2,CheckWarning_NotSet
	addi	$t0,$t0,1
CheckWarning_NotSet:
	addi	$t1,$t1,1
	addi	$t8,$t8,-1
	_BNEZ	$t8,CheckWarning_ColLoop
	addi	$t1,$t1,2
	addi	$t9,$t9,-1
	_BNEZ	$t9,CheckWarning_RowLoop

	slti	$t1,$t0,10

	_BNEZ	$t1,CheckWarning_NoWarning

	_LDA	$t0,WarningCount
	movi	$t1,WARNING_TIME
	_BNE	$t0,$t1,CheckWarning_NoSound

	movi	$a0,FX_GAME_WARNING
	_JAL	PlaySampleCh2

CheckWarning_NoSound:
	_LDA	$t0,WarningCount
	addi	$t0,$t0,-1
	_STA	$t0,WarningCount
	_BNEZ	$t0,CheckWarning_Exit
CheckWarning_NoWarning:
	movi	$t0,WARNING_TIME
	_STA	$t0,WarningCount
CheckWarning_Exit:
	POP	$ra
	_RTS


###################
# TetrIC Game Gfx #
###################

DrawGameBackground:
	PUSH	$ra
	PUSH	$a0		; Function input
	PUSH	$a1		; Function input
	PUSH	$a2		; Function input
	_LI	$a0,TetrisPal	; Expand palette
	_LI	$a1,TempMem
	_JAL	ExpandPalette
	_LI	$a0,TetrisPic	; Draw background in first bufffer
	_JAL	GetWorkScreen
	mov	$a1,$v0
	_LI	$a2,TempMem
	_JAL	ExpandPicture
	_JAL	WaitGameNextFrame	; Swap Buffers
	_LI	$a0,TetrisPic	; Draw background in second bufffer
	_JAL	GetWorkScreen
	mov	$a1,$v0
	_LI	$a2,TempMem
	_JAL	ExpandPicture
	_LI	$a0,TempMem	; Shade palette (Make it darker)
	_JAL	ShadePalette
	_LI	$a0,TetrisPic	; Draw Board Background
	_LI	$a1,BoardBKG
	_LI	$a2,TempMem
	_JAL	ExpandBoardBkg

	_LI	$a0,TetrisPal	; Expand palette
	_LI	$a1,TempMem
	_JAL	ExpandPalette
	_LI	$a0,TempMem	; Grey palette (Make it darker)
	_JAL	GreyPalette

	_LI	$a0,TetrisPic	; Draw Board Background
	_LI	$a1,NextPieceBKG
	_LI	$a2,TempMem
	_JAL	ExpandNextPieceBkg
	_LI	$a1,StatBKG
	_JAL	ExpandStatBkg
	_LI	$a1,ScoreBKG
	_JAL	ExpandScoreBkg

	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS

ExpandPalette:
	; Expands a 256*16 bits (512 byte) palette to 256*32 bits (Zero in high 16 bits)
	mov	$t0,$a0		; Packed palette pointer
	mov	$t1,$a1		; Expanded palette pointer
	movi	$t2,128		; Count
	moviu	$t3,0xffff	; Mask
ExpandPal_Loop:
	_LW	$t4,0($t0)	; Load 32 bits
	srl	$t5,$t4,16	; Mask 16 high bits
	_SW	$t5,0($t1)	; Store color
	addi	$t1,$t1,1	; Add 1 to expanded palette pointer
	and	$t4,$t4,$t3	; Mask 16 Low bits
	_SW	$t4,0($t1)	; Store color
	addi	$t1,$t1,1	; Add 1 to expanded palette pointer
	addi	$t0,$t0,1	; Add 1 to packed palette pointer
	addi	$t2,$t2,-1	; Count--
	_BNEZ	$t2,ExpandPal_Loop
	_RTS

ExpandPicture:
	; Fix Background from 8 bit palette colorto 16 bit color
	mov	$t0,$a0		; Pointer to Image
	mov	$t1,$a1		; Poiter to Screen
	mov	$t2,$a2		; Pointer to Palette
	movi	$t3,20480	; 20480 words = 320*256/4
ExpandPic_RowLoop:
	_LW	$t5,0($t0)	; Load word (4 bytes = 4 pixels)
	movi	$t4,2		; Byte counter
ExpandPic_ByteLoop:
	srl	$t6,$t5,24	; Get leftmost byte
	add	$t7,$t2,$t6	; Add to palette pointer
	_LW	$t8,0($t7)	; Get palette value
	sll	$t9,$t8,16	; Left pixel in word
	sll	$t5,$t5,8	; Shift out used byte
	srl	$t6,$t5,24	; Get leftmost byte
	add	$t7,$t2,$t6	; Add to palette pointer
	_LW	$t8,0($t7)	; Get palette value
	or	$t9,$t9,$t8	; Right pixel in word
	sll	$t5,$t5,8	; SHift out used byte
	_SW	$t9,0($t1)	; Store 2 pixels (2*16 bits)
	addi	$t1,$t1,1	; Add 1 to screen pointer
	addi	$t4,$t4,-1	; bytecount--
	_BNEZ	$t4,ExpandPic_ByteLoop
	addi	$t0,$t0,1	; Add 1 to image pointer
	addi	$t3,$t3,-1	; wordcount--
	_BNEZ	$t3,ExpandPic_RowLoop
	_RTS

ShadePalette:
	; Shades the 256 color palette to half the value for each color
	mov	$t0,$a0			; Palette pointer
	movi	$t1,256			; Color counter (256 colors)
	moviu	$t2,0b1111011111011110	; And Mask
ShadePal_Loop:
	_LW	$t3,0($t0)		; Get color value
	and	$t3,$t3,$t2		; And with mask (remove LSB for each color)
	srl	$t3,$t3,1		; Shift word 1 bit right (half the color values)
	_SW	$t3,0($t0)		; Store color value
	addi	$t0,$t0,1		; Add 1 to palette pointer
	addi	$t1,$t1,-1		; Color--
	_BNEZ	$t1,ShadePal_Loop	; Are we done ?
	_RTS

GreyPalette:
	; Shades the 256 color palette to half the value for each color
	mov	$t0,$a0			; Palette pointer
	movi	$t1,256			; Color counter (256 colors)
GreyPal_Loop:
	_LW	$t3,0($t0)		; Get color value
	sll	$t4,$t3,27
	srl	$t4,$t4,27
	sll	$t5,$t3,21
	srl	$t5,$t5,27
	sll	$t6,$t3,16
	srl	$t6,$t6,27
	add	$t4,$t4,$t5
	add	$t4,$t4,$t6
	srl	$t4,$t4,2
	sll	$t5,$t4,6
	or	$t4,$t4,$t5
	sll	$t5,$t5,5
	or	$t4,$t4,$t5
	_SW	$t4,0($t0)		; Store color value
	addi	$t0,$t0,1		; Add 1 to palette pointer
	addi	$t1,$t1,-1		; Color--
	_BNEZ	$t1,GreyPal_Loop	; Are we done ?
	_RTS

ExpandBoardBkg:
	; Fix Board Background from 8 bit palette colorto 16 bit color
	PUSH	$s0	; Row counter
	PUSH	$s1	; Col Counter
	PUSH	$s2	; Byte counter
	mov	$t0,$a0	; Pointer to Image
	mov	$t1,$a1	; Pointer to Screen
	mov	$t2,$a2 ; Pointer to palette
	movi	$t3,[BOARD_LEFT+8]
	srl	$t4,$t3,2	; / 4 for x pos (4 pixels / byte)
	add	$t0,$t0,$t4
	movi	$t3,[BOARD_TOP+8]
	sll	$t4,$t3,4	; * 16
	add	$t0,$t0,$t4
	sll	$t4,$t3,6	; * 64
	add	$t0,$t0,$t4     ; = * 80 (80 words / row)
	movi	$s0,160		; Row counter
Copy_To_BoardBKG_Loop
	movi	$s1,20		; Col Counter
Copy_To_BoardBKG_RowLoop
	_LW	$t3,0($t0)	; Get word
	addi	$t0,$t0,1	; Add 1 to Image pointer
	movi	$s2,2		; Byte counter
Copy_To_BoardBKG_ByteLoop:
	srl	$t4,$t3,24	; Get leftmost byte
	add	$t5,$t2,$t4	; Add to palette pointer
	_LW	$t6,0($t5)	; Get palette value
	sll	$t7,$t6,16	; Left pixel in word
	sll	$t3,$t3,8	; Shift out used byte
	srl	$t4,$t3,24	; Get leftmost byte
	add	$t5,$t2,$t4	; Add to palette pointer
	_LW	$t6,0($t5)	; Get palette value
	or	$t7,$t7,$t6	; Right pixel in word
	sll	$t3,$t3,8	; Shift out used byte
	_SW	$t7,0($t1)	; Store Pixel (2*16bits)
	addi	$t1,$t1,1	; Add 1 to Screen pointer
	addi	$s2,$s2,-1	; Byte--
	_BNEZ	$s2,Copy_To_BoardBKG_ByteLoop
	addi	$s1,$s1,-1	; Col --
	_BNEZ	$s1,Copy_To_BoardBKG_RowLoop
	addi	$t0,$t0,60	; Add rest of row
	addi	$s0,$s0,-1	; Row --
	_BNEZ	$s0,Copy_To_BoardBKG_Loop
	POP	$s2
	POP	$s1
	POP	$s0
	_RTS

ExpandNextPieceBkg:
	; Fix Board Background from 8 bit palette colorto 16 bit color
	PUSH	$s0	; Row counter
	PUSH	$s1	; Col Counter
	PUSH	$s2	; Byte counter
	mov	$t0,$a0	; Pointer to Image
	mov	$t1,$a1	; Pointer to Screen
	mov	$t2,$a2 ; Pointer to palette
	movi	$t3,NEXTPIECE_LEFT
	srl	$t4,$t3,2	; / 4 for x pos (4 pixels / byte)
	add	$t0,$t0,$t4
	movi	$t3,NEXTPIECE_TOP
	sll	$t4,$t3,4	; * 16
	add	$t0,$t0,$t4
	sll	$t4,$t3,6	; * 64
	add	$t0,$t0,$t4     ; = * 80 (80 words / row)
	movi	$s0,48		; Row counter
Copy_To_NPBKG_Loop
	movi	$s1,23		; Col Counter
Copy_To_NPBKG_RowLoop
	_LW	$t3,0($t0)	; Get word
	addi	$t0,$t0,1	; Add 1 to Image pointer
	movi	$s2,2		; Byte counter
Copy_To_NPBKG_ByteLoop:
	srl	$t4,$t3,24	; Get leftmost byte
	add	$t5,$t2,$t4	; Add to palette pointer
	_LW	$t6,0($t5)	; Get palette value
	sll	$t7,$t6,16	; Left pixel in word
	sll	$t3,$t3,8	; Shift out used byte
	srl	$t4,$t3,24	; Get leftmost byte
	add	$t5,$t2,$t4	; Add to palette pointer
	_LW	$t6,0($t5)	; Get palette value
	or	$t7,$t7,$t6	; Right pixel in word
	sll	$t3,$t3,8	; Shift out used byte
	_SW	$t7,0($t1)	; Store Pixel (2*16bits)
	addi	$t1,$t1,1	; Add 1 to Screen pointer
	addi	$s2,$s2,-1	; Byte--
	_BNEZ	$s2,Copy_To_NPBKG_ByteLoop
	addi	$s1,$s1,-1	; Col --
	_BNEZ	$s1,Copy_To_NPBKG_RowLoop
	addi	$t0,$t0,57	; Add rest of row
	addi	$s0,$s0,-1	; Row --
	_BNEZ	$s0,Copy_To_NPBKG_Loop
	POP	$s2
	POP	$s1
	POP	$s0
	_RTS

ExpandStatBkg:
	; Fix Board Background from 8 bit palette colorto 16 bit color
	PUSH	$s0	; Row counter
	PUSH	$s1	; Col Counter
	PUSH	$s2	; Byte counter
	mov	$t0,$a0	; Pointer to Image
	mov	$t1,$a1	; Pointer to Screen
	mov	$t2,$a2 ; Pointer to palette
	movi	$t3,STAT_LEFT
	srl	$t4,$t3,2	; / 4 for x pos (4 pixels / byte)
	add	$t0,$t0,$t4
	movi	$t3,STAT_TOP
	sll	$t4,$t3,4	; * 16
	add	$t0,$t0,$t4
	sll	$t4,$t3,6	; * 64
	add	$t0,$t0,$t4     ; = * 80 (80 words / row)
	movi	$s0,48		; Row counter
Copy_To_StatBKG_Loop
	movi	$s1,23		; Col Counter
Copy_To_StatBKG_RowLoop
	_LW	$t3,0($t0)	; Get word
	addi	$t0,$t0,1	; Add 1 to Image pointer
	movi	$s2,2		; Byte counter
Copy_To_StatBKG_ByteLoop:
	srl	$t4,$t3,24	; Get leftmost byte
	add	$t5,$t2,$t4	; Add to palette pointer
	_LW	$t6,0($t5)	; Get palette value
	sll	$t7,$t6,16	; Left pixel in word
	sll	$t3,$t3,8	; Shift out used byte
	srl	$t4,$t3,24	; Get leftmost byte
	add	$t5,$t2,$t4	; Add to palette pointer
	_LW	$t6,0($t5)	; Get palette value
	or	$t7,$t7,$t6	; Right pixel in word
	sll	$t3,$t3,8	; Shift out used byte
	_SW	$t7,0($t1)	; Store Pixel (2*16bits)
	addi	$t1,$t1,1	; Add 1 to Screen pointer
	addi	$s2,$s2,-1	; Byte--
	_BNEZ	$s2,Copy_To_StatBKG_ByteLoop
	addi	$s1,$s1,-1	; Col --
	_BNEZ	$s1,Copy_To_StatBKG_RowLoop
	addi	$t0,$t0,57	; Add rest of row
	addi	$s0,$s0,-1	; Row --
	_BNEZ	$s0,Copy_To_StatBKG_Loop
	POP	$s2
	POP	$s1
	POP	$s0
	_RTS

ExpandScoreBkg:
	; Fix Board Background from 8 bit palette colorto 16 bit color
	PUSH	$s0	; Row counter
	PUSH	$s1	; Col Counter
	PUSH	$s2	; Byte counter
	mov	$t0,$a0	; Pointer to Image
	mov	$t1,$a1	; Pointer to Screen
	mov	$t2,$a2 ; Pointer to palette
	movi	$t3,SCORE_LEFT
	srl	$t4,$t3,2	; / 4 for x pos (4 pixels / byte)
	add	$t0,$t0,$t4
	movi	$t3,SCORE_TOP
	sll	$t4,$t3,4	; * 16
	add	$t0,$t0,$t4
	sll	$t4,$t3,6	; * 64
	add	$t0,$t0,$t4     ; = * 80 (80 words / row)
	movi	$s0,48		; Row counter
Copy_To_ScoreBKG_Loop
	movi	$s1,23		; Col Counter
Copy_To_ScoreBKG_RowLoop
	_LW	$t3,0($t0)	; Get word
	addi	$t0,$t0,1	; Add 1 to Image pointer
	movi	$s2,2		; Byte counter
Copy_To_ScoreBKG_ByteLoop:
	srl	$t4,$t3,24	; Get leftmost byte
	add	$t5,$t2,$t4	; Add to palette pointer
	_LW	$t6,0($t5)	; Get palette value
	sll	$t7,$t6,16	; Left pixel in word
	sll	$t3,$t3,8	; Shift out used byte
	srl	$t4,$t3,24	; Get leftmost byte
	add	$t5,$t2,$t4	; Add to palette pointer
	_LW	$t6,0($t5)	; Get palette value
	or	$t7,$t7,$t6	; Right pixel in word
	sll	$t3,$t3,8	; Shift out used byte
	_SW	$t7,0($t1)	; Store Pixel (2*16bits)
	addi	$t1,$t1,1	; Add 1 to Screen pointer
	addi	$s2,$s2,-1	; Byte--
	_BNEZ	$s2,Copy_To_ScoreBKG_ByteLoop
	addi	$s1,$s1,-1	; Col --
	_BNEZ	$s1,Copy_To_ScoreBKG_RowLoop
	addi	$t0,$t0,57	; Add rest of row
	addi	$s0,$s0,-1	; Row --
	_BNEZ	$s0,Copy_To_ScoreBKG_Loop
	POP	$s2
	POP	$s1
	POP	$s0
	_RTS

QuadGfx:
	PUSH	$ra
	PUSH	$a0	; Input to DrawBoard
	PUSH	$a1	; Input to DrawBoard, FixTopLines
	PUSH	$s0	; Delta accumulator
	PUSH	$s1	; Total accumulator
	PUSH	$s2	; Number of Lines
	_LI	$t0,RemoveRow_Array	; Get RemoveRow array
	_LW	$s2,3($t0)		; Get Top Row
	movi	$s0,0			; Start with zero delta
	movi	$s1,0			; Start with zero total
QuadGfx_Loop:
	_JAL	WaitGameNextFrame		; WaitGameNextFrame
	mov	$a0,$s1			; Set DeltaY
	_JAL	FixTopLines		; FixTopLines
	mov	$a0,$s2			; Set Number of Lines
	mov	$a1,$s1			; Set DeltaY
	_JAL	DrawBoard		; DrawBoard
	addi	$s0,$s0,1		; Add one to delta
	srl	$t0,$s0,2		; Half the speed (low gravity)
	add	$s1,$s1,$t0		; Add delta to total
	slti	$t0,$s1,32		; Is it above 32
	_BNEZ	$t0,QuadGfx_Loop	; If not, continue
	_JAL	WaitGameNextFrame		; WaitGameNextFrame
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS

FixTopLines:
	; a0 = Number of Lines to fix in top
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	_BEQZ	$a0,FixTopLine_NoTopLine
	_LI	$s0,BoardBKG
	_JAL	GetWorkScreen
	mov	$s1,$v0
	movi	$t0,[BOARD_LEFT+8]
	srl	$t0,$t0,1		; X / 2
	add	$s1,$s1,$t0		; add X offset
	movi	$t0,[BOARD_TOP+8]
	sll	$t1,$t0,7		; Y * 128
	add	$s1,$s1,$t1
	sll	$t1,$t0,5		; Y * 32
	add	$s1,$s1,$t1
	mov	$t9,$a0			; RowCount
FixTopLines_RowLoop:
	movi	$t8,10			; ColCount
FixTopLines_ColLoop:
	lw	$t0,0($s0)		; Load
	nop
	lw	$t1,1($s0)
	nop
	lw	$t2,2($s0)
	nop
	lw	$t3,3($s0)
	nop
	sw	$t0,0($s1)		; Store
	sw	$t1,1($s1)
	sw	$t2,2($s1)
	sw	$t3,3($s1)
	addi	$s0,$s0,4		; Add BKG pointer
	addi	$s1,$s1,4		; Add Workscreen pointer
	addi	$t8,$t8,-1		; Dec ColCount
	_BNEZ	$t8,FixTopLines_ColLoop ; Col Count = 0 ? No, ColLoop
	addi	$s1,$s1,120		; Add rest of line
	addi	$t9,$t9,-1		; Dec RowCount
	_BNEZ	$t9,FixTopLines_RowLoop	; Row Count = 0 ? No, RowLoop
FixTopLine_NoTopLine:
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS				; Return from subroutine

RemoveRowsGfx:
	; a0 = Number of Rows
	PUSH	$ra
	PUSH	$a0	; Input to DrawBoard & FadeRow
	PUSH	$a1	; Input to DrawBoard
	PUSH	$s0	; Array pointer
	PUSH	$s1	; Row counter
	PUSH	$s2	; Number of rows
	PUSH	$s3	; Fadeorder counter
	PUSH	$s4	; Done flag
	movi	$s3,1		; Set fadeorder counter (start fade with first row only)
	sll	$s3,$s3,3	; Multiply by 4 (4 frames between fadestart for one line to fade start for next)
	mov	$s2,$a0		; Number of rows
	sll	$s2,$s2,3	; Multiply by 4 (4 frames between fadestart for one line to fade start for next)

	movi	$a0,20		; Draw 20 Rows
	movi	$a1,0		; DeltaY = 0
	_JAL	DrawBoard	; Draw board

	_JAL	WaitGameNextFrame
	movi	$a0,20		; Draw 20 Rows
	movi	$a1,0		; DeltaY = 0
	_JAL	DrawBoard	; Draw board

RemoveRowsGfx_Loop:
	_JAL	WaitGameNextFrame
	_LI	$s0,RemoveRow_Array
	clr	$s1		; Clear row counter
	clr	$s4		; Clear done flags
RemoveRowsGfx_RowLoop:
	_LW	$a0,0($s0)	; Get row nbr to fade
	_JAL	FadeRow		; And do it
	or	$s4,$s4,$v0	; Are we done
	addi	$s0,$s0,1	; Next row
	addi	$s1,$s1,1	; Row = Row +1
	slt	$t0,$s3,$s2	; Fadeorder counter less than rows ?
	add	$s3,$s3,$t0	; If yes, then Add one
	srl	$t0,$s3,3	; Divide by 4 to get rownbr
	_BNE	$s1,$t0,RemoveRowsGfx_RowLoop	; Are we done
	_BNEZ	$s4,RemoveRowsGfx_Loop		; Are we done
	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS

FadeRow:
	; a0 = Row
	PUSH	$ra
	PUSH	$a0	; Input FadeDown
	PUSH	$a1	; Input Fade Down
	PUSH	$s0	; WorkScreen
	PUSH	$s1	; Board Bkg
	PUSH	$s2	; Done Flag
	PUSH	$s3	; Row Counter
	PUSH	$s4	; Col Counter
	_JAL	GetActiveScreen
	mov	$s0,$v0
	movi	$t0,[BOARD_LEFT+8]
	srl	$t1,$t0,1	; / 2
	add	$s0,$s0,$t1
	movi	$t0,[BOARD_TOP+8]
	sll	$t1,$t0,5	; * 32
	add	$s0,$s0,$t1
	sll	$t1,$t0,7	; * 128
	add	$s0,$s0,$t1
	mov	$t0,$a0
	sll	$t0,$t0,3	; * 8
	sll	$t1,$t0,5	; * 32
	add	$s0,$s0,$t1
	sll	$t1,$t0,7	; * 128
	add	$s0,$s0,$t1
	_LI	$s1,BoardBkg
	mov	$t0,$a0
	sll	$t0,$t0,3	; * 8
	sll	$t1,$t0,3	; * 8
	add	$s1,$s1,$t1
	sll	$t1,$t0,5	; * 32
	add	$s1,$s1,$t1
	clr	$s2
	movi	$s3,8
FadeRow_Rowloop:
	movi	$s4,40
FadeRow_ColLoop:
	_LW	$a0,0($s0)	; Source color
	_LW	$a1,0($s1)	; Destination color
	_JAL	FadeDown	; And Fade
	_SW	$v0,0($s0)
	or	$s2,$s2,$v1
	addi	$s0,$s0,1
	addi	$s1,$s1,1
	addi	$s4,$s4,-1
	_BNEZ	$s4,FadeRow_ColLoop
	addi	$s0,$s0,120
	addi	$s3,$s3,-1
	_BNEZ	$s3,FadeRow_RowLoop
	mov	$v0,$s2
	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS

BOARD_TOP = 40
BOARD_LEFT = 112

DrawBoard:
	; a0 = StopRow
	; a1 = DeltaY
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	mov	$s2,$a0			; Set number of rows
	_LI	$s0,Tetris_Board
	movi	$a0,BOARD_LEFT
	addi	$a1,$a1,BOARD_TOP	; Add DeltaY to BoardTop
	addi	$s0,$s0,12		; Skip first row
	addi	$a0,$a0,8		; Begin x+8
	addi	$a1,$a1,8		; Begin y+8
DrawBoard_RowLoop:
	addi	$s0,$s0,1		; Skip first col
	movi	$s1,10			; Set number of cols
DrawBoard_ColLoop:
	_LW	$a2,0($s0)
	_BNEZ	$a2,DrawBoard_ColorBox
	_JAL	CopyBox
	_J	DrawBoard_TestDone
DrawBoard_ColorBox:
	_JAL	DrawPieceBox		; DrawBox with texture
DrawBoard_TestDone:
	addi	$s0,$s0,1
	addi	$a0,$a0,8		; Add 8 to X
	addi	$s1,$s1,-1		; Decrease col counter
	_BNEZ	$s1,DrawBoard_ColLoop
	addi	$s0,$s0,1		; Skip last col
	addi	$a0,$a0,-80		; Sub 80 from X
	addi	$a1,$a1,8		; Add 8 to Y
	addi	$s2,$s2,-1		; Decrease row counter
	_BNEZ	$s2,DrawBoard_RowLoop
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS

NEXTPIECE_LEFT = 208
NEXTPIECE_TOP  = 48
NEXTPIECE_WIDTH = 92
NEXTPIECE_HEIGHT = 48

DrawNextPiece:
	PUSH	$ra			; Store to stack
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2
	PUSH	$a3
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4

	_JAL	GetWorkScreen
	mov	$t0,$v0
	addiu	$t0,$t0,NEXTPIECE_TOP*160+NEXTPIECE_LEFT/2
	_LI	$t1,NextPieceBKG
	movi	$t9,48
DrawNextPiece_Copy_Bkg_Row_Loop:
	movi	$t8,9
DrawNextPiece_Copy_Bkg_Col_Loop:

	_LW	$t2,0($t1)
	_LW	$t3,1($t1)
	_LW	$t4,2($t1)
	_LW	$t5,3($t1)
	_LW	$t6,4($t1)

	_SW	$t2,0($t0)
	_SW	$t3,1($t0)
	_SW	$t4,2($t0)
	_SW	$t5,3($t0)
	_SW	$t6,4($t0)

	addi	$t0,$t0,5
	addi	$t1,$t1,5
	addi	$t8,$t8,-1
	_BNEZ	$t8,DrawNextPiece_Copy_Bkg_Col_Loop
	addi	$t0,$t0,115
	addi	$t1,$t1,1
	addi	$t9,$t9,-1
	_BNEZ	$t9,DrawNextPiece_Copy_Bkg_Row_Loop

	_LI	$a0,NextPiece_Txt
	movi	$a1,NEXTPIECE_LEFT+4
	movi	$a2,NEXTPIECE_TOP
	movi	$a3,0xffff
	_JAL	PrintString

	_LI	$t0,ShowNextPiece
	_LW	$t1,0($t0)		; Should we show next piece ?
	_BEQZ	$t1,DontShowNextPiece	; No, then dont do it !
	_LI	$t0,NextPieceNumber
	_LW	$t1,0($t0)		; Get Next piece number
	_LI	$t2,Piece_Array
	add	$t2,$t2,$t1
	_LW	$s2,0($t2)		; And the corresponding piece data
	movi	$s0,0			; X = 0
	movi	$s1,0			; Y = 0
	_LW	$a2,PIECE_COLOR($s2)	; Color
	_LW	$s3,PIECE_HORDIFF($s2)	; Hordiff
	_LW	$s4,PIECE_VERDIFF($s2)	; Verdiff
DrawNextPiece_Loop:
	_LW	$t0,0($s2)		;
	_BEQZ	$t0,NextPiece_BitNotSet	; Is bit set ? No, BitNotSet
	mov	$a0,$s0			; a0 = X Count
	sll	$a0,$a0,3		; a0 = a0 * 8
	addi	$a0,$a0,NEXTPIECE_LEFT+29	; a0 = a0 + LeftPos+29
	add	$a0,$a0,$s3		; Horisontal slide for different pieces
	mov	$a1,$s1			; a1 = Y Count
	sll	$a1,$a1,3		; a1 = a1 * 8
	addi	$a1,$a1,NEXTPIECE_TOP+16;  a1 = a1 + TopPos + 16
	add	$a1,$a1,$s4		; Vertical slide for different pieces
	_JAL	DrawPieceBox		; DrawBox
NextPiece_BitNotSet:
	addi	$s2,$s2,1		; Piece Address++
	addi	$s0,$s0,1		; X = X + 1
	andi	$s0,$s0,0x0003		; X = X & 0x0003
	_BNEZ	$s0,DrawNextPiece_Loop	; X = 0 ? No, PieceLoop
	addi	$s1,$s1,1		; Y = Y + 1
	andi	$s1,$s1,0x0003		; Y = Y & 0x0003
	_BNEZ	$s1,DrawNextPiece_Loop	; Y = 0 ? No, PieceLoop
DontShowNextPiece:
	POP	$s4			; Get from stack
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a3
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS				; Return from subroutine


STAT_LEFT = 208
STAT_TOP  = 104
STAT_HEIGHT = 48
STAT_WIDTH = 92

DrawStat:
	PUSH	$ra			; Store to stack
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2
	PUSH	$a3
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s7

	_JAL	GetWorkScreen
	mov	$t0,$v0
	addiu	$t0,$t0,STAT_TOP*160+STAT_LEFT/2
	_LI	$t1,StatBKG
	movi	$t9,48
DrawStat_Copy_Bkg_Row_Loop:
	movi	$t8,9
DrawStat_Copy_Bkg_Col_Loop:

	_LW	$t2,0($t1)
	_LW	$t3,1($t1)
	_LW	$t4,2($t1)
	_LW	$t5,3($t1)
	_LW	$t6,4($t1)

	_SW	$t2,0($t0)
	_SW	$t3,1($t0)
	_SW	$t4,2($t0)
	_SW	$t5,3($t0)
	_SW	$t6,4($t0)

	addi	$t0,$t0,5
	addi	$t1,$t1,5
	addi	$t8,$t8,-1
	_BNEZ	$t8,DrawStat_Copy_Bkg_Col_Loop
	addi	$t0,$t0,115
	addi	$t1,$t1,1
	addi	$t9,$t9,-1
	_BNEZ	$t9,DrawStat_Copy_Bkg_Row_Loop

	_LI	$a0,Statistics_Txt
	movi	$a1,STAT_LEFT+4
	movi	$a2,STAT_TOP
	movi	$a3,0xffff
	_JAL	PrintString

	movi	$t9,6
	_LI	$t0,Stat
	_LW	$s1,0($t0)
DrawStat_FindMax_Loop:
	addi	$t0,$t0,1
	addi	$t9,$t9,-1
	_LW	$t1,0($t0)
	slt	$t2,$t1,$s1
	_BNEZ	$t2,DrawStat_NoMax
	mov	$s1,$t1
DrawStat_NoMax:
	_BNEZ	$t9,DrawStat_FindMax_Loop

	_LI	$s0,Stat
	movi	$s2,4
	movi	$s7,7
DrawStat_Loop:
	_LW	$a0,0($s0)		; Current Count in $a0
	_LW	$a3,7($s0)		; Current Color in $a3
	_BEQZ	$a0,DrawStat_NoStat	; No bar if no pieces
	sll	$a0,$a0,5
	mov	$a1,$s1
	_JAL	Divu16
	_BEQZ	$v0,DrawStat_NoStat	; No bar if no pieces

	mov	$a0,$v0
	movi	$a1,STAT_LEFT
	add	$a1,$a1,$s2
	movi	$a2,STAT_TOP+STAT_HEIGHT
	_JAL	DrawStatBar

DrawStat_NoStat:
	addi	$s0,$s0,1
	addi	$s2,$s2,12
	addi	$s7,$s7,-1
	_BNEZ	$s7,DrawStat_Loop

	POP	$s7			; Get from stack
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a3
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS				; Return from subroutine

DrawStatBar:
	PUSH	$ra

	_JAL	GetWorkScreen
	mov	$t1,$v0

	srl	$t2,$a1,1
	add	$t1,$t1,$t2

	sll	$t2,$a2,5	; * 32
	add	$t1,$t1,$t2
	sll	$t2,$a2,7	; * 128
	add	$t1,$t1,$t2

	sll	$t2,$a3,16
	srl	$t3,$t2,16
	or	$t8,$t3,$t2

	mov	$t9,$a0
DrawStatBar_Loop:
	_SW	$t8,0($t1)
	_SW	$t8,1($t1)
	_SW	$t8,2($t1)
	_SW	$t8,3($t1)

	addi	$t1,$t1,-160
	addi	$t9,$t9,-1
	_BNEZ	$t9,DrawStatBar_Loop

	POP	$ra
	_RTS

SCORE_LEFT = 208
SCORE_TOP  = 160
SCORE_WIDTH = 92
SCORE_TXTHEIGHT = 16

DrawScore:
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2
	PUSH	$a3

	_JAL	GetWorkScreen
	mov	$t0,$v0
	addiu	$t0,$t0,SCORE_TOP*160+SCORE_LEFT/2
	_LI	$t1,ScoreBKG
	movi	$t9,48
DrawScore_Copy_Bkg_Row_Loop:
	movi	$t8,9
DrawScore_Copy_Bkg_Col_Loop:

	_LW	$t2,0($t1)
	_LW	$t3,1($t1)
	_LW	$t4,2($t1)
	_LW	$t5,3($t1)
	_LW	$t6,4($t1)

	_SW	$t2,0($t0)
	_SW	$t3,1($t0)
	_SW	$t4,2($t0)
	_SW	$t5,3($t0)
	_SW	$t6,4($t0)

	addi	$t0,$t0,5
	addi	$t1,$t1,5
	addi	$t8,$t8,-1
	_BNEZ	$t8,DrawScore_Copy_Bkg_Col_Loop
	addi	$t0,$t0,115
	addi	$t1,$t1,1
	addi	$t9,$t9,-1
	_BNEZ	$t9,DrawScore_Copy_Bkg_Row_Loop

	_LI	$a0,Score_Txt
	movi	$a1,SCORE_LEFT
	movi	$a2,SCORE_TOP
	movi	$a3,0xffff
	_JAL	PrintString

	_LI	$t0,Score
	_LW	$a0,0($t0)
	movi	$a1,SCORE_LEFT+SCORE_WIDTH-4
	movi	$a2,SCORE_TOP
	movi	$a3,0xffff
	_JAL	PrintNumber16

	_LI	$a0,Lines_Txt
	movi	$a1,SCORE_LEFT
	movi	$a2,SCORE_TOP+SCORE_TXTHEIGHT
	movi	$a3,0xffff
	_JAL	PrintString

	_LI	$t0,LineCount
	_LW	$a0,0($t0)
	movi	$a1,SCORE_LEFT+SCORE_WIDTH-4
	movi	$a2,SCORE_TOP+SCORE_TXTHEIGHT
	movi	$a3,0xffff
	_JAL	PrintNumber16

	_LI	$a0,Level_Txt
	movi	$a1,SCORE_LEFT
	movi	$a2,SCORE_TOP+SCORE_TXTHEIGHT*2
	movi	$a3,0xffff
	_JAL	PrintString

	_LI	$t0,Level
	_LW	$a0,0($t0)
	movi	$a1,SCORE_LEFT+SCORE_WIDTH-4
	movi	$a2,SCORE_TOP+SCORE_TXTHEIGHT*2
	movi	$a3,0xffff
	_JAL	PrintNumber16
	POP	$a3
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS

DrawCurrentPiece:
	; a0 = X pos
	; a1 = Y Pos
	PUSH	$ra			; Store to stack
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4
	_LI	$t0,Piece_Pos
	_LW	$s0,0($t0)
	_LW	$s1,1($t0)
	_LI	$s2,Current_Piece	; Piece address
	movi	$s3,0			; X = 0
	movi	$s4,0			; Y = 0
PieceLoop:
	_LW	$t0,0($s2)		;
	_BEQZ	$t0,BitNotSet		; Is bit set ? No, BitNotSet
	mov	$a0,$s3			; a0 = X Count
	add	$a0,$a0,$s0		; a0 = a0 + X pos
	sll	$a0,$a0,3		; a0 = a0 * 8
	addi	$a0,$a0,BOARD_LEFT	; a0 = a0 + LeftPos
	mov	$a1,$s4			; s1 = Y Count
	add	$a1,$a1,$s1		; s0 = s0 + Y pos
	sll	$a1,$a1,3		; s1 = s1 * 8
	addi	$a1,$a1,BOARD_TOP	; s0 = s0 + TopPos
	_LI	$t0,Current_Piece_Color
	_LW	$a2,0($t0)		; s2 = Color
	_JAL	DrawPieceBox		; DrawBox
BitNotSet:
	addi	$s2,$s2,1		; Piece Address++
	addi	$s3,$s3,1		; X = X + 1
	andi	$s3,$s3,0x0003		; X = X & 0x0003
	_BNEZ	$s3,PieceLoop		; X = 0 ? No, PieceLoop
	addi	$s4,$s4,1		; Y = Y + 1
	andi	$s4,$s4,0x0003		; Y = Y & 0x0003
	_BNEZ	$s4,PieceLoop		; Y = 0 ? No, PieceLoop
	POP	$s4			; Get from stack
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS				; Return from subroutine

DrawBox:
	; a0 = x pos
	; a1 = y pos
	; a2 = color
	PUSH	$ra

	_JAL	GetWorkScreen
	mov	$t1,$v0
	srl	$t0,$a0,1		; X / 2
	add	$t1,$t1,$t0		; add X offset
	sll	$t3,$a2,16
	or	$t3,$t3,$a2
	sll	$t0,$a1,7		; Y * 128
	add	$t1,$t1,$t0
	sll	$t0,$a1,5		; Y * 32
	add	$t1,$t1,$t0
	movi	$t2,8			; RowCount = 8
DrawBox_Loop:
	sw	$t3,0($t1)		; Two pixels  X + 0 , X + 1
	sw	$t3,1($t1)		; Two pixels  X + 2 , X + 3
	sw	$t3,2($t1)		; Two pixels  X + 4 , X + 5
	sw	$t3,3($t1)		; Two pixels  X + 6 , X + 7
	addi	$t1,$t1,160		; Add one row
	addi	$t2,$t2,-1		; Dec RowCount
	_BNEZ	$t2,DrawBox_Loop	; Row Count = 0 ? No, BoxLoop

	POP	$ra
	_RTS				; Return from subroutine

CopyBox:
	; a0 = x pos
	; a1 = y pos
	; a2 = color
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	_LI	$t1,BoardBKG
	addi	$s0,$a0,-[BOARD_LEFT+8]
	addi	$s1,$a1,-[BOARD_TOP+8]
	srl	$t0,$s0,1		; X / 2
	add	$t1,$t1,$t0		; add X offset
	sll	$t0,$s1,5		; Y * 32
	add	$t1,$t1,$t0
	sll	$t0,$s1,3		; Y * 8
	add	$s0,$t1,$t0
	_JAL	GetWorkScreen
	mov	$t1,$v0
	srl	$t0,$a0,1		; X / 2
	add	$t1,$t1,$t0		; add X offset
	sll	$t0,$a1,7		; Y * 128
	add	$t1,$t1,$t0
	sll	$t0,$a1,5		; Y * 32
	add	$s1,$t1,$t0
	movi	$t9,8			; RowCount = 8
CopyBox_Loop:
	lw	$t0,0($s0)
	nop
	lw	$t1,1($s0)
	nop
	lw	$t2,2($s0)
	nop
	lw	$t3,3($s0)
	nop
	sw	$t0,0($s1)		; Two pixels  X + 0 , X + 1
	sw	$t1,1($s1)		; Two pixels  X + 2 , X + 3
	sw	$t2,2($s1)		; Two pixels  X + 4 , X + 5
	sw	$t3,3($s1)		; Two pixels  X + 6 , X + 7
	addi	$s0,$s0,40
	addi	$s1,$s1,160		; Add one row
	addi	$t9,$t9,-1		; Dec RowCount
	_BNEZ	$t9,CopyBox_Loop	; Row Count = 0 ? No, BoxLoop
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS				; Return from subroutine

DrawPieceBox:
	; a0 = X pos
	; a1 = Y Pos
	; a2 = TextureData
	PUSH	$ra

	_JAL	GetWorkScreen
	mov	$t1,$v0
	srl	$t0,$a0,1		; X / 2
	add	$t1,$t1,$t0		; add X offset
	sll	$t0,$a1,7		; Y * 128
	add	$t1,$t1,$t0
	sll	$t0,$a1,5		; Y * 32
	add	$t6,$t1,$t0		; screenpointer in t6
	mov	$t7,$a2			; mappingpointer in t7
	movi	$t8,8			; RowCount = 8
DrawPieceBox_Loop:
	lw	$t0,0($t7)
	nop
	lw	$t1,1($t7)
	nop
	lw	$t2,2($t7)
	nop
	lw	$t3,3($t7)
	nop
	sw	$t0,0($t6)		; Two pixels  X + 0 , X + 1
	sw	$t1,1($t6)		; Two pixels  X + 2 , X + 3
	sw	$t2,2($t6)		; Two pixels  X + 4 , X + 5
	sw	$t3,3($t6)		; Two pixels  X + 6 , X + 7
	addi	$t6,$t6,160		; Add one row
	addi	$t7,$t7,4		; Add one row
	addi	$t8,$t8,-1		; Dec RowCount
	_BNEZ	$t8,DrawPieceBox_Loop	; Row Count = 0 ? No, BoxLoop

	POP	$ra
	_RTS				; Return from subroutine

ClearBox:
	; a0 - Start Address
	; a1 = BoxWidtht
	; a2 = ScreenWidth
	; a3 = BoxHeight
	mov	$t0,$a0
	mov	$t2,$a2
	sub	$t2,$t2,$a1
	mov	$t3,$a3
ClearBox_RowLoop:
	mov	$t1,$a1
ClearBox_ColLoop:
	sw	$zero,0($t0)
	addi	$t0,$t0,1
	addi	$t1,$t1,-1
	_BNEZ	$t1,ClearBox_ColLoop
	add	$t0,$t0,$t2
	addi	$t3,$t3,-1
	_BNEZ	$t3,ClearBox_RowLoop
	_RTS

####################
# TetrIC Functions #
####################

GetScore:
	_LI	$t0,Score
	_LW	$v0,0($t0)
	_RTS

GetLevel:
	_LI	$t0,Level
	_LW	$v0,0($t0)
	_RTS

InitBoard:
	; a0 = starthieght
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3

	_LI	$t0,Tetris_Board		; Get Board pointer
	addi	$t0,$t0,13			; Add top row and left col

	movi	$t1,20				; 20 rows to clear
ClearBoard_Loop:
	_SW	$zero,0($t0)
	_SW	$zero,1($t0)
	_SW	$zero,2($t0)
	_SW	$zero,3($t0)
	_SW	$zero,4($t0)
	_SW	$zero,5($t0)
	_SW	$zero,6($t0)
	_SW	$zero,7($t0)
	_SW	$zero,8($t0)
	_SW	$zero,9($t0)
	addi	$t0,$t0,12			; Next row
	addi	$t1,$t1,-1			; Row=Row-1
	_BNEZ	$t1,ClearBoard_Loop		; Are we done ?

	_BEQZ	$a0,InitBoard_Done		; Do we have a startheight ?
	mov	$s0,$a0

	_LI	$s2,Tetris_Board		; Get baord pointer
	addi	$s2,$s2,12*20+1			; And point at the bottom row
StartHeight_Loop:
	_JAL	Rnd				; Get random number
	mov	$a0,$v0				; Number of filled blocks in this row
	movi	$a1,6
	_JAL	Divu16
	mov	$s1,$v1
	addi	$s1,$s1,3			; s1 = Rnd(3,8)
RowFill_Loop:
	_JAL	Rnd				; Get random number
	mov	$a0,$v0				; Which block in row to be filled
	movi	$a1,10
	_JAL	Divu16
	mov	$s3,$v1				; s3 = Rnd(0,9)
	add	$s3,$s3,$s2
	_LW	$t1,0($s3)			; Is this one set already ?
	_BNEZ	$t1,RowFill_Loop		; Yes, get new rnadom value

	_JAL	Rnd				; Get random number
	mov	$a0,$v0				; Which block to fill with
	movi	$a1,7
	_JAL	Divu16
	_LI	$t0,BlockPointer_Array		; Rnd(0,6)
	add	$t0,$t0,$v1
	_LW	$t1,0($t0)			; Get block pointer
	_SW	$t1,0($s3)			; Store in board

	addi	$s1,$s1,-1			; Fill=Fill-1
	_BNEZ	$s1,RowFill_Loop		; Are we done ?

	addi	$s2,$s2,-12			; One row up in board
	addi	$s0,$s0,-1			; Row=Row-1
	_BNEZ	$s0,StartHeight_Loop		; Are we done ?

InitBoard_Done:
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS

AddScore:
	_LI	$t0,Score			; Get Score
	_LW	$t1,0($t0)

	movi	$t4,20

	_LI	$t2,Piece_Pos			; DropHeight Points (1 * DropHeight)
	_LW	$t3,1($t2)			;
	sub	$t4,$t4,$t3

	_LI	$t2,Current_Piece_ScoreDiff
	_LW	$t3,0($t2)
	sub	$t4,$t4,$t3

	_LI	$t2,Level			; Level Points (3 * Level)
	_LW	$t3,0($t2)			; 1 * Level
	sll	$t2,$t3,1			; + 2 * Level
	add	$t3,$t3,$t2			; = 3 * Level
	add	$t4,$t4,$t3

	_LI	$t2,ShowNextPiece
	_LW	$t3,0($t2)
	_BNEZ	$t3,CheatModeOn
	addi	$t4,$t4,5			; Cheat Mode OFF Points (5)
CheatModeOn:					;
	add	$t1,$t1,$t4
	_SW	$t1,0($t0)

	_RTS

CheckLevel:
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$s0
	PUSH	$s1

	_LI	$t0,LineCount
	_LW	$t1,0($t0)

	_LI	$s0,Level
	_LW	$s1,0($s0)

	movi	$t0,9
	_BEQ	$t0,$s1,NoHigherLevel

	mov	$a0,$t1
	movi	$a1,10
	_JAL	Divu16		; _JAL Divu8

	_BGE	$s1,$v0,NoHigherLevel

	_BEQZ	$v1,NoHigherLevel

	addi	$s1,$s1,1
	_SW	$s1,0($s0)

	movi	$a0,FX_GAME_CHANGELEVEL
	_JAL	PlaySampleCh2

NoHigherLevel:
	POP	$s1
	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS


RemoveFullRows:
	PUSH	$ra
	PUSH	$a0
	PUSH	$s0
	PUSH	$s1

	_LI	$s0,RemoveRow_Array

	clr	$s1

	movi	$a0,20
RowLoop:
	addi	$a0,$a0,-1
	_JAL	TestRow
	_BEQZ	$v0,NotThisRow

	_SW	$a0,0($s0)
	addi	$s0,$s0,1
	addi	$s1,$s1,1
NotThisRow:
	_BNEZ	$a0,RowLoop

	_BEQZ	$s1,NoFullRows

	movi	$a0,FX_GAME_ROW
	_JAL	PlaySampleCh1

	mov	$a0,$s1
	_JAL	RemoveRowsGfx

	_LI	$t0,LineCount	; Add one line to linecount
	_LW	$t1,0($t0)
	add	$t1,$t1,$s1
	_SW	$t1,0($t0)

	movi	$t0,4
	_BNE	$t0,$s1,NoQuadEffect

	_JAL	TestWeight		; Test weight above quad
	_BEQZ	$v0,NoQuadEffect	; Zero ? Then ther is nothing to see
	mov	$s0,$v0			; Store weigt result
	_JAL	QuadGfx			; Drop slowly

	movi	$a0,FX_GAME_QUAD
	_JAL	PlaySampleCh1

	slti	$t0,$s0,8		; Less than eight in weight ?
	_BNEZ	$t0,NoQuadEffect	; Then dont shake
	_LI	$t0,ShakePointer	; And shake some
	_SW	$zero,0($t0)
NoQuadEffect:
	mov	$a0,$s1
	_JAL	RemoveRows

NoFullRows:
	POP	$s1
	POP	$s0
	POP	$a0
	POP	$ra
	_RTS

TestWeight:
	clr	$v0			; Default Not Enough weight

	_LI	$t0,Tetris_Board	; Get Board
	addi	$t0,$t0,13		; Not visible top roof

	_LI	$t1,RemoveRow_Array
	_LW	$t9,3($t1)		; Last Row Number
	_BEQZ	$t9,TestWeight_NoWeight
TestWeight_RowLoop:
	movi	$t8,10
TestWeight_ColLoop:
	_LW	$t1,0($t0)
	_BEQZ	$t1,TestWeight_NotSet
	addi	$v0,$v0,1
TestWeight_NotSet:
	addi	$t0,$t0,1
	addi	$t8,$t8,-1
	_BNEZ	$t8,TestWeight_ColLoop
	addi	$t0,$t0,2
	addi	$t9,$t9,-1
	_BNEZ	$t9,TestWeight_RowLoop
TestWeight_NoWeight:
	_RTS

ShakeBoard:
	_LI	$t0,ShakeSin
	_LI	$t1,ShakePointer
	_LW	$t2,0($t1)
	slti	$t3,$t2,63
	add	$t2,$t2,$t3
	_SW	$t2,0($t1)
	add	$t0,$t0,$t2
	_LW	$t1,0($t0)			; 0..10 lines down (PAL: + 30 top margin)
	_SW	$t1,GFX_TOPPOS($gfx)
	_RTS

TestRow:
	movi	$v0,0			; Default not full

	_LI	$t0,Tetris_Board	; Get Board
	addi	$t0,$t0,12		; Not visible top roof
	sll	$t1,$a0,3		; Row * 12
	add	$t0,$t0,$t1		;
	sll	$t1,$a0,2		;
	add	$t0,$t0,$t1		;
	addi	$t0,$t0,1		; Not first col

	movi	$t1,10			; Check next 10
TestRowLoop:
	_LW	$t2,0($t0)		; What is this ?
	_BEQZ	$t2,TestRowExit		; Zero ? Not full

	addi	$t0,$t0,1		; Next
	addi	$t1,$t1,-1		; And less to go

	_BNEZ	$t1,TestRowLoop		; Are we done ?

	movi	$v0,1			; Return 1 for full

TestRowExit:
	_RTS

RemoveRows:
	; a0 = number of rows to disappear
	_LI	$t0,RemoveRow_Array
	clr	$t9
RemoveRows_RowLoop:
	_LW	$t2,0($t0)		; Get First Row to dissapear
	add	$t2,$t2,$t9		; Subtract already removed rows
RemoveRows_CopyLoop:
	_LI	$t1,Tetris_Board	; Get board
	addi	$t1,$t1,13		; Not first row
	addi	$t2,$t2,-1		; Row - 1
	sll	$t3,$t2,3		; Row * 8
	add	$t1,$t1,$t3
	sll	$t3,$t2,2		; Row * 4
	add	$t1,$t1,$t3		; = Row * 12

	movi	$t8,10			; 10 pieces
RemoveRows_LineLoop:
	_LW	$t3,0($t1)		; Copy from the row above
	_SW	$t3,12($t1)		; And store on this row
	addi	$t1,$t1,1		; Next piece
	addi	$t8,$t8,-1		; One less to go
	_BNEZ	$t8,RemoveRows_LineLoop	; Are we done with this line
	_BNEZ	$t2,RemoveRows_CopyLoop ; Are we done with this Block ?

	_LI	$t1,Tetris_Board	; Get Board
	addi	$t1,$t1,13		; Not first row
	movi	$t8,10			; 10 pieces
RemoveRows_TopLoop:
	sw	$zero,0($t1)		; Store zeros in the top row
	addi	$t1,$t1,1		; Next piece
	addi	$t8,$t8,-1		; one less to go
	_BNEZ	$t8,RemoveRows_TopLoop	; Are we done with the top line

	addi	$t0,$t0,1			; Next Rows to delete
	addi	$t9,$t9,1			; Rows + 1
	_BNE	$t9,$a0,RemoveRows_RowLoop	; Are we done with all rows

RemoveRows_Done:
	_RTS

SetFallSpeed:
	_LI	$t0,Level_FallSpeed_Array
	_LI	$t1,Level
	_LW	$t2,0($t1)
	add	$t0,$t0,$t2
	_LW	$t1,0($t0)
	_LI	$t0,FallSpeed
	_SW	$t1,0($t0)
	_RTS

PieceFall:
	PUSH	$ra
	PUSH	$s0

	_LI	$s0,FallSpeed
	_LW	$t0,0($s0)
	addi	$t0,$t0,-1
	_SW	$t0,0($s0)
	_BNEZ	$t0,PieceFallExit
	_JAL	SetFallSpeed

	_JAL	DropOne
	_BNEZ	$v0,PieceFallExit

	_JAL	AddScore
	_JAL	PutDownPiece

PieceFallExit:
	POP	$s0
	POP	$ra

	_RTS

DropOne:
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2
	PUSH	$s0

	_LI	$s0,Piece_Pos
	_LW	$a1,0($s0)
	_LW	$a2,1($s0)
	addi	$a2,$a2,1
	_SW	$a2,1($s0)

	_LI	$a0,Current_Piece
	_JAL	TestPiece
	_BNEZ	$v0,DropExit
	addi	$a2,$a2,-1
	_SW	$a2,1($s0)

DropExit:
	POP	$s0
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra

	_RTS				; Return from subroutine

PutDownPiece:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3

	_LI	$s0,Piece_Pos
	_LW	$t0,0($s0)
	_LW	$t1,1($s0)

	_LI	$s0,Current_Piece

	_LI	$s1,Tetris_Board
	add	$s1,$s1,$t0
	sll	$t2,$t1,3
	add	$s1,$s1,$t2
	sll	$t2,$t1,2
	add	$s1,$s1,$t2

	_LI	$t0,Current_Piece_color	;Get Current Piece Color
	_LW	$t1,0($t0)

	movi	$s2,4
PutDown_OuterLoop:
	movi	$s3,4
PutDown_InnerLoop:
	_LW	$t0,0($s0)
	_BEQZ	$t0,PutDown_BitNotSet
	_SW	$t1,0($s1)
PutDown_BitNotSet:
	addi	$s0,$s0,1
	addi	$s1,$s1,1

	addi	$s3,$s3,-1
	_BNEZ	$s3,PutDown_InnerLoop

	addi	$s1,$s1,8

	addi	$s2,$s2,-1
	_BNEZ	$s2,PutDown_OuterLoop

	_JAL	RemoveFullRows
	_JAL	CheckLevel

	_JAL	GetRandomPiece
	_BNEZ	$v0,PutDownExit

	_LI	$t0,GameOver
	movi	$t1,1
	_SW	$t1,0($t0)
PutDownExit:
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra

	_RTS				; Return from subroutine


TestPiece:
	; a0 = TestPiece
	; a1 = Test X Pos
	; a2 = Test Y Pos
	; v0 = 0 if Fail, 1 if OK

	movi	$v0,0
	mov	$t0,$a0

	_LI	$t1,Tetris_Board
	add	$t1,$t1,$a1
	sll	$t2,$a2,3
	add	$t1,$t1,$t2
	sll	$t2,$a2,2
	add	$t1,$t1,$t2

	movi	$t2,4
Test_OuterLoop:
	movi	$t3,4
Test_InnerLoop:
	_LW	$t6,0($t0)
	_LW	$t5,0($t1)
	_BEQZ	$t5,Test_BitNotSet

	_BNEZ	$t6,Test_Exit

Test_BitNotSet:
	addi	$t0,$t0,1
	addi	$t1,$t1,1

	addi	$t3,$t3,-1
	_BNEZ	$t3,Test_InnerLoop

	addi	$t1,$t1,8

	addi	$t2,$t2,-1
	_BNEZ	$t2,Test_OuterLoop
	movi	$v0,1

Test_Exit:
	_RTS				; Return from subroutine

GetRandomPiece:
	PUSH	$ra			; Store to stack
	PUSH	$a0
	PUSH	$a1
	PUSH	$s0
	PUSH	$s1

	_JAL	SetFallSpeed		; Initiate fallspeed

	_JAL	Rnd			; Get Random number
	mov	$a0,$v0			; Next Piece
	movi	$a1,7
	_JAL	Divu16			; Rnd(0,6)

	# Debug
	# movi	$v1,1 ; Only red ones

	_LI	$t0,NextPieceNumber
	_LW	$t1,0($t0)		; Get ThisPieceNumber
	_SW	$v1,0($t0)		; Store NextPieceNumber

	_LI	$t2,Stat
	add	$t2,$t2,$t1		; Get current piece
	_LW	$t3,0($t2)
	addi	$t3,$t3,1		; Add 1 to the current piece count
	_SW	$t3,0($t2)

	_LI	$s0,Piece_Array		; Piece Array address
	add	$s0,$s0,$t1
	_LW	$a0,0($s0)		; Get Piece pointer
	_LI	$a1,Current_Piece	; Current Pice address Destination Piece
	_JAL	CopyPiece		; Copy Piece t0,t1,t2,t3

	_LI	$t1,Current_Piece_Size		; Calc Piece start pos X
	_LW	$t0,0($t1)			; Get Piece width
	srl	$t0,$t0,1			; (Width / 2)
	neg	$t0,$t0				; - (Width / 2)
	addi	$t0,$t0,5			; 5 - (Width / 2)
	addi	$t0,$t0,1			; 1 + 5 - (Width / 2)
	_LI	$t2,Current_Piece_StartDiff	; Calc Piece start pos Y
	_LW	$t1,0($t2)			; Get Piece startheight
	_LI	$s0,Piece_Pos			; Write to piece position
	_SW	$t0,0($s0)
	_SW	$t1,1($s0)

	_LI	$a0,Current_Piece	; Current Piece address Destination Piece
	mov	$a1,$t0
	mov	$a2,$t1
	_JAL	TestPiece

	POP	$s1
	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra

	_RTS				; Return from subroutine

CopyPiece:
	; a0 = Source Piece
	; a1 = Destination Piece

	PUSH	$a0
	PUSH	$a1
	PUSH	$s0
	PUSH	$s1

	movi	$s0,PIECE_SIZETOTAL	; Copy the size of a Piece struct
CopyLoop:
	_LW	$s1,0($a0)		; Load from source
	addi	$a0,$a0,1		; Inc source adddress
	_SW	$s1,0($a1)		; Store to destination
	addi	$a1,$a1,1		; Inc destination address

	addi	$s0,$s0,-1		; Dec words to copy
	_BNEZ	$s0,CopyLoop		; Finished ? CopyLoop

	POP	$s1
	POP	$s0
	POP	$a1
	POP	$a0

	_RTS				; Return from subroutine

SoftDrop:
	PUSH	$ra
	_JAL	SetFallSpeed

	_JAL	DropOne			; Gravity on the TetrisBlock
	_BNEZ	$v0,SoftDropExit
	_JAL	AddScore
	_JAL	PutDownPiece
SoftDropExit:
	POP	$ra
	_RTS				; Return from subroutine

HardDrop:
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2
	PUSH	$s0

	movi	$a0,FX_GAME_DROP
	_JAL	PlaySampleCh1

	_JAL	AddScore
	_JAL	SetFallSpeed
DropLoop:
	_JAL	DropOne
	_BNEZ	$v0,DropLoop
	_JAL	PutDownPiece

	POP	$s0
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra

	_RTS				; Return from subroutine

MoveLeft:
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2
	PUSH	$s0

	_LI	$s0,Piece_Pos
	_LW	$a1,0($s0)
	_LW	$a2,1($s0)
	addi	$a1,$a1,-1

	_LI	$a0,Current_Piece
	_JAL	TestPiece
	_BEQZ	$v0,MoveLeft_NotOK

	_SW	$a1,0($s0)
MoveLeft_NotOK:
	POP	$s0
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra

	_RTS				; Return from subroutine

MoveRight:
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2
	PUSH	$s0

	_LI	$s0,Piece_Pos
	_LW	$a1,0($s0)
	_LW	$a2,1($s0)
	addi	$a1,$a1,1

	_LI	$a0,Current_Piece
	_JAL	TestPiece
	_BEQZ	$v0,MoveRight_NotOK

	_SW	$a1,0($s0)
MoveRight_NotOK:
	POP	$s0
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra

	_RTS				; Return from subroutine

RotateCW:
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2

	_JAL	RotatePiece_CW

	_LI	$a0,Temp_Piece
	_LI	$t0,Piece_Pos
	_LW	$a1,0($t0)
	_LW	$a2,1($t0)

	_JAL	TestPiece
	_BEQZ	$v0,RotateCW_NotOK

	_LI	$a0,Temp_Piece
	_LI	$a1,Current_Piece
	_JAL	CopyPiece

	movi	$a0,FX_GAME_ROTATE
	_JAL	PlaySampleCh1

RotateCW_NotOK:
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra

	_RTS				; Return from subroutine

RotateCCW:
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$a2

	_JAL	RotatePiece_CCW

	_LI	$a0,Temp_Piece
	_LI	$t0,Piece_Pos
	_LW	$a1,0($t0)
	_LW	$a2,1($t0)

	_JAL	TestPiece
	_BEQZ	$v0,RotateCCW_NotOK

	_LI	$a0,Temp_Piece
	_LI	$a1,Current_Piece
	_JAL	CopyPiece

	movi	$a0,FX_GAME_ROTATE
	_JAL	PlaySampleCh1

RotateCCW_NotOK:
	POP	$a2
	POP	$a1
	POP	$a0
	POP	$ra

	_RTS				; Return from subroutine

PrepareRotate:
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2

	_LI	$s0,Current_Piece_ExtraData
	_LI	$s1,Temp_Piece_ExtraData
	movi	$s2,PIECE_SIZEEXTRADATA
PrepareRotate_Loop:
	_LW	$t0,0($s0)
	_SW	$t0,0($s1)
	addi	$s0,$s0,1
	addi	$s1,$s1,1
	addi	$s2,$s2,-1
	_BNEZ	$s2,PrepareRotate_Loop

	_LI	$s0,Current_Piece_ScoreDiff	; Rotate ScoreDiff
	_LI	$s1,Temp_Piece_ScoreDiff

	_LW	$t0,1($s0)
	_SW	$t0,0($s1)
	_LW	$t0,0($s0)
	_SW	$t0,1($s1)

	_LI	$s0,Current_Piece_Size		; Rotate PieceSize
	_LI	$s1,Temp_Piece_Size

	_LW	$t0,0($s0)
	_SW	$t0,1($s1)
	_LW	$t0,1($s0)
	_SW	$t0,0($s1)

	POP	$s2
	POP	$s1
	POP	$s0

	_RTS

RotatePiece_CW:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4

	_JAL	PrepareRotate

	_LI	$s0,Current_Piece_Size		; Get Piece height
	_LW	$t0,1($s0)
	mov	$s2,$t0

	_LI	$s0,Temp_Piece
	movi	$s3,16
Clear_Temp_CW:
	_SW	$zero,0($s0)
	addi	$s0,$s0,1
	addi	$s3,$s3,-1
	_BNEZ	$s3,Clear_Temp_CW

	; for (x=4;x=0,--x) {
	;   for (y=height,y=0,--y) {
	;     temp_piece(hieght-y-1,x) = current_piece(x,y)
	;   }
	; }

	movi	$s3,4		; X=4
Col_Loop_CW:
	mov	$s4,$s2		; Y=Height
	addi	$s3,$s3,-1	; --X
Row_Loop_CW:
	addi	$s4,$s4,-1	; --Y

	_LI	$s0,Current_Piece
	_LI	$s1,Temp_Piece

				; Current_Piece(x,y)
	add	$s0,$s0,$s3	; add X
	sll	$t0,$s4,2	; 4 * Y
	add	$s0,$s0,$t0	; add 4 * Y

				; Temp_Piece(height-y-1,x)
	mov	$t0,$s2		; Height
	sub	$t0,$t0,$s4	; -Y
	addi	$t0,$t0,-1	; -1
	add	$s1,$s1,$t0	; Add Height-Y-1
	sll	$t0,$s3,2	; 4 * X
	add	$s1,$s1,$t0	; Add 4 * X

	_LW	$t0,0($s0)
	_SW	$t0,0($s1)

	_BNEZ	$s4,Row_Loop_CW
	_BNEZ	$s3,Col_Loop_CW

	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra

	_RTS				; Return from subroutine

RotatePiece_CCW:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4

	_JAL	PrepareRotate

	_LI	$s0,Current_Piece_Size	; Get Piece width
	_LW	$t0,0($s0)
	mov	$s2,$t0

	_LI	$s0,Temp_Piece
	movi	$s3,16

Clear_Temp_CCW:
	_SW	$zero,0($s0)
	addi	$s0,$s0,1
	addi	$s3,$s3,-1
	_BNEZ	$s3,Clear_Temp_CCW

	; for (x=width;x=0,--x) {
	;   for (y=4,y=0,--y) {
	;     temp_piece(y,height-x-1) = current_piece(x,y)
	;   }
	; }

	mov	$s3,$s2		; X=width
Col_Loop_CCW:
	movi	$s4,4		; Y=4
	addi	$s3,$s3,-1	; --X
Row_Loop_CCW:
	addi	$s4,$s4,-1	; --Y

	_LI	$s0,Current_Piece
	_LI	$s1,Temp_Piece

				; Current_Piece(x,y)
	add	$s0,$s0,$s3	; add X
	sll	$t0,$s4,2	; 4 * Y
	add	$s0,$s0,$t0	; add 4 * Y

				; Temp_Piece(y,width-x-1)
	add	$s1,$s1,$s4	; add Y
	mov	$t0,$s2		; width
	sub	$t0,$t0,$s3	; -X
	addi	$t0,$t0,-1	; -1
	sll	$t0,$t0,2	; 4*(width-X-1)
	add	$s1,$s1,$t0	; add 4*(width-X-1)

	_LW	$t0,0($s0)
	_SW	$t0,0($s1)

	_BNEZ	$s4,Row_Loop_CCW
	_BNEZ	$s3,Col_Loop_CCW

	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra

	_RTS				; Return from subroutine

###############
# TetrIC DATA #
###############

Stat:			.dc	0,0,0,0,0,0,0
			.dc	0x029c,0xe1c0,0x067c,0xe031,0xaf20,0x072a,0xdba0

FallSpeed:		.dc	0
Score:			.dc	0
LineCount:		.dc	0
Level:			.dc	0
NextPieceNumber:	.dc	0
ShowNextPiece:		.dc	0
RemoveRow_Array:	.dc	0,0,0,0

Level_FallSpeed_Array:	.dc	15,14,12,11,9,8,6,5,4,2 ; frames at 30 Hz (50 Hz: 25,23,20,18,15,13,10,8,6,4)
BlockPointer_Array:	.dc	BlockGfx1,BlockGfx2,BlockGfx7,BlockGfx5,BlockGfx6,BlockGfx3,BlockGfx4

Piece_Pos:		.dc	0,0

Current_Piece:		.dc	0,0,0,0
			.dc	0,0,0,0
			.dc	0,0,0,0
			.dc	0,0,0,0
Current_Piece_Size:	.dc	0,0
Current_Piece_ScoreDiff:	.dc	0,0
Current_Piece_ExtraData:
Current_Piece_StartDiff:	.dc	0
Current_Piece_Color:	.dc	0

Temp_Piece:		.dc	0,0,0,0
			.dc	0,0,0,0
			.dc	0,0,0,0
			.dc	0,0,0,0
Temp_Piece_Size:	.dc	0,0
Temp_Piece_ScoreDiff:	.dc	0,0
Temp_Piece_ExtraData:
Temp_Piece_StartDiff:	.dc	0
Temp_Piece_Color:	.dc	0

Piece_Array:
	.dc	PieceO,PieceI,PieceZ,PieceS,PieceL,PieceJ,PieceT

PIECE_DATA = 0			; The 4x4 matrix that describes the piece
PIECE_SIZE = 16			; 4x4 = 16
PIECE_SCOREDIFF = 18		; Scorediff position in array
PIECE_STARTDIFF = 20		; Startdiff position in array
PIECE_COLOR = 21		; PieceColor position in array
PIECE_HORDIFF = 22		; Horizontal slide for showing nextpiece
PIECE_VERDIFF = 23		; Vertical slide for showing nextpiece
PIECE_SIZETOTAL = 24		; The total size of the array
PIECE_SIZEEXTRADATA = 2		; SCOREDIFF and STARTDIFF size

PieceO:
	.dc	1,1,0,0
	.dc	1,1,0,0
	.dc	0,0,0,0
	.dc	0,0,0,0

	.dc	2,2
	.dc	0,0
	.dc	1
	.dc	BlockGfx2
	.dc	8,8

PieceI:
	.dc	0,0,0,0
	.dc	1,1,1,1
	.dc	0,0,0,0
	.dc	0,0,0,0

	.dc	4,3
	.dc	1,1
	.dc	0
	.dc	BlockGfx1
	.dc	0,4

PieceZ:
	.dc	1,1,0,0
	.dc	0,1,1,0
	.dc	0,0,0,0
	.dc	0,0,0,0

	.dc	3,2
	.dc	0,1
	.dc	1
	.dc	BlockGfx4
	.dc	4,8

PieceS:
	.dc	0,1,1,0
	.dc	1,1,0,0
	.dc	0,0,0,0
	.dc	0,0,0,0

	.dc	3,2
	.dc	0,1
	.dc	1
	.dc	BlockGfx5
	.dc	4,8

PieceL:
	.dc	0,0,0,0
	.dc	1,1,1,0
	.dc	1,0,0,0
	.dc	0,0,0,0

	.dc	3,3
	.dc	1,1
	.dc	0
	.dc	BlockGfx6
	.dc	4,0

PieceJ:
	.dc	0,0,0,0
	.dc	1,1,1,0
	.dc	0,0,1,0
	.dc	0,0,0,0

	.dc	3,3
	.dc	1,1
	.dc	0
	.dc	BlockGfx3
	.dc	4,0

PieceT:
	.dc	0,0,0,0
	.dc	1,1,1,0
	.dc	0,1,0,0
	.dc	0,0,0,0

	.dc	3,3
	.dc	1,1
	.dc	0
	.dc	BlockGfx7
	.dc	4,0

Tetris_Board:
	.dc	1,1,1,1,1,1,1,1,1,1,1,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1

	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,0,0,0,0,0,0,0,0,0,0,1
	.dc	1,1,1,1,1,1,1,1,1,1,1,1

########
# Text #
########

NextPiece_Txt:	.ascii	"Next Piece"
Statistics_Txt:	.ascii	"Statistics"
Score_Txt:	.ascii	"Score"
Lines_Txt:	.ascii	"Lines"
Level_Txt:	.ascii	"Level"

#################
# Stolen Blocks #
#################

BlockGfx1:	.file	Data/img_blockred.raw 32
BlockGfx2:	.file	Data/img_blockblue.raw 32
BlockGfx3:	.file	Data/img_blockgreen.raw 32
BlockGfx4:	.file	Data/img_blockcyan.raw 32
BlockGfx5:	.file	Data/img_blockpink.raw 32
BlockGfx6:	.file	Data/img_blockyellow.raw 32
BlockGfx7:	.file	Data/img_blockorange.raw 32

##############
# Background #
##############

TetrisPic:	.file	Data/img_kremlin320x256x8c.raw 20480
TetrisPal	.file	Data/img_kremlin320x256x8c.pal 128

##############
# ShakeTable #
##############

ShakeSin:	.file	Data/data_shakesin.raw 64
ShakePointer:	.dc	63

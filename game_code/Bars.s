Bars:
	PUSH	$ra

	movi	$t0,8*64		; 128 wide screen: skip 8 lines
	_STA	$t0,ScrOffset
	_JAL	WaitNextFrame
	; DVI: 128 pixels stretched to the full width (PAL: 10 clocks/pixel)
	movi	$t0, 0
	nop			; hazard
	nop			; hazard
	_SW	$t0, GFX_TOPPOS($gfx)
	movi	$t0, 0
	nop			; hazard
	nop			; hazard
	_SW	$t0, GFX_LEFTPOS($gfx)
	movi	$t0, 128
	nop			; hazard
	nop			; hazard
	_SW	$t0, GFX_WIDTH($gfx)
	movi	$t0, 240
	nop			; hazard
	nop			; hazard
	_SW	$t0, GFX_HEIGHT($gfx)
	movi	$t0, 5			; 128 x 5 = 640 DVI pixels
	nop			; hazard
	nop			; hazard
	_SW	$t0, GFX_PIXREAD($gfx)
	movi	$t0, 0
	nop			; hazard
	nop			; hazard
	_SW	$t0, GFX_DELTA($gfx)

	_LI	$t0,JoyRepeatWait
	_LI	$t1,0x000000			; Filter = 0, RepeatVal = 0, Accelerate = 0
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

BarsLoop:
	_JAL	WaitNextFrame		; show the drawn screen (was: draw into the shown one)
	_JAL	ClearBarsScreen
	_JAL	DrawBars
	_JAL	CheckJoystick

	andi	$t0,$v0,0xd2	; any button
	_BEQZ	$t0,BarsLoop

	POP	$ra
	_RTS

ClearBarsScreen:
	PUSH	$ra
	_JAL	GetWorkScreen		; draw into the hidden screen (double buffered)
	mov	$t1,$v0
	movi	$t0,256
ClearBarsScreen_RowLoop:
	movi	$t2,8
ClearBarsScreen_ColLoop:
	sw	$zero,0($t1)
	sw	$zero,1($t1)
	sw	$zero,2($t1)
	sw	$zero,3($t1)
	sw	$zero,4($t1)
	sw	$zero,5($t1)
	sw	$zero,6($t1)
	sw	$zero,7($t1)
	addi	$t1,$t1,8
	addi	$t2,$t2,-1
	_BNEZ	$t2,ClearBarsScreen_ColLoop
	addi	$t0,$t0,-1
	_BNEZ	$t0,ClearBarsScreen_RowLoop
	POP	$ra
	_RTS


DrawBars:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s4
	PUSH	$s5
	PUSH	$s6
	PUSH	$s7

	_LI	$s0,BarList
	_LDA	$s1,BarAngle
	nop			; hazard
	addi	$s1,$s1,BAR_ANGLE_DELTA
	_STA	$s1,BarAngle

	_LI	$s0,BarZ
	movi	$s7,NOF_BARS
DrawBars_GetZ:
	mov	$a0,$s1
	_JAL	Sin
	_SW	$v0,0($s0)
	addi	$s1,$s1,ANGLE_BETWEEN_BAR
	addi	$s0,$s0,1
	addi	$s7,$s7,-1
	_BNEZ	$s7,DrawBars_GetZ

	lui	$s6,0x7fff
	movi	$s7,NOF_BARS
DrawBars_Loop:
	clr	$t0
	_LDA	$t1,BarAngle
	mov	$t2,$s6
	_LI	$t3,BarZ
	clr	$s4
	clr	$s5
DrawBars_FindMin:
	_LW	$t9,0($t3)
	nop			; hazard
	slt	$t8,$t9,$t2
	_BEQZ	$t8,DrawBars_NotSmaller
	mov	$t2,$t9 ; min in t2
	mov	$s4,$t0	; pos in s4
	mov	$s5,$t1 ; angle in s5
DrawBars_NotSmaller:
	addi	$t1,$t1,ANGLE_BETWEEN_BAR
	addi	$t3,$t3,1
	addi	$t0,$t0,1
	movi	$t9,NOF_BARS
	_BNE	$t0,$t9,DrawBars_FindMin

	movi	$t0,NOF_BARS/2
	_BNE	$t0,$s7,DrawBars_NotMiddle
	_JAL	DrawMiddleBar
DrawBars_NotMiddle:
	mov	$a0,$s5
	_JAL	Cos
	sra	$t0,$v0,10
	addi	$a1,$t0,128
	_LDO	$a0,BarList,$s4
	_STO	$s6,BarZ,$s4
	_JAL	DrawBar

	addi	$s7,$s7,-1
	_BNEZ	$s7,DrawBars_Loop

	POP	$s7
	POP	$s6
	POP	$s5
	POP	$s4
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS


DrawBar:
	PUSH	$ra
	_JAL	GetWorkScreen		; draw into the hidden screen (double buffered)
	mov	$t0,$v0
	addi	$t1,$a1,-8
	sll	$t1,$t1,6
	add	$t0,$t0,$t1
	mov	$t1,$a0

	_LI	$t2,0b00100001000001000010000100000100
	and	$t2,$t2,$a0
	_LI	$t3,0b00001000010000010000100001000001
	and	$t3,$t3,$a0
	movi	$t9,16
DrawBar_Loop:
	_SW	$t2,0($t0)
	sw	$t2,1($t0)
	sw	$t2,2($t0)
	sw	$t2,3($t0)
	sw	$t2,4($t0)
	sw	$t2,5($t0)
	sw	$t2,6($t0)
	sw	$t2,7($t0)
	sw	$t2,8($t0)
	sw	$t2,9($t0)
	sw	$t2,10($t0)
	sw	$t2,11($t0)
	sw	$t2,12($t0)
	sw	$t2,13($t0)
	sw	$t2,14($t0)
	sw	$t2,15($t0)
	sw	$t2,16($t0)
	sw	$t2,17($t0)
	sw	$t2,18($t0)
	sw	$t2,19($t0)
	sw	$t2,20($t0)
	sw	$t2,21($t0)
	sw	$t2,22($t0)
	sw	$t2,23($t0)
	sw	$t2,24($t0)
	sw	$t2,25($t0)
	sw	$t2,26($t0)
	sw	$t2,27($t0)
	sw	$t2,28($t0)
	sw	$t2,29($t0)
	sw	$t2,30($t0)
	sw	$t2,31($t0)
	sw	$t2,32($t0)
	sw	$t2,33($t0)
	sw	$t2,34($t0)
	sw	$t2,35($t0)
	sw	$t2,36($t0)
	sw	$t2,37($t0)
	sw	$t2,38($t0)
	sw	$t2,39($t0)
	sw	$t2,40($t0)
	sw	$t2,41($t0)
	sw	$t2,42($t0)
	sw	$t2,43($t0)
	sw	$t2,44($t0)
	sw	$t2,45($t0)
	sw	$t2,46($t0)
	sw	$t2,47($t0)
	sw	$t2,48($t0)
	sw	$t2,49($t0)
	sw	$t2,50($t0)
	sw	$t2,51($t0)
	sw	$t2,52($t0)
	sw	$t2,53($t0)
	sw	$t2,54($t0)
	sw	$t2,55($t0)
	sw	$t2,56($t0)
	sw	$t2,57($t0)
	sw	$t2,58($t0)
	sw	$t2,59($t0)
	sw	$t2,60($t0)
	sw	$t2,61($t0)
	sw	$t2,62($t0)
	sw	$t2,63($t0)
	add	$t2,$t2,$t3
	addi	$t0,$t0,64
	addi	$t1,$t1,1
	addi	$t9,$t9,-1
	andi	$t8,$t9,7
	_BNEZ	$t8,DrawBar_Loop
	neg	$t3,$t3
	_BNEZ	$t9,DrawBar_Loop

	POP	$ra
	_RTS

DrawMiddleBar:
	PUSH	$ra
	_JAL	GetWorkScreen		; draw into the hidden screen (double buffered)
	mov	$t0,$v0
	addi	$t0,$t0,112*64
	clr	$t2
	_LI	$t3,0b00001000010000010000100001000001
	movi	$t9,32
DrawMiddleBar_Loop:
	_SW	$t2,0($t0)
	sw	$t2,1($t0)
	sw	$t2,2($t0)
	sw	$t2,3($t0)
	sw	$t2,4($t0)
	sw	$t2,5($t0)
	sw	$t2,6($t0)
	sw	$t2,7($t0)
	sw	$t2,8($t0)
	sw	$t2,9($t0)
	sw	$t2,10($t0)
	sw	$t2,11($t0)
	sw	$t2,12($t0)
	sw	$t2,13($t0)
	sw	$t2,14($t0)
	sw	$t2,15($t0)
	sw	$t2,16($t0)
	sw	$t2,17($t0)
	sw	$t2,18($t0)
	sw	$t2,19($t0)
	sw	$t2,20($t0)
	sw	$t2,21($t0)
	sw	$t2,22($t0)
	sw	$t2,23($t0)
	sw	$t2,24($t0)
	sw	$t2,25($t0)
	sw	$t2,26($t0)
	sw	$t2,27($t0)
	sw	$t2,28($t0)
	sw	$t2,29($t0)
	sw	$t2,30($t0)
	sw	$t2,31($t0)
	sw	$t2,32($t0)
	sw	$t2,33($t0)
	sw	$t2,34($t0)
	sw	$t2,35($t0)
	sw	$t2,36($t0)
	sw	$t2,37($t0)
	sw	$t2,38($t0)
	sw	$t2,39($t0)
	sw	$t2,40($t0)
	sw	$t2,41($t0)
	sw	$t2,42($t0)
	sw	$t2,43($t0)
	sw	$t2,44($t0)
	sw	$t2,45($t0)
	sw	$t2,46($t0)
	sw	$t2,47($t0)
	sw	$t2,48($t0)
	sw	$t2,49($t0)
	sw	$t2,50($t0)
	sw	$t2,51($t0)
	sw	$t2,52($t0)
	sw	$t2,53($t0)
	sw	$t2,54($t0)
	sw	$t2,55($t0)
	sw	$t2,56($t0)
	sw	$t2,57($t0)
	sw	$t2,58($t0)
	sw	$t2,59($t0)
	sw	$t2,60($t0)
	sw	$t2,61($t0)
	sw	$t2,62($t0)
	sw	$t2,63($t0)

	add	$t2,$t2,$t3
	addi	$t0,$t0,64
	addi	$t1,$t1,2
	addi	$t9,$t9,-1
	andi	$t8,$t9,15
	_BNEZ	$t8,DrawMiddleBar_Loop
	neg	$t3,$t3
	_BNEZ	$t9,DrawMiddleBar_Loop
	POP	$ra
	_RTS

NOF_BARS = 7

BarList:	.dc	0xf800f800,0xffe0ffe0,0x07e007e0
		.dc	0x07ff07ff,0x001f001f,0xf81ff81f
		.dc	0x7fff7fff

BarZ:		.pad	NOF_BARS,0

BAR_ANGLE_DELTA = -0xd5		; -0x100 at 50 Hz

ANGLE_BETWEEN_BAR = 0x10000/NOF_BARS

BarAngle:	.dc	0

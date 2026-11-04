NOF_STARS = 50
SPEED_SHIFT = 13

Stars_Xpos:	.pad	NOF_STARS,0
Stars_Ypos:	.pad	NOF_STARS,0
Stars_Speed:	.pad	NOF_STARS,0
Stars_SpeedAdd:	.dc	0

InitStars:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s7

	_LI	$s0,Stars_Xpos
	_LI	$s1,Stars_Ypos
	_LI	$s2,Stars_Speed

	movi	$s7,NOF_STARS
InitStars_Loop:
	_JAL	Rnd
	srl	$t0,$v0,8
	lui	$t1,320
	add	$t0,$t0,$t1
	_SW	$t0,0($s0)	; Xpos = Rnd(319,<(319+256)), Fp16+16

	_JAL	Rnd
	sll	$t0,$v0,24
	srl	$t0,$t0,24
	_SW	$t0,0($s1)	; Ypos = Rnd(0,255), Int

	_JAL	Rnd
	srl	$t0,$v0,14
	lui	$t1, 1
	add	$t0,$t0,$t1
	_SW	$t0,0($s2)	; Speed = Rnd(1,<5), Fp16+16

	addi	$s0,$s0,1
	addi	$s1,$s1,1
	addi	$s2,$s2,1

	addi	$s7,$s7,-1
	_BNEZ	$s7,InitStars_Loop

	_STA	$zero,Stars_SpeedAdd

	POP	$s7
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

StopStars:
	movi	$t0,0x0100
	_STA	$t0,Stars_SpeedAdd
	_RTS

Stars:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s6
	PUSH	$s7

	movi	$v0,NOF_STARS

	_LI	$s0,Stars_Xpos
	_LI	$s1,Stars_Ypos
	_LI	$s2,Stars_Speed

	_LDA	$s3,Stars_SpeedAdd

	movi	$s7,NOF_STARS
Stars_Loop:
	_LW	$s6,0($s2)
	add	$t0,$s6,$s3
	_SW	$t0,0($s2)

	sll	$a0,$s6,SPEED_SHIFT
	srl	$a0,$a0,27
	sll	$t0,$a0,6
	or	$a0,$a0,$t0
	sll	$t0,$t0,5
	or	$a0,$a0,$t0
	_JAL	SetColor

	_LW	$a0,0($s0)
	sub	$a0,$a0,$s6
	slt	$t0,$a0,$zero
	_BEQZ	$t0,Stars_StarStillOnScreen
	addi	$v0,$v0,-1
	_BNEZ	$s3,Stars_SkipStar
	lui	$a0,319
Stars_StarStillOnScreen:
	_SW	$a0,0($s0)
	srl	$a0,$a0,16
	_LW	$a1,0($s1)

	slti	$t0,$a0,319
	_BEQZ	$t0,Stars_SkipStar
	_JAL	Point
Stars_SkipStar:
	addi	$s0,$s0,1
	addi	$s1,$s1,1
	addi	$s2,$s2,1

	addi	$s7,$s7,-1
	_BNEZ	$s7,Stars_Loop

	_BNEZ	$s3,Stars_FadingDown
	clr	$v0
Stars_fadingDown:
	POP	$s7
	POP	$s6
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

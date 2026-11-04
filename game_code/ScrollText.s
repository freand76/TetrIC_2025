InitScroll:
	_STA	$zero,Scroll_Char
	movi	$t0,8
	_STA	$t0,Scroll_Slide
	movi	$t0,-1
	_STA	$t0,Scroll_LastChar
	movi	$t0,-4			; 4 pixels every frame: 240 px/s, 1.3 s across
					; the screen (2 per 50 Hz frame on the original)
	_STA	$t0,Scroll_Speed

	_RTS

SCROLL_LEFT = 0
SCROLL_RIGHT = 312
SCROLL_FADE = 64
SCROLL_YPOS = 209

Scroll:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2

	mov	$s2,$a0

	clr	$v1
	_LDA	$t0,Scroll_Char
	_LDA	$t1,Scroll_LastChar
	_BEQ	$t0,$t1,Scroll_FadeDone

	_LI	$s0,Scroll_Text
	_LI	$t0,Scroll_Char
	_LW	$s1,0($t0)
	_LI	$t0,Scroll_Slide
	_LW	$a1,0($t0)
	movi	$a2,SCROLL_YPOS
	movi	$s7,10
Scroll_PrintLoop:
	srl	$t0,$s1,2
	add	$t0,$t0,$s0
	_LW	$a0,0($t0)
	andi	$t0,$s1,3
	movi	$t1,3
	sub	$t1,$t1,$t0
	sll	$t1,$t1,3
	srlv	$a0,$a0,$t1
	sll	$a0,$a0,24
	srl	$a0,$a0,24

	moviu	$a3,0xf800

	slti	$t0,$a1,SCROLL_LEFT+SCROLL_FADE
	_BEQZ	$t0,Scroll_LeftNoFade
	sll	$a3,$a1,10
	_J	Scroll_Print
Scroll_LeftNoFade:
	slti	$t0,$a1,SCROLL_RIGHT-SCROLL_FADE+2
	_BNEZ	$t0,Scroll_RightNoFade
	movi	$t1,SCROLL_RIGHT
	sub	$t0,$t1,$a1
	sll	$a3,$t0,10
Scroll_RightNoFade:
Scroll_Print:
	moviu	$t0,0xf800		; edge fade colour is x<<10: keep red only,
	and	$a3,$a3,$t0		; an odd x would set a green bit
	_BEQZ	$s2,Scroll_DontEndEarly
	_LDA	$t2,Scroll_LastChar
	_BNE	$t2,$s1,Scroll_DontEndEarly
	movi	$a0,'
	_JAL	PrintASCII
	_B	Scroll_Continue

Scroll_DontEndEarly:
	_JAL	PrintASCII
	addi	$s1,$s1,1

Scroll_Continue:
	movi	$t2,Scroll_Length+1
	_BNE	$s1,$t2,Scroll_NoLoopOver
	clr	$s1
Scroll_NoLoopOver:
	addi	$a1,$a1,8
	slti	$t0,$a1,312
	_BNEZ	$t0,Scroll_PrintLoop
	_LI	$t0,Scroll_Slide
	_LW	$t1,0($t0)
	_LDA	$t2,Scroll_Speed
	add	$t1,$t1,$t2
	slt	$t2,$t1,$zero
	_BEQZ	$t2,Scroll_SlideOn
	movi	$t3,7
	and	$t1,$t1,$t3
Scroll_SlideOn:
	_SW	$t1,0($t0)

	_BEQZ	$s2,Scroll_DontSetLastChar
	movi	$t0,-1
	_LDA	$t1,Scroll_LastChar
	_BNE	$t0,$t1,Scroll_DontSetLastChar
	_STA	$s1,Scroll_LastChar
	movi	$t0,-8			; twice the speed when fading out
	_STA	$t0,Scroll_Speed
Scroll_DontSetLastChar:

	_LI	$t0,Scroll_Char
	_LW	$t1,0($t0)
	add	$t1,$t1,$t2
	movi	$t2,Scroll_Length+1
	_BNE	$t1,$t2,Scroll_ScrollOn
	clr	$t1
Scroll_ScrollOn:
	_SW	$t1,0($t0)

	movi	$v1,1
Scroll_FadeDone:
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra

	_RTS



Scroll_Char:		.dc	0
Scroll_Slide:		.dc	0
Scroll_LastChar:	.dc	0
Scroll_Speed:		.dc	0

Scroll_Text:	.file	TheText.txt
Scroll_Text_End:
Scroll_Pad:	.pad	4,0
Scroll_Length = 4*[Scroll_Text_End-Scroll_Text]

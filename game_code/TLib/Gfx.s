####################
# GfxBox Registers #
####################

GFX_TOPPOS = 0
GFX_LEFTPOS = 1
GFX_WIDTH = 2
GFX_HEIGHT = 3
GFX_PIXREAD = 4
GFX_SCRADDR = 5
GFX_DELTA = 6
GFX_ROWLENGTH = 7
GFX_HSYNC = 8
GFX_ESYNC = 9
GFX_VSYNC = 10

ClearScreen:
	_LDA	$t0,WorkScreen
	nop			; hazard
	addiu	$t1,$t0,0xa000
Clear_loop:
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
	_BNE	$t0,$t1,Clear_loop
	_RTS

CopyActiveToWork:
	_LDA	$t0,WorkScreen
	_LDA	$t1,ViewScreen
	addiu	$t2,$t0,0xa000
CopyActiveToWork_Loop:
	lw	$t3,0($t0)
	lw	$t4,1($t0)
	lw	$t5,2($t0)
	lw	$t6,3($t0)
	lw	$t7,4($t0)
	lw	$t8,5($t0)
	lw	$t9,6($t0)
	sw	$t3,0($t1)
	sw	$t4,1($t1)
	sw	$t5,2($t1)
	sw	$t6,3($t1)
	sw	$t7,4($t1)
	sw	$t8,5($t1)
	sw	$t9,6($t1)
	lw	$t3,7($t0)
	lw	$t4,8($t0)
	lw	$t5,9($t0)
	lw	$t6,10($t0)
	lw	$t7,11($t0)
	lw	$t8,12($t0)
	lw	$t9,13($t0)
	sw	$t3,7($t1)
	sw	$t4,8($t1)
	sw	$t5,9($t1)
	sw	$t6,10($t1)
	sw	$t7,11($t1)
	sw	$t8,12($t1)
	sw	$t9,13($t1)
	lw	$t3,14($t0)
	lw	$t4,15($t0)
	nop
	sw	$t3,14($t1)
	sw	$t4,15($t1)
	addi	$t0,$t0,0x10
	addi	$t1,$t1,0x10
	_BNE	$t0,$t2,CopyActiveToWork_Loop
	_RTS

ScreenFadeList:
	.dc	FadeOutLeftRight,FadeOutTopDown
ScreenFadeList_End:

SCREENFADELIST_SIZE = ScreenFadeList_End-ScreenFadeList

ScreenFadeOut:
	PUSH	$ra
	_JAL	Rnd
	mov	$a0,$v0
	movi	$a1,SCREENFADELIST_SIZE
	_JAL	Divu16
	_LDO	$t0,ScreenFadeList,$v1
	nop
	_JALR	$t0,$ra
	POP	$ra
	_RTS

LEFTRIGHT_ROWS = 256
LEFTRIGHT_COLS = 160
LEFTRIGHT_FRAMES = 60		; 50 at 50 Hz
LEFTRIGHT_STEP = LEFTRIGHT_COLS/LEFTRIGHT_FRAMES+1
LEFTRIGHT_HEIGHT = 8

FadeOutLeftRight:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1

	_JAL	WaitNextFrameNoSwap
	_JAL	CopyActiveToWork

	movi	$s1,-LEFTRIGHT_STEP
	movi	$s0,LEFTRIGHT_FRAMES
FadeOutLeftRight_FrameLoop:
	_LDA	$t0,WorkScreen
	movi	$t9,LEFTRIGHT_ROWS/LEFTRIGHT_HEIGHT/2
FadeOutLeftRight_RowLoop:
	mov	$t3,$s1
	mov	$t1,$t0
	addi	$t2,$t0,160*LEFTRIGHT_HEIGHT*2-1
	movi	$t8,2*LEFTRIGHT_STEP
FadeOutLeftRight_ColLoop:
	slti	$t4,$t3,0
	_BNEZ	$t4,FadeOutLeftRight_OutsideScreen
	slti	$t4,$t3,160
	_BEQZ	$t4,FadeOutLeftRight_OutsideScreen
	add	$t4,$t1,$t3
	sub	$t5,$t2,$t3


	movi	$t7,LEFTRIGHT_HEIGHT
FadeOutLeftRight_BlockLoop:

	_LI	$t6,0x20000	; Check if address t4 or t5 ever writes outside
	slt	$at,$t4,$t6
	_BNEZ	$at,Error	; if so jump to foreverloop error
	slt	$at,$t5,$t6
	_BNEZ	$at,Error
	_LI	$t6,0x33fff	; doublebuffer area 0x20000-0x33fff
	slt	$at,$t6,$t4
	_BNEZ	$at,Error
	slt	$at,$t6,$t5
	_BNEZ	$at,Error

	sw	$zero,0($t4)
	sw	$zero,0($t5)
	addi	$t4,$t4,160
	addi	$t5,$t5,-160
	addi	$t7,$t7,-1
	_BNEZ	$t7,FadeOutLeftRight_BlockLoop

FadeOutLeftRight_OutsideScreen:
	addi	$t3,$t3,1
	addi	$t8,$t8,-1
	_BNEZ	$t8,FadeOutLeftRight_ColLoop
	addi	$t0,$t0,160*LEFTRIGHT_HEIGHT*2
	addi	$t9,$t9,-1
	_BNEZ	$t9,FadeOutLeftRight_RowLoop
	addi	$s0,$s0,-1
	_JAL	WaitNextFrame
	addi	$s1,$s1,LEFTRIGHT_STEP
	_BNEZ	$s0,FadeOutLeftRight_FrameLoop

	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

TOPDOWN_ROWS = 256
TOPDOWN_COLS = 160
TOPDOWN_FRAMES = 60		; 50 at 50 Hz
TOPDOWN_STEP = TOPDOWN_ROWS/TOPDOWN_FRAMES+1
TOPDOWN_WIDTH = 4

FadeOutTopDown:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1

	_JAL	WaitNextFrameNoSwap
	_JAL	CopyActiveToWork

	movi	$s1,-TOPDOWN_STEP
	movi	$s0,TOPDOWN_FRAMES
FadeOutTopDown_FrameLoop:
	_LDA	$t0,WorkScreen
	movi	$t9,TOPDOWN_COLS/TOPDOWN_WIDTH/2
FadeOutTopDown_ColLoop:
	mov	$t3,$s1
	mov	$t1,$t0
	addiu	$t2,$t0,255*160+TOPDOWN_WIDTH*2-1
	movi	$t8,2*TOPDOWN_STEP
FadeOutTopDown_RowLoop:
	slti	$t4,$t3,0
	_BNEZ	$t4,FadeOutTopDown_OutsideScreen
	slti	$t4,$t3,256
	_BEQZ	$t4,FadeOutTopDown_OutsideScreen

	sll	$t4,$t3,7
	sll	$t5,$t3,5
	add	$t5,$t5,$t4

	add	$t4,$t1,$t5
	sub	$t5,$t2,$t5

	movi	$t7,TOPDOWN_WIDTH
FadeOutTopDown_BlockLoop:

	_LI	$t6,0x20000	; Check if address t4 or t5 ever writes outside
	slt	$at,$t4,$t6
	_BNEZ	$at,Error	; if so jump to foreverloop error
	slt	$at,$t5,$t6
	_BNEZ	$at,Error
	_LI	$t6,0x33fff	; doublebuffer area 0x20000-0x33fff
	slt	$at,$t6,$t4
	_BNEZ	$at,Error
	slt	$at,$t6,$t5
	_BNEZ	$at,Error

	sw	$zero,0($t4)
	sw	$zero,0($t5)
	addi	$t4,$t4,1
	addi	$t5,$t5,-1
	addi	$t7,$t7,-1
	_BNEZ	$t7,FadeOutTopDown_BlockLoop
FadeOutTopDown_OutsideScreen:
	addi	$t3,$t3,1
	addi	$t8,$t8,-1
	_BNEZ	$t8,FadeOutTopDown_RowLoop
	addi	$t0,$t0,TOPDOWN_WIDTH*2
	addi	$t9,$t9,-1
	_BNEZ	$t9,FadeOutTopDown_ColLoop
	addi	$s0,$s0,-1
	_JAL	WaitNextFrame
	addi	$s1,$s1,TOPDOWN_STEP
	_BNEZ	$s0,FadeOutTopDown_FrameLoop

	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

FadeDown:
	mov	$t0,$a0
	srl	$t1,$t0,27	; Mask out Red Left
	sll	$t0,$t0,5
	srl	$t2,$t0,27	; Mask out Green Left
	sll	$t0,$t0,6
	srl	$t3,$t0,27	; Mask out Blue Left
	sll	$t0,$t0,5
	srl	$t4,$t0,27	; Mask out Red Right
	sll	$t0,$t0,5
	srl	$t5,$t0,27	; Mask out Green Right
	sll	$t0,$t0,6
	srl	$t6,$t0,27	; Mask out Blue RIght
	clr	$v1		; clear /done flag
	mov	$t7,$a1
	srl	$t8,$t7,27	; Get destination value Red Left
	sll	$t7,$t7,5
	slt	$t0,$t8,$t1	; To High ?
	sub	$t1,$t1,$t0	; Then Sub
	slt	$t0,$t8,$t1	; To High ?
	sub	$t1,$t1,$t0	; Then Sub
	or	$v1,$v1,$t0	; We are not done
	slt	$t0,$t1,$t8	; To Low ?
	add	$t1,$t1,$t0	; Then Add
	slt	$t0,$t1,$t8	; To Low ?
	add	$t1,$t1,$t0	; Then Add
	or	$v1,$v1,$t0	; We are not done
	srl	$t8,$t7,27	; Get destination value Green Left
	sll	$t7,$t7,6
	slt	$t0,$t8,$t2	; To High ?
	sub	$t2,$t2,$t0	; Then Sub
	slt	$t0,$t8,$t2	; To High ?
	sub	$t2,$t2,$t0	; Then Sub
	or	$v1,$v1,$t0	; We are not done
	slt	$t0,$t2,$t8	; To Low ?
	add	$t2,$t2,$t0	; Then Add
	slt	$t0,$t2,$t8	; To Low ?
	add	$t2,$t2,$t0	; Then Add
	or	$v1,$v1,$t0	; We are not done
	srl	$t8,$t7,27	; Get destination value Blue Left
	sll	$t7,$t7,5
	slt	$t0,$t8,$t3	; To High ?
	sub	$t3,$t3,$t0	; Then Sub
	slt	$t0,$t8,$t3	; To High ?
	sub	$t3,$t3,$t0	; Then Sub
	or	$v1,$v1,$t0	; We are not done
	slt	$t0,$t3,$t8	; To Low ?
	add	$t3,$t3,$t0	; Then Add
	slt	$t0,$t3,$t8	; To Low ?
	add	$t3,$t3,$t0	; Then Add
	or	$v1,$v1,$t0	; We are not done
	srl	$t8,$t7,27	; Get destination value Red Right
	sll	$t7,$t7,5
	slt	$t0,$t8,$t4	; To High ?
	sub	$t4,$t4,$t0	; Then Sub
	slt	$t0,$t8,$t4	; To High ?
	sub	$t4,$t4,$t0	; Then Sub
	or	$v1,$v1,$t0	; We are not done
	slt	$t0,$t4,$t8	; To Low ?
	add	$t4,$t4,$t0	; Then Add
	slt	$t0,$t4,$t8	; To Low ?
	add	$t4,$t4,$t0	; Then Add
	or	$v1,$v1,$t0	; We are not done
	srl	$t8,$t7,27	; Get destination value Green Right
	sll	$t7,$t7,6
	slt	$t0,$t8,$t5	; To High ?
	sub	$t5,$t5,$t0	; Then Sub
	slt	$t0,$t8,$t5	; To High ?
	sub	$t5,$t5,$t0	; Then Sub
	or	$v1,$v1,$t0	; We are not done
	slt	$t0,$t5,$t8	; To Low ?
	add	$t5,$t5,$t0	; Then Add
	slt	$t0,$t5,$t8	; To Low ?
	add	$t5,$t5,$t0	; Then Add
	or	$v1,$v1,$t0	; We are not done
	srl	$t8,$t7,27	; Get destination value Blue Right
	slt	$t0,$t8,$t6	; To High ?
	sub	$t6,$t6,$t0	; Then Sub
	slt	$t0,$t8,$t6	; To High ?
	sub	$t6,$t6,$t0	; Then Sub
	or	$v1,$v1,$t0	; We are not done
	slt	$t0,$t6,$t8	; To Low ?
	add	$t6,$t6,$t0	; Then Add
	slt	$t0,$t6,$t8	; To Low ?
	add	$t6,$t6,$t0	; Then Add
	or	$v1,$v1,$t0	; We are not done
	sll	$v0,$t1,27	; Merge in Red Left
	sll	$t2,$t2,22
	or	$v0,$v0,$t2	; Merge in Green Left
	sll	$t3,$t3,16
	or	$v0,$v0,$t3	; Merge in Blue Left
	sll	$t4,$t4,11
	or	$v0,$v0,$t4	; Merge in Red Right
	sll	$t5,$t5,6
	or	$v0,$v0,$t5	; Merge in Green Right
	or	$v0,$v0,$t6	; Merge in Blue Right
	_RTS

FadeSourceToDest:
	mov	$t0,$a0
	sll	$t0,$t0,16
	srl	$t4,$t0,27	; Mask out Red
	sll	$t0,$t0,5
	srl	$t5,$t0,27	; Mask out Green
	sll	$t0,$t0,6
	srl	$t6,$t0,27	; Mask out Blue
	clr	$v1		; clear /done flag

	mov	$t7,$a1
	sll	$t7,$t7,16
	srl	$t8,$t7,27	; Get destination value Red Left
	sll	$t7,$t7,5
	slt	$t0,$t8,$t4	; To High ?
	sub	$t4,$t4,$t0	; Then Sub
	or	$v1,$v1,$t0	; We are not done
	slt	$t0,$t4,$t8	; To Low ?
	add	$t4,$t4,$t0	; Then Add
	or	$v1,$v1,$t0	; We are not done

	srl	$t8,$t7,27	; Get destination value Green Right
	sll	$t7,$t7,6
	slt	$t0,$t8,$t5	; To High ?
	sub	$t5,$t5,$t0	; Then Sub
	or	$v1,$v1,$t0	; We are not done
	slt	$t0,$t5,$t8	; To Low ?
	add	$t5,$t5,$t0	; Then Add
	or	$v1,$v1,$t0	; We are not done

	srl	$t8,$t7,27	; Get destination value Blue Right
	slt	$t0,$t8,$t6	; To High ?
	sub	$t6,$t6,$t0	; Then Sub
	or	$v1,$v1,$t0	; We are not done
	slt	$t0,$t6,$t8	; To Low ?
	add	$t6,$t6,$t0	; Then Add
	or	$v1,$v1,$t0	; We are not done

	sll	$v0,$t4,11	; Merge in Red Right
	sll	$t5,$t5,6
	or	$v0,$v0,$t5	; Merge in Green Right
	or	$v0,$v0,$t6	; Merge in Blue Right
	_RTS

SetColor:
	_LI	$t0,theColor
	_SW	$a0,0($t0)
	_RTS

theColor:	.dc	0xffff

Point:
	_LI	$t0,theColor
	lw	$t7,0($t0)		; Get Color
	srl	$t1,$a0,1		; t1 = xpos
	_LI	$t0,WorkScreen
	lw	$t0,0($t0)
	sll	$t2,$a1,7		; t2 = ypos*128
	sll	$t3,$a1,5		; t3 = ypos*32
	add	$t0,$t0,$t1
	add	$t0,$t0,$t2
	add	$t0,$t0,$t3

	lw	$t2,0($t0)		; Get Pixel
	moviu	$t4,0xffff		; Set Mask
	sll	$t1,$t7,16		; Shift Color to upper half
	sll	$t3,$a0,31
	slti	$t3,$t3,0		; Is it an odd or even pixel
	sll	$t3,$t3,4		; Mult by 16
	srlv	$t1,$t1,$t3		; Set Color in correct half
	sllv	$t4,$t4,$t3		; Set Mask in correct half
	and	$t2,$t2,$t4		; Mask
	or	$t2,$t2,$t1		; Set
	nop
	nop
	sw	$t2,0($t0)		; Set Pixel

	_RTS

FilledRect:
	; a0 - X0
	; a1 - Y0
	; a2 - Width
	; a3 - Height

	_LI	$t0,WorkScreen
	lw	$t0,0($t0)
	_LI	$t7,theColor
	lw	$t7,0($t7)
	moviu	$t3,0xffff	; LeftMask
	lui	$t4,0xffff	; RightMask
	sll	$t5,$t7,16	; LeftPix
	srl	$t6,$t5,16	; RightPix
	or	$t7,$t5,$t6	; BothPix
	srl	$t1,$a0,1
	add	$t0,$t0,$t1
	sll	$t1,$a1,7
	add	$t0,$t0,$t1
	sll	$t1,$a1,5
	add	$t0,$t0,$t1

	sll	$t1,$a0,31
	_BEQZ	$t1,FilledRect_LeftEven

	mov	$t9,$t0
	mov	$t8,$a3
FilledRect_LeftOddLoop:
	_LW	$t1,0($t9)
	nop			; hazard
	and	$t1,$t1,$t4
	or	$t1,$t1,$t6
	nop			; hazard
	nop			; hazard
	_SW	$t1,0($t9)
	addi	$t9,$t9,160
	addi	$t8,$t8,-1
	_BNEZ	$t8,FilledRect_LeftOddLoop
	addi	$a0,$a0,1
	addi	$a2,$a2,-1
	addi	$t0,$t0,1

FilledRect_LeftEven:
	add	$t1,$a0,$a2
	sll	$t1,$t1,31
	_BEQZ	$t1,FilledRect_RightEven

	mov	$t9,$t0
	srl	$t1,$a2,1
	add	$t9,$t9,$t1

	mov	$t8,$a3
FilledRect_RightOddLoop:
	_LW	$t1,0($t9)
	nop			; hazard
	and	$t1,$t1,$t3
	or	$t1,$t1,$t5
	nop			; hazard
	nop			; hazard
	_SW	$t1,0($t9)
	addi	$t9,$t9,160
	addi	$t8,$t8,-1
	_BNEZ	$t8,FilledRect_RightOddLoop
	addi	$a2,$a2,-1
FilledRect_RightEven:

	srl	$t1,$a2,1
FilledRect_FillRowLoop:
	mov	$t8,$a3
	mov	$t9,$t0
FilledRect_FillColLoop:
	_SW	$t7,0($t9)
	addi	$t9,$t9,160
	addi	$t8,$t8,-1
	_BNEZ	$t8,FilledRect_FillColLoop
	addi	$t0,$t0,1
	addi	$t1,$t1,-1
	_BNEZ	$t1,FilledRect_FillRowLoop

	_RTS
















Line:	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4

	movi	$t5,160				; Yinc = t5

	_LI	$t7,theColor
	lw	$t7,0($t7)

	_BGE	$a2,$a0,Line_dont_swap_X	; Make
	mov	$t0,$a0				; a0
	mov	$a0,$a2				; less
	mov	$a2,$t0				; than
	mov	$t0,$a1				; a2
	mov	$a1,$a3				; xinc always 1
	mov	$a3,$t0
Line_dont_swap_X:

	_LI	$t0,WorkScreen
	lw	$t0,0($t0)
	sll	$t1,$a1,7	; y1 = y1 * 128
	add	$t8,$t0,$t1
	sll	$t1,$a1,5	; y1 = y1 * 32
	add	$t8,$t8,$t1	; y1 row addr in t8
	sll	$t1,$a3,7	; y2 = y2 * 128
	add	$t9,$t0,$t1
	sll	$t1,$a3,5	; y2 = y2 * 32
	add	$t9,$t9,$t1	; y2 row addr in t9

	lui	$t0,0x8000
	sub	$s0,$a2,$a0			; dX = s0
	sub	$s1,$a3,$a1			; dY = s1

	_BGE	$t0,$s1,Line_dont_neg_dY
	neg	$s1,$s1				; dY = -dY
	neg	$t5,$t5				; Yinc = -Yinc
Line_dont_neg_dY:
	_BEQZ	$s0,Line_Vertical
	_BEQZ	$s1,Line_Horizontal
	_BGT	$s1,$s0,Line_Big_dY
Line_Big_dX:
	sll	$s3,$s1,1	;s3 = dPr = 2*dY
	neg	$s2,$s0		;s2 = P = -dX
	sll	$s4,$s2,1	;s4 = dPru = -2*dX
	srl	$t4,$s0,1	;t4 = loop counter = dX/2
	_BEQZ	$t4,Line_Big_dX_MidPoint
Line_Big_dX_Loop:
	srl	$t6,$a0,1
	add	$t6,$t6,$t8
	lw	$t0,0($t6)
	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a0,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	addi	$a0,$a0,1
	add	$s2,$s2,$s3
	sw	$t0,0($t6)

	srl	$t6,$a2,1
	add	$t6,$t6,$t9
	lw	$t0,0($t6)
	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a2,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	addi	$a2,$a2,-1
	nop
	sw	$t0,0($t6)

	slti	$t0,$s2,0
	_BNEZ	$t0,Line_Big_dX_Next
Line_Big_dX_RightUp:
	add	$s2,$s2,$s4
	add	$t8,$t8,$t5
	sub	$t9,$t9,$t5
Line_Big_dX_Next:
	addi	$t4,$t4,-1
	_BNEZ	$t4,Line_Big_dX_Loop
Line_Big_dX_MidPoint:
	srl	$t6,$a0,1
	add	$t6,$t6,$t8
	lw	$t0,0($t6)
	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a0,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	addi	$a0,$a0,1
	add	$s2,$s2,$s3
	sw	$t0,0($t6)

	andi	$t0,$s0,1
	_BEQZ	$t0,Line_Done

	srl	$t6,$a2,1
	add	$t6,$t6,$t9
	lw	$t0,0($t6)
	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a2,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	addi	$a2,$a2,-1
	nop
	sw	$t0,0($t6)

	_J	Line_Done

Line_Big_dY:
	sll	$s3,$s0,1	;s3 = dPr = 2*dX
	neg	$s2,$s1		;s2 = P = -dY
	sll	$s4,$s2,1	;s4 = dPru = -2*dY
	srl	$t4,$s1,1	;t4 = loop counter = dY/2
	_BEQZ	$t4,Line_Big_dY_MidPoint
Line_Big_dY_Loop:
	srl	$t6,$a0,1
	add	$t6,$t6,$t8
	lw	$t0,0($t6)
	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a0,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	add	$t8,$t8,$t5
	add	$s2,$s2,$s3
	sw	$t0,0($t6)

	srl	$t6,$a2,1
	add	$t6,$t6,$t9
	lw	$t0,0($t6)
	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a2,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	sub	$t9,$t9,$t5
	nop
	sw	$t0,0($t6)

	slti	$t0,$s2,0
	_BNEZ	$t0,Line_Big_dY_Next
Line_Big_dY_RightUp:
	add	$s2,$s2,$s4
	addi	$a0,$a0,1
	addi	$a2,$a2,-1
Line_Big_dY_Next:
	addi	$t4,$t4,-1
	_BNEZ	$t4,Line_Big_dY_Loop
Line_Big_dY_MidPoint:
	srl	$t6,$a0,1
	add	$t6,$t6,$t8
	lw	$t0,0($t6)
	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a0,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	nop
	nop
	sw	$t0,0($t6)

	andi	$t0,$s1,1
	_BEQZ	$t0,Line_Done

	srl	$t6,$a2,1
	add	$t6,$t6,$t9
	lw	$t0,0($t6)
	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a2,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	nop
	nop
	sw	$t0,0($t6)
	_J	Line_Done

Line_Vertical:
	srl	$t4,$s1,1	;t4 = loop counter = dY/2
	srl	$t0,$a0,1
	add	$t8,$t8,$t0
	add	$t9,$t9,$t0

	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a0,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	_BEQZ	$t4,Line_Vertical_MidPoint
Line_Vertical_Loop:
	lw	$t0,0($t8)
	nop
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	nop
	nop
	sw	$t0,0($t8)

	lw	$t0,0($t9)
	nop
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	nop
	nop
	sw	$t0,0($t9)

	add	$t8,$t8,$t5
	sub	$t9,$t9,$t5

	addi	$t4,$t4,-1
	_BNEZ	$t4,Line_Vertical_Loop

Line_Vertical_MidPoint:
	lw	$t0,0($t8)
	nop
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	nop
	nop
	sw	$t0,0($t8)

	andi	$t0,$s1,1
	_BEQZ	$t0,Line_Done

	lw	$t0,0($t9)
	nop
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	nop
	nop
	sw	$t0,0($t9)

	_J	Line_Done

Line_Horizontal:
	addi	$s0,$s0,1
	srl	$t0,$a0,1
	add	$t8,$t8,$t0
	srl	$t0,$a2,1
	add	$t9,$t9,$t0

	andi	$t0,$a0,1
	_BEQZ	$t0,Line_Horizontal_LeftEven

	lw	$t0,0($t8)
	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a0,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	nop
	nop
	sw	$t0,0($t8)
	addi	$t8,$t8,1
	addi	$s0,$s0,-1

Line_Horizontal_LeftEven:
	andi	$t0,$a2,1
	_BNEZ	$t0,Line_Horizontal_RightOdd

	lw	$t0,0($t9)
	moviu	$t2,0xffff
	sll	$t1,$t7,16
	sll	$t3,$a2,31
	slti	$t3,$t3,0
	sll	$t3,$t3,4
	srlv	$t1,$t1,$t3
	sllv	$t2,$t2,$t3
	and	$t0,$t0,$t2
	or	$t0,$t0,$t1
	nop
	nop
	sw	$t0,0($t9)
	addi	$t9,$t9,-1
	addi	$s0,$s0,-1

Line_Horizontal_RightOdd:
	srl	$t4,$s0,1	;t4 = loop counter = dY/2
	_BEQZ	$t4,Line_Done

	sll	$t1,$t7,16
	or	$t1,$t1,$t7
	nop
	nop
Line_Horizontal_Loop:
	sw	$t1,0($t8)
	addi	$t8,$t8,1
	addi	$t4,$t4,-1
	_BNEZ	$t4,Line_Horizontal_Loop
Line_Horizontal_MidPoint;
	_J	Line_Done

Line_Diagonal:
	_J	Line_Done

Line_Done:
	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	_RTS

#######################
# Wait for next frame #
#######################

; The game runs at 60 Hz, one game frame per DVI frame. The time base is
; the frame counter in MFC1[31:20], which steps at the end of the visible
; picture (start of the vertical blank). On PAL the game ran once per field
; (50 Hz), so the frame based timings have been scaled by 60/50:
;  - frame counts * 6/5, per frame steps * 5/6
;  - FrameCount (GetFrameCount) counts 50 Hz ticks: it steps on 5 of 6
;    frames. Tick50 = 0 on the 6th frame (FramePhase 5), there GetFrameCount
;    returns -1 so "every Nth frame" tests (low bits zero) do not fire.
;  - HalfStep = 1 on frames 2 and 5 of 6: steps of 2 units per 50 Hz frame
;    become 2,2,1,2,2,1 per 60 Hz frame (5/6 of the speed)
;
; The screens are 320x256 (old PAL layout), the DVI picture shows 240 lines:
; ScrOffset words are skipped at the top (8 lines, set to match the width).

WorkScreen:
	.dc	0
ViewScreen:
	.dc	0
CurrentScreen:
	.dc	0
FrameCount:
	.dc	0
NextFrameTick:
	.dc	0
FramePhase:
	.dc	0
Tick50:
	.dc	1
HalfStep:
	.dc	0
ScrOffset:
	.dc	8*160

FRAME_STEP = 1

WaitNextFrame:
	_LDA	$t0,WorkScreen
	_LDA	$t1,ViewScreen
	_STA	$t1,WorkScreen
	_STA	$t0,ViewScreen
	_STA	$t0,CurrentScreen
	_LDA	$t1,ScrOffset
	nop			; hazard
	add	$t0,$t0,$t1
	nop			; hazard
	nop			; hazard
	_SW	$t0,GFX_SCRADDR($gfx)	; used from the next frame start
	; The old screen is shown until the next frame boundary: also wait for
	; that (frame counter + 1), even if this game frame is late
	mfc1	$t1,$zero
	srl	$t1,$t1,20
	addi	$t6,$t1,1
	_J	WaitFrameTickMin

#######################
# WaitNextFrameNoSwap #
#######################

WaitNextFrameNoSwap:
	_J	WaitFrameTick

; Wait for the next 60 Hz tick and count the game frame
WaitFrameTick:
	_LDA	$t6,NextFrameTick
; ... and until DVI frame $t6 (mod 4096) has been reached
WaitFrameTickMin:
	_LDA	$t2,NextFrameTick
	_LI	$t3,0x0fff		; the DVI frame counter has 12 bits
	_LI	$t5,0x0800
WaitFrameTick_Loop:
	mfc1	$t1,$zero
	srl	$t1,$t1,20
	sub	$t4,$t1,$t2
	and	$t4,$t4,$t3		; (counter - tick) mod 4096
	_BGE	$t4,$t5,WaitFrameTick_Loop	; "negative": not there yet
	sub	$t4,$t1,$t6
	and	$t4,$t4,$t3
	_BGE	$t4,$t5,WaitFrameTick_Loop	; screen swap not done yet
	addi	$t1,$t1,FRAME_STEP
	_STA	$t1,NextFrameTick

	; 50 Hz tick bookkeeping, see above
	_LDA	$t0,FramePhase
	nop			; hazard
	addi	$t0,$t0,1
	slti	$t1,$t0,6
	_BNEZ	$t1,WaitFrameTick_PhaseOk
	clr	$t0
WaitFrameTick_PhaseOk:
	_STA	$t0,FramePhase
	slti	$t1,$t0,5		; Tick50: phase 0..4
	_STA	$t1,Tick50
	movi	$t2,2
	_BEQ	$t0,$t2,WaitFrameTick_Half
	movi	$t2,5
	_BEQ	$t0,$t2,WaitFrameTick_Half
	clr	$t2
	_B	WaitFrameTick_SetHalf
WaitFrameTick_Half:
	movi	$t2,1
WaitFrameTick_SetHalf:
	_STA	$t2,HalfStep

	_LI	$t0, FrameCount
	_LW	$t2, 0($t0)
	nop			; hazard
	add	$t2,$t2,$t1
	nop			; hazard
	nop			; hazard
	_SW	$t2, 0($t0)

	_RTS

##############
# WaitFrames #
##############

WaitFrames:
	PUSH	$ra
	PUSH	$s0
	mov	$s0,$a0
WaitFrames_Loop:
	_JAL	WaitFrameTick
	addi	$s0,$s0,-1
	_BNEZ	$s0,WaitFrames_Loop
	POP	$s0
	POP	$ra
	_RTS

#####################
# DoubleBufferStuff #
#####################

SetupDoubleBuffer:
	_STA	$a0,WorkScreen
	_STA	$a1,ViewScreen
	_RTS

GetWorkScreen:
	_LDA	$v0,WorkScreen
	_RTS

GetActiveScreen:
	_LDA	$v0,ViewScreen
	_RTS

; FrameCount in 50 Hz ticks, -1 on the frame without a tick
GetFrameCount:
	_LDA	$v0,FrameCount
	_LDA	$t0,Tick50
	nop			; hazard
	_BNEZ	$t0,GetFrameCount_Tick
	movi	$v0,-1
GetFrameCount_Tick:
	_RTS

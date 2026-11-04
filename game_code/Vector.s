VEC_POINTS = 16
VEC_SURFACE_COUNT = 10

MIDPOINT_X = 70
MIDPOINT_Y = 128

FRAMESBEFOREMORPH = 240		; 200 at 50 Hz
ROTATESPEED = 0x140		; 0x180 at 50 Hz

VEC_COLOR = 0x01e0

Current_Color:	.dc	0
Target_Color:	.dc	0

Dz = 8
Dk = 16
Dsi = 4*2
Dco = 9*2

NOFOBJECTS = 7
Current_ObjectNbr:	.dc	0
Object_List:		.dc	O_Object,I_Object,S_Object,L_Object,Z_Object,J_Object,T_Object,-1

Dot_Object:	.dc	Dot_Points_X,Dot_Points_Y,Points_Z
O_Object:	.dc	O_Points_X,O_Points_Y,Points_Z
I_Object:	.dc	I_Points_X,I_Points_Y,Points_Z
L_Object:	.dc	L_Points_X,L_Points_Y,Points_Z
J_Object:	.dc	J_Points_X,J_Points_Y,Points_Z
S_Object:	.dc	S_Points_X,S_Points_Y,Points_Z
Z_Object:	.dc	Z_Points_X,Z_Points_Y,Points_Z
T_Object:	.dc	T_Points_X,T_Points_Y,Points_Z

Dot_Points_X:	.dc	-Dsi,Dsi,Dco,Dco,Dsi,-Dsi,-Dco,-Dco
		.dc	-Dsi,Dsi,Dco,Dco,Dsi,-Dsi,-Dco,-Dco
Dot_Points_Y:	.dc	-Dco,-Dco,-Dsi,Dsi,Dco,Dco,Dsi,-Dsi
		.dc	-Dco,-Dco,-Dsi,Dsi,Dco,Dco,Dsi,-Dsi

O_Points_X:	.dc	-2*Dk,-2*Dk,2*Dk,2*Dk,2*Dk,2*Dk,-2*Dk,-2*Dk
		.dc	-2*Dk,-2*Dk,2*Dk,2*Dk,2*Dk,2*Dk,-2*Dk,-2*Dk
O_Points_Y:	.dc	-2*Dk,-2*Dk,-2*Dk,-2*Dk,2*Dk,2*Dk,2*Dk,2*Dk
		.dc	-2*Dk,-2*Dk,-2*Dk,-2*Dk,2*Dk,2*Dk,2*Dk,2*Dk

I_Points_X:	.dc	-Dk,-Dk,Dk,Dk,Dk,Dk,-Dk,-Dk
		.dc	-Dk,-Dk,Dk,Dk,Dk,Dk,-Dk,-Dk
I_Points_Y:	.dc	-4*Dk,-4*Dk,-4*Dk,-4*Dk,4*Dk,4*Dk,4*Dk,4*Dk
		.dc	-4*Dk,-4*Dk,-4*Dk,-4*Dk,4*Dk,4*Dk,4*Dk,4*Dk

L_Points_X:	.dc	-Dk,-Dk,Dk,Dk,3*Dk,3*Dk,-Dk,-Dk
		.dc	-Dk,-Dk,Dk,Dk,3*Dk,3*Dk,-Dk,-Dk
L_Points_Y:	.dc	-3*Dk,-3*Dk,-3*Dk,Dk,Dk,3*Dk,3*Dk,3*Dk
		.dc	-3*Dk,-3*Dk,-3*Dk,Dk,Dk,3*Dk,3*Dk,3*Dk

J_Points_X:	.dc	-Dk,Dk,Dk,Dk,Dk,-3*Dk,-3*Dk,-Dk
		.dc	-Dk,Dk,Dk,Dk,Dk,-3*Dk,-3*Dk,-Dk
J_Points_Y:	.dc	-3*Dk,-3*Dk,-3*Dk,3*Dk,3*Dk,3*Dk,Dk,Dk
		.dc	-3*Dk,-3*Dk,-3*Dk,3*Dk,3*Dk,3*Dk,Dk,Dk

S_Points_X:	.dc	-2*Dk,0,0,2*Dk,2*Dk,0,0,-2*Dk
		.dc	-2*Dk,0,0,2*Dk,2*Dk,0,0,-2*Dk
S_Points_Y:	.dc	-3*Dk,-3*Dk,-Dk,-Dk,3*Dk,3*Dk,Dk,Dk
		.dc	-3*Dk,-3*Dk,-Dk,-Dk,3*Dk,3*Dk,Dk,Dk

Z_Points_X:	.dc	-2*Dk,0,0,2*Dk,2*Dk,0,0,-2*Dk
		.dc	-2*Dk,0,0,2*Dk,2*Dk,0,0,-2*Dk
Z_Points_Y:	.dc	-Dk,-Dk,-3*Dk,-3*Dk,Dk,Dk,3*Dk,3*Dk
		.dc	-Dk,-Dk,-3*Dk,-3*Dk,Dk,Dk,3*Dk,3*Dk

T_Points_X:	.dc	-Dk,-Dk,Dk,Dk,3*Dk,3*Dk,-3*Dk,-3*Dk
		.dc	-Dk,-Dk,Dk,Dk,3*Dk,3*Dk,-3*Dk,-3*Dk
T_Points_Y:	.dc	-Dk,-3*Dk,-3*Dk,-Dk,-Dk,Dk,Dk,-Dk
		.dc	-Dk,-3*Dk,-3*Dk,-Dk,-Dk,Dk,Dk,-Dk

Points_Z:	.dc	Dz,Dz,Dz,Dz,Dz,Dz,Dz,Dz
		.dc	-Dz,-Dz,-Dz,-Dz,-Dz,-Dz,-Dz,-Dz

Vector_Points:
Vec_Points_X:	.pad	VEC_POINTS,0
Vec_Points_Y:	.pad	VEC_POINTS,0
Vec_Points_Z:	.pad	VEC_POINTS,0

Vec_Surface_List:	.dc	Vec_Surface1
			.dc	Vec_Surface2
			.dc	Vec_Surface3
			.dc	Vec_Surface4
			.dc	Vec_Surface5
			.dc	Vec_Surface6
			.dc	Vec_Surface7
			.dc	Vec_Surface8
			.dc	Vec_Surface9
			.dc	Vec_Surface10

Vec_Surface1:	.dc	0,1,2,3,4,5,6,7,0, -1		; Flat Top Surface
Vec_Surface2:	.dc	15,14,13,12,11,10,9,8,15, -1	; Flat Bottom Surface
Vec_Surface3:	.dc	1,0,8,9,1, -1
Vec_Surface4:	.dc	2,1,9,10,2, -1
Vec_Surface5:	.dc	3,2,10,11,3, -1
Vec_Surface6:	.dc	4,3,11,12,4, -1
Vec_Surface7:	.dc	5,4,12,13,5, -1
Vec_Surface8:	.dc	6,5,13,14,6, -1
Vec_Surface9:	.dc	7,6,14,15,7, -1
Vec_Surface10:	.dc	0,7,15,8,0, -1

Rot_Points_X:	.pad	VEC_POINTS , 0
Rot_Points_Y:	.pad	VEC_POINTS , 0
Rot_Points_Z:	.pad	VEC_POINTS , 0

Morph_Points:
Morph_Points_X:	.pad	VEC_POINTS , 0
Morph_Points_Y:	.pad	VEC_POINTS , 0
Morph_Points_Z:	.pad	VEC_POINTS , 0

Morph_Delta:
Morph_dX:	.pad	VEC_POINTS , 0
Morph_dY:	.pad	VEC_POINTS , 0
Morph_dZ:	.pad	VEC_POINTS , 0

LineDrawnTable:	.pad	VEC_POINTS , 0

Angle_X:	.dc	0
Angle_Y:	.dc	0
Angle_Z:	.dc	0

Vec_FrameCount:	.dc	0

Rotate:	PUSH	$ra
	PUSH	$s0	; Point
	PUSH	$s1	; Sin
	PUSH	$s2	; Cos
	PUSH	$s3	; X Point
	PUSH	$s4	; Y Point
	PUSH	$s5	; Z Point
	PUSH	$s6	; Acc1
	PUSH	$s7	; Acc2

	clr	$s0
Rotate_Point_Loop:
	; Get original positions
	lw	$s3,Vec_Points_X($s0)
	nop
	lw	$s4,Vec_Points_Y($s0)
	nop
	lw	$s5,Vec_Points_Z($s0)
	nop

	; Get Cos and Sin for Z-angle
	lw	$a0,Angle_Z($zero)
	nop
	_JAL	Sin
	mov	$s1,$v0
	lw	$a0,Angle_Z($zero)
	nop
	_JAL	Cos
	mov	$s2,$v0
	; Rotate around Z-axis ( Z-pos unaffected )
	mov	$a0,$s2	; X_Rot = Cos(xphi) * X_Pos - Sin(xphi) * Y_Pos
	mov	$a1,$s3
	_JAL	Muls16fpfast
	mov	$s6,$v0
	mov	$a0,$s1
	mov	$a1,$s4
	_JAL	Muls16fpfast
	sub	$s6,$s6,$v0
	mov	$a0,$s1	; Y_Rot = Sin(xphi) * X_Pos + Cos(xphi) * Y_Pos
	mov	$a1,$s3
	_JAL	Muls16fpfast
	mov	$s7,$v0
	mov	$a0,$s2
	mov	$a1,$s4
	_JAL	Muls16fpfast
	add	$s4,$s7,$v0	; New Ypos after Z-rotate to s4
	mov	$s3,$s6		; New Xpos after Z-rotate to s3

	; Get Cos and Sin for Y-angle
	lw	$a0,Angle_Y($zero)
	nop
	_JAL	Sin
	mov	$s1,$v0
	lw	$a0,Angle_Y($zero)
	nop
	_JAL	Cos
	mov	$s2,$v0
	; Rotate around Y-axis ( Y-pos unaffected )
	mov	$a0,$s2	; X_Rot = Cos(yphi) * X_Pos - Sin(yphi) * Z_Pos
	mov	$a1,$s3
	_JAL	Muls16fpfast
	mov	$s6,$v0
	mov	$a0,$s1
	mov	$a1,$s5
	_JAL	Muls16fpfast
	sub	$s6,$s6,$v0
	mov	$a0,$s1	; Z_Rot = Sin(yphi) * X_Pos + Cos(yphi) * Z_Pos
	mov	$a1,$s3
	_JAL	Muls16fpfast
	mov	$s7,$v0
	mov	$a0,$s2
	mov	$a1,$s5
	_JAL	Muls16fpfast
	add	$s5,$s7,$v0	; New Zpos after Y-rotate to s5
	mov	$s3,$s6		; New Xpos after Y-rotate to s3

	; Get Cos and Sin for X-angle
	lw	$a0,Angle_X($zero)
	nop
	_JAL	Sin
	mov	$s1,$v0
	lw	$a0,Angle_X($zero)
	nop
	_JAL	Cos
	mov	$s2,$v0
	; Rotate around X-axis ( X-pos unaffected )
	mov	$a0,$s2	; Y_Rot = Cos(yphi) * Y_Pos - Sin(yphi) * Z_Pos
	mov	$a1,$s4
	_JAL	Muls16fpfast
	mov	$s6,$v0
	mov	$a0,$s1
	mov	$a1,$s5
	_JAL	Muls16fpfast
	sub	$s6,$s6,$v0
	mov	$a0,$s1	; Z_Rot = Sin(yphi) * Y_Pos + Cos(yphi) * Z_Pos
	mov	$a1,$s4
	_JAL	Muls16fpfast
	mov	$s7,$v0
	mov	$a0,$s2
	mov	$a1,$s5
	_JAL	Muls16fpfast
	add	$s5,$s7,$v0	; New Zpos after Y-rotate to s5
	mov	$s4,$s6		; New Xpos after Y-rotate to s3

	sra	$s5,$s5,16

	; Perspective
	sra	$a0,$s3,8	; Perspective on X-cord
	addi	$a1,$s5,256
	_JAL	Divs16
	addi	$s3,$v0,MIDPOINT_X
	nop
	nop
	sw	$s3,Rot_Points_X($s0)

	sra	$a0,$s4,8	; Perspective on Y-cord
	addi	$a1,$s5,256
	_JAL	Divs16
	addi	$s4,$v0,MIDPOINT_Y
	nop
	nop
	sw	$s4,Rot_Points_Y($s0)

	addi	$s0,$s0,1
	movi	$t9,VEC_POINTS
	_BNE	$s0,$t9,Rotate_Point_Loop

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

Draw:	PUSH	$ra
	PUSH	$s0	; cord 0
	PUSH	$s1	; cord 1
	PUSH	$s2	; cord 2
	PUSH	$s3	;  temp

	PUSH	$s6	; Surface counter
	PUSH	$s7	; Surface pointer

	clr	$s6
	clr	$s3	; temp

	li	$t0,LineDrawnTable
	movi	$t1,VEC_POINTS
Draw_ClearLineDrawnTable:
	sw	$zero,0($t0)
	addi	$t0,$t0,1
	addi	$t1,$t1,-1
	_BNEZ	$t1,Draw_ClearLineDrawnTable

Draw_Surface_Loop:
	lw	$s7,Vec_Surface_List($s6)
	nop
	lw	$s0,0($s7)
	nop
	lw	$s1,1($s7)
	nop
	lw	$s2,2($s7)
	nop

Draw_Line_Loop:
	mov	$t0,$s0
	mov	$t1,$s1
	slt	$t2,$t0,$t1
	_BEQZ	$t2,Draw_NoSwitch
	mov	$t0,$s1
	mov	$t1,$s0
Draw_NoSwitch:
	lw	$t2,LineDrawnTable($t0)
	nop
	movi	$t3,1
	sllv	$t4,$t3,$t1
	and	$t3,$t4,$t2
	_BNEZ	$t3,Draw_LineAlreadyDrawn
	or	$t2,$t2,$t4
	nop
	nop
	sw	$t2,LineDrawnTable($t0)

	_LW	$a0,Rot_Points_X($s0)
	_LW	$a1,Rot_Points_Y($s0)
	_LW	$a2,Rot_Points_X($s1)
	_LW	$a3,Rot_Points_Y($s1)
	_JAL	Line
	addi	$s3,$s3,1

Draw_LineAlreadyDrawn:
	addi	$s7,$s7,1
	mov	$s0,$s1
	lw	$s1,1($s7)
	nop
	movi	$t1,-1
	_BNE	$s1,$t1,Draw_Line_Loop

	addi	$s6,$s6,1
	movi	$t1,VEC_SURFACE_COUNT
	_BNE	$s6,$t1,Draw_Surface_Loop

	POP	$s7
	POP	$s6
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

SetupMorph:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2

	clr	$s0

	li	$t1,Morph_Points
	li	$t2,Vector_Points
	li	$t3,Morph_Delta
	movi	$t9,3
SetupMorph_Loop:
	lw	$t0,0($a0)
	movi	$t8,VEC_POINTS
SetupMorph_InnerLoop:
	lw	$t5,0($t0)
	addi	$t0,$t0,1
	lw	$t6,0($t2)
	sll	$t5,$t5,16
	addi	$t8,$t8,-1
	sub	$t7,$t5,$t6
	addi	$t2,$t2,1
	sw	$t5,0($t1)
	addi	$t1,$t1,1
	sw	$t7,0($t3)
	slti	$t5,$t7,0
	sll	$t6,$t5,31
	sra	$t6,$t6,31
	xor	$t7,$t7,$t6
	add	$t7,$t7,$t5
	slt	$t5,$s0,$t7
	_BEQZ	$t5,SetupMorph_LessThan
	mov	$s0,$t7
SetupMorph_LessThan:
	addi	$t3,$t3,1
	_BNEZ	$t8,SetupMorph_InnerLoop
	addi	$a0,$a0,1
	addi	$t9,$t9,-1
	_BNEZ	$t9,SetupMorph_Loop

	li	$s2,Morph_Delta
	movi	$s1,VEC_POINTS*3
SetupMorph_Normalize_Loop:
	lw	$a0,0($s2)
	srl	$a1,$s0,16
	sra	$a0,$a0,8
	_JAL	Divs16
	sll	$v0,$v0,8
	nop
	nop
	sw	$v0,0($s2)
	addi	$s2,$s2,1
	addi	$s1,$s1,-1
	_BNEZ	$s1,SetupMorph_Normalize_Loop

	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	movi	$v0,7

	_RTS

MorphPoints:
	clr	$v0
	li	$t0,Vector_Points
	li	$t1,Morph_Points
	li	$t2,Morph_Delta
	movi	$t9,VEC_POINTS*3
MorphPoints_Loop:
	lw	$t3,0($t0)
	addi	$t9,$t9,-1
	lw	$t4,0($t1)
	addi	$t1,$t1,1
	lw	$t5,0($t2)
	nop
	add	$t3,$t3,$t5

	sra	$t6,$t3,16
	sra	$t4,$t4,16
	_BNE	$t4,$t6,MorphPoints_NotDone
	sw	$zero,0($t2)
	lui	$t6,0xffff
	and	$t3,$t3,$t6
	nop
	nop
MorphPoints_NotDone:
	sw	$t3,0($t0)
	addi	$t0,$t0,1
	addi	$t2,$t2,1
	_BNEZ	$t9,MorphPoints_Loop
	_RTS

SimpleMorphPoints:
	clr	$v0
	li	$t1,Vector_points
	movi	$t9,3
SimpleMorphPoints_Loop:
	lw	$t0,0($a0)
	movi	$t8,VEC_POINTS
SimpleMorphPoints_Inner_Loop:
	lw	$t2,0($t0)
	addi	$t0,$t0,1
	lw	$t3,0($t1)
	addi	$t8,$t8,-1

	slt	$t4,$t3,$t2
	add	$t3,$t3,$t4
	or	$v0,$v0,$t4
	slt	$t4,$t2,$t3
	sub	$t3,$t3,$t4
	or	$v0,$v0,$t4
	nop
	sw	$t3,0($t1)
	addi	$t1,$t1,1
	_BNEZ	$t8,SimpleMorphPoints_Inner_Loop
	addi	$a0,$a0,1
	addi	$t9,$t9,-1
	_BNEZ	$t9,SimpleMorphPoints_Loop
	_RTS

CopyPoints:
	li	$t1,Vector_points
	movi	$t9,3
CopyPoints_Loop:
	lw	$t0,0($a0)
	movi	$t8,VEC_POINTS
CopyPoints_Inner_Loop:
	lw	$t2,0($t0)
	addi	$t0,$t0,1
	addi	$t8,$t8,-1
	sll	$t2,$t2,16
	nop
	nop
	sw	$t2,0($t1)
	addi	$t1,$t1,1
	_BNEZ	$t8,CopyPoints_Inner_Loop
	addi	$a0,$a0,1
	addi	$t9,$t9,-1
	_BNEZ	$t9,CopyPoints_Loop
	_RTS

MorphFrame:
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1

	_BEQZ	$a0,MorphFrame_DontChangeTarget
	_STA	$zero,Target_Color
MorphFrame_DontChangeTarget:
	_JAL	MorphPoints		; 2 morph steps per frame at 50 Hz,
	_LDA	$t0,HalfStep		; 2,2,1,2,2,1 at 60 Hz
	_BNEZ	$t0,MorphFrame_HalfStep
	_JAL	MorphPoints
MorphFrame_HalfStep:

	_LI	$t0,Angle_Y
	_LW	$t1,0($t0)
	addi	$t1,$t1,ROTATESPEED
	_SW	$t1,0($t0)

	_LI	$s0,Vec_FrameCount
	_LW	$s1,0($s0)
	addi	$s1,$s1,-1
	_BNEZ	$s1,MorphFrame_DontMorphNext
	movi	$s1,FRAMESBEFOREMORPH
	_JAL	MorphNext
MorphFrame_DontMorphNext:
	_SW	$s1,0($s0)
	_LDA	$a0,Current_Color
	_JAL	SetColor
	_JAL	Rotate
	_JAL	Draw

	movi	$v1,1
	_JAL	GetFrameCount
	sll	$v0,$v0,29			; fade every 8th 50 Hz tick
	_BNEZ	$v0,MorphFrame_DontFade
	_LDA	$a0,Current_Color
	_LDA	$a1,Target_Color
	_JAL	FadeSourceToDest
	_STA	$v0,Current_Color
MorphFrame_DontFade:
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS

StartMorph:
	PUSH	$ra

	_LI	$t0,Angle_X
	movi	$t1,0x1234
	_SW	$t1,0($t0)
	_SW	$zero,1($t0)
	_SW	$zero,2($t0)

	_STA	$zero,Current_Color
	moviu	$t0,VEC_COLOR
	_STA	$t0,Target_Color

	movi	$t1,FRAMESBEFOREMORPH
	_STA	$t1,Vec_FrameCount

	_LI	$t0,Vector_Points
	movi	$t1,VEC_POINTS*3
StartMorph_Loop:
	sw	$zero,0($t0)
	addi	$t0,$t0,1
	addi	$t1,$t1,-1
	_BNEZ	$t1,StartMorph_Loop

	_LDA	$a0,Object_List
	_JAL	SetupMorph

	POP	$ra
	_RTS

MorphNext:
	PUSH	$ra

	_LDA	$t0,Current_ObjectNbr
	addi	$t0,$t0,1
	movi	$t1,NOFOBJECTS
	_BNE	$t0,$t1,MorphNext_NoOverflow
	clr	$t0
MorphNext_NoOverflow:
	_STA	$t0,Current_ObjectNbr

	_LDO	$a0,Object_List,$t0
	_JAL	SetupMorph

	POP	$ra
	_RTS

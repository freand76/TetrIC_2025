##################
# Text Functions #
##################

PrintString:
	; a0 = string
	; a1 = x (left)
	; a2 = y (top)
	; a3 = HIGH = Transparent | LOW = Color
	; Transparent 0=No, 1=Yes

	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3

	mov	$s0,$a0
	mov	$s1,$a1

String_NextWord:
	_LW	$s2,0($s0)
	addi	$s0,$s0,1
	movi	$s3,4
String_NextChar:
	srl	$a0,$s2,24
	mov	$a1,$s1
	_BEQZ	$a0,String_Done
	_JAL	PrintASCII
	addi	$s1,$s1,8
	sll	$s2,$s2,8
	addi	$s3,$s3,-1
	_BNEZ	$s3,String_NextChar
	_J	String_NextWord

String_Done:
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS

PrintLargeString:
	; a0 = string
	; a1 = x (left)
	; a2 = y (top)
	; a3 = Color

	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3

	mov	$s0,$a0
	mov	$s1,$a1

Large_NextWord:
	_LW	$s2,0($s0)
	addi	$s0,$s0,1
	movi	$s3,4
Large_NextChar:
	srl	$a0,$s2,24
	mov	$a1,$s1
	_BEQZ	$a0,Large_Done
	_JAL	PrintLargeASCII
	addi	$s1,$s1,16
	sll	$s2,$s2,8
	addi	$s3,$s3,-1
	_BNEZ	$s3,Large_NextChar
	_J	Large_NextWord

Large_Done:
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS


PrintASCII:
	; a0 = ASCII
	; a1 = x (left)
	; a2 = y (top)
	; a3 = HIGH = Transparent | LOW = Color
	; Transparent 0=No, 1=Yes

	PUSH	$s0
	PUSH	$s1
	PUSH	$s3
	PUSH	$s4
	PUSH	$s5

	_LI	$s0,Font8x16		; Array Offset
	mov	$t0,$a0			; ASCII value
	srl	$t1,$t0,4		; Get Row in font
	sll	$t1,$t1,6		; 128 pixels each row gives 128/8x16=256 bytes=64 words before next char row
	add	$s0,$s0,$t1		; We are on the right row

	andi	$t0,$t0,0x000f		; Get Col in font
	srl	$t1,$t0,2		; 1 byte in each col gives 1/4 word
	add	$s0,$s0,$t1		; We are on the right col

	andi	$t0,$t0,0x0003		; Byteoffset in word
	sll	$s4,$t0,3		; Shiftamount in word = Byteoffset*8

	srl	$t6,$a3,16		; Transparant in $t6
	sll	$t7,$a3,16		; color in $t7 High/Left
	srl	$t8,$t7,16		; color in $t8 Low/Right

	_LI	$t0,WorkScreen		; Screen Offset
	_LW	$s1,0($t0)

	srl	$t0,$a1,1		; X / 2
	add	$s1,$s1,$t0		; Add X Offset to workscreen

	sll	$t0,$a2,7		; Y * 128
	sll	$t1,$a2,5		; Y * 32
	add	$t0,$t0,$t1		; Y * 160
	add	$s1,$s1,$t0		; Add Y Offset to workscreen

	or	$s5,$t7,$t8		; color in both halves of a word
	movi	$s3,16			; 16 Rows in total
	; 8 pixels = 4 words per row, unrolled and without branches: the font
	; bits give a mask per word, the transparent version keeps the screen
	; pixels where the font pixel is clear
	_BNEZ	$t6,ASCII_TransRow
ASCII_OpaqueRow:
	lw	$t1,0($s0)		; font row: 4 characters, 8 bits each
	nop
	sllv	$t1,$t1,$s4		; this character in bits 31:24
	sra	$t2,$t1,31		; left pixel set: all ones
	sll	$t1,$t1,1
	sra	$t3,$t1,31		; right pixel set: all ones
	sll	$t1,$t1,1
	andi	$t2,$t2,0		; andi fills bits 31:16 with ones: left mask
	srl	$t3,$t3,16		; right mask
	or	$t2,$t2,$t3		; pixel mask
	and	$t0,$t2,$s5		; color where the font pixel is set
	sra	$t2,$t1,31		; left pixel set: all ones
	sll	$t1,$t1,1
	sra	$t3,$t1,31		; right pixel set: all ones
	sll	$t1,$t1,1
	andi	$t2,$t2,0		; andi fills bits 31:16 with ones: left mask
	srl	$t3,$t3,16		; right mask
	or	$t2,$t2,$t3		; pixel mask
	and	$t6,$t2,$s5		; color where the font pixel is set
	sra	$t2,$t1,31		; left pixel set: all ones
	sll	$t1,$t1,1
	sra	$t3,$t1,31		; right pixel set: all ones
	sll	$t1,$t1,1
	andi	$t2,$t2,0		; andi fills bits 31:16 with ones: left mask
	srl	$t3,$t3,16		; right mask
	or	$t2,$t2,$t3		; pixel mask
	and	$t7,$t2,$s5		; color where the font pixel is set
	sra	$t2,$t1,31		; left pixel set: all ones
	sll	$t1,$t1,1
	sra	$t3,$t1,31		; right pixel set: all ones
	sll	$t1,$t1,1
	andi	$t2,$t2,0		; andi fills bits 31:16 with ones: left mask
	srl	$t3,$t3,16		; right mask
	or	$t2,$t2,$t3		; pixel mask
	and	$t8,$t2,$s5		; color where the font pixel is set
	sw	$t0,0($s1)
	sw	$t6,1($s1)
	sw	$t7,2($s1)
	sw	$t8,3($s1)
	addi	$s3,$s3,-1		; Row=Row-1
	bnez	$s3,ASCII_OpaqueRow
	addi	$s1,$s1,160		; delay slot: next row on screen
	addi	$s0,$s0,4		; delay slot: next row in font
	nop
	_J	ASCII_Done
ASCII_TransRow:
	lw	$t1,0($s0)		; font row: 4 characters, 8 bits each
	nop
	sllv	$t1,$t1,$s4		; this character in bits 31:24
	lw	$t4,0($s1)		; screen word
	sra	$t2,$t1,31		; left pixel set: all ones
	sll	$t1,$t1,1
	sra	$t3,$t1,31		; right pixel set: all ones
	sll	$t1,$t1,1
	andi	$t2,$t2,0		; andi fills bits 31:16 with ones: left mask
	srl	$t3,$t3,16		; right mask
	or	$t2,$t2,$t3		; pixel mask
	xor	$t5,$t4,$s5
	and	$t5,$t5,$t2
	xor	$t0,$t4,$t5		; screen word with the set pixels in the color
	lw	$t4,1($s1)		; screen word
	sra	$t2,$t1,31		; left pixel set: all ones
	sll	$t1,$t1,1
	sra	$t3,$t1,31		; right pixel set: all ones
	sll	$t1,$t1,1
	andi	$t2,$t2,0		; andi fills bits 31:16 with ones: left mask
	srl	$t3,$t3,16		; right mask
	or	$t2,$t2,$t3		; pixel mask
	xor	$t5,$t4,$s5
	and	$t5,$t5,$t2
	xor	$t6,$t4,$t5		; screen word with the set pixels in the color
	lw	$t4,2($s1)		; screen word
	sra	$t2,$t1,31		; left pixel set: all ones
	sll	$t1,$t1,1
	sra	$t3,$t1,31		; right pixel set: all ones
	sll	$t1,$t1,1
	andi	$t2,$t2,0		; andi fills bits 31:16 with ones: left mask
	srl	$t3,$t3,16		; right mask
	or	$t2,$t2,$t3		; pixel mask
	xor	$t5,$t4,$s5
	and	$t5,$t5,$t2
	xor	$t7,$t4,$t5		; screen word with the set pixels in the color
	lw	$t4,3($s1)		; screen word
	sra	$t2,$t1,31		; left pixel set: all ones
	sll	$t1,$t1,1
	sra	$t3,$t1,31		; right pixel set: all ones
	sll	$t1,$t1,1
	andi	$t2,$t2,0		; andi fills bits 31:16 with ones: left mask
	srl	$t3,$t3,16		; right mask
	or	$t2,$t2,$t3		; pixel mask
	xor	$t5,$t4,$s5
	and	$t5,$t5,$t2
	xor	$t8,$t4,$t5		; screen word with the set pixels in the color
	sw	$t0,0($s1)
	sw	$t6,1($s1)
	sw	$t7,2($s1)
	sw	$t8,3($s1)
	addi	$s3,$s3,-1		; Row=Row-1
	bnez	$s3,ASCII_TransRow
	addi	$s1,$s1,160		; delay slot: next row on screen
	addi	$s0,$s0,4		; delay slot: next row in font
	nop
ASCII_Done:
	POP	$s5
	POP	$s4
	POP	$s3
	POP	$s1
	POP	$s0

	_RTS

PrintLargeASCII:
	; a0 = ASCII
	; a1 = x (left)
	; a2 = y (top)
	; a3 = Color

	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4

	_LI	$s0,Font8x16		; Array Offset
	mov	$t0,$a0			; ASCII value
	srl	$t1,$t0,4		; Get Row in font
	sll	$t1,$t1,6		; 128 pixels each row gives 128/8x16=256 bytes=64 words before next char row
	add	$s0,$s0,$t1		; We are on the right row

	andi	$t0,$t0,0x000f		; Get Col in font
	srl	$t1,$t0,2		; 1 byte in each col gives 1/4 word
	add	$s0,$s0,$t1		; We are on the right col

	andi	$t0,$t0,0x0003		; Byteoffset in word
	sll	$s4,$t0,3		; Shiftamount in word = Byteoffset*8

	sll	$t7,$a3,16		; color in $t7 High/Left
	srl	$t8,$t7,16		; color in $t8 Low/Right
	or	$t7,$t7,$t8		; color in $t7 (High and Low)

	_LI	$t0,WorkScreen		; Screen Offset
	_LW	$s1,0($t0)

	srl	$t0,$a1,1		; X / 2
	add	$s1,$s1,$t0		; Add X Offset to workscreen

	sll	$t0,$a2,7		; Y * 128
	sll	$t1,$a2,5		; Y * 32
	add	$t0,$t0,$t1		; Y * 160
	add	$s1,$s1,$t0		; Add Y Offset to workscreen

	movi	$s3,16			; 16 Rows in total
Large_RowLoop:
	_LW	$t1,0($s0)		; Read font data
	nop			; hazard
	sllv	$t1,$t1,$s4		; Character offset in word (4 characters in each word)
	movi	$s2,8			; 4 Words = 8 pixels on screen
Large_ColLoop:
	slt	$t2,$t1,$zero		; Is pixel set in font ?
	_BEQZ	$t2,Large_NotSet	; If not continue
	_SW	$t7,0($s1)		;
	_SW	$t7,160($s1)		;
Large_NotSet:
	sll	$t1,$t1,1		; Next pixel
	addi	$s1,$s1,1		; Next word on screen
	addi	$s2,$s2,-1		; Word=Word-1
	_BNEZ	$s2,Large_ColLoop	; Is this row done ?

	addi	$s1,$s1,312		; Add number of words until next row on screen

	addi	$s3,$s3,-1		; Row=Row-1
	addi	$s0,$s0,4		; Add number of words until next row in font
	_BNEZ	$s3,Large_RowLoop	; Are we done with this character ?

	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0

	_RTS

PrintNumber16:
	; a0 = tal
	; a1 = x (right edge)
	; a2 = y (top edge)
	; a3 = color
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2

	mov	$s0,$a0
	addi	$s1,$a1,-8

	movi	$s2,5
PrintNumber16_Div10Loop:
	mov	$a0,$s0
	movi	$a1,10
	_JAL	Divu16
	mov	$s0,$v0

	mov	$a0,$v1
	addi	$a0,$a0,0x30	; ASCII Value for zero
	mov	$a1,$s1
	_JAL	PrintASCII
	_BEQZ	$s0,PrintNumber16_Done
	addi	$s1,$s1,-8
	addi	$s2,$s2,-1
	_BNEZ	$s2,PrintNumber16_Div10Loop

PrintNumber16_Done:

	POP	$s2
	POP	$s1
	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra
	_RTS


PrintHex:
	; a0 = tal
	; a1 = x (right edge)
	; a2 = y (top edge)
	; a3 = color
	PUSH	$ra
	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3
	PUSH	$s4

	mov	$s0,$a0
	mov	$s1,$a1
	mov	$s2,$a2
	mov	$s3,$a3

	movi	$s4,8
PrintHex_Loop:
	movi	$t0,0xf
	and	$t0,$s0,$t0
	srl	$s0,$s0,4
	slti	$t1,$t0,10
	addi	$a0,$t0,0x30
	addi	$t1,$t1,-1
	srl	$t1,$t1,29
	add	$a0,$a0,$t1
PrintHex_LessThan10:
	mov	$a1,$s1
	mov	$a2,$s2
	mov	$a3,$s3
	_JAL	PrintASCII
	addi	$s1,$s1,-8
	addi	$s4,$s4,-1
	_BNEZ	$s4,PrintHex_Loop

	POP	$s4
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	POP	$ra
	_RTS


########
# Font #
########

Font8x16:	.file	TLib/Data/Font8x16.raw 1024

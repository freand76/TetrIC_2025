##################
# Math Functions #
##################

Divu16:	; Unsigned Division
	; $a0 - dividend (16 bits) unsigned
	; $a1 - divisor (16 bits) unsigned
	; $v0 - quotient (16 bits) unsigned
	; $v1 - remainder (16 bits) unsigned

	_BEQZ	$a1,Divu16_Exit		; DivideByZero
	moviu	$t8,0xffff		; mask a0 16 bits
	and	$a0,$a0,$t8
	sll	$a1,$a1,16		; mask a1 16 bits
	movi	$t9,16
Divu16_Loop:
	sll	$a0,$a0,1
	addi	$t4,$a0,1		; add one for less than or equal
	slt	$t4,$a1,$t4
	sll	$t5,$t4,31
	sra	$t5,$t5,31
	and	$t5,$a1,$t5
	sub	$a0,$a0,$t5
	or	$a0,$a0,$t4
	addi	$t9,$t9,-1
	_BNEZ	$t9,Divu16_Loop
	and	$v0,$a0,$t8
	srl	$v1,$a0,16
Divu16_Exit:
	_RTS				; Return from subroutine

Divs16:	; Signed Division
	; $a0 - dividend (16 bits) signed
	; $a1 - divisor (16 bits) signed
	; $v0 - quotient (16 bits) signed
	; $v1 - remainder (16 bits) signed

	_BEQZ	$a1,Divs16_Exit		;DivideByZero
	slti	$t0,$a0,0	; make a0 positive
	sll	$t1,$t0,31
	sra	$t1,$t1,31
	xor	$a0,$a0,$t1
	add	$a0,$a0,$t0
	slti	$t2,$a1,0	; make a1 positive
	sll	$t3,$t2,31
	sra	$t3,$t3,31
	xor	$a1,$a1,$t3
	add	$a1,$a1,$t2
	moviu	$t8,0xffff	; mask a0 16 bits
	and	$a0,$a0,$t8
	sll	$a1,$a1,16	; mask a1 16 bits
	movi	$t9,16
Divs16_Loop:
	sll	$a0,$a0,1
	addi	$t4,$a0,1	; add one for less than or equal
	slt	$t4,$a1,$t4
	sll	$t5,$t4,31
	sra	$t5,$t5,31
	and	$t5,$a1,$t5
	sub	$a0,$a0,$t5
	or	$a0,$a0,$t4
	addi	$t9,$t9,-1
	_BNEZ	$t9,Divs16_Loop
	and	$v0,$a0,$t8
	srl	$v1,$a0,16
	xor	$t1,$t1,$t3	; put correct sign on result
	xor	$t0,$t0,$t2
	xor	$v0,$v0,$t1
	add	$v0,$v0,$t0
	xor	$v1,$v1,$t1
	add	$v1,$v1,$t0
Divs16_Exit:
	_RTS				; Return from subroutine

Mulu16:	; Unsigned Multiplication
	; $a0 - multiplier 1 (16 bits)
	; $a1 - multiplier 2 (32 bits)
	; $v0 - result (maximum 32 bits)
	clr	$v0
	movi	$t9,16
Mulu16_Loop:
	sll	$t8,$a0,31
	sra	$t8,$t8,31
	and	$t8,$a1,$t8
	add	$v0,$v0,$t8
	sll	$a1,$a1,1
	srl	$a0,$a0,1
	addi	$t9,$t9,-1
	_BNEZ	$t9,Mulu16_Loop
	_RTS

Muls16:	; Signed Multiplication
	; $a0 - multiplier 1 (16 bits)
	; $a1 - multiplier 2 (32 bits)
	; $v0 - result (maximum 32 bits)
	slti	$t0,$a0,0	; make a0 positive
	sll	$t1,$t0,31
	sra	$t1,$t1,31
	xor	$a0,$a0,$t1
	add	$a0,$a0,$t0
	slti	$t2,$a1,0	; make a1 positive
	sll	$t3,$t2,31
	sra	$t3,$t3,31
	xor	$a1,$a1,$t3
	add	$a1,$a1,$t2
	clr	$v0
	movi	$t9,16
Muls16_Loop:
	sll	$t8,$a0,31
	sra	$t8,$t8,31
	and	$t8,$a1,$t8
	add	$v0,$v0,$t8
	sll	$a1,$a1,1
	srl	$a0,$a0,1
	addi	$t9,$t9,-1
	_BNEZ	$t9,Muls16_Loop
	xor	$t1,$t1,$t3	; put correct sign on result
	xor	$t0,$t0,$t2
	xor	$v0,$v0,$t1
	add	$v0,$v0,$t0
	_RTS

Muls16fp:
	; Signed Multiplication fixed point 16 + 16
	; $a0 - multiplier 1 (16 + 16 bits)
	; $a1 - multiplier 2 (16 + 16 bits)
	; $v0 - result (16 + 16 bits)
	slti	$t0,$a0,0	; make a0 positive
	sll	$t1,$t0,31
	sra	$t1,$t1,31
	xor	$a0,$a0,$t1
	add	$a0,$a0,$t0

	slti	$t2,$a1,0	; make a1 positive
	sll	$t3,$t2,31
	sra	$t3,$t3,31
	xor	$a1,$a1,$t3
	add	$a1,$a1,$t2
	clr	$v0

	clr	$t4	; high multiplier
	clr	$t5	; high result
	clr	$t6	; low result

	movi	$t9,32
Muls16fp_Loop:
	sll	$t8,$a0,31
	sra	$t8,$t8,31

	and	$t7,$a1,$t8
	add	$t7,$t6,$t7
	sltu	$t0,$t7,$t6
	add	$t5,$t5,$t0
	mov	$t6,$t7

	and	$t7,$t4,$t8
	add	$t5,$t5,$t7

	sll	$t4,$t4,1
	srl	$t8,$a1,31
	or	$t4,$t4,$t8
	sll	$a1,$a1,1
	srl	$a0,$a0,1

	addi	$t9,$t9,-1
	_BNEZ	$t9,Muls16fp_Loop

	xor	$t1,$t1,$t3	; put correct sign on result
	xor	$t0,$t0,$t2
	xor	$t5,$t5,$t1
	xor	$t6,$t6,$t1
	add	$t7,$t6,$t0
	sltu	$t0,$t7,$t6
	add	$t5,$t5,$t0
	mov	$t6,$t7
	sll	$t5,$t5,16
	srl	$t6,$t6,16
	or	$v0,$t5,$t6

	_RTS

Muls16fpfast:
	; Signed Multiplication
	; $a0 - multiplier 1	(fixed point 0 + 16 bits)
	; $a1 - multiplier 2	(fixed point 8 + 16 bits)
	; $v0 - result		(fixed point 16 + 16 bits)

	sra	$a1,$a1,8

	slti	$t0,$a0,0	; make a0 positive
	sll	$t1,$t0,31
	sra	$t1,$t1,31
	xor	$a0,$a0,$t1
	add	$a0,$a0,$t0
	slti	$t2,$a1,0	; make a1 positive
	sll	$t3,$t2,31
	sra	$t3,$t3,31
	xor	$a1,$a1,$t3
	add	$a1,$a1,$t2
	clr	$v0
	movi	$t9,16
Muls16fpfast_Loop:
	sll	$t8,$a0,31
	sra	$t8,$t8,31
	and	$t8,$a1,$t8
	add	$v0,$v0,$t8
	sll	$a1,$a1,1
	srl	$a0,$a0,1
	addi	$t9,$t9,-1
	_BNEZ	$t9,Muls16fpfast_Loop
	xor	$t1,$t1,$t3	; put correct sign on result
	xor	$t0,$t0,$t2
	xor	$v0,$v0,$t1
	add	$v0,$v0,$t0

	sra	$v0,$v0,8
	_RTS

Randomize:
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$s0

	_LI	$s0,RandomSeed
	_LW	$a0,0($s0)

	movi	$t0, 2
	mfc1	$a1, $t0	; Get hcount
	_JAL	Mulu16		; Mulu Randomseed with hcount

	movi	$t0, 0
	mfc1	$t1, $t0	; get gfxregisters
	xor	$v0,$v0,$t1	; Xor New seed with gfxregisterss

	_SW	$v0, 0($s0)

	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra

	_RTS

RANDOMMULTIPLIER = 903317621
RandomSeed:	.dc	42346786

Rnd:
	PUSH	$ra
	PUSH	$a0
	PUSH	$a1
	PUSH	$s0

	_LI	$s0,RandomSeed
	_LW	$a0,0($s0)
	_LI	$a1,RANDOMMULTIPLIER
	_JAL	Mulu16
	addi	$v0,$v0,1
	_SW	$v0,0($s0)

	POP	$s0
	POP	$a1
	POP	$a0
	POP	$ra

	_RTS

Sin:	; $a0 input - 16 bit value
	; 0x0000 = 0 degrees
	; 0x4000 = 90 degrees
	; 0x8000 = 180 degrees
	; 0xc000 = 270 degrees
	; 0x10000 = 360 degrees = 0 degrees
	; $v0 = result -65535 <-> +65535
	sll	$t0,$a0,16	; remove whole part of fixed point 16+16
	srl	$t0,$t0,20	; Keep 12 upper bits (4096) of lower 16 bits (pointer)
	sll	$t1,$a0,28	; mask out odd (was $t9, only set by Cos)
	srl	$t1,$t1,31	; or even value
	sll	$t1,$t1,4	; and multiply it by 16
	li	$t2,Sinus
	add	$t2,$t2,$t0
	lw	$t0,0($t2)
	nop
	sllv	$t0,$t0,$t1
	sra	$v0,$t0,15
	_RTS

Cos:	; $a0 input - 16 bit value
	; 0x0000 = 0 degrees
	; 0x4000 = 90 degrees
	; 0x8000 = 180 degrees
	; 0xc000 = 270 degrees
	; 0x10000 = 360 degrees = 0 degrees
	; $v0 = result -65535 <-> +65535
	addiu	$t9,$a0,0x4000	; add 90 degrees in the sin table to get cos
	sll	$t0,$t9,16	; remove whole part of fixed point 16+16
	srl	$t0,$t0,20	; Keep 12 upper bits (4096) of lower 16 bits (pointer)
	sll	$t1,$t9,28	; mask out odd
	srl	$t1,$t1,31	; or even value
	sll	$t1,$t1,4	; and multiply it by 16
	li	$t2,Sinus
	add	$t2,$t2,$t0
	lw	$t0,0($t2)
	nop
	sllv	$t0,$t0,$t1
	sra	$v0,$t0,15
	_RTS

Sinus:	.file	TLib/Data/Sinus.raw	4096

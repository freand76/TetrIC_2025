#############
# M A C R O #
#############

	; The load/store macros have no nops of their own: abnasm checks the
	; pipeline rules (rtl/processor/PIPELINE_HAZARDS.md) and the nops are
	; written where the code needs them. The branch and jump macros keep
	; their nops, those are the delay slots.

	; load immidiate 32-bit integer
	.macro _LI @reg0,@Imm0
	lui	@reg0, @Imm0.H
	ori	@reg0, @reg0, @Imm0.L
	.endmacro

	; pop register from stack
	.macro POP @reg0
	lw	@reg0, 0($sp)
	addi	$sp,$sp, 1   # post-increment
	.endmacro

	; pop register to stack
	.macro PUSH @reg0
	addi	$sp,$sp, -1   # pre-decrement
	sw	@reg0, 0($sp)
	.endmacro

	; safe branch
	.macro _B @Imm0
	b	@Imm0
	nop
	nop
	nop
	.endmacro

	; safe bne
	.macro _BNE @reg0,@reg1,@Imm0
	bne	@reg0,@reg1,@Imm0
	nop
	nop
	nop
	.endmacro

	; safe bnez
	.macro _BNEZ @reg0,@Imm0
	bnez	@reg0,@Imm0
	nop
	nop
	nop
	.endmacro

	; safe bgt
	.macro _BGT @reg0,@reg1,@Imm0
	bgt	@reg0,@reg1,@Imm0
	nop
	nop
	nop
	.endmacro

	; safe bge
	.macro _BGE @reg0,@reg1,@Imm0
	bge	@reg0,@reg1,@Imm0
	nop
	nop
	nop
	.endmacro

	; safe bgez
	.macro _BGEZ @reg0,@Imm0
	bgez	@reg0,@Imm0
	nop
	nop
	nop
	.endmacro

	; safe beq
	.macro _BEQ @reg0,@reg1,@Imm0
	beq	@reg0,@reg1,@Imm0
	nop
	nop
	nop
	.endmacro

	; safe beqz
	.macro _BEQZ @reg0,@Imm0
	beqz	@reg0,@Imm0
	nop
	nop
	nop
	.endmacro

	; safe jump
	.macro _J @Imm0
	j	@Imm0
	nop
	.endmacro

	; safe jump and link
	.macro _JAL @Imm0
	jal	@Imm0
	nop
	.endmacro

	; safe jump and link register
	.macro _JALR @Reg0,@Reg1
	jalr	@Reg0,@Reg1
	nop
	nop
	nop
	.endmacro

	; safe return from subroutine
	.macro _RTS
	jr	$ra
	nop
	nop
	nop
	.endmacro

	; safe load word instruction
	.macro _LW @reg0,@Imm0(@reg1)
	lw	@reg0,@Imm0(@reg1)
	.endmacro

	; safe store word instruction
	.macro _SW @reg0,@Imm0(@reg1)
	sw	@reg0,@Imm0(@reg1)
	.endmacro

	; load register from address
	.macro	_LDA @reg0,@Imm0
	lui	$at, @Imm0.H
	ori	$at, $at, @Imm0.L
	lw	@reg0,0($at)
	.endmacro

	; store register to address
	.macro	_STA @reg0,@Imm0
	lui	$at, @Imm0.H
	ori	$at, $at, @Imm0.L
	sw	@reg0,0($at)
	.endmacro

	; load register from address with offset from register
	.macro	_LDO @reg0,@Imm0,@reg1
	lui	$at, @Imm0.H
	ori	$at, $at, @Imm0.L
	add	$at,$at,@reg1
	lw	@reg0,0($at)
	.endmacro

	; store register to address with offset from register
	.macro	_STO @reg0,@Imm0,@reg1
	lui	$at, @Imm0.H
	ori	$at, $at, @Imm0.L
	add	$at,$at,@reg1
	sw	@reg0,0($at)
	.endmacro

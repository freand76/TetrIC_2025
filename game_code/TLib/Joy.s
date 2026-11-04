##################
# Check Joystick #
##################

JoyRepeatWait:	.dc	0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

JOY_UP		= 15
JOY_DOWN	= 13
JOY_LEFT	= 10
JOY_RIGHT	= 12
JOY_BUTA	= 14
JOY_BUTB	= 11
JOY_BUTC	= 8
JOY_START	= 9

CheckJoystick:
	; $v0 = Result
	mfc2	$t0			; Read Joystick (Active Low)
	not	$t0,$t0			; Neg (Active High)
	clr	$v0			; Clear Result
	moviu	$t9,0xffff		; Mask
	_LI	$t1,JoyRepeatWait	; Clear repeat counter
	movi	$t2,8			; Count=8, 8 Bits (Directions and Buttons)
	sll	$t0,$t0,24		; Shift to sign bit
CheckJoyStick_Loop:
ClearRepeat:
	_LW	$t4,0($t1)		; Load
	_LW	$t6,8($t1)		; Load Filter | RepeatVal | Accellerate
	sll	$t6,$t6,8
	srl	$t7,$t6,24		; Filter in $t7
	sll	$t6,$t6,8
	srl	$t8,$t6,24		; RepeatVal in $t8
	sll	$t6,$t6,8
	srl	$t6,$t6,24		; Accelerate in $t6

	srl	$t5,$t4,16		; Get Repeat Value
	and	$t4,$t4,$t9		; Get Repeat Count
	slti	$t3,$t0,0		; Is Joy Bit Set ?
	_BNEZ	$t3,ClearRepeat_Dont	; No, Set Default values
	mov	$t4,$t7			; Set filtervalue
	mov	$t5,$t8			; Set repeatvalue
ClearRepeat_Dont:
	sub	$t4,$t4,$t3		; Yes, repeatvalue--
SetRepeatCount:
	slti	$t3,$t4,0		; Is repeatcount Negative ?
	sll	$v0,$v0,1		; Shift result
	or	$v0,$v0,$t3		; Yes, Set Result Bit
	_BEQZ	$t3,SetRepeatCount_Dont	; Is repeatcount negative ?
	mov	$t4,$t5			; repeatcount = repeatval
	slt	$t3,$zero,$t5		; is repeatcount bigger than zero
	sll	$t3,$t3,31		; Yes, Shift set bit to top
	sra	$t3,$t3,31		; Yes, And make a nice mask word
	and	$t3,$t3,$t6		; Mask accelerate value
	sub	$t5,$t5,$t3		; Sub Aceelerate value
SetRepeatCount_Dont:
	sll	$t5,$t5,16		; Shift up repeatval
	or	$t4,$t4,$t5		; or with repeatcount
	_SW	$t4,0($t1)		; Store until next time
	sll	$t0,$t0,1		; Next joybit
	addi	$t1,$t1,1		; Next mempos
	addi	$t2,$t2,-1		; count--
	_BNEZ	$t2,CheckJoystick_Loop	; Are we done
	_RTS

###########################
# WaitButton_PressRelease #
###########################

WaitButton_PressRelease:
	PUSH	$ra
WaitButton_Press:
	mfc2	$t0
	andi	$t0,$t0,0xd2
	movi	$t1,0xd2
	_BEQ	$t0,$t1,WaitButton_Press
	_JAL	WaitNextFrameNoSwap
WaitButton_Release:
	mfc2	$t0
	andi	$t0,$t0,0xd2
	movi	$t1,0xd2
	_BNE	$t0,$t1,WaitButton_Release
	_JAL	WaitNextFrameNoSwap
	POP	$ra
	_RTS

###############
# CheckButton #
###############

CheckButton:
	movi	$v0,0
	mfc2	$t0
	movi	$t1,0xd2
	and	$t0,$t0,$t1
	_BEQ	$t0,$t1,CheckButton_NoButton
	movi	$v0,1
CheckButton_NoButton:
	_RTS

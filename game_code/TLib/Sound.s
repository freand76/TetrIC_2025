###################
# Sound Registers #
###################

SFX_OFFSET	= 0
SFX_LUT		= 1
SFX_CHANSTATUS	= 2
SFX_SONGSTATUS	= 3
SFX_FX0_START	= 4
SFX_FX1_START	= 5
SFX_FX2_START	= 6
SFX_FX3_START	= 7
SFX_FX0_VOL	= 8
SFX_FX1_VOL	= 9
SFX_FX2_VOL	= 10
SFX_FX3_VOL	= 11
SFX_FX0_END	= 12
SFX_FX1_END	= 13
SFX_FX2_END	= 14
SFX_FX3_END	= 15
SFX_FX0_LSTART	= 16
SFX_FX1_LSTART	= 17
SFX_FX2_LSTART	= 18
SFX_FX3_LSTART	= 19
SFX_FX0_LEND	= 20
SFX_FX1_LEND	= 21
SFX_FX2_LEND	= 22
SFX_FX3_LEND	= 23
SFX_FX0_FREQ	= 24
SFX_FX1_FREQ	= 25
SFX_FX2_FREQ	= 26
SFX_FX3_FREQ	= 27
SFX_WAITCLK	= 28
SFX_STEPCLK	= 29
SFX_MUXSEL	= 31
SFX_SONGLEN	= 32
SFX_SONGPOS	= 33
SFX_PATROW	= 34
SFX_PATADDR	= 35
SFX_CURPAT	= 36
SFX_MASTERVOL	= 37

SONG_PLAY = 0x01
SONG_LOOP = 0x04

###################
# Sound Functions #
###################

EMPTYMODSIZE = 413

CreateEmptyMod:
	; $a0 = ptr to 413 word buffer
	mov	$t0, $a0
	moviu	$t1, 413
C_E_clearloop:
	sw	$zero, 0($t0)
	addiu	$t0, $t0, 1
	addi	$t1, $t1, -1
	_BNEZ	$t1, C_E_clearloop
	moviu	$t0, 16		;make instr.1 a short silent sample, vol 0, no loop
	_SW	$t0, 0($a0)
	moviu	$t0, 64
	_SW	$t0, 1($a0)
	_LI	$t0, 0x01040000
	_SW	$t0, 124($a0)	;set songinfo
	_LI	$t0, 0x0AF40F06	;instrument 1, note 756, SetSpeed 6
	_SW	$t0, 157($a0)
	_SW	$t0, 158($a0)
	_SW	$t0, 159($a0)
	_SW	$t0, 160($a0)
	_RTS

InitSound:
	PUSH	$ra
	_LI	$a0,SilentMod
	_JAL	CreateEmptyMod

	_LI	$sfx,SfxBase
	_LI	$t0,Lut-108
	_SW	$t0,SFX_LUT($sfx)
	_LI	$t0,504000			; MOD tick: 25.2 MHz / 50 Hz (480000 at 24 MHz)
	_SW	$t0,SFX_WAITCLK($sfx)
	movi	$t0,732
	_SW	$t0,SFX_STEPCLK($sfx)
	POP	$ra
	_RTS


#########
# Music #
#########

Lut:		.file	TLib/Data/Lut.raw	800

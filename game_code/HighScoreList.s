OnHighScoreList:
	; input:
	; a0 - The last games score
	;
	; output
	; v0 - 1 if the score should be in highscorelist
	_LI	$t0,HighScoreScores
	_LW	$t1,9($t0)
	slt	$v0,$t1,$a0
	_RTS

AddToHighScoreList:
	; a0 - name
	; a1 - score
	; a2 - level

	PUSH	$s0
	PUSH	$s1
	PUSH	$s2
	PUSH	$s3

	movi	$t9,10
	_LI	$t0,HighScoreNames
	_LI	$t1,HighScoreScores
	_LI	$t2,HighScoreLevels
AddToHighScoreList_FindPosition:
	_LW	$t3,0($t1)
	addi	$t3,$t3,1
	slt	$t8,$a1,$t3
	add	$t0,$t0,$t8
	add	$t0,$t0,$t8
	add	$t0,$t0,$t8
	add	$t1,$t1,$t8
	add	$t2,$t2,$t8
	addi	$t9,$t9,-1
	sra	$t7,$t9,31
	_BNEZ	$t7,AddToHighScoreList_Done
	_BNEZ	$t8,AddToHighScoreList_FindPosition
	_LW	$t4,0($t0)
	_LW	$t5,1($t0)
	_LW	$t6,0($t1)
	_LW	$t7,0($t2)

	_LW	$t3,0($a0)
	_SW	$t3,0($t0)
	_LW	$t3,1($a0)
	_SW	$t3,1($t0)
	_SW	$zero,2($t0)
	_SW	$a1,0($t1)
	_SW	$a2,0($t2)

AddToHighScoreList_MoveDown:
	_BEQZ	$t9,AddToHighScoreList_Done

	addi	$t0,$t0,3
	addi	$t1,$t1,1
	addi	$t2,$t2,1

	_LW	$s0,0($t0)
	_LW	$s1,1($t0)
	_LW	$s2,0($t1)
	_LW	$s3,0($t2)

	_SW	$t4,0($t0)
	_SW	$t5,1($t0)
	_SW	$zero,2($t0)
	_SW	$t6,0($t1)
	_SW	$t7,0($t2)

	mov	$t4,$s0
	mov	$t5,$s1
	mov	$t6,$s2
	mov	$t7,$s3

	addi	$t9,$t9,-1
	_J	AddToHighScoreList_MoveDown

AddToHighScoreList_Done:
	POP	$s3
	POP	$s2
	POP	$s1
	POP	$s0
	_RTS

GetHighScore:
	; input:  a0 - position
	; output: v0 - score
	_LI	$t0,HighScoreScores
	addi	$t1,$a0,-1
	add	$t0,$t0,$t1
	_LW	$v0,0($t0)
	_RTS

GetHighLevel:
	; input:  a0 - position
	; output: v0 - level
	_LI	$t0,HighScoreLevels
	addi	$t1,$a0,-1
	add	$t0,$t0,$t1
	_LW	$v0,0($t0)
	_RTS

GetHighName:
	; input:  a0 - position
	; output: v0 - name ptr
	_LI	$v0,HighScoreNames
	addi	$t0,$a0,-1
	add	$v0,$v0,$t0
	add	$v0,$v0,$t0
	add	$v0,$v0,$t0
	_RTS

HighScoreNames:
	.ascii	"FAN"
	.dc	0,0
	.ascii	"TA"
	.dc	0,0
	.ascii	"MCH"
	.dc	0,0
	.ascii	"MJH"
	.dc	0,0
	.ascii	"JPN"
	.dc	0,0
	.ascii	"MSV"
	.dc	0,0
	.ascii	"ABN"
	.dc	0,0
	.ascii	"MNI"
	.dc	0,0
	.ascii	"ES"
	.dc	0,0
	.ascii	"IC"
	.dc	0,0

HighScoreScores:
	.dc	5000,4500,4000,3500,3000,2500,2000,1500,1000,500

HighScoreLevels:
	.dc	9,8,7,6,5,4,3,2,1,0

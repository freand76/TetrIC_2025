    ; load register from address
    .macro    _LDA @reg0,@Imm0
    lui    $at, @Imm0.H
    ori    $at, $at, @Imm0.L
    lw    @reg0,0($at)
    nop
    .endmacro

    .macro li @reg0,@Imm0
    lui    @reg0, @Imm0.H
    ori    @reg0, @reg0, @Imm0.L
    .endmacro

start:
    nop
    nop
    nop
    lui $t1, 0x0123
    ori $t1, $t1, 0x4567
    jal print_hex_val
    nop
    nop
    nop
    lui $t1, 0xdead
    ori $t1, $t1, 0xbeef
    jal print_hex_val
    nop
    nop
    nop
    _LDA    $t1, data_word
    nop
    nop
    nop
    jal print_hex_val
    nop
    nop
    nop
    li  $t1, data_string
    nop
    nop
    nop
    jal print_string
    nop
    nop
    nop
endless:
    b endless
    nop
    nop
    nop

data_word:
    .dc 0xfa1337fa

data_string:
    .file HelloWorld.txt 32

print_string:
    lui $a0, 0xf000
    mov $at, $t1
    nop
    nop
    mov $k1, $ra
_loop_mem:
    lw $t2, 0($at)
    nop
    nop
    nop
    nop
    nop
    addi $at, $at, 1
    movi $v0, 0
    movi $v1, 4
_loop_word:
    mov $t1, $t2
    srl $t1, $t1, 24
    sll $t2, $t2, 8
    beq  $zero, $t1, _done
    nop
    nop
    nop
    sw $t1, 0($a0)
    jal wait_uart_ready
    nop
    nop
    nop
    nop
    nop
    nop
    addi $v0, $v0, 1
    bne $v0, $v1, _loop_word
    nop
    nop
    nop
    j _loop_mem
    nop
    nop
    nop
_done:
    b _done
    nop
    nop
    nop
    mov $ra, $k1
    jr $ra
    nop
    nop
    nop

print_hex_val:
    lui $a0, 0xf000
    movi $s1, 9
    movi $v0, 0
    movi $v1, 8
    mov  $k1, $ra
_print_hex_val_loop:
    mov $t2, $t1
    srl $t2, $t2, 28
    andi $t2, $t2, 0x0f
    bge $s1, $t2, _number
    nop
    nop
    nop
    addi $t2, $t2, 7
_number:
    addi $t2, $t2, 0x30
    sll $t1, $t1, 4
    nop
    nop
    sw $t2, 0($a0)
    jal wait_uart_ready
    nop
    nop
    nop
    addi $v0, $v0, 1
    bne $v0, $v1, _print_hex_val_loop
    nop
    nop
    nop
    movi $t1, 0x0a
    nop
    nop
    sw $t1, 0($a0)
    jal wait_uart_ready
    nop
    nop
    nop
    mov $ra, $k1
    jr $ra
    nop
    nop
    nop

wait_uart_ready:
    mfc0 $s0
    beqz $s0, wait_uart_ready
    nop
    nop
    nop
    jr $ra
    nop
    nop
    nop

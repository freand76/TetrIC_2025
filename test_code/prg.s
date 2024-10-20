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
    lui $t2, 0xf800
    lui $t1, 0xffe0
    ori $t1, $t1, 0x07e0
    nop
    lui $a0, 0x00e0
    sw $t2, 0($a0)
    sw $t2, 159($a0)
    sw $t1, 1($a0)
    sw $t1, 2($a0)
    sw $t1, 3($a0)
    sw $t1, 4($a0)
    sw $t1, 5($a0)
    sw $t1, 6($a0)
    sw $t1, 7($a0)
    sw $t1, 8($a0)
    sw $t1, 9($a0)
    sw $t1, 10($a0)
    nop
    nop
    lui $t1, 0x001f
    ori $t1, $t1, 0xf800
    nop
    lui $a0, 0x00e0
    ori $a0, $a0, 0x0100
    sw $t2, 0($a0)
    sw $t2, 159($a0)
    sw $t1, 1($a0)
    sw $t1, 2($a0)
    sw $t1, 3($a0)
    sw $t1, 4($a0)
    sw $t1, 5($a0)
    sw $t1, 6($a0)
    sw $t1, 7($a0)
    sw $t1, 8($a0)
    sw $t1, 9($a0)
    sw $t1, 10($a0)
    nop
    nop
    lui $t1, 0xdead
    ori $t1, $t1, 0xbeef
    jal print_hex_val
    nop
    nop
    nop
    lui $t1, 0x0123
    ori $t1, $t1, 0x4567
    jal print_hex_val
    nop
    nop
    nop
    lui $t1, 0x0000
    ori $t1, $t1, 0x0000
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
    lui $t1, 0x0000
    ori $t1, $t1, 0x0001
    jal print_hex_val
    nop
    nop
    nop
    li  $t1, empty_space
    sw $zero, 0($t1)
    nop
    nop
    nop
    nop
    nop
    jal print_string
    nop
    nop
    nop
    lui $t1, 0x0000
    ori $t1, $t1, 0x0002
    jal print_hex_val
    nop
    nop
    nop

    li  $t1, data_string
    li  $t2, empty_space
    li  $t3, 2
    jal memcopy
    nop
    nop
    nop

    _LDA $t1, data_word
    jal print_hex_val
    nop
    nop
    nop
    li  $t1, empty_space
    nop
    nop
    nop
    jal print_string
    nop
    nop
    nop
    li $t1, 0x0a
    nop
    nop
    nop
    jal print_char
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

print_char:
    nop
    nop
    nop
    mov $k0, $ra
    lui $a0, 0x00f0
    sw $t1, 0($a0)
    jal wait_uart_ready
    nop
    nop
    nop
    mov $ra, $k0
    jr $ra
    nop
    nop
    nop

print_string:
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
    beq  $zero, $t2, _done
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
    nop
    beq  $zero, $t1, _done
    nop
    nop
    nop
    jal print_char
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
    mov $ra, $k1
    jr $ra
    nop
    nop
    nop

print_hex_val:
    lui $a0, 0x00f0
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

empty_space: .pad 128, 0

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

memcopy:
    movi $v0, 0
_memcopy_loop:
    lw $v1, 0($t1)
    nop
    nop
    nop
    nop
    nop
    nop
    nop
    sw $v1, 0($t2)
    addi $t1, $t1, 1
    addi $t2, $t2, 1
    addi $v0, $v0, 1
    bge $t3, $v0, _memcopy_loop
    nop
    nop
    nop
    jr $ra
    nop
    nop
    nop

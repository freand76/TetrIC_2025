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
    lw $t1, 0($zero)
    nop
    nop
    nop
    nop
    nop
    jal print_hex_val
    nop
    nop
    nop
endless:
    b endless
    nop
    nop
    nop

print_hex_val:
    lui $a0, 0xf000
    movi $s1, 9
    movi $v0, 0
    movi $v1, 8
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
_print_hex_val_wait_uart_ready:
    nop
    mfc0 $s0
    beqz $s0, _print_hex_val_wait_uart_ready
    nop
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
_print_hex_val_wait_uart_ready2:
    nop
    mfc0 $s0
    beqz $s0, _print_hex_val_wait_uart_ready2
    nop
    nop
    nop
    jr $ra
    nop
    nop
    nop

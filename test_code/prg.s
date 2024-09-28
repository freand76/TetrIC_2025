start:
    nop
    nop
    nop
    movi $r1, 0x30
    movi $t2, 0x0
    movi $t3, 7
    lui  $t4, 0xf000
    nop
    nop
    nop
    nop
new:
    sw $r1, 0($t4)
    nop
    nop
    nop
    jal wait_uart_ready
    nop
    nop
    nop
    addi $r1, $r1, 1
    addi $t2, $t2, 1
    nop
    nop
    nop
    bgt $t3, $t2, new
    nop
    nop
    nop
    movi $r1, 0x46
    nop
    nop
    nop
    nop
    sw $r1, 0($t4)
    nop
    nop
    nop
    jal wait_uart_ready
    nop
    nop
    nop
    movi $r1, 0x0a
    nop
    nop
    nop
    nop
    nop
    sw $r1, 0($t4)
    nop
    nop
endless_loop:
    j endless_loop
    nop
    nop
    nop
    nop
    nop
    nop

wait_uart_ready:
    mfc0 $s0
    nop
    nop
    nop
    nop
    nop
    nop
    beqz $s0, wait_uart_ready
    nop
    nop
    nop
    jr $ra
    nop
    nop
    nop
    nop
    nop
    nop

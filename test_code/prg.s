start:
    nop
    nop
    nop
    movi $t1, 0x30
    movi $t2, 0x0
    movi $t3, 5
    nop
new:
    sw $t1, 0($t2)
    nop
    nop
    nop
wait_uart_ready:
    mfc0 $s0
    beqz $s0, wait_uart_ready
    nop
    nop
    nop
    addi $t1, $t1, 1
    addi $t2, $t2, 1
    nop
    nop
    nop
    bgt $t3, $t2, new
    nop
    nop
    nop
    j 0xffffff
    nop
    nop
    nop

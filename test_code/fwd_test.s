; Register forwarding test (rtl/processor/fwunit): a value written at
; distance 2 must be forwarded from WB also when the instruction in between
; (here sw) does not write a register but names the same one (its rt and
; rd fields are both $8). Before the fwunit fix the add read the stale $8.
; Prints 00000005, 00000005, 0000000A (stale: 00000064, 00000064, 000000C8).
; Assembled with --hazards=off: the sw reads its data at distance 1, which
; is not forwarded (only the add is checked).

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
    li  $9, 0x1000
    li  $8, 100            ; stale value
    nop
    nop
    nop
    nop
    nop
    ; r1 (rs): $10 = $8 + $0
    addi $8, $0, 5
    sw   $8, 0x4000($9)    ; EX: no register write, rt = 8 and rd field = 8
    add  $10, $8, $0       ; $8 at distance 2: WB forwarding
    nop
    nop
    nop
    li  $8, 100
    nop
    nop
    nop
    nop
    nop
    ; r2 (rt): $11 = $0 + $8
    addi $8, $0, 5
    sw   $8, 0x4000($9)
    add  $11, $0, $8
    nop
    nop
    nop
    li  $8, 100
    nop
    nop
    nop
    nop
    nop
    ; both: $12 = $8 + $8
    addi $8, $0, 5
    sw   $8, 0x4000($9)
    add  $12, $8, $8
    nop
    nop
    nop
    mov  $t1, $10
    jal  print_hex_val
    nop
    nop
    nop
    mov  $t1, $11
    jal  print_hex_val
    nop
    nop
    nop
    mov  $t1, $12
    jal  print_hex_val
    nop
    nop
    nop
done:
    j    done
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


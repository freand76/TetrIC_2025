; Gamepad test: every time MFC2 changes, its value is printed on the uart
; (hex) and a gamepad is drawn on the screen: 16 squares at the button
; positions, lit in the button colour while pressed, dark grey otherwise.
;
; MFC2 = {8'h00, B2, B1, joy}, all active low (1 = released)
;   joy: 0 UP, 1 A (square), 2 DOWN, 3 RIGHT, 4 B (cross), 5 LEFT,
;        6 START, 7 C (circle)
;   B1:  0 SELECT, 1 L3, 2 R3, 3 START, 4 UP, 5 RIGHT, 6 DOWN, 7 LEFT
;   B2:  0 L2, 1 R2, 2 L1, 3 R1, 4 TRIANGLE, 5 CIRCLE, 6 CROSS, 7 SQUARE
; With no buttons pressed it prints 00FFFFFF.

    .macro li @reg0,@Imm0
    lui    @reg0, @Imm0.H
    ori    @reg0, @reg0, @Imm0.L
    .endmacro

    .macro vset @off,@val
    li     $t1, @val
    nop
    nop
    nop
    sw     $t1, @off($fp)
    .endmacro

FB       = 0x10000              ; 320x240 frame buffer, 160 words per line
GREY     = 0x21042104
WHITE    = 0xffffffff
RED      = 0xf800f800
GREEN    = 0x07e007e0
BLUE     = 0x001f001f
MAGENTA  = 0xf81ff81f
YELLOW   = 0xffe0ffe0

start:
    nop
    li   $fp, 0x00e00000        ; video registers
    li   $gp, 0x00f00000        ; uart
; clear the frame buffer
    li   $t0, FB
    li   $t9, 38400/8
    nop
_clr:
    sw   $0, 0($t0)
    sw   $0, 1($t0)
    sw   $0, 2($t0)
    sw   $0, 3($t0)
    sw   $0, 4($t0)
    sw   $0, 5($t0)
    sw   $0, 6($t0)
    sw   $0, 7($t0)
    addi $t0, $t0, 8
    addi $t9, $t9, -1
    bnez $t9, _clr
    nop
    nop
    nop
    vset 0, 0                   ; TOPPOS
    vset 1, 0                   ; LEFTPOS
    vset 2, 320                 ; PIXPERLINE
    vset 3, 240                 ; LINEPERIMG
    vset 4, 2                   ; PIXREAD
    vset 6, 0                   ; DELTAADDR
    vset 5, FB                  ; GFXADDR
    li   $s0, 0xffffffff        ; last value (forces a first print)
    nop
    nop
loop:
    mfc2 $s1
    beq  $s1, $s0, loop
    nop
    nop
    nop
    mov  $s0, $s1
    nop
    nop
    jal  print_hex              ; prints $s0
    nop
    jal  draw_pad               ; draws $s0
    nop
    j    loop
    nop

;-----------------------------------------------------------------------------
; draw all buttons for the MFC2 value in $s0
draw_pad:
    mov  $s7, $ra
    li   $s2, buttons
    movi $s3, 16
    nop
    nop
_dp_loop:
    lw   $a0, 0($s2)            ; word offset in the frame buffer
    lw   $t4, 1($s2)            ; MFC2 bit of the button
    lw   $a1, 2($s2)            ; colour when pressed
    nop
    and  $t4, $t4, $s0          ; active low: 0 = pressed
    nop
    beqz $t4, _dp_draw
    nop
    nop
    nop
    li   $a1, GREY              ; released
_dp_draw:
    nop
    nop
    jal  rect
    nop
    addi $s2, $s2, 3
    addi $s3, $s3, -1
    bnez $s3, _dp_loop
    nop
    nop
    nop
    mov  $ra, $s7
    nop
    jr   $ra
    nop
    nop
    nop

; 16x16 pixel square: $a0 = word offset of the top left corner, $a1 = colour
rect:
    li   $t0, FB
    add  $t0, $t0, $a0
    movi $t9, 16
    nop
    nop
_rect_row:
    sw   $a1, 0($t0)
    sw   $a1, 1($t0)
    sw   $a1, 2($t0)
    sw   $a1, 3($t0)
    sw   $a1, 4($t0)
    sw   $a1, 5($t0)
    sw   $a1, 6($t0)
    sw   $a1, 7($t0)
    addi $t0, $t0, 160
    addi $t9, $t9, -1
    bnez $t9, _rect_row
    nop
    nop
    nop
    jr   $ra
    nop
    nop
    nop

;-----------------------------------------------------------------------------
; print $s0 as 8 hex digits and a newline
print_hex:
    mov  $k1, $ra
    mov  $t3, $s0
    movi $v0, 8
    movi $v1, 9
    nop
_hex_loop:
    srl  $t1, $t3, 28
    sll  $t3, $t3, 4
    nop
    nop
    bge  $v1, $t1, _digit       ; 0..9
    nop
    nop
    nop
    addi $t1, $t1, 7            ; 'A'..'F'
_digit:
    addi $t1, $t1, 48
    jal  putc
    nop
    addi $v0, $v0, -1
    bnez $v0, _hex_loop
    nop
    nop
    nop
    movi $t1, 10
    jal  putc
    nop
    mov  $ra, $k1
    nop
    jr   $ra
    nop
    nop
    nop

;-----------------------------------------------------------------------------
; write $t1 to the uart (waits until the uart is ready first)
putc:
    mfc0 $k0
    beqz $k0, putc
    nop
    nop
    nop
    sw   $t1, 0($gp)
    jr   $ra
    nop
    nop
    nop

;-----------------------------------------------------------------------------
; buttons: word offset (y * 160 + x / 2), MFC2 bit, colour when pressed
buttons:
    .dc  80*160+60/2,   0x00001000, WHITE       ; UP       (B1 bit 4)
    .dc  120*160+60/2,  0x00004000, WHITE       ; DOWN     (B1 bit 6)
    .dc  100*160+40/2,  0x00008000, WHITE       ; LEFT     (B1 bit 7)
    .dc  100*160+80/2,  0x00002000, WHITE       ; RIGHT    (B1 bit 5)
    .dc  80*160+244/2,  0x00100000, GREEN       ; TRIANGLE (B2 bit 4)
    .dc  100*160+264/2, 0x00200000, RED         ; CIRCLE   (B2 bit 5) = C
    .dc  120*160+244/2, 0x00400000, BLUE        ; CROSS    (B2 bit 6) = B
    .dc  100*160+224/2, 0x00800000, MAGENTA     ; SQUARE   (B2 bit 7) = A
    .dc  110*160+130/2, 0x00000100, YELLOW      ; SELECT   (B1 bit 0)
    .dc  110*160+174/2, 0x00000800, YELLOW      ; START    (B1 bit 3)
    .dc  40*160+50/2,   0x00040000, YELLOW      ; L1       (B2 bit 2)
    .dc  20*160+50/2,   0x00010000, YELLOW      ; L2       (B2 bit 0)
    .dc  40*160+254/2,  0x00080000, YELLOW      ; R1       (B2 bit 3)
    .dc  20*160+254/2,  0x00020000, YELLOW      ; R2       (B2 bit 1)
    .dc  170*160+110/2, 0x00000200, WHITE       ; L3       (B1 bit 1)
    .dc  170*160+194/2, 0x00000400, WHITE       ; R3       (B1 bit 2)

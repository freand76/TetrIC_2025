; Video test for the gfxbox style video registers (rtl/video/video.v)
;
; Draws 8 colour bars (white top and bottom line) into a 320x240 frame buffer
; at FB and then switches every 2 seconds (120 frames, timed with MFC1) between
;   A: full screen
;   B: a 200x160 window at (60,40) that shows the same part of the picture
;      in place (GFXADDR/DELTAADDR crop), with a black border
; Each switch prints the mode and the MFC1 status word on the UART.
;
; Registers: $fp = video registers, $gp = uart

    .macro li @reg0,@Imm0
    lui    @reg0, @Imm0.H
    ori    @reg0, @reg0, @Imm0.L
    .endmacro

    ; write a video register (the stored register must be written >= 4 before)
    .macro vset @off,@val
    li     $t1, @val
    nop
    nop
    nop
    sw     $t1, @off($fp)
    .endmacro

FB      = 0x1000                ; frame buffer, 160 words per line
FB_LAST = FB+239*160        ; last line
WIN     = FB+40*160+30    ; window: line 40, pixel 60

start:
    nop
    li   $fp, 0x00e00000        ; video registers
    li   $gp, 0x00f00000        ; uart

; ---- colour bars: 240 lines x 8 bars x 20 words
    li   $t0, FB
    li   $s1, 240
line_loop:
    li   $t5, colors
    li   $s2, 8
    nop
bar_loop:
    lw   $t1, 0($t5)
    addi $t5, $t5, 1
    li   $s3, 20
    nop
word_loop:
    sw   $t1, 0($t0)
    addi $t0, $t0, 1
    addi $s3, $s3, -1
    bnez $s3, word_loop
    nop
    nop
    nop
    addi $s2, $s2, -1
    bnez $s2, bar_loop
    nop
    nop
    nop
    addi $s1, $s1, -1
    bnez $s1, line_loop
    nop
    nop
    nop

; ---- white first and last line
    li   $t0, FB
    li   $t2, FB_LAST
    li   $t1, 0xffffffff
    li   $s3, 160
    nop
white_loop:
    sw   $t1, 0($t0)
    sw   $t1, 0($t2)
    addi $t0, $t0, 1
    addi $t2, $t2, 1
    addi $s3, $s3, -1
    bnez $s3, white_loop
    nop
    nop
    nop

; ---- switch between full screen and window
main_loop:
    vset 0, 0                   ; TOPPOS
    vset 1, 0                   ; LEFTPOS
    vset 2, 320                 ; PIXPERLINE
    vset 3, 240                 ; LINEPERIMG
    vset 6, 0                   ; DELTAADDR
    vset 5, FB                  ; GFXADDR
    movi $t1, 65                ; 'A'
    jal  report
    nop
    jal  wait_2s
    nop

    vset 0, 40                  ; TOPPOS
    vset 1, 60                  ; LEFTPOS
    vset 2, 200                 ; PIXPERLINE (100 words)
    vset 3, 160                 ; LINEPERIMG
    vset 6, 60                  ; DELTAADDR: stride 100 + 60 = 160 words
    vset 5, WIN                 ; GFXADDR
    movi $t1, 66                ; 'B'
    jal  report
    nop
    jal  wait_2s
    nop
    j    main_loop
    nop

; ---- wait 120 frames using the MFC1 frame counter
wait_2s:
    mfc1 $t6, $0
    srl  $t6, $t6, 20
    movi $s4, 119
    nop
_wait_loop:
    mfc1 $t7, $0
    srl  $t7, $t7, 20
    sub  $t8, $t7, $t6
    andi $t8, $t8, 0x0fff
    bge  $s4, $t8, _wait_loop   ; loop while frames passed <= 119
    nop
    nop
    nop
    jr   $ra
    nop
    nop
    nop

; ---- print char in $t1, ' ', MFC1 status in hex and newline
report:
    mov  $k1, $ra
    jal  putc
    nop
    movi $t1, 32
    nop
    nop
    nop
    jal  putc
    nop
    mfc1 $t3, $0
    movi $v0, 8
    nop
    nop
_hex_loop:
    srl  $t1, $t3, 28
    sll  $t3, $t3, 4
    movi $v1, 9
    nop
    bge  $v1, $t1, _digit       ; 0..9
    nop
    nop
    nop
    addi $t1, $t1, 7            ; 'A'..'F'
_digit:
    addi $t1, $t1, 48
    nop
    nop
    nop
    jal  putc
    nop
    addi $v0, $v0, -1
    bnez $v0, _hex_loop
    nop
    nop
    nop
    movi $t1, 10
    nop
    nop
    nop
    jal  putc
    nop
    mov  $ra, $k1
    nop
    jr   $ra
    nop
    nop
    nop

; ---- write $t1 to the uart (waits until the uart is ready first)
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

; two equal RGB565 pixels per word
colors:
    .dc 0xffffffff, 0xffe0ffe0, 0x07ff07ff, 0x07e007e0
    .dc 0xf81ff81f, 0xf800f800, 0x001f001f, 0x00000000

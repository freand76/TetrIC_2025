; Bars: standalone version of the TetrIC intro "Bars" (TetrIC/Bars.s)
;
; Seven shaded colour bars rotate around a grey middle bar. The bars move on
; a circle: y = cos(angle), depth z = sin(angle). Each frame they are sorted
; by depth and drawn back to front, so they pass in front of and behind the
; middle bar.
;
; Differences to the original:
;   * DVI instead of PAL: 128x240 pixels instead of 128x256. As in the
;     original, PIXREAD stretches the 128 pixels over the full width
;     (5 DVI pixels per pixel; the original used 10 PAL clocks)
;   * runs at exactly 30 Hz: the screens are swapped every second frame,
;     timed with the MFC1 frame counter ('L' on the uart if a frame was late)
;   * double buffered (the original drew into the shown screen)
;   * no joystick exit, no library calls: everything is in this file
;   * Sin uses its own argument for the odd/even table half (the original
;     used $t9, set only by Cos)
;
; Registers: $fp video registers, $gp uart, $s5 shown screen, $s6 work
; screen, $s1 bar angle, $s0 loop count, $a3 frame number of the next swap

    .macro li @reg0,@Imm0
    lui    @reg0, @Imm0.H
    ori    @reg0, @reg0, @Imm0.L
    .endmacro

    ; write a video register (uses $t1)
    .macro vset @off,@val
    li     $t1, @val
    nop
    nop
    nop
    sw     $t1, @off($fp)
    .endmacro

    ; print a character (uses $t1)
    .macro print @char
    movi   $t1, @char
    jal    putc
    nop
    .endmacro

GFX_TOPPOS  = 0
GFX_LEFTPOS = 1
GFX_WIDTH   = 2
GFX_HEIGHT  = 3
GFX_PIXREAD = 4
GFX_SCRADDR = 5
GFX_DELTA   = 6

ROWW      = 64                  ; words per row (128 pixels)
ROWS      = 240
SCREEN0   = 0x10000
SCREEN1   = 0x14000
NOF_BARS  = 7
BAR_ANGLE_DELTA   = -0x100
ANGLE_BETWEEN_BAR = 0x10000/NOF_BARS
CENTER_Y  = 120                 ; original: 128 (of 256 lines)
MIDDLE_Y  = 104                 ; original: 112
FRAMES    = 2                   ; frames per update: 60 Hz / 2 = 30 Hz

start:
    nop
    li   $fp, 0x00e00000        ; video registers
    li   $gp, 0x00f00000        ; uart
    li   $s5, SCREEN0
    li   $s6, SCREEN1
    clr  $s1
    clr  $s0

    mov  $a2, $s5
    nop
    jal  ClearScreen
    nop
    mov  $a2, $s6
    nop
    jal  ClearScreen
    nop

    vset GFX_TOPPOS, 0
    vset GFX_LEFTPOS, 0
    vset GFX_WIDTH, ROWW*2      ; 128 pixels
    vset GFX_PIXREAD, 5         ; 128 x 5 = 640 DVI pixels: full width
    vset GFX_HEIGHT, ROWS
    vset GFX_DELTA, 0
    sw   $s5, GFX_SCRADDR($fp)

    print 66                    ; "BARS\n"
    print 65
    print 82
    print 83
    print 10

    ; first swap FRAMES frames from now
    mfc1 $t1, $0
    srl  $t1, $t1, 20           ; MFC1[31:20] = frame counter
    nop
    addi $a3, $t1, FRAMES

main_loop:
    mov  $a2, $s6
    nop
    jal  ClearScreen
    nop
    jal  DrawBars
    nop
    jal  WaitFrame              ; until frame $a3 has started (vertical blank)
    nop
    ; swap: the new screen is shown from the next frame
    mov  $t0, $s5
    mov  $s5, $s6
    mov  $s6, $t0
    addi $a3, $v0, FRAMES       ; next swap
    nop
    nop
    sw   $s5, GFX_SCRADDR($fp)
    beqz $v1, _on_time
    nop
    nop
    nop
    print 76                    ; 'L': this update was late
_on_time:
    ; a dot on the uart every 32 updates (64 frames)
    addi $s0, $s0, 1
    andi $t1, $s0, 31
    bnez $t1, main_loop
    nop
    nop
    nop
    print 46
    j    main_loop
    nop

;-----------------------------------------------------------------------------
; Wait until the frame counter has reached $a3.
; The counter steps when the last visible line has been shown, so this
; returns at the start of the vertical blank.
; Returns $v0 = frame counter, $v1 = frames too late (0 = on time)
WaitFrame:
    li   $t3, 0x0fff            ; the frame counter has 12 bits
    li   $t5, 0x0800
    nop
_wait_frame:
    mfc1 $t1, $0
    srl  $t1, $t1, 20
    sub  $t2, $t1, $a3
    and  $t2, $t2, $t3          ; (counter - target) mod 4096
    bge  $t2, $t5, _wait_frame  ; "negative": not there yet
    nop
    nop
    nop
    mov  $v0, $t1
    mov  $v1, $t2
    jr   $ra
    nop
    nop
    nop

;-----------------------------------------------------------------------------
; Clear screen at $a2
ClearScreen:
    mov  $t0, $a2
    li   $t9, ROWS*ROWW/8
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
    jr   $ra
    nop
    nop
    nop

;-----------------------------------------------------------------------------
; Draw all bars into the screen at $a2
DrawBars:
    mov  $k1, $ra
    addi $s1, $s1, BAR_ANGLE_DELTA

    ; depth of every bar
    li   $s2, BarZ
    movi $s7, NOF_BARS
    mov  $s3, $s1
_getz:
    mov  $a0, $s3
    nop
    nop
    jal  Sin
    nop
    sw   $v0, 0($s2)
    addi $s3, $s3, ANGLE_BETWEEN_BAR
    addi $s2, $s2, 1
    addi $s7, $s7, -1
    bnez $s7, _getz
    nop
    nop
    nop

    ; draw back to front
    movi $s7, NOF_BARS
_draw_loop:
    clr  $t0                    ; bar number
    mov  $t1, $s1               ; its angle
    lui  $t2, 0x7fff            ; smallest depth so far
    li   $t3, BarZ
    clr  $s4
    clr  $v1
    nop
_find:
    lw   $t9, 0($t3)
    nop
    slt  $t8, $t9, $t2
    beqz $t8, _not_smaller
    nop
    nop
    nop
    mov  $t2, $t9               ; min depth
    mov  $s4, $t0               ; min bar
    mov  $v1, $t1               ; min angle
_not_smaller:
    addi $t1, $t1, ANGLE_BETWEEN_BAR
    addi $t3, $t3, 1
    addi $t0, $t0, 1
    movi $t9, NOF_BARS
    bne  $t0, $t9, _find
    nop
    nop
    nop

    ; the middle bar is drawn when half of the bars are drawn
    movi $t0, NOF_BARS/2
    nop
    bne  $t0, $s7, _not_middle
    nop
    nop
    nop
    jal  DrawMiddleBar
    nop
_not_middle:
    mov  $a0, $v1
    nop
    nop
    jal  Cos
    nop
    sra  $t0, $v0, 10           ; -64..64
    nop
    addi $a1, $t0, CENTER_Y
    li   $at, BarList
    add  $at, $at, $s4
    lw   $a0, 0($at)            ; colour
    li   $at, BarZ
    add  $at, $at, $s4
    lui  $t9, 0x7fff
    nop
    nop
    nop
    sw   $t9, 0($at)            ; mark the bar as drawn
    jal  DrawBar
    nop
    addi $s7, $s7, -1
    bnez $s7, _draw_loop
    nop
    nop
    nop

    mov  $ra, $k1
    nop
    jr   $ra
    nop
    nop
    nop

;-----------------------------------------------------------------------------
; Draw a bar: colour $a0, center line $a1, screen $a2.
; 16 lines, getting brighter for 8 lines and then darker again.
DrawBar:
    addi $t0, $a1, -8
    nop
    sll  $t0, $t0, 6            ; * ROWW
    add  $t0, $t0, $a2
    li   $t2, 0x21042104        ; start: a low bit of every colour channel
    and  $t2, $t2, $a0
    li   $t3, 0x08410841        ; step: lowest bit of every colour channel
    and  $t3, $t3, $a0
    movi $t9, 16
_bar_row:
    movi $t8, ROWW/8
_bar_words:
    sw   $t2, 0($t0)
    sw   $t2, 1($t0)
    sw   $t2, 2($t0)
    sw   $t2, 3($t0)
    sw   $t2, 4($t0)
    sw   $t2, 5($t0)
    sw   $t2, 6($t0)
    sw   $t2, 7($t0)
    addi $t0, $t0, 8
    addi $t8, $t8, -1
    bnez $t8, _bar_words
    nop
    nop
    nop
    add  $t2, $t2, $t3
    addi $t9, $t9, -1
    andi $t7, $t9, 7
    bnez $t7, _bar_row
    nop
    nop
    nop
    neg  $t3, $t3
    bnez $t9, _bar_row
    nop
    nop
    nop
    jr   $ra
    nop
    nop
    nop

;-----------------------------------------------------------------------------
; Grey middle bar, 32 lines from MIDDLE_Y, screen $a2
DrawMiddleBar:
    li   $t0, MIDDLE_Y*ROWW
    add  $t0, $t0, $a2
    clr  $t2
    li   $t3, 0x08410841
    movi $t9, 32
_mid_row:
    movi $t8, ROWW/8
_mid_words:
    sw   $t2, 0($t0)
    sw   $t2, 1($t0)
    sw   $t2, 2($t0)
    sw   $t2, 3($t0)
    sw   $t2, 4($t0)
    sw   $t2, 5($t0)
    sw   $t2, 6($t0)
    sw   $t2, 7($t0)
    addi $t0, $t0, 8
    addi $t8, $t8, -1
    bnez $t8, _mid_words
    nop
    nop
    nop
    add  $t2, $t2, $t3
    addi $t9, $t9, -1
    andi $t7, $t9, 15
    bnez $t7, _mid_row
    nop
    nop
    nop
    neg  $t3, $t3
    bnez $t9, _mid_row
    nop
    nop
    nop
    jr   $ra
    nop
    nop
    nop

;-----------------------------------------------------------------------------
; Sin / Cos: $a0 angle (0x10000 = 360 degrees) -> $v0 = -65535..65535
; The table has two 16 bit samples per word.
Cos:
    addiu $t4, $a0, 0x4000      ; cos(a) = sin(a + 90 degrees)
    nop
    j    _sincos
    nop
Sin:
    mov  $t4, $a0
    nop
_sincos:
    sll  $t0, $t4, 16
    srl  $t0, $t0, 20           ; word index: angle bits 15..4
    sll  $t1, $t4, 28
    srl  $t1, $t1, 31           ; angle bit 3: which half of the word
    sll  $t1, $t1, 4            ; shift 0 or 16
    li   $t2, Sinus
    add  $t2, $t2, $t0
    lw   $t0, 0($t2)
    nop
    sllv $t0, $t0, $t1
    sra  $v0, $t0, 15
    jr   $ra
    nop
    nop
    nop

;-----------------------------------------------------------------------------
; Write $t1 to the uart (waits until the uart is ready first)
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
BarList:
    .dc 0xf800f800, 0xffe0ffe0, 0x07e007e0
    .dc 0x07ff07ff, 0x001f001f, 0xf81ff81f
    .dc 0x7fff7fff

BarZ:
    .pad NOF_BARS, 0

Sinus:
    .file "Sinus.raw" 4096

; Sound test for the sound unit (rtl/sound/sound.v), effect channels 4..7
;
; Writes the sound registers the same way as game_code/FXMusic.s and runs
; through a few cases, about 3 ms apart (video DMA runs all the time):
;   0: ch4+ch5 one shot game sample (snd_menu_changevalue), 44100 / 65000 Hz
;      ch6 looped 64 sample sine at 32000 Hz (500 Hz tone)
;      ch7 same sine at 60000 Hz (> 48 kHz, 1-2 samples per output sample)
;   1: ch6 volume 64 -> 16, mute ch5 (CHANSTATUS)
;   2: unmute, restart ch4 while it plays (11025 Hz)
;   3: stop the looping ch6 with END = 0, MASTERVOL ch5 7 -> 6
;   4: print DONE
; The testbench (sim/system/tb_system.v +audio=...) logs every register write and
; every 48 kHz output sample, tools/sound_ref.py checks them bit exact.
;
; Registers: $s0 = sound registers, $gp = uart

    .macro li @reg0,@Imm0
    lui    @reg0, @Imm0.H
    ori    @reg0, @reg0, @Imm0.L
    .endmacro

    ; write a sound register
    .macro sset @off,@val
    li     $t1, @val
    nop
    nop
    sw     $t1, @off($s0)
    .endmacro

start:
    nop
    li   $s0, 0x00400000        ; sound registers
    li   $gp, 0x00f00000        ; uart

    sset 37, 0x77775555         ; MASTERVOL as the game: FX 7, MOD 5

; ---- 0: start everything (order as PlaySampleCh1)
    sset 12, 0                  ; FX0_END
    sset 13, 0                  ; FX1_END
    sset 16, 0                  ; FX0_LSTART
    sset 17, 0
    sset 20, 0                  ; FX0_LEND (no loop)
    sset 21, 0
    sset 24, 44100              ; FX0_FREQ
    sset 25, 65000
    sset 4, smp                 ; FX0_START
    sset 5, smp
    sset 12, smp_end            ; FX0_END
    sset 13, smp_end
    sset 8, 64                  ; FX0_VOL
    sset 9, 48

    sset 14, 0                  ; FX2_END
    sset 15, 0
    sset 18, sine               ; FX2_LSTART
    sset 19, sine
    sset 22, sine_end           ; FX2_LEND
    sset 23, sine_end
    sset 26, 32000              ; FX2_FREQ
    sset 27, 60000
    sset 6, sine                ; FX2_START
    sset 7, sine
    sset 14, sine_end           ; FX2_END
    sset 15, sine_end
    sset 10, 64                 ; FX2_VOL
    sset 11, 40
    movi $t1, 48                ; '0'
    jal  putc
    nop
    jal  wait_3ms
    nop

; ---- 1: volume change, mute ch5
    sset 10, 16
    sset 2, 0xfb                ; CHANSTATUS: ch5 (bit 2) muted
    movi $t1, 49
    jal  putc
    nop
    jal  wait_3ms
    nop

; ---- 2: unmute, restart ch4 at a lower rate
    sset 2, 0xff
    sset 24, 11025
    sset 4, smp
    movi $t1, 50
    jal  putc
    nop
    jal  wait_3ms
    nop

; ---- 3: stop the looping ch6, master volume
    sset 14, 0
    sset 37, 0x77675555         ; ch5 master volume 6
    movi $t1, 51
    jal  putc
    nop
    jal  wait_3ms
    nop

; ---- 4: done
    movi $t1, 68                ; 'D'
    jal  putc
    nop
    movi $t1, 10
    jal  putc
    nop
end:
    j    end
    nop

; ---- wait 3 ms (5 clocks per loop at 25.2 MHz)
wait_3ms:
    li   $t2, 15120
    nop
_wait_loop:
    addi $t2, $t2, -1
    bnez $t2, _wait_loop
    nop
    nop
    nop
    jr   $ra
    nop
    nop
    nop

; ---- print char in $t1
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

; 64 sample sine, amplitude 100
sine:
    .dc 0x000a141d, 0x262f383f, 0x474d5358, 0x5c606264
    .dc 0x64646260, 0x5c58534d, 0x473f382f, 0x261d140a
    .dc 0x00f6ece3, 0xdad1c8c1, 0xb9b3ada8, 0xa4a09e9c
    .dc 0x9c9c9ea0, 0xa4a8adb3, 0xb9c1c8d1, 0xdae3ecf6
sine_end:

smp:
    .file ../game_code/Data/snd_menu_changevalue.raw 166
smp_end:

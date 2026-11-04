// MOD sequencer for sound channels 0..3 (mainunit.vhd of the original VHDL, the "MOD"
// part of the TetrIC sound unit). Runs in clk_cpu next to the channel
// engine in sound.v: it reads the song through the engine's memory port
// and changes channels 0..3 with the same writes the CPU uses for the
// effect channels (START, VOL, END, LSTART, LEND, FREQ).
//
// Registers (from the CPU, through the sound.v write queue):
//    0 OFFSET      word address of the song
//    1 LUT         word address of the note frequency table - 108
//    3 SONGSTATUS  bit 0 play, bit 1 pause, bit 2 loop. Writing play = 0
//                  stops the song; play = 1 (re)starts it from the start
//                  when it is stopped.
//   28 WAITCLK     MOD tick length in clk_cpu clocks (25.2 MHz / 50 =
//                  504000). Counted in output samples: +525 per sample,
//                  a tick when WAITCLK has been passed.
//   29 STEPCLK, 31 MUXSEL, 32..36 song position registers: ignored.
//
// Song format (word addresses relative to OFFSET, byte addresses >> 2):
//   0..123    31 instruments, 4 words: [25:2] start (byte), [30:24] volume
//             and [23:2] end (byte, exclusive), [25:2] loop start, [25:2]
//             loop end (byte, exclusive, 0 = no loop)
//   124       [30:24] song length, [6:0] first pattern
//   125..156  pattern order, 4 per word, entry n in bits [8n+6:8n]
//   157..     patterns: 64 rows x 4 channels, one word per note:
//             [31:27] instrument, [26:16] note (Amiga period 108..907),
//             [15:8] effect, [7:0] parameter
// The frequency of note p is word LUT + p, bits [15:0] (Hz).
//
// Effects (as the old hardware): 1/2 portamento up/down, 3 tone
// portamento, 5 tone portamento + volume slide, 6/A volume slide (6 =
// vibrato + volume slide, the vibrato is not done), B position jump, C set
// volume, D pattern break (row number not BCD), E1/E2 fine portamento,
// EA/EB fine volume slide, F set speed (1..31). Changes from the old:
//   - one tone portamento direction per channel (was shared)
//   - tone portamento stops at the target note in the step that reaches it
//   - E1/E2 change the playing note (the old changed only the row's note)
//   - F00 is ignored (speed 0)
//   - pause stops the ticks, the channels keep playing
//   - sample end and loop end are exclusive (as for channels 4..7)

module sound_seq(
    input             clk,
    input             rst_n,

    // register writes (when the sound.v queue applies them)
    input             cpu_w,
    input [5:0]       cpu_reg,
    input [31:0]      cpu_data,

    input             mix_tick,      // one per output sample

    // memory reads
    output reg        rd_req,        // until rd_ack
    output reg [19:0] rd_addr,
    input             rd_ack,        // pulse: read issued
    input             rd_valid,      // pulse, rd_data valid
    input [31:0]      rd_data,

    // channel writes (FX register numbers, channel 0..3)
    output reg        w_req,
    output reg [5:0]  w_reg,
    output reg [1:0]  w_ch,
    output reg [19:0] w_data,
    input             w_ack,         // pulse: write applied

    // test bench events
    output reg        ev_start,
    output reg        ev_tick,
    output reg        ev_stop
);

    // ---- registers ----
    reg [19:0] offset, lut;
    reg [2:0]  status;
    reg        stop_req;
    reg [19:0] waitclk;

    // ---- song state ----
    reg        playing;
    reg [20:0] tick_acc;
    reg        tick_pend;
    reg [4:0]  speed, tickcount;
    reg [6:0]  songpos, songlen, curpat;
    reg [5:0]  patrow;
    reg        breakflag, jumpflag;
    reg [1:0]  ch;

    // ---- per channel state (LUT RAM) ----
    // [10:0] note [15:11] lastinst [23:16] fx [31:24] param [39:32] portaspeed
    // [50:40] slideto [51] slidedir [58:52] vol
    wire [59:0] cr;
    reg  [59:0] cr_n;                    // written in S_RFX / S_TFX
    wire        cr_we;
    sound_ram #(.WIDTH(60)) chs(.clk(clk), .we(cr_we), .waddr({2'b00, ch}), .wdata(cr_n),
        .raddr({2'b00, ch}), .rdata(cr));
    wire [10:0] c_note = cr[10:0];
    wire [4:0]  c_inst = cr[15:11];
    wire [7:0]  c_fx = cr[23:16], c_param = cr[31:24], c_pspeed = cr[39:32];
    wire [10:0] c_slideto = cr[50:40];
    wire        c_sdir = cr[51];
    wire [6:0]  c_vol = cr[58:52];

    // ---- row being handled ----
    reg [31:0] pat;                      // pattern word
    reg [19:0] h_start, h_end, h_ls, h_le;
    reg [6:0]  h_vol;
    reg [15:0] freq;
    reg [2:0]  hw;                       // header word being read
    reg [2:0]  wn;                       // write being done
    reg        rd_busy;                  // read requested, no data yet
    reg        t_pitch_d, t_vfx_d;       // tick effect kind (S_TLUT, S_TW)

    wire [4:0]  p_inst  = pat[31:27];
    wire [10:0] p_note  = pat[26:16];
    wire [7:0]  p_fx    = pat[15:8];
    wire [7:0]  p_param = pat[7:0];
    wire [4:0]  p_ei    = (p_inst != 0) ? p_inst : c_inst;
    wire        p_porta = (p_fx == 8'h03) || (p_fx == 8'h05);
    wire        p_hdr   = (p_ei != 0) && (p_inst != 0 || p_note != 0);
    wire        p_trig  = (p_ei != 0) && (p_note != 0) && !p_porta;

    function [10:0] nclamp(input signed [12:0] n);
        nclamp = (n < 13'sd108) ? 11'd108 : (n > 13'sd907) ? 11'd907 : n[10:0];
    endfunction
    function [6:0] vclamp(input signed [8:0] v);
        vclamp = (v < 9'sd0) ? 7'd0 : (v > 9'sd64) ? 7'd64 : v[6:0];
    endfunction
    function [6:0] vslide(input [6:0] v, input [7:0] prm);
        vslide = (prm[7:4] != 0) ? vclamp($signed({2'b00, v}) + $signed({5'd0, prm[7:4]}))
            : vclamp($signed({2'b00, v}) - $signed({5'd0, prm[3:0]}));
    endfunction

    // row: new channel state
    reg [10:0] r_note, r_slideto;
    reg [7:0]  r_pspeed;
    reg        r_sdir;
    reg [6:0]  r_vol;
    always @(*)
        begin
            r_note = (p_note != 0 && !p_porta) ? p_note : c_note;
            r_vol = (p_inst != 0) ? h_vol : c_vol;
            r_pspeed = c_pspeed;
            r_slideto = c_slideto;
            r_sdir = c_sdir;
            case (p_fx)
                8'h01, 8'h02: r_pspeed = p_param;
                8'h03:
                    begin
                        if (p_param != 0) r_pspeed = p_param;
                        if (p_note != 0)  r_slideto = p_note;
                        r_sdir = r_note < r_slideto;
                    end
                8'h0c: r_vol = vclamp({2'b00, p_param[6:0]});
                8'h0e:
                    case (p_param[7:4])
                        4'h1: r_note = nclamp($signed({2'b00, r_note}) - $signed({9'd0, p_param[3:0]}));
                        4'h2: r_note = nclamp($signed({2'b00, r_note}) + $signed({9'd0, p_param[3:0]}));
                        4'ha: r_vol = vclamp($signed({2'b00, r_vol}) + $signed({5'd0, p_param[3:0]}));
                        4'hb: r_vol = vclamp($signed({2'b00, r_vol}) - $signed({5'd0, p_param[3:0]}));
                        default: ;
                    endcase
                default: ;
            endcase
        end

    // tick effects: new channel state
    reg [10:0] t_note;
    reg [7:0]  t_fx;
    reg [6:0]  t_vol;
    reg signed [12:0] t_n;
    wire       t_pitch = (c_fx == 8'h01) || (c_fx == 8'h02) || (c_fx == 8'h03) || (c_fx == 8'h05);
    wire       t_vfx   = (c_fx == 8'h05) || (c_fx == 8'h06) || (c_fx == 8'h0a);
    always @(*)
        begin
            t_note = c_note;
            t_fx = c_fx;
            t_vol = t_vfx ? vslide(c_vol, c_param) : c_vol;
            t_n = 0;
            case (c_fx)
                8'h01: t_note = nclamp($signed({2'b00, c_note}) - $signed({5'd0, c_pspeed}));
                8'h02: t_note = nclamp($signed({2'b00, c_note}) + $signed({5'd0, c_pspeed}));
                8'h03, 8'h05:
                    begin
                        if (c_sdir)
                            begin
                                t_n = $signed({2'b00, c_note}) + $signed({5'd0, c_pspeed});
                                if (t_n >= $signed({2'b00, c_slideto})) begin t_note = c_slideto; t_fx = 0; end
                                else t_note = nclamp(t_n);
                            end
                        else
                            begin
                                t_n = $signed({2'b00, c_note}) - $signed({5'd0, c_pspeed});
                                if (t_n <= $signed({2'b00, c_slideto})) begin t_note = c_slideto; t_fx = 0; end
                                else t_note = nclamp(t_n);
                            end
                    end
                default: ;
            endcase
        end

    // ---- state machine ----
    localparam [4:0] S_IDLE = 0, S_TICK = 2, S_ROW = 3, S_PAT = 4,
        S_HDR = 5, S_RFX = 6, S_RLUT = 7, S_RW = 8, S_RNEXT = 9,
        S_ADV = 10, S_ORDER = 11, S_TFX = 12, S_TLUT = 13, S_TW = 14,
        S_TNEXT = 15, S_STOP = 16, S_INITRD = 17;
    reg [4:0] st;

    assign cr_we = (st == S_RFX) || (st == S_TFX);
    always @(*)
        if (st == S_RFX)
        cr_n = {1'b0, r_vol, r_sdir, r_slideto, r_pspeed, p_param, p_fx,
            (p_inst != 0) ? p_inst : c_inst, r_note};
    else
        cr_n = {1'b0, t_vol, cr[51:24], t_fx, cr[15:11], t_note};

    wire [19:0] pat_addr = offset + 20'd157 + {5'd0, curpat, patrow, ch};

    // writes of a row: END, LSTART, LEND (header), START (trigger), VOL, FREQ
    localparam [5:0] R_START = 6'd4, R_VOL = 6'd8, R_END = 6'd12, R_LSTART = 6'd16,
        R_LEND = 6'd20, R_FREQ = 6'd24;

    always @(posedge clk or negedge rst_n)
        if (!rst_n)
        begin
            offset <= 0; lut <= 0; status <= 0; stop_req <= 0; waitclk <= 20'd504000;
            playing <= 0; tick_acc <= 0; tick_pend <= 0;
            speed <= 5'd6; tickcount <= 5'd1; songpos <= 0; songlen <= 0; curpat <= 0;
            patrow <= 0; breakflag <= 0; jumpflag <= 0; ch <= 0;
            pat <= 0; h_start <= 0; h_end <= 0; h_ls <= 0; h_le <= 0; h_vol <= 0;
            freq <= 0; hw <= 0; wn <= 0;
            rd_req <= 0; rd_addr <= 0; w_req <= 0; w_reg <= 0; w_ch <= 0; w_data <= 0;
            rd_busy <= 0;
            ev_start <= 0; ev_tick <= 0; ev_stop <= 0;
            st <= S_IDLE;
        end
    else
        begin
            ev_start <= 0;
            ev_tick <= 0;
            ev_stop <= 0;

            if (cpu_w)
                case (cpu_reg)
                    6'd0:  offset <= cpu_data[19:0];
                    6'd1:  lut <= cpu_data[19:0];
                    6'd3:
                        begin
                            status <= cpu_data[2:0];
                            if (!cpu_data[0])
                                stop_req <= 1;
                        end
                    6'd28: waitclk <= cpu_data[19:0];
                    default: ;
                endcase

            if (mix_tick && playing && !status[1])
                begin
                    if (tick_acc + 21'd525 >= {1'b0, waitclk})
                        begin
                            tick_acc <= tick_acc + 21'd525 - {1'b0, waitclk};
                            tick_pend <= 1;
                        end
                    else
                        tick_acc <= tick_acc + 21'd525;
                end

            if (w_ack)
                w_req <= 0;
            if (rd_ack)
                rd_req <= 0;
            if (rd_valid)
                rd_busy <= 0;

            case (st)
                S_IDLE:
                    if (stop_req)
                    begin
                        stop_req <= 0;
                        if (playing)
                            begin
                                playing <= 0;
                                ch <= 0;
                                ev_stop <= 1;
                                st <= S_STOP;
                            end
                    end
                else if (!playing && status[0] && !status[1])
                    begin
                        rd_req <= 1; rd_busy <= 1;
                        rd_addr <= offset + 20'd124;
                        ev_start <= 1;
                        st <= S_INITRD;
                    end
                else if (playing && tick_pend)
                    begin
                        tick_pend <= 0;
                        st <= S_TICK;
                    end

                S_INITRD:
                    if (rd_valid)
                    begin
                        songlen <= rd_data[30:24];
                        curpat <= rd_data[6:0];
                        speed <= 5'd6;
                        tickcount <= 5'd1;
                        songpos <= 0;
                        patrow <= 0;
                        playing <= 1;
                        tick_acc <= 0;
                        tick_pend <= 0;
                        st <= S_TICK;           // the first row now
                    end

                S_TICK:
                    begin
                        ev_tick <= 1;
                        ch <= 0;
                        if (tickcount == 5'd1)
                            begin
                                tickcount <= speed;
                                breakflag <= 0;
                                jumpflag <= 0;
                                st <= S_ROW;
                            end
                        else
                            begin
                                tickcount <= tickcount - 1'b1;
                                st <= S_TFX;
                            end
                    end

                // ---- row: one channel at a time ----
                S_ROW:
                    begin
                        rd_req <= 1; rd_busy <= 1;
                        rd_addr <= pat_addr;
                        st <= S_PAT;
                    end

                S_PAT:
                    if (rd_valid)
                    begin
                        pat <= rd_data;
                        hw <= 0;
                        st <= S_HDR;
                    end

                S_HDR:                     // instrument header, if needed
                    if (!p_hdr)
                    st <= S_RFX;
                else if (!rd_busy)
                    begin
                        if (hw == 3'd4)
                            st <= S_RFX;
                        else
                            begin
                                rd_req <= 1; rd_busy <= 1;
                                rd_addr <= offset + {13'd0, p_ei - 1'b1, hw[1:0]};
                            end
                    end
                else if (rd_valid)
                    begin
                        case (hw[1:0])
                            2'd0: h_start <= offset + rd_data[21:2];
                            2'd1:
                                begin
                                    h_vol <= rd_data[30:24];
                                    h_end <= offset + rd_data[21:2];
                                end
                            2'd2: h_ls <= offset + rd_data[21:2];
                            default: h_le <= (rd_data[25:2] == 0) ? 20'd0 : offset + rd_data[21:2];
                        endcase
                        hw <= hw + 1'b1;
                    end

                S_RFX:                     // row effects
                    begin
                        case (p_fx)
                            8'h0b:
                                if (!jumpflag)
                                begin
                                    patrow <= 0;
                                    jumpflag <= 1;
                                    songpos <= p_param[6:0];
                                end
                            8'h0d:
                                if (!breakflag)
                                begin
                                    patrow <= p_param[5:0];
                                    breakflag <= 1;
                                    if (!jumpflag)
                                        songpos <= songpos + 1'b1;
                                end
                            8'h0f:
                                if (p_param != 0 && p_param < 8'd32)
                                speed <= p_param[4:0];
                            default: ;
                        endcase
                        st <= S_RLUT;
                    end

                S_RLUT:                    // frequency of the (new) note
                    if (c_note == 0)
                    begin
                        wn <= 0;
                        st <= S_RW;
                    end
                else if (!rd_busy)
                    begin
                        rd_req <= 1; rd_busy <= 1;
                        rd_addr <= lut + {9'd0, c_note};
                    end
                else if (rd_valid)
                    begin
                        freq <= rd_data[15:0];
                        wn <= 0;
                        st <= S_RW;
                    end

                S_RW:                      // channel writes
                    if (!w_req)
                    begin
                        wn <= wn + 1'b1;
                        w_ch <= ch;
                        case (wn)
                            3'd0: if (p_hdr)  begin w_req <= 1; w_reg <= R_END;    w_data <= h_end;   end
                            3'd1: if (p_hdr)  begin w_req <= 1; w_reg <= R_LSTART; w_data <= h_ls;    end
                            3'd2: if (p_hdr)  begin w_req <= 1; w_reg <= R_LEND;   w_data <= h_le;    end
                            3'd3: if (p_trig) begin w_req <= 1; w_reg <= R_START;  w_data <= h_start; end
                            3'd4:             begin w_req <= 1; w_reg <= R_VOL;    w_data <= {13'd0, c_vol}; end
                            3'd5: if (c_note != 0) begin w_req <= 1; w_reg <= R_FREQ; w_data <= {4'd0, freq}; end
                            default: st <= S_RNEXT;
                        endcase
                    end

                S_RNEXT:
                    if (ch == 2'd3)
                    st <= S_ADV;
                else
                    begin
                        ch <= ch + 1'b1;
                        st <= S_ROW;
                    end

                S_ADV:                     // next row / song position
                    if (!jumpflag && !breakflag && patrow != 6'd63)
                    begin
                        patrow <= patrow + 1'b1;
                        st <= S_IDLE;
                    end
                else
                    begin
                        if (!jumpflag && !breakflag)
                            begin
                                patrow <= 0;
                                songpos <= songpos + 1'b1;
                            end
                        st <= S_ORDER;
                    end

                S_ORDER:
                    if (!rd_busy)
                    begin
                        if (songpos >= songlen && !status[2])
                            begin
                                // song end, no loop
                                status[0] <= 0;
                                playing <= 0;
                                ch <= 0;
                                ev_stop <= 1;
                                st <= S_STOP;
                            end
                        else
                            begin
                                if (songpos >= songlen)
                                    songpos <= 0;
                                rd_req <= 1; rd_busy <= 1;
                                rd_addr <= offset + 20'd125 +
                                    ((songpos >= songlen) ? 20'd0 : {15'd0, songpos[6:2]});
                            end
                    end
                else if (rd_valid)
                    begin
                        case (songpos[1:0])
                            2'd0: curpat <= rd_data[6:0];
                            2'd1: curpat <= rd_data[14:8];
                            2'd2: curpat <= rd_data[22:16];
                            default: curpat <= rd_data[30:24];
                        endcase
                        st <= S_IDLE;
                    end

                // ---- tick effects ----
                S_TFX:
                    begin
                        st <= S_TLUT;
                    end

                S_TLUT:
                    if (!(c_note != 0 && t_pitch_d))
                    begin
                        wn <= 0;
                        st <= S_TW;
                    end
                else if (!rd_busy)
                    begin
                        rd_req <= 1; rd_busy <= 1;
                        rd_addr <= lut + {9'd0, c_note};
                    end
                else if (rd_valid)
                    begin
                        freq <= rd_data[15:0];
                        wn <= 0;
                        st <= S_TW;
                    end

                S_TW:
                    if (!w_req)
                    begin
                        wn <= wn + 1'b1;
                        w_ch <= ch;
                        case (wn)
                            3'd0: if (t_vfx_d) begin w_req <= 1; w_reg <= R_VOL; w_data <= {13'd0, c_vol}; end
                            3'd1: if (t_pitch_d && c_note != 0)
                                begin w_req <= 1; w_reg <= R_FREQ; w_data <= {4'd0, freq}; end
                            default: st <= S_TNEXT;
                        endcase
                    end

                S_TNEXT:
                    if (ch == 2'd3)
                    st <= S_IDLE;
                else
                    begin
                        ch <= ch + 1'b1;
                        st <= S_TFX;
                    end

                // ---- stop: END = 0 for channels 0..3 ----
                S_STOP:
                    if (!w_req)
                    begin
                        w_req <= 1;
                        w_ch <= ch;
                        w_reg <= R_END;
                        w_data <= 0;
                        ch <= ch + 1'b1;
                        if (ch == 2'd3)
                            st <= S_IDLE;
                    end

                default: st <= S_IDLE;
            endcase
        end

    // the tick effect kind of the channel, kept from S_TFX (the record is
    // rewritten there, t_fx may clear the effect)
    always @(posedge clk or negedge rst_n)
        if (!rst_n)
        begin
            t_pitch_d <= 0;
            t_vfx_d <= 0;
        end
    else if (st == S_TFX)
        begin
            t_pitch_d <= t_pitch;
            t_vfx_d <= t_vfx;
        end

endmodule // sound_seq

// Sound: 8 channel sample player, mixed to 16 bit stereo at 48 kHz for HDMI.
//
// Register set follows the old TetrIC sound unit (old_vhdl/mainunit.vhd) so
// game_code/TLib/Sound.s and FXMusic.s work unchanged. Processor address
// 0x4xxxxx, register = addr[5:0], write only:
//
//    2 CHANSTATUS  channel on (1) / mute (0), bit 7 = ch0 .. bit 0 = ch7
//    4.. 7 FXn_START    sample start, word address           (channel 4+n)
//    8..11 FXn_VOL      volume 0..64
//   12..15 FXn_END      sample end, word address (exclusive)
//   16..19 FXn_LSTART   loop start, word address
//   20..23 FXn_LEND     loop end, word address (exclusive), 0 = no loop
//   24..27 FXn_FREQ     sample rate in Hz (0..65535)
//   37 MASTERVOL  3 bit master volume per channel, one nibble each:
//                 [30:28] ch4 [26:24] ch5 [22:20] ch6 [18:16] ch7
//                 [14:12] ch0 [10:8]  ch1 [6:4]   ch2 [2:0]   ch3
//                 7 = full, 6 = half, ... 0 = off
//   0, 1, 3, 28  MOD player: OFFSET, LUT, SONGSTATUS, WAITCLK, see
//                sound_seq.v (29, 31..36 are ignored)
//
// Channels 0..3 are played by the MOD sequencer (sound_seq.v), which
// changes them with the same writes as above (START, VOL, END, ...).
// Mixing is Amiga style: left = ch 0,3,4,7, right = ch 1,2,5,6.
//
// Samples are signed 8 bit, 4 per word, first sample in bits 31:24.
// A channel plays the words START .. END-1. Writing START restarts the
// channel; it starts playing (one silent sample later) as soon as
// START < END, so the game writes END last. When LEND != 0 the channel
// jumps to LSTART when it reaches LEND. END = 0 stops the channel at once
// (also a looping one).
//
// Each channel buffers two words and fetches the next word from SDRAM as
// soon as one is free, so a word has 4..8 output samples (>= 83 us at
// 48 kHz) to arrive. Channel state is kept in LUT RAM (one record per
// channel) and handled one channel per clock; register writes go through
// a 16 entry queue and are applied between the mix passes.
//
// Volume: out = sample * (VOL >> (7 - MASTERVOL)), so one channel at full
// volume is +-8192 and four channels use the full 16 bit range.
//
// Clock domains: registers, mixing and fetch logic in clk_cpu, 48 kHz sample
// clock and audio output in clk_pixel (25.2 MHz / 525), SDRAM requests in
// clk_ram. The output rate follows clk_pixel, as HDMI expects.

module sound
    #(
        parameter [9:0] SAMPLE_DIV = 10'd525      // clk_pixel clocks per sample (48 kHz)
    )
        (
            input             clk_cpu,
            input             clk_pixel,
            input             clk_ram,
            input             rst_n,

            input             enable,        // clk_ram: memory ready (flash copy done)

            // REGISTER WRITE (clk_cpu)
            input [23:0]      addr_in,
            input [31:0]      data_in,
            input             sel,
            input             wr,

            // MEMORY CONTROLLER (clk_ram), single word reads
            output            req,
            output [19:0]     req_address,
            input             req_ack,
            input [31:0]      rsp_data,
            input             rsp_data_strobe,

            // AUDIO OUT (clk_pixel), audio_valid pulses at 48 kHz
            output reg [15:0] audio_l,
            output reg [15:0] audio_r,
            output reg        audio_valid
        );

    wire rst_cpu_n, rst_pixel_n, rst_ram_n;
    reset_sync rs_cpu  (.clk(clk_cpu),   .rst_n_in(rst_n), .rst_n_out(rst_cpu_n));
    reset_sync rs_pixel(.clk(clk_pixel), .rst_n_in(rst_n), .rst_n_out(rst_pixel_n));
    reset_sync rs_ram  (.clk(clk_ram),   .rst_n_in(rst_n), .rst_n_out(rst_ram_n));

    // ============================ clk_pixel ============================

    reg [9:0]  div;
    reg        tick_tog;
    reg [15:0] out_l, out_r;                 // clk_cpu, stable after out_tog
    reg        out_tog;
    wire       out_ev;

    sync_toggle st_out(.clk(clk_pixel), .rst_n(rst_pixel_n), .toggle(out_tog), .pulse(out_ev));

    always @(posedge clk_pixel or negedge rst_pixel_n)
        if (!rst_pixel_n)
        begin
            div <= 0;
            tick_tog <= 0;
            audio_l <= 0;
            audio_r <= 0;
            audio_valid <= 0;
        end
    else
        begin
            div <= (div == SAMPLE_DIV - 1'b1) ? 10'd0 : div + 1'b1;
            if (div == SAMPLE_DIV - 1'b1)
                tick_tog <= ~tick_tog;
            audio_valid <= out_ev;
            if (out_ev)
                begin
                    audio_l <= out_l;
                    audio_r <= out_r;
                end
        end

    // ============================ clk_ram ==============================
    reg         f_tog;          // clk_cpu: fetch request toggle
    reg [19:0]  f_addr_h;       // clk_cpu: held until the response
    wire [31:0] f_data;         // clk_ram: held until the next request
    wire        f_rsp_tog;

    sound_dma sound_dma(.clk_ram(clk_ram),
        .rst_n(rst_ram_n),
        .enable(enable),
        .fetch_tog(f_tog),
        .fetch_address(f_addr_h),
        .fetch_data(f_data),
        .fetch_done_tog(f_rsp_tog),
        .req(req),
        .req_address(req_address),
        .req_ack(req_ack),
        .rsp_data(rsp_data),
        .rsp_data_strobe(rsp_data_strobe));

    // ============================ clk_cpu ==============================
    // All channel state is in one record RAM (LUT RAM, 8 entries). One
    // operation per clock reads the record of one channel, modifies it and
    // writes it back. Operations in priority order:
    //   CLEAR  clear the records after reset (8 clocks)
    //   RSP    put a fetched word into the channel buffer
    //   MIX    mix one channel (8 clocks per 48 kHz tick)
    //   SEQW   apply one channel write from the MOD sequencer (ch 0..3)
    //   WRITE  apply one register write from the write queue
    //   FETCH  check one channel (round robin) and request its next word
    wire tick_ev, rsp_ev;
    sync_toggle st_tick(.clk(clk_cpu), .rst_n(rst_cpu_n), .toggle(tick_tog),  .pulse(tick_ev));
    sync_toggle st_rsp (.clk(clk_cpu), .rst_n(rst_cpu_n), .toggle(f_rsp_tog), .pulse(rsp_ev));

    localparam [2:0] OP_CLEAR = 3'd0, OP_RSP = 3'd1, OP_MIX = 3'd2, OP_WRITE = 3'd3, OP_FETCH = 3'd4,
        OP_SEQW = 3'd5;

    // ---- register write queue (the CPU writes without waiting) ----
    wire        wen = sel && wr;
    reg  [4:0]  wq_w, wq_r;
    wire        wq_empty = wq_w == wq_r;
    wire        wq_full  = (wq_w[3:0] == wq_r[3:0]) && (wq_w[4] != wq_r[4]);
    wire [39:0] wq_head;
    sound_ram #(.WIDTH(40)) wq(.clk(clk_cpu),
        .we(wen && !wq_full),
        .waddr(wq_w[3:0]),
        .wdata({2'b00, addr_in[5:0], data_in}),
        .raddr(wq_r[3:0]),
        .rdata(wq_head));
    wire [5:0]  q_reg  = wq_head[37:32];
    wire [31:0] q_data = wq_head[31:0];

    // ---- global registers ----
    reg [7:0]   chan_on;        // bit 7 = ch0
    reg [23:0]  mvol;           // 3 bits per channel, ch0 in [2:0]

    // ---- MOD sequencer ----
    wire        seq_rd_req, seq_w_req;
    wire [19:0] seq_rd_addr, seq_w_data;
    wire [5:0]  seq_w_reg;
    wire [1:0]  seq_w_ch;
    reg         seq_rd_valid;
    reg  [3:0]  seq_gap;        // clocks without sequencer reads (sample fetches)
    wire        seq_ev_start, seq_ev_tick, seq_ev_stop;

    // ---- fetch: one request in flight ----
    reg         f_seq;          // the word in flight is for the sequencer
    reg         f_busy;
    reg [2:0]   f_ch;
    reg         f_discard;      // channel restarted while its word was in flight
    reg         rsp_pend;
    reg [2:0]   rr;             // channel to check for fetch

    // ---- mixer ----
    reg         mixing;
    reg [2:0]   mch;
    reg signed [16:0] acc_l, acc_r;

    reg         cleared;
    reg [2:0]   clr_ch;

    // debug / testbench
    reg [31:0]  tick_count;     // mix passes started
    reg [31:0]  underruns;      // samples where a playing channel had no data
    reg         wq_overflow;    // sticky: register write lost

    // ---- operation select ----
    reg [2:0]   op;
    reg [2:0]   op_ch;
    always @(*)
        begin
            if (!cleared)       begin op = OP_CLEAR; op_ch = clr_ch; end
            else if (rsp_pend)  begin op = OP_RSP;   op_ch = f_ch;   end
            else if (mixing)    begin op = OP_MIX;   op_ch = mch;    end
            else if (seq_w_req) begin op = OP_SEQW;  op_ch = {1'b0, seq_w_ch}; end
            else if (!wq_empty) begin op = OP_WRITE; op_ch = 3'd4 + q_reg[1:0]; end
            else                begin op = OP_FETCH; op_ch = rr;     end
        end

    // ---- channel record ----
    localparam RW = 188;
    wire [RW-1:0] rec;
    reg  [RW-1:0] rec_n;
    reg           rec_we;
    sound_ram #(.WIDTH(RW)) chm(.clk(clk_cpu),
        .we(rec_we),
        .waddr({1'b0, op_ch}),
        .wdata(rec_n),
        .raddr({1'b0, op_ch}),
        .rdata(rec));

    // record fields
    reg [6:0]  r_vol;
    reg [15:0] r_freq;
    reg [19:0] r_lend, r_lstart, r_fend, r_faddr;   // faddr = next word to fetch
    reg [31:0] r_nxt, r_cur;                        // next word / word being played
    reg        r_nxt_v, r_cur_v, r_play;
    reg [1:0]  r_idx;                               // sample in cur
    reg [15:0] r_frac;                              // position between samples

    // ---- mix arithmetic (channel op_ch) ----
    reg  [7:0]  m_byte;
    always @(*)
        case (r_idx)
            2'd0: m_byte = r_cur[31:24];
            2'd1: m_byte = r_cur[23:16];
            2'd2: m_byte = r_cur[15:8];
            default: m_byte = r_cur[7:0];
        endcase

    wire [6:0]  m_vol  = r_vol > 7'd64 ? 7'd64 : r_vol;
    wire [2:0]  m_mv   = mvol[3*op_ch +: 3];
    wire [6:0]  m_eff  = (m_mv == 3'd0) ? 7'd0 : (m_vol >> (3'd7 - m_mv));
    wire signed [15:0] m_prod = $signed(m_byte) * $signed({1'b0, m_eff});
    wire [30:0] m_incx = r_freq * 15'd22370;               // 2^16 / 48000 = 22370 / 2^14
    wire [16:0] m_inc  = m_incx[30:14];
    wire [17:0] m_pos  = r_frac + m_inc;
    wire [2:0]  m_ni   = r_idx + m_pos[17:16];
    wire        m_more = r_faddr < r_fend;
    wire        m_left = m_more || r_nxt_v || (f_busy && !f_seq && f_ch == op_ch && !f_discard);
    wire        m_on   = chan_on[3'd7 - op_ch];
    wire signed [15:0] m_sample = (r_play && r_cur_v && m_on) ? m_prod : 16'sd0;
    wire        m_is_left = op_ch[0] ~^ op_ch[1];
    wire signed [16:0] m_acc_l = acc_l + (m_is_left ? m_sample : 16'sd0);
    wire signed [16:0] m_acc_r = acc_r + (m_is_left ? 16'sd0 : m_sample);
    wire        m_underrun = r_play && !r_cur_v && m_left;

    // ---- fetch arithmetic ----
    wire        f_need   = m_more && !(r_cur_v && r_nxt_v);
    // sequencer reads only in a fetch slot of a channel that needs nothing
    // (the sample words go first)
    wire        seq_take = !f_busy && seq_rd_req && seq_gap == 0 && !f_need;
    wire        f_issue  = !f_busy && f_need && !seq_take;
    wire [19:0] f_next0  = r_faddr + 1'b1;
    wire [19:0] f_next   = (r_lend != 0 && f_next0 >= r_lend) ? r_lstart : f_next0;

    function [15:0] sat16(input signed [16:0] v);
        sat16 = (v > 17'sd32767) ? 16'h7fff : (v < -17'sd32768) ? 16'h8000 : v[15:0];
    endfunction

    // ---- register write (CPU queue or sequencer) ----
    wire [5:0]  w_reg  = (op == OP_SEQW) ? seq_w_reg : q_reg;
    wire [31:0] w_data = (op == OP_SEQW) ? {12'd0, seq_w_data} : q_data;

    sound_seq seq(.clk(clk_cpu), .rst_n(rst_cpu_n),
        .cpu_w(op == OP_WRITE), .cpu_reg(q_reg), .cpu_data(q_data),
        .mix_tick(tick_ev),
        .rd_req(seq_rd_req), .rd_addr(seq_rd_addr),
        .rd_ack(op == OP_FETCH && seq_take),
        .rd_valid(seq_rd_valid), .rd_data(f_data),
        .w_req(seq_w_req), .w_reg(seq_w_reg), .w_ch(seq_w_ch), .w_data(seq_w_data),
        .w_ack(op == OP_SEQW),
        .ev_start(seq_ev_start), .ev_tick(seq_ev_tick), .ev_stop(seq_ev_stop));

    // ---- record update (combinational) ----
    always @(*)
        begin
            {r_vol, r_freq, r_lend, r_lstart, r_fend, r_faddr,
                r_nxt, r_cur, r_nxt_v, r_cur_v, r_play, r_idx, r_frac} = rec;
            rec_n = rec;
            rec_we = 0;
            case (op)
                OP_CLEAR:
                    begin
                        rec_n = 0;
                        rec_we = 1;
                    end

                OP_RSP:
                    if (!f_discard)
                    begin
                        rec_we = 1;
                        if (!r_cur_v)
                            rec_n = {r_vol, r_freq, r_lend, r_lstart, r_fend, r_faddr,
                                r_nxt, f_data, r_nxt_v, 1'b1, r_play, r_idx, r_frac};
                        else
                            rec_n = {r_vol, r_freq, r_lend, r_lstart, r_fend, r_faddr,
                                f_data, r_cur, 1'b1, r_cur_v, r_play, r_idx, r_frac};
                    end

                OP_MIX:
                    begin
                        rec_we = 1;
                        if (!r_play)
                            begin
                                // start one (silent) sample after START < END
                                if (m_more || r_cur_v)
                                    rec_n[18] = 1'b1;
                            end
                        else if (r_cur_v)
                            begin
                                if (m_ni[2])
                                    // word done: next word (if there) becomes the current one
                                    rec_n = {r_vol, r_freq, r_lend, r_lstart, r_fend, r_faddr,
                                        r_nxt, r_nxt_v ? r_nxt : r_cur, 1'b0, r_nxt_v,
                                        r_play, m_ni[1:0], m_pos[15:0]};
                                else
                                    rec_n = {r_vol, r_freq, r_lend, r_lstart, r_fend, r_faddr,
                                        r_nxt, r_cur, r_nxt_v, r_cur_v,
                                        r_play, m_ni[1:0], m_pos[15:0]};
                            end
                        else if (!m_left)
                            rec_n[18] = 1'b0;   // sample done
                    end

                OP_WRITE, OP_SEQW:
                    case (w_reg[5:2])
                        4'd1:                       // START: restart the channel
                            begin
                                rec_we = 1;
                                rec_n = {r_vol, r_freq, r_lend, r_lstart, r_fend, w_data[19:0],
                                    r_nxt, r_cur, 1'b0, 1'b0, 1'b0, 2'd0, 16'd0};
                            end
                        4'd2:                       // VOL
                            begin
                                rec_we = 1;
                                rec_n[187:181] = w_data[6:0];
                            end
                        4'd3:                       // END (0: stop now)
                            begin
                                rec_we = 1;
                                rec_n[124:105] = w_data[19:0];
                                if (w_data[19:0] == 0)
                                    rec_n[20:18] = 3'b000;     // nxt_v, cur_v, play
                            end
                        4'd4:                       // LSTART
                            begin
                                rec_we = 1;
                                rec_n[144:125] = w_data[19:0];
                            end
                        4'd5:                       // LEND
                            begin
                                rec_we = 1;
                                rec_n[164:145] = w_data[19:0];
                            end
                        4'd6:                       // FREQ
                            begin
                                rec_we = 1;
                                rec_n[180:165] = w_data[15:0];
                            end
                        default: ;
                    endcase

                OP_FETCH:
                    if (f_issue)
                    begin
                        rec_we = 1;
                        rec_n[104:85] = f_next;
                    end

                default: ;
            endcase
        end

    // ---- everything else ----
    always @(posedge clk_cpu or negedge rst_cpu_n)
        if (!rst_cpu_n)
        begin
            cleared <= 0;
            clr_ch <= 0;
            wq_w <= 0;
            wq_r <= 0;
            wq_overflow <= 0;
            chan_on <= 8'hff;
            mvol <= 24'hffffff;
            f_busy <= 0;
            f_seq <= 0;
            seq_rd_valid <= 0;
            seq_gap <= 0;
            f_ch <= 0;
            f_discard <= 0;
            f_tog <= 0;
            f_addr_h <= 0;
            rsp_pend <= 0;
            rr <= 0;
            mixing <= 0;
            mch <= 0;
            acc_l <= 0;
            acc_r <= 0;
            out_l <= 0;
            out_r <= 0;
            out_tog <= 0;
            tick_count <= 0;
            underruns <= 0;
        end
    else
        begin
            if (wen)
                begin
                    if (wq_full)
                        wq_overflow <= 1;
                    else
                        wq_w <= wq_w + 1'b1;
                end
            seq_rd_valid <= 0;
            if (seq_gap != 0)
                seq_gap <= seq_gap - 1'b1;
            if (rsp_ev)
                begin
                    if (f_seq)
                        begin
                            seq_rd_valid <= 1;   // f_data is held until the next request
                            f_busy <= 0;
                        end
                    else
                        rsp_pend <= 1;
                end
            if (tick_ev)
                begin
                    mixing <= 1;
                    mch <= 0;
                    acc_l <= 0;
                    acc_r <= 0;
                    tick_count <= tick_count + 1;
                end

            case (op)
                OP_CLEAR:
                    begin
                        clr_ch <= clr_ch + 1'b1;
                        if (clr_ch == 3'd7)
                            cleared <= 1;
                    end

                OP_RSP:
                    begin
                        rsp_pend <= 0;
                        f_busy <= 0;
                    end

                OP_MIX:
                    begin
                        if (m_underrun)
                            underruns <= underruns + 1;
                        acc_l <= m_acc_l;
                        acc_r <= m_acc_r;
                        mch <= mch + 1'b1;
                        if (mch == 3'd7)
                            begin
                                mixing <= 0;
                                out_l <= sat16(m_acc_l);
                                out_r <= sat16(m_acc_r);
                                out_tog <= ~out_tog;
                            end
                    end

                OP_SEQW:
                    // a restarted / stopped channel drops the word in flight for it
                    if ((w_reg[5:2] == 4'd1 || (w_reg[5:2] == 4'd3 && w_data[19:0] == 0)) &&
                        f_busy && !f_seq && f_ch == op_ch)
                    f_discard <= 1;

                OP_WRITE:
                    begin
                        wq_r <= wq_r + 1'b1;
                        case (q_reg)
                            6'd2:
                                chan_on <= q_data[7:0];
                            6'd4, 6'd5, 6'd6, 6'd7:
                                // a restarted channel drops the word in flight for it
                                if (f_busy && !f_seq && f_ch == op_ch)
                                f_discard <= 1;
                            6'd12, 6'd13, 6'd14, 6'd15:
                                // END = 0 stops the channel now, also the word in flight
                                if (q_data[19:0] == 0 && f_busy && !f_seq && f_ch == op_ch)
                                f_discard <= 1;
                            6'd37:
                                mvol <= {q_data[18:16], q_data[22:20], q_data[26:24], q_data[30:28],
                                    q_data[2:0],   q_data[6:4],   q_data[10:8],  q_data[14:12]};
                            default: ;
                        endcase
                    end

                OP_FETCH:
                    if (seq_take)
                    begin
                        f_addr_h <= seq_rd_addr;
                        f_seq <= 1;
                        f_tog <= ~f_tog;
                        f_busy <= 1;
                        seq_gap <= 4'd12;
                    end
                else
                    begin
                        rr <= rr + 1'b1;
                        if (f_issue)
                            begin
                                f_addr_h <= r_faddr;
                                f_ch <= op_ch;
                                f_seq <= 0;
                                f_tog <= ~f_tog;
                                f_busy <= 1;
                                f_discard <= 0;
                            end
                    end

                default: ;
            endcase
        end

endmodule // sound

// WIDTH x 16 LUT RAM (RAM16SDP4 cells): synchronous write, asynchronous read
module sound_ram
    #(
        parameter WIDTH = 4                 // multiple of 4
    )
        (
            input              clk,
            input              we,
            input [3:0]        waddr,
            input [WIDTH-1:0]  wdata,
            input [3:0]        raddr,
            output [WIDTH-1:0] rdata
        );

    genvar n;
    generate
        for (n = 0; n < WIDTH / 4; n = n + 1) begin : nib
            RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000))
                ram(.DI(wdata[4*n+3:4*n]), .DO(rdata[4*n+3:4*n]),
                    .WRE(we), .CLK(clk), .WAD(waddr), .RAD(raddr));
        end
    endgenerate

endmodule // sound_ram

// Sound DMA (clk_ram): one word per request from the clk_cpu fetch logic.
// The request address is held until the response toggle has been seen, and
// the response word is held until the next request.
module sound_dma(
    input             clk_ram,
    input             rst_n,       // synchronised to clk_ram
    input             enable,

    input             fetch_tog,
    input [19:0]      fetch_address,
    output reg [31:0] fetch_data,
    output reg        fetch_done_tog,

    output reg        req,
    output reg [19:0] req_address,
    input             req_ack,
    input [31:0]      rsp_data,
    input             rsp_data_strobe
);

    wire fetch_ev;
    reg  pending;
    reg  busy;

    sync_toggle st_fetch(.clk(clk_ram), .rst_n(rst_n), .toggle(fetch_tog), .pulse(fetch_ev));

    always @(posedge clk_ram or negedge rst_n)
        if (!rst_n)
        begin
            req <= 0;
            req_address <= 0;
            fetch_data <= 0;
            fetch_done_tog <= 0;
            pending <= 0;
            busy <= 0;
        end
    else
        begin
            if (fetch_ev)
                pending <= 1;
            if (pending && !busy && enable)
                begin
                    pending <= 0;
                    req <= 1;
                    req_address <= fetch_address;
                    busy <= 1;
                end
            if (req_ack)
                req <= 0;
            if (busy && rsp_data_strobe)
                begin
                    fetch_data <= rsp_data;
                    fetch_done_tog <= ~fetch_done_tog;
                    busy <= 0;
                end
        end

endmodule // sound_dma

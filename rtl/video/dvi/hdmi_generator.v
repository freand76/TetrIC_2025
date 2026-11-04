// HDMI 640x480@60 generator with 2 channel 48 kHz L-PCM audio.
//
// Same interface/timing as dvi_generator, plus an audio input. Adds the
// HDMI video preamble + guard band, and one data island per line (in the
// horizontal blanking) holding two packets:
//   packet 0: audio sample packet with the samples received since last line
//   packet 1: AVI InfoFrame (line 0), Audio InfoFrame (line 1),
//             SPD InfoFrame (line 2), else ACR
//
// Line layout (xpos): 640..647 control, 648..655 island preamble,
// 656..657 guard band, 658..721 two packets, 722..723 guard band,
// 724..789 control, 790..797 video preamble, 798..799 video guard band.
//
// audio_valid must pulse at 48 kHz (every 525 pixel clocks at 25.2 MHz).
module hdmi_generator
    #(
        // Source Product Description shown by the sink (ASCII, zero padded)
        parameter [8*8-1:0]  SPD_VENDOR  = "TetrIC",       // up to 8 characters
        parameter [16*8-1:0] SPD_PRODUCT = "TetrIC 2025",  // up to 16 characters
        parameter [7:0]      SPD_SOURCE  = 8'h08           // 0x08 game, 0x09 PC
    )
        (input            clk_pixel,
            input            n_reset,
            input [23:0]     rgb_data,
            input [15:0]     audio_l,
            input [15:0]     audio_r,
            input            audio_valid,
            output [9:0]     tmds_r,
            output [9:0]     tmds_g,
            output [9:0]     tmds_b,
            output reg [9:0] xpos,
            output reg [9:0] ypos,
            output           line_end,
            output           frame_end);

    localparam FRAME_WIDTH = 800;
    localparam FRAME_HEIGHT = 525;
    localparam SCREEN_WIDTH = 640;
    localparam SCREEN_HEIGHT = 480;
    localparam HSYNC_PULSE_START = 16;
    localparam HSYNC_PULSE_SIZE = 96;
    localparam VSYNC_PULSE_START = 10;
    localparam VSYNC_PULSE_SIZE = 2;
    localparam INVERT = 1;

    // Audio clock regeneration, 128*fs = f_tmds * N / CTS
    localparam [19:0] ACR_N = 20'd6144;
    localparam [19:0] ACR_CTS = 20'd25200;

    // SPD InfoFrame payload PB0..PB27 (PB0 = checksum). Verilog right-aligns
    // short strings, so skip leading zero bytes to get the text first.
    function [28*8-1:0] spd_payload(input [63:0] v, input [127:0] p, input [7:0] st);
        integer i, n;
        reg [7:0] sum;
        begin
            spd_payload = 0;
            n = 1;
            for (i = 7; i >= 0; i = i - 1)
                if (v[i*8 +: 8] != 0 || n > 1)
                begin
                    spd_payload[n*8 +: 8] = v[i*8 +: 8];
                    n = n + 1;
                end
            n = 9;
            for (i = 15; i >= 0; i = i - 1)
                if (p[i*8 +: 8] != 0 || n > 9)
                begin
                    spd_payload[n*8 +: 8] = p[i*8 +: 8];
                    n = n + 1;
                end
            spd_payload[25*8 +: 8] = st;
            sum = 8'h83 + 8'h01 + 8'h19;
            for (i = 1; i < 28; i = i + 1)
                sum = sum + spd_payload[i*8 +: 8];
            spd_payload[7:0] = -sum;
        end
    endfunction

    localparam [28*8-1:0] SPD_PB = spd_payload(SPD_VENDOR, SPD_PRODUCT, SPD_SOURCE);

    assign line_end  = (xpos == SCREEN_WIDTH-1'b1) && (ypos < SCREEN_HEIGHT-1'b1);
    assign frame_end = (xpos == SCREEN_WIDTH-1'b1) && (ypos == SCREEN_HEIGHT-1'b1);

    logic hsync, vsync;
    always @(*)
        begin
            hsync = INVERT ^ (xpos >= SCREEN_WIDTH + HSYNC_PULSE_START && xpos < SCREEN_WIDTH + HSYNC_PULSE_START + HSYNC_PULSE_SIZE);
            if (ypos == SCREEN_HEIGHT + VSYNC_PULSE_START - 1)
                vsync = INVERT ^ (xpos >= SCREEN_WIDTH + HSYNC_PULSE_START);
            else if (ypos == SCREEN_HEIGHT + VSYNC_PULSE_START + VSYNC_PULSE_SIZE - 1)
                vsync = INVERT ^ (xpos < SCREEN_WIDTH + HSYNC_PULSE_START);
            else
                vsync = INVERT ^ (ypos >= SCREEN_HEIGHT + VSYNC_PULSE_START && ypos < SCREEN_HEIGHT + VSYNC_PULSE_START + VSYNC_PULSE_SIZE);
        end

    always @(posedge clk_pixel)
        if (!n_reset)
        begin
            xpos <= 0;
            ypos <= 0;
        end
    else
        begin
            xpos <= xpos == FRAME_WIDTH-1'b1 ? 0 : xpos + 1'b1;
            ypos <= xpos == FRAME_WIDTH-1'b1 ? ypos == FRAME_HEIGHT-1'b1 ? 0 : ypos + 1'b1 : ypos;
        end

    // ---- position classification ----
    wire next_active = (ypos == FRAME_HEIGHT-1) || (ypos < SCREEN_HEIGHT-1);
    wire p_video  = xpos < SCREEN_WIDTH && ypos < SCREEN_HEIGHT;
    wire p_vpre   = next_active && xpos >= 790 && xpos < 798;
    wire p_vgb    = next_active && xpos >= 798;
    wire p_dpre   = xpos >= 648 && xpos < 656;
    wire p_dgb    = xpos == 656 || xpos == 657 || xpos == 722 || xpos == 723;
    wire p_data   = xpos >= 658 && xpos < 722;
    wire p_load   = xpos == 657 || xpos == 689;

    // ---- BCH ECC, G(x) = 1 + x^6 + x^7 + x^8, data sent LSB first ----
    function [7:0] ecc24(input [23:0] d);
        integer i;
        begin
            ecc24 = 0;
            for (i = 0; i < 24; i = i + 1)
                ecc24 = (ecc24 >> 1) ^ ((ecc24[0] ^ d[i]) ? 8'h83 : 8'h00);
        end
    endfunction

    function [7:0] ecc56(input [55:0] d);
        integer i;
        begin
            ecc56 = 0;
            for (i = 0; i < 56; i = i + 1)
                ecc56 = (ecc56 >> 1) ^ ((ecc56[0] ^ d[i]) ? 8'h83 : 8'h00);
        end
    endfunction

    // ---- audio sample buffer (up to 4 samples between islands) ----
    logic [15:0] buf_l [0:3];
    logic [15:0] buf_r [0:3];
    logic [2:0]  buf_cnt;
    logic [7:0]  iec_frame;    // IEC 60958 frame number 0..191
    wire         take = xpos == 657;

    always @(posedge clk_pixel)
        if (!n_reset)
        begin
            buf_cnt <= 0;
            iec_frame <= 0;
        end
    else
        begin
            if (take)
                iec_frame <= (iec_frame + buf_cnt >= 192) ? iec_frame + buf_cnt - 8'd192 : iec_frame + buf_cnt;
            if (audio_valid && (take || buf_cnt != 3'd4))
                begin
                    buf_l[take ? 2'd0 : buf_cnt[1:0]] <= audio_l;
                    buf_r[take ? 2'd0 : buf_cnt[1:0]] <= audio_r;
                end
            if (take)
                buf_cnt <= audio_valid ? 3'd1 : 3'd0;
            else if (audio_valid && buf_cnt != 3'd4)
                buf_cnt <= buf_cnt + 1'b1;
        end

    // ---- packet contents ----
    logic [23:0] hdr;
    logic [55:0] sub [0:3];
    logic [3:0]  present, bflag;
    integer      k;
    logic [8:0]  idx;
    logic        cs;

    always @(*)
        begin
            if (xpos == 657)
                begin
                    // Audio sample packet (HB0=0x02), or null packet if no samples
                    for (k = 0; k < 4; k = k + 1)
                        begin
                            idx = iec_frame + k;
                            if (idx >= 192)
                                idx = idx - 9'd192;
                            present[k] = k < buf_cnt;
                            bflag[k] = present[k] && idx == 0;
                            cs = idx == 25;             // channel status: fs = 48 kHz
                            sub[k] = present[k] ?
                                {^buf_r[k] ^ cs, cs, 2'b00, ^buf_l[k] ^ cs, cs, 2'b00,
                                    buf_r[k], 8'h00, buf_l[k], 8'h00} : 56'd0;
                        end
                    hdr = buf_cnt != 0 ? {bflag, 4'b0000, 4'b0000, present, 8'h02} : 24'd0;
                end
            else if (ypos == 0)
                begin
                    // AVI InfoFrame: RGB, 4:3, VIC 1 (640x480p60)
                    hdr = {8'h0d, 8'h02, 8'h82};
                    sub[0] = {8'h00, 8'h00, 8'h01, 8'h00, 8'h18, 8'h00, 8'h56};
                    sub[1] = 56'd0;
                    sub[2] = 56'd0;
                    sub[3] = 56'd0;
                end
            else if (ypos == 1)
                begin
                    // Audio InfoFrame: 2 channels, rest refer to stream header
                    hdr = {8'h0a, 8'h01, 8'h84};
                    sub[0] = {8'h00, 8'h00, 8'h00, 8'h00, 8'h00, 8'h01, 8'h70};
                    sub[1] = 56'd0;
                    sub[2] = 56'd0;
                    sub[3] = 56'd0;
                end
            else if (ypos == 2)
                begin
                    // SPD InfoFrame: vendor, product, source type
                    hdr = {8'h19, 8'h01, 8'h83};
                    sub[0] = SPD_PB[55:0];
                    sub[1] = SPD_PB[111:56];
                    sub[2] = SPD_PB[167:112];
                    sub[3] = SPD_PB[223:168];
                end
            else
                begin
                    // Audio clock regeneration packet
                    hdr = {8'h00, 8'h00, 8'h01};
                    for (k = 0; k < 4; k = k + 1)
                        sub[k] = {ACR_N[7:0], ACR_N[15:8], 4'h0, ACR_N[19:16],
                            ACR_CTS[7:0], ACR_CTS[15:8], 4'h0, ACR_CTS[19:16], 8'h00};
                end
        end

    // ---- packet shift registers ----
    logic [31:0] hdr_sr;
    logic [63:0] sub_sr [0:3];
    always @(posedge clk_pixel)
        if (p_load)
        begin
            hdr_sr <= {ecc24(hdr), hdr};
            for (k = 0; k < 4; k = k + 1)
                sub_sr[k] <= {ecc56(sub[k]), sub[k]};
        end
    else
        begin
            hdr_sr <= hdr_sr >> 1;
            for (k = 0; k < 4; k = k + 1)
                sub_sr[k] <= sub_sr[k] >> 2;
        end

    // ---- stage 1: registered per-pixel mode and data ----
    // Mode: 0 = control, 1 = video, 2 = video guard, 3 = island, 4 = island guard
    logic [2:0] mode1, mode;
    logic [1:0] ctl0_1, ctl1_1, ctl2_1, ctl0, ctl1, ctl2;
    logic [3:0] di0_1, di1_1, di2_1, di0, di1, di2;

    always @(posedge clk_pixel)
        if (!n_reset)
        begin
            mode1 <= 0;
            mode <= 0;
        end
    else
        begin
            mode1 <= p_video ? 3'd1 : p_vgb ? 3'd2 : p_data ? 3'd3 : p_dgb ? 3'd4 : 3'd0;
            ctl0_1 <= {vsync, hsync};
            ctl1_1 <= (p_vpre || p_dpre) ? 2'b01 : 2'b00;   // CTL0 = 1
            ctl2_1 <= p_dpre ? 2'b01 : 2'b00;               // CTL2 = 1
            di0_1 <= {xpos != 658, hdr_sr[0], vsync, hsync};
            di1_1 <= {sub_sr[3][0], sub_sr[2][0], sub_sr[1][0], sub_sr[0][0]};
            di2_1 <= {sub_sr[3][1], sub_sr[2][1], sub_sr[1][1], sub_sr[0][1]};

            mode <= mode1;
            ctl0 <= ctl0_1;
            ctl1 <= ctl1_1;
            ctl2 <= ctl2_1;
            di0 <= di0_1;
            di1 <= di1_1;
            di2 <= di2_1;
        end

    tmds_channel #(.CN(2)) tmds_channel_r(.clk_pixel(clk_pixel),
        .video_data(rgb_data[23:16]),
        .data_island_data(di2),
        .control_data(ctl2),
        .mode(mode),
        .tmds(tmds_r));

    tmds_channel #(.CN(1)) tmds_channel_g(.clk_pixel(clk_pixel),
        .video_data(rgb_data[15:8]),
        .data_island_data(di1),
        .control_data(ctl1),
        .mode(mode),
        .tmds(tmds_g));

    tmds_channel #(.CN(0)) tmds_channel_b(.clk_pixel(clk_pixel),
        .video_data(rgb_data[7:0]),
        .data_island_data(di0),
        .control_data(ctl0),
        .mode(mode),
        .tmds(tmds_b));

endmodule // hdmi_generator

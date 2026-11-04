module top(input wire        sys_clk,
    input logic       rst,
    output wire       tmds_clk_n,
    output wire       tmds_clk_p,
    output wire [2:0] tmds_d_n,
    output wire [2:0] tmds_d_p);

    // CLOCKS & RESET
    wire                      pll_lock;
    wire                      clk_pixel;
    wire                      clk_pixel_x5;
    wire                      rst_n = !rst;

    // DVI
    wire [2:0]                tmds;
    wire [9:0]                tmds_r, tmds_g, tmds_b;
    wire [9:0]                xpos, ypos;
    wire                      line_end, frame_end;

    // --- PATTERN GENERATOR ----------------------------------------------------------------
    logic [23:0]              rgb_data, rgb_data_next;
    logic [8:0]               frame_cnt, moving_bar;

    always @(posedge clk_pixel)
        begin
            if (!rst_n)
                begin
                    rgb_data_next <= 24'd0;
                    rgb_data <= 24'd0;
                    frame_cnt <= 0;
                    moving_bar <= 0;
                end
            else
                begin
                    rgb_data <= rgb_data_next;
                    if ((xpos == 0) || (ypos == 0) || (xpos == 639) || (ypos == 479))
                        rgb_data_next <= 24'hffffff;
                    else if (ypos < moving_bar)
                        rgb_data_next <= {ypos[7:0], 16'h0000 };
                    else
                        rgb_data_next <= 24'h00003f;

                    frame_cnt <= frame_end ? frame_cnt + 1'b1 : frame_cnt;
                    moving_bar <= frame_end ? moving_bar + 1'b1 : moving_bar;
                end
        end // always @ (posedge clk_pixel)
    // --- PATTERN GENERATOR ----------------------------------------------------------------

    // --- 4 kHz SINE, 48 kHz SAMPLE RATE ---------------------------------------------------
    // 25.2 MHz / 525 = 48 kHz, and 48 kHz / 12 = 4 kHz, so one period is 12 samples.
    logic [9:0]               sample_div;
    logic [3:0]               sine_idx;
    logic signed [15:0]       sine;
    logic                     audio_valid;

    always @(posedge clk_pixel)
        begin
            if (!rst_n)
                begin
                    sample_div <= 0;
                    sine_idx <= 0;
                    audio_valid <= 0;
                end
            else
                begin
                    audio_valid <= sample_div == 10'd524;
                    sample_div <= sample_div == 10'd524 ? 10'd0 : sample_div + 1'b1;
                    if (sample_div == 10'd524)
                        sine_idx <= sine_idx == 4'd11 ? 4'd0 : sine_idx + 1'b1;
                end
        end

    always @(posedge clk_pixel)
        case (sine_idx)
            4'd0: sine <= 16'sd0;
            4'd1: sine <= 16'sd8192;
            4'd2: sine <= 16'sd14189;
            4'd3: sine <= 16'sd16384;
            4'd4: sine <= 16'sd14189;
            4'd5: sine <= 16'sd8192;
            4'd6: sine <= 16'sd0;
            4'd7: sine <= -16'sd8192;
            4'd8: sine <= -16'sd14189;
            4'd9: sine <= -16'sd16384;
            4'd10: sine <= -16'sd14189;
            4'd11: sine <= -16'sd8192;
            default: sine <= 16'sd0;
        endcase
    // --- 4 kHz SINE ------------------------------------------------------------------------

    // pixel_clock_x5 is 126MHz
    // pixel_clock    is 25.2MHz
    PLL126 dvi_pll(.clkin_27mhz(sys_clk),
        .clkout_126mhz(clk_pixel_x5),
        .lock(pll_lock));

    CLKDIV #(.DIV_MODE("5")) clk_div (.CLKOUT(clk_pixel),
        .HCLKIN(clk_pixel_x5),
        .RESETN(pll_lock)
    );

    hdmi_generator #(.SPD_VENDOR("TetrIC"),
        .SPD_PRODUCT("TetrIC hdmitest"),
        .SPD_SOURCE(8'h08))
        hdmi_gen(.clk_pixel(clk_pixel),
            .n_reset(rst_n),
            .rgb_data(rgb_data),
            .audio_l(sine),
            .audio_r(sine),
            .audio_valid(audio_valid),
            .tmds_r(tmds_r),
            .tmds_g(tmds_g),
            .tmds_b(tmds_b),
            .xpos(xpos),
            .ypos(ypos),
            .line_end(line_end),
            .frame_end(frame_end));

    OSER10 gwSer0(.Q(tmds[2]),
        .D0(tmds_r[0]),
        .D1(tmds_r[1]),
        .D2(tmds_r[2]),
        .D3(tmds_r[3]),
        .D4(tmds_r[4]),
        .D5(tmds_r[5]),
        .D6(tmds_r[6]),
        .D7(tmds_r[7]),
        .D8(tmds_r[8]),
        .D9(tmds_r[9]),
        .PCLK(clk_pixel ),
        .FCLK(clk_pixel_x5 ),
        .RESET(rst ) );

    OSER10 gwSer1(.Q(tmds[1]),
        .D0(tmds_g[0]),
        .D1(tmds_g[1]),
        .D2(tmds_g[2]),
        .D3(tmds_g[3]),
        .D4(tmds_g[4]),
        .D5(tmds_g[5]),
        .D6(tmds_g[6]),
        .D7(tmds_g[7]),
        .D8(tmds_g[8]),
        .D9(tmds_g[9]),
        .PCLK(clk_pixel ),
        .FCLK(clk_pixel_x5 ),
        .RESET(rst ) );

    OSER10 gwSer2(.Q(tmds[0]),
        .D0(tmds_b[0]),
        .D1(tmds_b[1]),
        .D2(tmds_b[2]),
        .D3(tmds_b[3]),
        .D4(tmds_b[4]),
        .D5(tmds_b[5]),
        .D6(tmds_b[6]),
        .D7(tmds_b[7]),
        .D8(tmds_b[8]),
        .D9(tmds_b[9]),
        .PCLK(clk_pixel),
        .FCLK(clk_pixel_x5),
        .RESET(rst));

    TLVDS_OBUF tmds_bufds [3:0] (.I({clk_pixel, tmds}),
        .O({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n}));

endmodule

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
   wire [10:0]               xpos, ypos;
   wire                      line_end, frame_end;

   // --- PATTERN GENERATOR ----------------------------------------------------------------
   logic [23:0]              rgb_data;
   logic [8:0]               frame_cnt, moving_bar;

   always @(posedge clk_pixel)
     begin
        if (!rst_n)
          begin
             rgb_data <= 24'd0;
             frame_cnt <= 0;
             moving_bar <= 0;
          end
        else
          begin
             if (ypos < moving_bar)
               rgb_data <= {ypos[7:0], 16'h0000 };
             else
               rgb_data <= 24'h00003f;

             frame_cnt <= frame_end ? frame_cnt + 1'b1 : frame_cnt;
             moving_bar <= frame_end ? moving_bar + 1'b1 : moving_bar;
          end
     end // always @ (posedge clk_pixel)
   // --- PATTERN GENERATOR ----------------------------------------------------------------

   // pixel_clock_x5 is 126MHz
   // pixel_clock    is 25.2MHz
   PLL126 dvi_pll(.clkin_27mhz(sys_clk),
                  .clkout_126mhz(clk_pixel_x5),
                  .lock(pll_lock));

   CLKDIV #(.DIV_MODE("5")) clk_div (.CLKOUT(clk_pixel),
                                     .HCLKIN(clk_pixel_x5),
                                     .RESETN(pll_lock)
                                     );

   dvi_generator dvi_gen(.clk_pixel(clk_pixel),
                         .n_reset(rst_n),
                         .rgb_data(rgb_data),
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

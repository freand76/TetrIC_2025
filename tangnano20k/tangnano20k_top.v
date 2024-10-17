module tangnano20k_top(
                       // Clock and Reset
                       input             sys_clk,
                       input             rst,

                       // UART Tx
                       output            uart_tx,

                       // LED (Active LOW)
                       output [5:0]      led,

                       // spi flash interface
                       output            mspi_cs,
                       output            mspi_clk,
                       output            mspi_di,
                       input             mspi_do,

                       // DVI
                       output wire       tmds_clk_n,
                       output wire       tmds_clk_p,
                       output wire [2:0] tmds_d_n,
                       output wire [2:0] tmds_d_p);

   // TOP WIRES
   wire                                  rst_n = !rst;
   wire                                  clk_pixel, clk_pixel_x5;
   wire                                  pll_lock;
   wire [2:0]                            tmds;
   wire [9:0]                            tmds_r, tmds_g, tmds_b;

   dvi_pll dvi_pll(.clkin_27mhz(sys_clk),
                   .clkout_126mhz(clk_pixel_x5),
                   .lock(pll_lock));

   CLKDIV #(.DIV_MODE("5")) clk_div (.CLKOUT(clk_pixel),
                                     .HCLKIN(clk_pixel_x5),
                                     .RESETN(pll_lock));

   top top(.clk_cpu(clk_pixel),
           .clk_pixel(clk_pixel),
           .rst_n(rst_n),
           .uart_tx(uart_tx),
           .led(led),
           .mspi_cs(mspi_cs),
           .mspi_clk(mspi_clk),
           .mspi_di(mspi_di),
           .mspi_do(mspi_do),
           .tmds_r(tmds_r),
           .tmds_g(tmds_g),
           .tmds_b(tmds_b));

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
                 .PCLK(clk_pixel),
                 .FCLK(clk_pixel_x5),
                 .RESET(rst));

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
                 .PCLK(clk_pixel),
                 .FCLK(clk_pixel_x5),
                 .RESET(rst));

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

endmodule // tangnano20k_top

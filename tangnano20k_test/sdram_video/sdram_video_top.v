`timescale 1ns / 1ps

// SDRAM video test for the Tang Nano 20K
//
// 1. After reset, COPY_WORDS 32-bit words (default 1 MByte) are copied from the
//    SPI flash (FLASH_START) to SDRAM word address 0.
// 2. Then a 320x240 RGB565 frame buffer at SDRAM address 0 (packed, 640 bytes
//    per line, two pixels per 32-bit word, left pixel in bits 31:16) is shown
//    over HDMI at 640x480. Each source line is fetched from SDRAM with a burst
//    into one of two line memories (even/odd lines) and is shown twice.
//
// Clocking:
//  * clk_pixel (25.2 MHz) : DVI timing, flash reader, line memory read side
//  * clk_sdram            : SDRAM controller, line memory write side
//    Default 50.4 MHz (2 x pixel clock) from a second PLL.
//    `-DSDRAM_CLK_PIXEL` : run the SDRAM on the 25.2 MHz pixel clock.
//    In both cases the SDRAM CLK pin is driven by the controller clock.
//  All signals crossing between the two domains go through the CDC logic in
//  sdram_video_core, so any clock ratio works.

module top(
    // Clock and Reset
    input             sys_clk,
    input             rst,

    // UART Tx
    output            uart_tx,

    // spi flash interface
    output            mspi_cs,
    output            mspi_clk,
    output            mspi_di,
    input             mspi_do,

    // SDRAM
    output            O_sdram_clk,
    output            O_sdram_cke,
    output            O_sdram_cs_n, // chip select
    output            O_sdram_cas_n, // columns address select
    output            O_sdram_ras_n, // row address select
    output            O_sdram_wen_n, // write enable
    inout [31:0]      IO_sdram_dq, // bidirectional data bus
    output [10:0]     O_sdram_addr, // multiplexed address bus
    output [1:0]      O_sdram_ba, // two banks
    output [3:0]      O_sdram_dqm,

    //DVI
    output wire       tmds_clk_n,
    output wire       tmds_clk_p,
    output wire [2:0] tmds_d_n,
    output wire [2:0] tmds_d_p
);

    parameter FLASH_START = 24'h600000;
    parameter COPY_WORDS  = 24'd262144;   // 1 MByte

    assign uart_tx = 1'b1;

    // ---------------- clocks ----------------
    wire clk_pixel_x5;   // 126 MHz
    wire clk_pixel;      // 25.2 MHz
    wire pll_lock;
    PLL126 dvi_pll(.clkin_27mhz(sys_clk),
        .clkout_126mhz(clk_pixel_x5),
        .lock(pll_lock));

    CLKDIV #(.DIV_MODE("5")) clk_div (.CLKOUT(clk_pixel),
        .HCLKIN(clk_pixel_x5),
        .RESETN(pll_lock));

    `ifdef SDRAM_CLK_PIXEL
    localparam SDRAM_FREQ_KHZ = 25_200;
    wire clk_sdram = clk_pixel;
    wire clk_sdram_pin = clk_pixel;
    wire sdram_lock = 1'b1;
    `else
    // 50.4 MHz (2 x pixel clock), SDRAM CLK pin = controller clock (no phase shift)
    localparam SDRAM_FREQ_KHZ = 50_400;
    wire clk_sdram;
    wire clk_sdram_pin = clk_sdram;
    wire sdram_lock;
    PLL_SDRAM50 sdram_pll(.clkin_27mhz(sys_clk),
        .clkout(clk_sdram),
        .lock(sdram_lock));
    `endif

    wire rst_n = !rst && pll_lock && sdram_lock;

    // ---------------- core ----------------
    wire [9:0] tmds_r, tmds_g, tmds_b;

    sdram_video_core #(.FLASH_START(FLASH_START),
        .COPY_WORDS(COPY_WORDS),
        .SDRAM_FREQ_KHZ(SDRAM_FREQ_KHZ))
        core(.clk_pixel(clk_pixel),
            .clk_sdram(clk_sdram),
            .rst_n(rst_n),

            .mspi_cs(mspi_cs),
            .mspi_clk(mspi_clk),
            .mspi_di(mspi_di),
            .mspi_do(mspi_do),

            .sdram_dq(IO_sdram_dq),
            .sdram_addr(O_sdram_addr),
            .sdram_ba(O_sdram_ba),
            .sdram_cs_n(O_sdram_cs_n),
            .sdram_wen_n(O_sdram_wen_n),
            .sdram_ras_n(O_sdram_ras_n),
            .sdram_cas_n(O_sdram_cas_n),
            .sdram_cke(O_sdram_cke),
            .sdram_dqm(O_sdram_dqm),

            .tmds_r(tmds_r),
            .tmds_g(tmds_g),
            .tmds_b(tmds_b),
            .xpos(),
            .ypos(),
            .rgb_data(),
            .copy_done());

    assign O_sdram_clk = clk_sdram_pin;

    // ---------------- HDMI output ----------------
    wire [2:0] tmds;

    OSER10 gwSer0(.Q(tmds[2]),
        .D0(tmds_r[0]), .D1(tmds_r[1]), .D2(tmds_r[2]), .D3(tmds_r[3]), .D4(tmds_r[4]),
        .D5(tmds_r[5]), .D6(tmds_r[6]), .D7(tmds_r[7]), .D8(tmds_r[8]), .D9(tmds_r[9]),
        .PCLK(clk_pixel), .FCLK(clk_pixel_x5), .RESET(rst));

    OSER10 gwSer1(.Q(tmds[1]),
        .D0(tmds_g[0]), .D1(tmds_g[1]), .D2(tmds_g[2]), .D3(tmds_g[3]), .D4(tmds_g[4]),
        .D5(tmds_g[5]), .D6(tmds_g[6]), .D7(tmds_g[7]), .D8(tmds_g[8]), .D9(tmds_g[9]),
        .PCLK(clk_pixel), .FCLK(clk_pixel_x5), .RESET(rst));

    OSER10 gwSer2(.Q(tmds[0]),
        .D0(tmds_b[0]), .D1(tmds_b[1]), .D2(tmds_b[2]), .D3(tmds_b[3]), .D4(tmds_b[4]),
        .D5(tmds_b[5]), .D6(tmds_b[6]), .D7(tmds_b[7]), .D8(tmds_b[8]), .D9(tmds_b[9]),
        .PCLK(clk_pixel), .FCLK(clk_pixel_x5), .RESET(rst));

    TLVDS_OBUF tmds_bufds [3:0] (.I({clk_pixel, tmds}),
        .O({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n}));

endmodule // top

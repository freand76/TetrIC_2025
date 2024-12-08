`timescale 1ns / 1ns

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

   parameter             FLASH_START = 24'h600000;

   wire rst_n = !rst;

   wire [22:0] address;
   wire [31:0] din;
   wire [31:0] dout;
   wire        dout_valid;
   wire        sel;
   wire        write;
   wire        read_ack;
   wire        write_ack;

   reg         read;
   reg [22:0]  ram_read_address;

   wire [23:0] flash_write_address;
   wire [31:0] flash_data_out;
   wire        flash_strobe;
   wire        flash_done;

   wire                   line_end, frame_end;

   assign sel = 1;

   wire busy;

   wire [2:0]                tmds;
   wire [9:0] tmds_r, tmds_g, tmds_b;

   wire [9:0] xpos, ypos;
   wire [8:0]             pixel_x, pixel_y;
   // Use half the resultion
   assign pixel_x = xpos[9:1];
   assign pixel_y = ypos[9:1];
   wire [15:0]            pixel_data_even, pixel_data_odd;
   reg [15:0]             pixel_data;
   reg [23:0]             rgb_data;


   wire clk_pixel_x5;   // pixel_clock_x5 is 126MHz
   wire clk_pixel;   // pixel_clock    is 25.2MHz
   wire pll_lock;
   PLL126 dvi_pll(.clkin_27mhz(sys_clk),
                  .clkout_126mhz(clk_pixel_x5),
                  .lock(pll_lock));

   CLKDIV #(.DIV_MODE("5")) clk_div (.CLKOUT(clk_pixel),
                                     .HCLKIN(clk_pixel_x5),
                                     .RESETN(pll_lock)
                                     );

   sdram_wrap sdram_wrap
     (
      .SDRAM_DQ(IO_sdram_dq),
      .SDRAM_A(O_sdram_addr),
      .SDRAM_BA(O_sdram_ba),
      .SDRAM_nCS(O_sdram_cs_n),
      .SDRAM_nWE(O_sdram_wen_n),
      .SDRAM_nRAS(O_sdram_ras_n),
      .SDRAM_nCAS(O_sdram_cas_n),
      .SDRAM_CLK(O_sdram_clk),
      .SDRAM_CKE(O_sdram_cke),
      .SDRAM_DQM(O_sdram_dqm),

      .clk(clk_pixel),
      .clk_sdram(clk_pixel),
      .resetn(rst_n),
      .sel(sel),
      .read(read),
      .read_ack(read_ack),
      .write(write),
      .write_ack(write_ack),
      .addr(address),
      .din(din),
      .dout_valid(dout_valid),
      .dout(dout),
      .busy(busy)
      );

   assign din = flash_data_out;
   assign address = flash_done ? ram_read_address : { flash_write_address[20:0], 2'b00 };
   assign write = flash_strobe;

   flash_reader flash_reader(.clk(clk_pixel),
                             .n_reset(rst_n),
                             .start(!busy),
                             .address(FLASH_START),
                             .word_count(512),
                             .mem_address(flash_write_address),
                             .strobe(flash_strobe),
                             .done(flash_done),
                             .data_out(flash_data_out),
                             .spi_cs(mspi_cs),
                             .spi_clk(mspi_clk),
                             .spi_mosi(mspi_di),
                             .spi_miso(mspi_do));

   reg  [7:0] state;
   reg [7:0]  line_addr;

   reg [31:0] line_data;
   reg [8:0]  line_id;
   reg        line_strobe;

   wire         line_strobe_even;
   wire         line_strobe_odd;

   assign line_strobe_even = line_strobe & !line_id[0];
   assign line_strobe_odd = line_strobe & line_id[0];

   always@(posedge clk_pixel, negedge rst_n)
     begin
        if (!rst_n)
          begin
             state <= 0;
             line_addr <= 0;
             line_data <= 0;
             line_id <= 0;
             line_strobe <= 0;
             ram_read_address <= 0;
          end
        else
          begin
             case(state)
               0 : // FRAME START
                 begin
                    if (frame_end)
                      begin
                         state <= 1;
                         line_id <= 0;
                         line_data <= 0;
                      end
                 end
               1 : // LINE START
                 begin
                    line_addr <= 0;
                    state <= 2;
                    line_data <= line_data + 32'h00080008;
                 end
               2 : // COPY SDRAM DATA TO LINE MEM
                 begin
                    line_addr <= 0;
                    line_strobe <= 1;
                    state <= 3;
                 end
               3 : // COPY SDRAM DATA TO LINE MEM
                 begin
                    line_addr <= line_addr + 1;
                    if (line_addr == 159)
                      begin
                         line_strobe <= 0;
                         state <= 4;
                      end
                 end
               4:
                 begin
                    if (pixel_y == line_id)
                      begin
                         line_id <= line_id + 1;
                         state <= 5;
                      end
                 end
               5 :
                 begin
                    if (line_id == 240)
                      begin
                         state <= 0;
                      end
                    else
                      begin
                         state <= 1;
                      end
                 end
             endcase // case (state)
          end // else: !if(!rst_n)
     end

   always@(posedge clk_pixel)
     begin
        if (!rst_n)
          begin
             pixel_data <= 0;
             rgb_data <= 0;
          end
        else
          begin
             // Pixel Data (16-bit)
             pixel_data <= !pixel_y[0] ? pixel_data_even : pixel_data_odd;
             // Expand 16 bit pixel 5-6-5 to 24 bit 8-8-8
             // RGB delivered 1 clk after pixel data
             rgb_data <= { pixel_data[15:11], {3{pixel_data[11]}},
                           pixel_data[10:5], {2{pixel_data[5]}},
                           pixel_data[4:0], {3{pixel_data[0]}}};
          end
     end

   line_mem line_mem_even(
                      .pixel_addr(pixel_x),
                      .pixel_data(pixel_data_even),
                      .clk_wr(clk_pixel),
                      .wr_en(line_strobe_even),
                      .wr_addr(line_addr),
                      .wr_data(line_data));

   line_mem line_mem_odd(
                      .pixel_addr(pixel_x),
                      .pixel_data(pixel_data_odd),
                      .clk_wr(clk_pixel),
                      .wr_en(line_strobe_odd),
                      .wr_addr(line_addr),
                      .wr_data(line_data));

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

endmodule // top


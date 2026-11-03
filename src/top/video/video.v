// Video: 320x240 RGB565 frame buffer in SDRAM, shown at 640x480 over DVI.
//
// Frame buffer: packed, 160 words (640 bytes) per line, left pixel in bits
// 31:16. Line n starts at word address video_address + n * 160.
//
// Registers (processor address 0xExxxxx, written from clk_cpu):
//   offset 5 : frame buffer start address (SDRAM word address, 20 bit)
//
// HDMI lines 2k and 2k+1 show source line k from line memory k[0]. At the end
// of the visible part of HDMI line 2k, source line k+1 is requested into the
// other line memory. Line 0 is requested on the last line of the frame.
//
// Clock domains: register in clk_cpu, timing / pixel output in clk_pixel,
// DMA and line memory writes in clk_ram.

module video(
             input             clk_pixel,
             input             clk_cpu,
             input             clk_ram,
             input             rst_n,

             input             enable,        // clk_ram: memory ready (flash copy done)

             input [23:0]      addr_in,
             input [31:0]      data_in,
             input             sel,
             input             wr,

             output [9:0]      tmds_r,
             output [9:0]      tmds_g,
             output [9:0]      tmds_b,

             // VIDEO INFO (clk_pixel)
             output reg [11:0] frame_counter,

             // MEMORY CONTROLLER (clk_ram)
             output            req,
             output [19:0]     req_address,
             input             req_ack,
             input [31:0]      rsp_data,
             input             rsp_data_strobe
             );

   wire rst_cpu_n, rst_pixel_n, rst_ram_n;
   reset_sync rs_cpu  (.clk(clk_cpu),   .rst_n_in(rst_n), .rst_n_out(rst_cpu_n));
   reset_sync rs_pixel(.clk(clk_pixel), .rst_n_in(rst_n), .rst_n_out(rst_pixel_n));
   reset_sync rs_ram  (.clk(clk_ram),   .rst_n_in(rst_n), .rst_n_out(rst_ram_n));

   // ============================ clk_cpu ==============================
   // Memory Mapped Registers
   reg [19:0]             video_address;
   reg                    video_address_tog;

   always @ (posedge clk_cpu or negedge rst_cpu_n)
     begin
        if (!rst_cpu_n)
          begin
             video_address <= 20'h00200;
             video_address_tog <= 0;
          end
        else
          begin
             if (sel & wr)
               begin
                  case(addr_in[3:0])
                    4'b0101 :
                      begin
                         video_address <= data_in[19:0];
                         video_address_tog <= ~video_address_tog;
                      end
                  endcase // case (addr_in[3:0])
               end
          end
     end

   // ============================ clk_pixel ============================
   wire [9:0]             xpos, ypos;
   wire [8:0]             pixel_x, pixel_y;
   wire                   line_end, frame_end;
   wire [15:0]            pixel_data_even, pixel_data_odd;
   reg [15:0]             pixel_data;
   reg [23:0]             rgb_data;

   // Use half the resolution
   assign pixel_x = xpos[9:1];
   assign pixel_y = ypos[9:1];

   // frame buffer address, copied from clk_cpu after a register write
   wire                   video_address_ev;
   reg [19:0]             fb_address;
   sync_toggle st_addr(.clk(clk_pixel), .rst_n(rst_pixel_n), .toggle(video_address_tog), .pulse(video_address_ev));

   // line requests
   reg                    line_req_tog;
   reg [19:0]             line_req_address;
   reg                    line_req_odd;
   wire                   line_req_now = (xpos == 10'd640) &&
                                         ((ypos == 10'd524) || ((ypos < 10'd478) && !ypos[0]));
   wire [7:0]             next_line = (ypos == 10'd524) ? 8'd0 : ypos[8:1] + 8'd1;

   always @(posedge clk_pixel or negedge rst_pixel_n)
     begin
        if (!rst_pixel_n)
          begin
             fb_address <= 20'h00200;
             line_req_tog <= 0;
             line_req_address <= 0;
             line_req_odd <= 0;
             pixel_data <= 0;
             rgb_data <= 0;
             frame_counter <= 0;
          end
        else
          begin
             if (video_address_ev)
               fb_address <= video_address;   // stable, written ~3 clocks ago

             if (line_req_now)
               begin
                  // line * 160 = line * 128 + line * 32
                  line_req_address <= fb_address + {5'd0, next_line, 7'd0} + {7'd0, next_line, 5'd0};
                  line_req_odd <= next_line[0];
                  line_req_tog <= ~line_req_tog;
               end

             // Pixel Data (16-bit)
             pixel_data <= !pixel_y[0] ? pixel_data_even : pixel_data_odd;
             // Expand 16 bit pixel 5-6-5 to 24 bit 8-8-8
             // RGB delivered 1 clk after pixel data
             rgb_data <= { pixel_data[15:11], pixel_data[15:13],
                           pixel_data[10:5],  pixel_data[10:9],
                           pixel_data[4:0],   pixel_data[4:2] };

             if (frame_end)
               frame_counter <= frame_counter + 1;
          end
     end

   dvi_generator dvi_gen(.clk_pixel(clk_pixel),
                         .n_reset(rst_pixel_n),
                         .rgb_data(rgb_data),
                         .tmds_r(tmds_r),
                         .tmds_g(tmds_g),
                         .tmds_b(tmds_b),
                         .xpos(xpos),
                         .ypos(ypos),
                         .line_end(line_end),
                         .frame_end(frame_end));

   // ============================ clk_ram ==============================
   wire [7:0]             line_addr;
   wire [31:0]            line_data;
   wire                   line_strobe_even;
   wire                   line_strobe_odd;
   wire                   dma_late;

   video_dma video_dma(
                       .clk_ram(clk_ram),
                       .rst_n(rst_ram_n),
                       .enable(enable),
                       .line_req_tog(line_req_tog),
                       .line_req_address(line_req_address),
                       .line_req_odd(line_req_odd),
                       .req(req),
                       .req_address(req_address),
                       .req_ack(req_ack),
                       .rsp_data(rsp_data),
                       .rsp_data_strobe(rsp_data_strobe),
                       .line_addr(line_addr),
                       .line_data(line_data),
                       .line_strobe_odd(line_strobe_odd),
                       .line_strobe_even(line_strobe_even),
                       .late(dma_late)
                       );

   // line memories: written in clk_ram, read asynchronously in clk_pixel
   line_mem line_mem_even(
                          .pixel_addr(pixel_x),
                          .pixel_data(pixel_data_even),
                          .clk_wr(clk_ram),
                          .wr_en(line_strobe_even),
                          .wr_addr(line_addr),
                          .wr_data(line_data));

   line_mem line_mem_odd(
                         .pixel_addr(pixel_x),
                         .pixel_data(pixel_data_odd),
                         .clk_wr(clk_ram),
                         .wr_en(line_strobe_odd),
                         .wr_addr(line_addr),
                         .wr_data(line_data));

endmodule // video

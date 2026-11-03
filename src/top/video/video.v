// Video: RGB565 frame buffer in SDRAM, shown on a fixed 640x480 DVI output.
// Every image pixel is 2x2 DVI pixels, so the screen is 320x240 "pixels".
//
// Register set and control follow the old TetrIC gfxbox (old_vhdl/gfxbox.vhd).
// Registers, processor address 0xExxxxx, offset = addr[3:0], write only:
//
//   0 TOPPOS      first screen line of the image (0..239)            default 0
//   1 LEFTPOS     first screen pixel of the image (0..319)           default 0
//   2 PIXPERLINE  image pixels per line (2..320, even)               default 320
//   3 LINEPERIMG  image lines (1..240)                               default 240
//   4 PIXREAD     DVI pixels (clocks) per image pixel, horizontal    default 2
//                 stretch (1..1023). 2 = 320 pixels on the 640 wide screen,
//                 e.g. 5 shows 128 pixels over the full width.
//   5 GFXADDR     frame buffer start, SDRAM word address             default 0x200
//   6 DELTAADDR   extra words skipped after each line                default 0
//                 (line stride = PIXPERLINE/2 + DELTAADDR words)
//   7..10         (gfxbox: ROWLENGTH, HSYNCLEN, ESYNCLEN, VSYNCLEN)
//                 ignored, the DVI timing is fixed (800x525 @ 25.2 MHz)
//
// Like gfxbox, the registers take effect at the start of the next frame
// (GFXADDR can be used for tear free page flipping). Everything outside the
// image (TOPPOS/LEFTPOS/PIXPERLINE x PIXREAD/LINEPERIMG window) is black.
// Vertically every image line is always 2 DVI lines.
// Pixels: two per 32-bit word, left pixel in bits 31:16.
//
// Status (gfxbox copreg), read with MFC1:
//   [31:20] frame counter   (+1 per frame, 60 Hz)
//   [19:9]  horizontal position (DVI pixel 0..799, visible 0..639)
//   [8:0]   screen line (0..262, visible 0..239, vertical blank >= 240)
//
// Clock domains: registers / status in clk_cpu, timing and pixel output in
// clk_pixel, DMA and line memory writes in clk_ram.

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

             // VIDEO INFO
             output reg [11:0] frame_counter,  // clk_pixel
             output reg [31:0] status,         // clk_cpu, for MFC1

             // MEMORY CONTROLLER (clk_ram)
             output            req,
             output [19:0]     req_address,
             output [8:0]      req_len,
             input             req_ack,
             input [31:0]      rsp_data,
             input             rsp_data_strobe
             );

   wire rst_cpu_n, rst_pixel_n, rst_ram_n;
   reset_sync rs_cpu  (.clk(clk_cpu),   .rst_n_in(rst_n), .rst_n_out(rst_cpu_n));
   reset_sync rs_pixel(.clk(clk_pixel), .rst_n_in(rst_n), .rst_n_out(rst_pixel_n));
   reset_sync rs_ram  (.clk(clk_ram),   .rst_n_in(rst_n), .rst_n_out(rst_ram_n));

   localparam [8:0]  DEF_TOPPOS     = 9'd0;
   localparam [8:0]  DEF_LEFTPOS    = 9'd0;
   localparam [8:0]  DEF_PIXPERLINE = 9'd320;
   localparam [8:0]  DEF_LINEPERIMG = 9'd240;
   localparam [9:0]  DEF_PIXREAD    = 10'd2;
   localparam [19:0] DEF_GFXADDR    = 20'h00200;
   localparam [19:0] DEF_DELTAADDR  = 20'd0;

   // ============================ clk_cpu ==============================
   reg [8:0]  r_toppos, r_leftpos, r_pixperline, r_lineperimg;
   reg [9:0]  r_pixread;
   reg [19:0] r_gfxaddr, r_deltaaddr;
   reg        reg_tog;

   always @ (posedge clk_cpu or negedge rst_cpu_n)
     if (!rst_cpu_n)
       begin
          r_toppos     <= DEF_TOPPOS;
          r_leftpos    <= DEF_LEFTPOS;
          r_pixperline <= DEF_PIXPERLINE;
          r_lineperimg <= DEF_LINEPERIMG;
          r_pixread    <= DEF_PIXREAD;
          r_gfxaddr    <= DEF_GFXADDR;
          r_deltaaddr  <= DEF_DELTAADDR;
          reg_tog      <= 0;
       end
     else if (sel & wr)
       begin
          case (addr_in[3:0])
            4'd0 : r_toppos     <= data_in[8:0];
            4'd1 : r_leftpos    <= data_in[8:0];
            4'd2 : r_pixperline <= data_in[8:0];
            4'd3 : r_lineperimg <= data_in[8:0];
            4'd4 : r_pixread    <= data_in[9:0];
            4'd5 : r_gfxaddr    <= data_in[19:0];
            4'd6 : r_deltaaddr  <= data_in[19:0];
            default : ;   // 7..10 sync timing: not used with DVI
          endcase
          reg_tog <= ~reg_tog;
       end

   // ============================ clk_pixel ============================
   wire [9:0]  xpos, ypos;
   wire [8:0]  screen_x = xpos[9:1];
   wire [8:0]  screen_y = ypos[9:1];
   wire        line_end, frame_end;

   // registers copied from clk_cpu after a write (values are stable then) ...
   wire        reg_ev;
   reg [8:0]   p_toppos, p_leftpos, p_pixperline, p_lineperimg;
   reg [9:0]   p_pixread, a_pixread;
   reg [19:0]  p_gfxaddr, p_deltaaddr;
   // ... and used from the start of the next frame
   reg [8:0]   a_toppos, a_leftpos, a_pixperline, a_lineperimg;
   reg [19:0]  a_deltaaddr;
   reg [19:0]  line_ptr;          // SDRAM address of the next image line

   sync_toggle st_reg(.clk(clk_pixel), .rst_n(rst_pixel_n), .toggle(reg_tog), .pulse(reg_ev));

   wire        frame_start = (ypos == 10'd524) && (xpos == 10'd0);

   // line requests: at the end of the visible part of DVI line 2s, fetch the
   // image line shown on screen line s+1 into the other line memory. Screen
   // line 0 is requested on the last DVI line of the frame (ypos 524).
   wire        req_now   = (xpos == 10'd640) &&
                           ((ypos == 10'd524) || ((ypos < 10'd478) && !ypos[0]));
   wire [8:0]  next_line = (ypos == 10'd524) ? 9'd0 : screen_y + 9'd1;
   wire [9:0]  img_line  = {1'b0, next_line} - {1'b0, a_toppos};   // image line on next_line
   wire        next_vis  = (next_line >= a_toppos) && (img_line < {1'b0, a_lineperimg}) &&
                           (a_pixperline != 0);
   wire [8:0]  line_words = (a_pixperline + 9'd1) >> 1;

   reg         line_req_tog;
   reg [19:0]  line_req_address;
   reg [8:0]   line_req_len;
   reg         line_req_odd;
   reg [1:0]   line_vis;           // per line memory: screen line shows image data

   // status sampling for clk_cpu: a new sample is taken as soon as clk_cpu
   // has acknowledged the previous one (so it is a few clocks old)
   reg         st_tog;
   reg [31:0]  st_hold;
   wire        st_ack_level;
   reg         st_ack_tog;         // clk_cpu
   sync_bit sb_st_ack(.clk(clk_pixel), .rst_n(rst_pixel_n), .d(st_ack_tog), .q(st_ack_level));

   always @(posedge clk_pixel or negedge rst_pixel_n)
     if (!rst_pixel_n)
       begin
          p_toppos     <= DEF_TOPPOS;
          p_leftpos    <= DEF_LEFTPOS;
          p_pixperline <= DEF_PIXPERLINE;
          p_lineperimg <= DEF_LINEPERIMG;
          p_pixread    <= DEF_PIXREAD;
          a_pixread    <= DEF_PIXREAD;
          p_gfxaddr    <= DEF_GFXADDR;
          p_deltaaddr  <= DEF_DELTAADDR;
          a_toppos     <= DEF_TOPPOS;
          a_leftpos    <= DEF_LEFTPOS;
          a_pixperline <= DEF_PIXPERLINE;
          a_lineperimg <= DEF_LINEPERIMG;
          a_deltaaddr  <= DEF_DELTAADDR;
          line_ptr     <= DEF_GFXADDR;
          line_req_tog <= 0;
          line_req_address <= 0;
          line_req_len <= 0;
          line_req_odd <= 0;
          line_vis     <= 2'b00;
          frame_counter <= 0;
          st_tog       <= 0;
          st_hold      <= 0;
       end
     else
       begin
          if (reg_ev)
            begin
               p_toppos     <= r_toppos;
               p_leftpos    <= r_leftpos;
               p_pixperline <= r_pixperline;
               p_lineperimg <= r_lineperimg;
               p_pixread    <= r_pixread;
               p_gfxaddr    <= r_gfxaddr;
               p_deltaaddr  <= r_deltaaddr;
            end

          if (frame_start)
            begin
               a_toppos     <= p_toppos;
               a_leftpos    <= p_leftpos;
               a_pixperline <= p_pixperline;
               a_lineperimg <= p_lineperimg;
               a_pixread    <= (p_pixread == 0) ? 10'd1 : p_pixread;
               a_deltaaddr  <= p_deltaaddr;
               line_ptr     <= p_gfxaddr;
            end

          if (req_now)
            begin
               line_vis[next_line[0]] <= next_vis;
               if (next_vis)
                 begin
                    line_req_address <= line_ptr;
                    line_req_len <= line_words;
                    line_req_odd <= next_line[0];
                    line_req_tog <= ~line_req_tog;
                    line_ptr <= line_ptr + {11'd0, line_words} + a_deltaaddr;
                 end
            end

          if (frame_end)
            frame_counter <= frame_counter + 1;

          if (st_tog == st_ack_level)
            begin
               st_hold <= {frame_counter, {1'b0, xpos}, screen_y};
               st_tog <= ~st_tog;
            end
       end

   // ---- pixel output ----
   // image pixel counter: starts at DVI x = 2 * LEFTPOS, advances every
   // PIXREAD clocks (registers hold the values for the current xpos)
   wire [9:0]  next_x = (xpos == 10'd799) ? 10'd0 : xpos + 10'd1;
   reg         hp_active;
   reg [9:0]   hp_sub;
   reg [9:0]   img_x;

   always @(posedge clk_pixel or negedge rst_pixel_n)
     if (!rst_pixel_n)
       begin
          hp_active <= 0;
          hp_sub <= 0;
          img_x <= 0;
       end
     else if (next_x == {a_leftpos, 1'b0})
       begin
          hp_active <= 1;
          hp_sub <= 0;
          img_x <= 0;
       end
     else if (next_x == 10'd0)
       hp_active <= 0;
     else if (hp_active)
       begin
          if (hp_sub == a_pixread - 10'd1)
            begin
               hp_sub <= 0;
               img_x <= (img_x == 10'h3ff) ? img_x : img_x + 10'd1;
            end
          else
            hp_sub <= hp_sub + 10'd1;
       end

   wire        x_vis = hp_active && (img_x < {1'b0, a_pixperline}) && (xpos < 10'd640);
   wire [15:0] pixel_data_even, pixel_data_odd;
   reg [15:0]  pixel_data;
   reg [23:0]  rgb_data;

   always @(posedge clk_pixel or negedge rst_pixel_n)
     if (!rst_pixel_n)
       begin
          pixel_data <= 0;
          rgb_data <= 0;
       end
     else
       begin
          if (x_vis && line_vis[screen_y[0]] && ypos < 10'd480)
            pixel_data <= !screen_y[0] ? pixel_data_even : pixel_data_odd;
          else
            pixel_data <= 16'h0000;
          // Expand 16 bit pixel 5-6-5 to 24 bit 8-8-8
          rgb_data <= { pixel_data[15:11], pixel_data[15:13],
                        pixel_data[10:5],  pixel_data[10:9],
                        pixel_data[4:0],   pixel_data[4:2] };
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

   // ============================ clk_cpu: status ======================
   wire st_ev;
   sync_toggle st_req(.clk(clk_cpu), .rst_n(rst_cpu_n), .toggle(st_tog), .pulse(st_ev));
   always @(posedge clk_cpu or negedge rst_cpu_n)
     if (!rst_cpu_n)
       begin
          status <= 0;
          st_ack_tog <= 0;
       end
     else if (st_ev)
       begin
          status <= st_hold;          // stable since the toggle
          st_ack_tog <= ~st_ack_tog;
       end

   // ============================ clk_ram ==============================
   wire [7:0]  line_addr;
   wire [31:0] line_data;
   wire        line_strobe_even;
   wire        line_strobe_odd;
   wire        dma_late;

   video_dma video_dma(
                       .clk_ram(clk_ram),
                       .rst_n(rst_ram_n),
                       .enable(enable),
                       .line_req_tog(line_req_tog),
                       .line_req_address(line_req_address),
                       .line_req_len(line_req_len),
                       .line_req_odd(line_req_odd),
                       .req(req),
                       .req_address(req_address),
                       .req_len(req_len),
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
                          .pixel_addr(img_x[8:0]),
                          .pixel_data(pixel_data_even),
                          .clk_wr(clk_ram),
                          .wr_en(line_strobe_even),
                          .wr_addr(line_addr),
                          .wr_data(line_data));

   line_mem line_mem_odd(
                         .pixel_addr(img_x[8:0]),
                         .pixel_data(pixel_data_odd),
                         .clk_wr(clk_ram),
                         .wr_en(line_strobe_odd),
                         .wr_addr(line_addr),
                         .wr_data(line_data));

endmodule // video

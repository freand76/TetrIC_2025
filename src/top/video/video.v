module video(
             input             clk_pixel,
             input             clk_cpu,
             input             rst_n,

             input             halt_n,

             input [23:0]      addr_in,
             input [31:0]      data_in,
             input             sel,
             input             wr,

             output [9:0]      tmds_r,
             output [9:0]      tmds_g,
             output [9:0]      tmds_b,

             // VIDEO INFO
             output reg [11:0] frame_counter,

             // VIDEO DMA
             output            req_16,
             output [19:0]     req_address,
             input [31:0]      rsp_data,
             input             rsp_data_strobe
             );

   wire [9:0]             xpos, ypos;
   wire [8:0]             pixel_x, pixel_y;
   wire                   line_end, frame_end;
   wire [15:0]            pixel_data_even, pixel_data_odd;
   reg [15:0]             pixel_data;
   reg [23:0]             rgb_data;

   wire [7:0]             line_addr;
   wire [31:0]            line_data;
   wire                   line_strobe_even;
   wire                   line_strobe_odd;

   // Use half the resultion
   assign pixel_x = xpos[9:1];
   assign pixel_y = ypos[9:1];

   // Memory Mapped Registers
   reg [19:0]             video_address;

   always @ (posedge clk_cpu)
     begin
        if (!rst_n)
          begin
             video_address <= 20'h00200;
          end
        else
          begin
             if (sel & wr)
               begin
                  case(addr_in[3:0])
                    4'b0101 : video_address <= data_in[19:0];
                  endcase // case (addr_in[3:0])
               end
          end // else: !if(!rst_n)
     end // always @ (posedge clk_cpu)

   video_dma video_dma(
                       .clk_cpu(clk_cpu),
                       .rst_n(rst_n),
                       .halt_n(halt_n),

                       // VIDEO ADDRESS
                       .video_address(video_address),
                       // VIDEO INFO
                       .line(pixel_y),
                       .line_end(line_end),
                       .frame_end(frame_end),
                       // MEMORY CONTROLLER REQUEST
                       .req_16(req_16),
                       .req_address(req_address),
                       .rsp_data(rsp_data),
                       .rsp_data_strobe(rsp_data_strobe),
                       // LINE MEM INTERFACE
                       .line_addr(line_addr),
                       .line_data(line_data),
                       .line_strobe_odd(line_strobe_odd),
                       .line_strobe_even(line_strobe_even)
                       );

   always@(posedge clk_pixel)
     begin
        if (!rst_n)
          begin
             pixel_data <= 0;
             rgb_data <= 0;
             frame_counter <= 0;
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

             if (frame_end)
               begin
                  frame_counter <= frame_counter + 1;
               end
          end
     end

   line_mem line_mem_even(
                      .pixel_addr(pixel_x),
                      .pixel_data(pixel_data_even),
                      .clk_wr(clk_cpu),
                      .wr_en(line_strobe_even),
                      .wr_addr(line_addr),
                      .wr_data(line_data));

   line_mem line_mem_odd(
                      .pixel_addr(pixel_x),
                      .pixel_data(pixel_data_odd),
                      .clk_wr(clk_cpu),
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

endmodule // video

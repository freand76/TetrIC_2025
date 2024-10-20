module video(
             input        clk_pixel,
             input        clk_cpu,
             input        rst_n,

             input [23:0] addr_in,
             input [31:0] data_in,
             input        sel,
             input        wr,

             output [9:0] tmds_r,
             output [9:0] tmds_g,
             output [9:0] tmds_b
             );

   wire                   video_strobe;
   wire [9:0]             xpos, ypos;
   wire [8:0]             pixel_x, pixel_y;
   wire                   line_end, frame_end;
   wire [15:0]            pixel_data_even, pixel_data_odd;
   reg [15:0]             pixel_data;
   reg [23:0]             rgb_data;

   // Write strobe
   assign video_strobe_even = sel & wr & !addr_in[8];
   assign video_strobe_odd  = sel & wr & addr_in[8];

   // Use half the resultion
   assign pixel_x = xpos[9:1];
   assign pixel_y = ypos[9:1];

   always@(posedge clk_pixel)
     begin
        // Pixel Data (16-bit)
        pixel_data <= !pixel_y[0] ? pixel_data_even : pixel_data_odd;
        // Expand 16 bit pixel 5-6-5 to 24 bit 8-8-8
        // RGB delivered 1 clk after pixel data
        rgb_data <= { pixel_data[15:11], {3{pixel_data[11]}},
                      pixel_data[10:5], {2{pixel_data[5]}},
                      pixel_data[4:0], {3{pixel_data[0]}}};
     end

   line_mem line_mem_even(
                      .pixel_addr(pixel_x),
                      .pixel_data(pixel_data_even),
                      .clk_wr(clk_cpu),
                      .wr_en(video_strobe_even),
                      .wr_addr(addr_in[7:0]),
                      .wr_data(data_in));

   line_mem line_mem_odd(
                      .pixel_addr(pixel_x),
                      .pixel_data(pixel_data_odd),
                      .clk_wr(clk_cpu),
                      .wr_en(video_strobe_odd),
                      .wr_addr(addr_in[7:0]),
                      .wr_data(data_in));

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

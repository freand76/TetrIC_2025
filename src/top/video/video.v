module video(
             input        clk_pixel,
             input        clk_cpu,
             input        rst_n,

             input [31:0] addr_in,
             input [31:0] data_in,
             input        sel,
             input        wr,

             output [9:0] tmds_r,
             output [9:0] tmds_g,
             output [9:0] tmds_b
             );

   wire                   video_strobe;
   wire [9:0]             xpos, ypos;
   wire                   line_end, frame_end;
   wire [15:0]            pixel_data;
   reg [23:0]             rgb_data;

   assign video_strobe = sel & wr;

   always@(posedge clk_pixel)
     begin
        // Expand 16 bit pixel 5-6-5 to 24 bit 8-8-8
        rgb_data <= { pixel_data[15:11], {3{pixel_data[11]}},
                      pixel_data[10:5], {2{pixel_data[5]}},
                      pixel_data[4:0], {3{pixel_data[0]}}};
     end

   line_mem line_mem1(
                      .pixel_addr(xpos[9:1]),
                      .pixel_data(pixel_data),
                      .clk_wr(clk_cpu),
                      .wr_en(video_strobe),
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

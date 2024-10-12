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
   reg [23:0]             rgb_data;

   assign video_strobe = sel & wr;

   always@(posedge clk_cpu)
     begin
        if (video_strobe)
          begin
             rgb_data <= data_in[23:0];
          end
     end

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

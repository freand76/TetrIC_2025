module dvi_generator(input clk_pixel,
                     input            n_reset,
                     input [23:0]     rgb_data,
                     output [9:0]     tmds_r,
                     output [9:0]     tmds_g,
                     output [9:0]     tmds_b,
                     output reg [9:0] xpos,
                     output reg [9:0] ypos,
                     output           line_end,
                     output           frame_end);

   localparam                         FRAME_WIDTH = 800;
   localparam                         FRAME_HEIGHT = 525;
   localparam                         SCREEN_WIDTH = 640;
   localparam                         SCREEN_HEIGHT = 480;

   localparam                         HSYNC_PULSE_START = 16;
   localparam                         HSYNC_PULSE_SIZE = 96;
   localparam                         VSYNC_PULSE_START = 10;
   localparam                         VSYNC_PULSE_SIZE = 2;

   localparam                         INVERT = 1;

   logic                              hsync, vsync;

   assign line_end  = (xpos == FRAME_WIDTH-1'b1);
   assign frame_end = (xpos == FRAME_WIDTH-1'b1) && (ypos == FRAME_HEIGHT-1'b1);

   always @ (xpos,ypos)
     begin
        hsync <= INVERT ^ (xpos >= SCREEN_WIDTH + HSYNC_PULSE_START && xpos < SCREEN_WIDTH + HSYNC_PULSE_START + HSYNC_PULSE_SIZE);
        // vsync pulses should begin and end at the start of hsync, so special
        // handling is required for the lines on which vsync starts and ends
        if (ypos == SCREEN_HEIGHT + VSYNC_PULSE_START)
          vsync <= INVERT ^ (xpos >= SCREEN_WIDTH + HSYNC_PULSE_START);
        else if (ypos == SCREEN_HEIGHT + VSYNC_PULSE_START + VSYNC_PULSE_SIZE)
          vsync <= INVERT ^ (xpos < SCREEN_WIDTH + HSYNC_PULSE_START);
        else
          vsync <= INVERT ^ (ypos >= SCREEN_HEIGHT + VSYNC_PULSE_START && ypos < SCREEN_HEIGHT + VSYNC_PULSE_START + VSYNC_PULSE_SIZE);
     end

   // See Section 5.2
   logic video_data_period = 0;
   always @(posedge clk_pixel)
     begin
        if (!n_reset)
          video_data_period <= 0;
        else
          video_data_period <= xpos < SCREEN_WIDTH && ypos < SCREEN_HEIGHT;
     end

   logic [2:0] mode = 3'd1;
   logic [1:0] control_data = 2'd0;

   always @(posedge clk_pixel)
     begin
        if (!n_reset)
          begin
             xpos <= 0;
             ypos <= 0;
          end
        else
          begin
             xpos <= xpos == FRAME_WIDTH-1'b1 ? 0 : xpos + 1'b1;
             ypos <= xpos == FRAME_WIDTH-1'b1 ? ypos == FRAME_HEIGHT-1'b1 ? 0 : ypos + 1'b1 : ypos;
          end
     end

   always @(posedge clk_pixel)
     begin
        if (!n_reset)
          begin
             mode <= 3'd0;
             control_data <= 2'd0;
          end
        else
          begin
             mode <= video_data_period ? 3'd1 : 3'd0;
             control_data <= {vsync, hsync}; // ctrl3, ctrl2, ctrl1, ctrl0, vsync, hsync
          end
     end

   tmds_channel tmds_channel_r(.clk_pixel(clk_pixel),
                               .video_data(rgb_data[7:0]),
                               .data_island_data(4'd0),
                               .control_data(2'd0),
                               .mode(mode),
                               .tmds(tmds_r));

   tmds_channel tmds_channel_g(.clk_pixel(clk_pixel),
                               .video_data(rgb_data[15:8]),
                               .data_island_data(4'd0),
                               .control_data(2'd0),
                               .mode(mode),
                               .tmds(tmds_g));

   tmds_channel tmds_channel_b(.clk_pixel(clk_pixel),
                               .video_data(rgb_data[23:16]),
                               .data_island_data(4'd0),
                               .control_data(control_data),
                               .mode(mode),
                               .tmds(tmds_b));

endmodule // dvi_generator

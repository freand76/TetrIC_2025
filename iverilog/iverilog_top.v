`timescale 1ns / 1ps

// Simulation of src/top/top.v with the W25Q64 flash model (MEM.TXT) and the
// burst SDRAM model. Clocks as on the Tang Nano 20K: CPU = pixel = 25.2 MHz,
// SDRAM = 50.4 MHz (unrelated phase). The simulation ends when the program
// has been quiet on the UART for UART_IDLE_NS, or at the timeout.

module iverilog_top;

   parameter real PIXEL_PERIOD = 39.683;   // 25.2 MHz
   parameter real SDRAM_PERIOD = 19.841;   // 50.4 MHz
   parameter real UART_IDLE_NS = 500000.0;
   parameter real TIMEOUT_NS   = 60.0e6;
   parameter      CHECK_VIDEO  = 1;        // compare one HDMI frame with SDRAM

   reg clk = 0;
   reg clk_ram = 0;
   reg rst_n = 0;

   initial
     begin
        $display("Hello, World");
        #(TIMEOUT_NS);
        $display("TIMEOUT");
        finish_sim;
     end

   initial
     begin
        #200 rst_n = 1;   // several clocks, like PLL lock on hardware
     end

   initial
     begin
        #(3.1);
        forever #(PIXEL_PERIOD / 2) clk = ~clk;
     end

   initial
     begin
        #(1.7);
        forever #(SDRAM_PERIOD / 2) clk_ram = ~clk_ram;
     end

   wire [5:0] led;
   wire       uart_tx;
   wire       mspi_cs, mspi_clk, mspi_di, mspi_do;

   wire        sdram_cke, sdram_cs_n, sdram_cas_n, sdram_ras_n, sdram_wen_n;
   wire [31:0] sdram_dq;
   wire [10:0] sdram_addr;
   wire [1:0]  sdram_ba;
   wire [3:0]  sdram_dqm;

   top top(.clk_cpu(clk),
           .clk_pixel(clk),
           .clk_ram(clk_ram),
           .rst_n(rst_n),
           .uart_tx(uart_tx),
           .led(led),
           .mspi_cs(mspi_cs),
           .mspi_clk(mspi_clk),
           .mspi_di(mspi_di),
           .mspi_do(mspi_do),
           .O_sdram_cke(sdram_cke),
           .O_sdram_cs_n(sdram_cs_n),
           .O_sdram_cas_n(sdram_cas_n),
           .O_sdram_ras_n(sdram_ras_n),
           .O_sdram_wen_n(sdram_wen_n),
           .IO_sdram_dq(sdram_dq),
           .O_sdram_addr(sdram_addr),
           .O_sdram_ba(sdram_ba),
           .O_sdram_dqm(sdram_dqm),
           .tmds_r(),
           .tmds_g(),
           .tmds_b());

   W25Q64JVxxIM spi_flash(.CSn(mspi_cs),
                          .CLK(mspi_clk),
                          .DIO(mspi_di),
                          .DO(mspi_do),
                          .RESETn(rst_n));

   // SDRAM CLK pin = controller clock (continuous assign, no delay)
   sdram_model_burst #(.TAC(7.5), .TOH(4.0))
   sdram(.clk(clk_ram),
         .cke(sdram_cke),
         .cs_n(sdram_cs_n),
         .ras_n(sdram_ras_n),
         .cas_n(sdram_cas_n),
         .we_n(sdram_wen_n),
         .ba(sdram_ba),
         .a(sdram_addr),
         .dqm(sdram_dqm),
         .dq(sdram_dq));

   // ---- progress / end of simulation ----
   always @(posedge top.sdram_ready)
     $display("%t SDRAM ready", $realtime);
   always @(posedge top.copy_done)
     $display("%t flash copy done", $realtime);

   reg [8*256-1:0] uart_text = 0;
   integer         uart_chars = 0;
   real            t_last_uart = 0.0;

   always @(posedge top.arbiter_write_strobe)
     if (top.arbiter_uart_sel)
       begin
          uart_text = {uart_text[8*255-1:0], top.proc_dmem_data_out[7:0]};
          uart_chars = uart_chars + 1;
          t_last_uart = $realtime;
       end

   initial
     begin
        wait (uart_chars > 0);
        while ($realtime - t_last_uart < UART_IDLE_NS)
          #(10000.0);
        if (CHECK_VIDEO)
          check_frame;
        finish_sim;
     end

   // ---- video check: one 640x480 frame against the SDRAM model ----
   function [23:0] expand;
      input [15:0] p;
      expand = { p[15:11], p[15:13], p[10:5], p[10:9], p[4:0], p[4:2] };
   endfunction

   reg [9:0]  vx_d1, vx_d2, vy_d1, vy_d2;
   always @(posedge clk)
     begin
        vx_d1 <= top.video.xpos; vx_d2 <= vx_d1;
        vy_d1 <= top.video.ypos; vy_d2 <= vy_d1;
     end

   integer    video_errors = 0;
   reg        video_capture = 0;
   reg [31:0] vw;
   reg [15:0] vp;

   always @(negedge clk)
     if (video_capture && vx_d2 < 640 && vy_d2 < 480)
       begin
          vw = sdram.mem[top.video.fb_address + (vy_d2 >> 1) * 160 + (vx_d2 >> 2)];
          vp = vx_d2[1] ? vw[15:0] : vw[31:16];
          if (top.video.rgb_data !== expand(vp))
            begin
               if (video_errors < 10)
                 $display("VIDEO ERROR: pixel (%0d,%0d) = %06x, expected %06x",
                          vx_d2, vy_d2, top.video.rgb_data, expand(vp));
               video_errors = video_errors + 1;
            end
       end

   task check_frame;
      begin
         // line 0 is fetched at ypos 524, so start from the next full frame
         wait (top.video.ypos == 10'd523);
         wait (vy_d2 == 10'd0 && vx_d2 == 10'd0);
         $display("%t checking video frame (frame buffer at %x)", $realtime, top.video.fb_address);
         video_capture = 1;
         wait (vy_d2 == 10'd480);
         video_capture = 0;
         $display("%t video frame: %0d pixel errors", $realtime, video_errors);
      end
   endtask

   task finish_sim;
      begin
         $display("UART output (%0d chars):\n%0s", uart_chars, uart_text);
         sdram.report;
         if (top.memory_controller.copy_overrun) $display("ERROR: flash copy overrun");
         if (top.video.video_dma.late)           $display("ERROR: video line fetch late");
         $finish;
      end
   endtask
endmodule


module uart_tx
  #(
    parameter CLK_FRE = 50, //clock frequency(Mhz)
    parameter BAUD_RATE = 115200 //serial baud rate
    )
   (
    input       clk, //clock input
    input       rst_n, //asynchronous reset input, low active
    input [7:0] tx_data, //data to send
    input       tx_data_valid, //data to be sent is valid
    output reg  tx_data_ready, //send ready
    output      tx_pin            //serial data output
    );

   initial
     begin
        tx_data_ready <= 1;
     end

   always @ (posedge tx_data_valid)
     begin
        if ((tx_data >= 8'h20) && (tx_data < 8'h80))
          $display("UART: %x [%c] (time is %0t)", tx_data, tx_data, $time);
        else
          $display("UART: %x [0x%x] (time is %0t)", tx_data, tx_data, $time);
        tx_data_ready <= 0;
        #1000
          tx_data_ready <= 1;
     end

endmodule

module processor_ram(clk, rst, w_strobe, w_addr, w_data, r_addr, r_data);

   input clk, rst;
   input w_strobe;
   input [9:0] w_addr, r_addr;
   input [31:0] w_data;
   output reg [31:0] r_data;

   reg [31:0]    memory[1024];

   integer       idx;

   always@(posedge clk or posedge rst)
     begin
        if (rst)
          begin
             r_data <= 0;
             for(idx = 0; idx < 4096; idx=idx+1)
               memory[idx] <= 0;
          end
        else
          begin
             r_data <= memory[r_addr];
             if (w_strobe)
               begin
                  memory[w_addr] <= w_data;
               end
          end
     end // always@ (posedge clk or posedge rst)

endmodule


module RAM16SDP4(DI, WRE, CLK, WAD, RAD, DO);

   parameter INIT_0 = 16'h0000;
   parameter INIT_1 = 16'h0000;
   parameter INIT_2 = 16'h0000;
   parameter INIT_3 = 16'h0000;

   input [3:0] DI;
   input       WRE;
   input       CLK;
   input [3:0] WAD;
   input [3:0] RAD;
   output [3:0] DO;

   reg [3:0]   MEM[16];

   assign DO = MEM[RAD];

   integer     idx;

   initial
     begin
        for (idx = 0; idx < 16; idx = idx + 1)
          MEM[idx] = 0;
     end

   always @(posedge CLK)
     begin
        if (WRE)
          MEM[WAD] <= DI;
     end
endmodule // RAM16SDP4

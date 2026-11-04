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
        if ($test$plusargs("run_ns"))
          #(1.0e12);
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

   wire [1:0] led;
   wire       ds_clk, ds_cs, ds_mosi, pad_miso;

   // gamepad: nothing pressed, unless +press_ns=<t> +release_ns=<t> (START)
   ps2pad_model pad(.clk(ds_clk), .cs(ds_cs), .mosi(ds_mosi), .miso(pad_miso));
   real pad_press_ns, pad_release_ns;
   initial
     if ($value$plusargs("press_ns=%f", pad_press_ns) &&
         $value$plusargs("release_ns=%f", pad_release_ns))
       begin
          #(pad_press_ns);
          pad.buttons1 = ~8'h08;          // START
          $display("%t gamepad: START pressed", $realtime);
          #(pad_release_ns - pad_press_ns);
          pad.buttons1 = 8'hff;
          $display("%t gamepad: START released", $realtime);
       end
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
           .ds_clk(ds_clk),
           .ds_cs(ds_cs),
           .ds_mosi(ds_mosi),
           .ds_miso(pad_miso),
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
        if ($test$plusargs("run_ns"))
          wait (0);                       // +run_ns decides when to stop
        wait (uart_chars > 0);
        while ($realtime - t_last_uart < UART_IDLE_NS)
          #(10000.0);
        if (CHECK_VIDEO)
          check_frame;
        finish_sim;
     end

   // ---- options for running other programs (e.g. game_code) ----
   //   +preload=<file>  $readmemh image (one 32-bit word per line) loaded
   //                    into the SDRAM model, so the program does not have to
   //                    be copied from the flash model (the copied words are
   //                    the same when MEM.TXT is the same image)
   //   +run_ns=<ns>     stop after this time: check one frame and finish
   //   +ppm             write the checked frame to frame.ppm
   //   +frames=<n>      check (and write, frame0.ppm ...) n frames
   reg [8*256-1:0] preload_file;
   real            run_ns;
   integer         ppm_fd = 0;
   integer         n_frames, frame_i = 0;
   reg [8*32-1:0]  ppm_name;
   initial
     begin
        if ($value$plusargs("preload=%s", preload_file))
          begin
             $readmemh(preload_file, sdram.mem);
             $display("SDRAM preloaded from %0s", preload_file);
          end
        if ($value$plusargs("run_ns=%f", run_ns))
          begin
             #(run_ns);
             $display("%t run_ns reached: PC %x, game frame counter (MFC1) %0d", $realtime,
                      top.processor.imem_addr_out, top.video.frame_counter);
             if (!$value$plusargs("frames=%d", n_frames))
               n_frames = 1;
             for (frame_i = 0; frame_i < n_frames; frame_i = frame_i + 1)
               check_frame;
             finish_sim;
          end
     end

   // ---- sound log (+audio=<file>) for tools/sound_ref.py ----
   //   W <pass> <phase> <reg> <data>   register write, when the sound unit
   //                                   applies it; phase = mixer channel in
   //                                   that clock, 8 = between passes
   //   S <left> <right>                one 48 kHz output sample
   reg [8*256-1:0] audio_file;
   integer         audio_fd = 0, audio_samples = 0;
   initial
     if ($value$plusargs("audio=%s", audio_file))
       audio_fd = $fopen(audio_file, "w");

   always @(negedge clk)
     if (audio_fd)
       begin
          if (top.sound.op == top.sound.OP_WRITE)
            $fwrite(audio_fd, "W %0d %0d %0d %0d\n", top.sound.tick_count,
                    top.sound.mixing ? top.sound.mch : 8, top.sound.q_reg, top.sound.q_data);
          if (top.audio_valid)
            begin
               $fwrite(audio_fd, "S %0d %0d\n", $signed(top.audio_l), $signed(top.audio_r));
               audio_samples = audio_samples + 1;
            end
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

   // video register values used for the checked frame
   integer    v_top, v_left, v_ppl, v_lines, v_gfx, v_delta, v_pixread, v_sx, v_sy, v_ix, v_iy;

   always @(negedge clk)
     if (video_capture && vx_d2 < 640 && vy_d2 < 480)
       begin
          v_sx = vx_d2 >> 1;
          v_sy = vy_d2 >> 1;
          v_ix = (vx_d2 >= 2 * v_left) ? (vx_d2 - 2 * v_left) / v_pixread : -1;
          v_iy = v_sy - v_top;
          if (v_ix >= 0 && v_ix < v_ppl && v_iy >= 0 && v_iy < v_lines)
            begin
               vw = sdram.mem[v_gfx + v_iy * ((v_ppl + 1) / 2 + v_delta) + v_ix / 2];
               vp = v_ix[0] ? vw[15:0] : vw[31:16];
            end
          else
            vp = 16'h0000;   // outside the image: black
          if (ppm_fd)
            $fwrite(ppm_fd, "%0d %0d %0d\n", top.video.rgb_data[23:16],
                    top.video.rgb_data[15:8], top.video.rgb_data[7:0]);
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
         // registers that become active at the start of the next frame
         v_top = top.video.p_toppos;      v_left = top.video.p_leftpos;
         v_ppl = top.video.p_pixperline;  v_lines = top.video.p_lineperimg;
         v_gfx = top.video.p_gfxaddr;     v_delta = top.video.p_deltaaddr;
         v_pixread = (top.video.p_pixread == 0) ? 1 : top.video.p_pixread;
         wait (vy_d2 == 10'd0 && vx_d2 == 10'd0);
         $display("%t checking video frame: TOPPOS %0d LEFTPOS %0d PIXPERLINE %0d LINEPERIMG %0d GFXADDR %x DELTAADDR %0d PIXREAD %0d",
                  $realtime, v_top, v_left, v_ppl, v_lines, v_gfx, v_delta, v_pixread);
         if ($test$plusargs("ppm"))
           begin
              $sformat(ppm_name, "frame%0d.ppm", frame_i);
              ppm_fd = $fopen(ppm_name, "w");
              $fwrite(ppm_fd, "P3\n640 480\n255\n");
           end
         video_capture = 1;
         wait (vy_d2 == 10'd480);
         video_capture = 0;
         if (ppm_fd)
           begin
              $fclose(ppm_fd);
              ppm_fd = 0;
           end
         $display("%t video frame: %0d pixel errors", $realtime, video_errors);
      end
   endtask

   task finish_sim;
      begin
         $display("UART output (%0d chars):\n%0s", uart_chars, uart_text);
         sdram.report;
         if (top.memory_controller.copy_overrun) $display("ERROR: flash copy overrun");
         if (top.video.video_dma.late)           $display("ERROR: video line fetch late");
         if (audio_fd)
           begin
              $fclose(audio_fd);
              $display("sound: %0d output samples, %0d mix passes, %0d underruns",
                       audio_samples, top.sound.tick_count, top.sound.underruns);
           end
         if (top.sound.underruns != 0)           $display("ERROR: sound underrun");
         if (top.sound.wq_overflow)              $display("ERROR: sound register write queue overflow");
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

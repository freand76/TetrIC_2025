// Stand-alone test bench for the sound unit (src/top/sound/sound.v).
//
//   +mem=<file>      memory image, one hex word per line (word address 0..)
//   +script=<file>   register writes: "<sample> <reg> <hex data>" per line,
//                    written when <sample> output samples have been made;
//                    lines starting with # are comments
//   +samples=<n>     output samples to run (default 4800 = 100 ms)
//   +audio=<file>    log for tools/sound_ref.py: W (register write), C
//                    (sequencer channel write), E (sequencer event) and S
//                    (output sample) lines
//
// The memory controller model answers a request after RSP_DELAY clk_ram
// clocks (the SDRAM is not modelled).
`timescale 1ns/1ps
module tb_sound;

   localparam real CLK_PERIOD = 1000.0 / 25.2;    // clk_cpu = clk_pixel
   localparam RSP_DELAY = 12;                     // clk_ram clocks

   reg clk = 0, clk_ram = 0, rst_n = 0;
   always #(CLK_PERIOD / 2) clk = ~clk;
   initial begin #(1.3); forever #(CLK_PERIOD / 4) clk_ram = ~clk_ram; end

   reg [23:0] addr_in = 0;
   reg [31:0] data_in = 0;
   reg        sel = 0, wr = 0;

   wire        req;
   wire [19:0] req_address;
   reg         req_ack = 0;
   reg  [31:0] rsp_data = 0;
   reg         rsp_data_strobe = 0;
   wire [15:0] audio_l, audio_r;
   wire        audio_valid;

`ifndef SAMPLE_DIV
 `define SAMPLE_DIV 525
`endif
   // SAMPLE_DIV < 525 runs faster (the MOD tick counts samples, not clocks)
   sound #(.SAMPLE_DIV(`SAMPLE_DIV))
     sound(.clk_cpu(clk), .clk_pixel(clk), .clk_ram(clk_ram), .rst_n(rst_n),
               .enable(1'b1),
               .addr_in(addr_in), .data_in(data_in), .sel(sel), .wr(wr),
               .req(req), .req_address(req_address), .req_ack(req_ack),
               .rsp_data(rsp_data), .rsp_data_strobe(rsp_data_strobe),
               .audio_l(audio_l), .audio_r(audio_r), .audio_valid(audio_valid));

   // ---- memory ----
   reg [31:0] mem [0:(1 << 20) - 1];
   reg [8*256-1:0] mem_file;
   integer i;
   initial
     begin
        for (i = 0; i < (1 << 20); i = i + 1)
          mem[i] = 0;
        if ($value$plusargs("mem=%s", mem_file))
          $readmemh(mem_file, mem);
     end

   integer delay = -1;
   reg [19:0] r_addr;
   integer reads = 0;
   always @(posedge clk_ram)
     begin
        req_ack <= 0;
        rsp_data_strobe <= 0;
        if (req && !req_ack && delay < 0)
          begin
             req_ack <= 1;
             r_addr <= req_address;
             delay <= RSP_DELAY;
          end
        else if (delay > 0)
          delay <= delay - 1;
        else if (delay == 0)
          begin
             rsp_data <= mem[r_addr];
             rsp_data_strobe <= 1;
             reads = reads + 1;
             delay <= -1;
          end
     end

   // ---- register writes from the script ----
   reg [8*256-1:0] script_file;
   integer sfd = 0, rc, c, w_sample, w_reg, writes = 0;
   reg [31:0] w_data;
   reg        have_write = 0;
   reg [8*256-1:0] line;

   task next_write;
      begin
         have_write = 0;
         while (!have_write && sfd && !$feof(sfd))
           begin
              c = $fgetc(sfd);
              if (c == "#")
                rc = $fgets(line, sfd);         // comment: skip the line
              else if (c != -1 && c != "\n" && c != " ")
                begin
                   rc = $ungetc(c, sfd);
                   rc = $fscanf(sfd, "%d %d %h", w_sample, w_reg, w_data);
                   if (rc == 3)
                     have_write = 1;
                end
           end
      end
   endtask

   initial
     if ($value$plusargs("script=%s", script_file))
       begin
          sfd = $fopen(script_file, "r");
          if (!sfd)
            begin
               $display("ERROR: cannot open %0s", script_file);
               $finish;
            end
       end

   always @(negedge clk)
     begin
        sel <= 0;
        wr <= 0;
        if (rst_n && sound.cleared)
          begin
             if (!have_write)
               next_write;
             if (have_write && sound.tick_count >= w_sample)
               begin
                  addr_in <= 24'h400000 | w_reg;
                  data_in <= w_data;
                  sel <= 1;
                  wr <= 1;
                  writes = writes + 1;
                  have_write = 0;
               end
          end
     end

   // ---- audio log ----
   reg [8*256-1:0] audio_file;
   integer afd = 0, samples = 0, n_samples, nonzero = 0, peak = 0;
   initial
     if ($value$plusargs("audio=%s", audio_file))
       afd = $fopen(audio_file, "w");

   always @(negedge clk)
     begin
        if (afd && sound.op == sound.OP_WRITE)
          $fwrite(afd, "W %0d %0d %0d %0d\n", sound.tick_count,
                  sound.mixing ? sound.mch : 8, sound.q_reg, sound.q_data);
        if (afd && sound.op == sound.OP_SEQW)
          $fwrite(afd, "C %0d %0d %0d %0d %0d\n", sound.tick_count,
                  sound.mixing ? sound.mch : 8, sound.seq_w_ch, sound.seq_w_reg, sound.seq_w_data);
        if (afd && sound.seq_ev_start) $fwrite(afd, "E start %0d\n", sound.tick_count);
        if (afd && sound.seq_ev_tick)  $fwrite(afd, "E tick %0d\n", sound.tick_count);
        if (afd && sound.seq_ev_stop)  $fwrite(afd, "E stop %0d\n", sound.tick_count);
        if (audio_valid)
          begin
             if (afd)
               $fwrite(afd, "S %0d %0d\n", $signed(audio_l), $signed(audio_r));
             samples = samples + 1;
             if (audio_l || audio_r)
               nonzero = nonzero + 1;
             if ($signed(audio_l) > peak)  peak = $signed(audio_l);
             if (-$signed(audio_l) > peak) peak = -$signed(audio_l);
             if ($signed(audio_r) > peak)  peak = $signed(audio_r);
             if (-$signed(audio_r) > peak) peak = -$signed(audio_r);
          end
     end

   initial
     begin
        if (!$value$plusargs("samples=%d", n_samples))
          n_samples = 4800;
        #(10 * CLK_PERIOD);
        rst_n = 1;
        wait (samples >= n_samples);
        #(20 * CLK_PERIOD);
        $display("sound: %0d samples (%.1f ms), %0d non-zero, peak %0d, %0d writes, %0d memory reads, %0d underruns",
                 samples, samples / 48.0, nonzero, peak, writes, reads, sound.underruns);
        if (sound.underruns != 0) $display("ERROR: underruns");
        if (sound.wq_overflow)    $display("ERROR: write queue overflow");
        if (afd) $fclose(afd);
        $finish;
     end

endmodule // tb_sound

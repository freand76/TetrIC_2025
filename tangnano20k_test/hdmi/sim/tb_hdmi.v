// HDMI test bench (tangnano20k_test/hdmi): decodes the TMDS words of top.v back into HDMI data
// island packets, checks ECC/checksums/parity and extracts the audio.
// Audio samples are written to audio.txt (one "left right" pair per line).
`timescale 1ns / 1ps

module tb_hdmi;
   reg sys_clk = 0;
   reg rst = 1;
   always #18.518 sys_clk = ~sys_clk;

   wire tmds_clk_n, tmds_clk_p;
   wire [2:0] tmds_d_n, tmds_d_p;
   top dut(.sys_clk(sys_clk), .rst(rst),
           .tmds_clk_n(tmds_clk_n), .tmds_clk_p(tmds_clk_p),
           .tmds_d_n(tmds_d_n), .tmds_d_p(tmds_d_p));

   localparam [9:0] GB_DATA = 10'b0100110011;
   localparam [9:0] GB_VID02 = 10'b1011001100;

   // TERC4 decode, returns {valid, nibble}
   function [4:0] terc4(input [9:0] s);
      case (s)
        10'b1010011100: terc4 = 5'h10; 10'b1001100011: terc4 = 5'h11;
        10'b1011100100: terc4 = 5'h12; 10'b1011100010: terc4 = 5'h13;
        10'b0101110001: terc4 = 5'h14; 10'b0100011110: terc4 = 5'h15;
        10'b0110001110: terc4 = 5'h16; 10'b0100111100: terc4 = 5'h17;
        10'b1011001100: terc4 = 5'h18; 10'b0100111001: terc4 = 5'h19;
        10'b0110011100: terc4 = 5'h1a; 10'b1011000110: terc4 = 5'h1b;
        10'b1010001110: terc4 = 5'h1c; 10'b1001110001: terc4 = 5'h1d;
        10'b0101100011: terc4 = 5'h1e; 10'b1011000011: terc4 = 5'h1f;
        default: terc4 = 5'h00;
      endcase
   endfunction

   // BCH(64,56)/(32,24) check: run the LFSR over data + parity, must end in 0
   function ecc_ok(input [63:0] d, input integer n);
      integer i; reg [7:0] e;
      begin
         e = 0;
         for (i = 0; i < n; i = i + 1)
           e = (e >> 1) ^ ((e[0] ^ d[i]) ? 8'h83 : 8'h00);
         ecc_ok = e == d[n +: 8];
      end
   endfunction

   integer errors = 0, n_audio_pkt = 0, n_acr = 0, n_avi = 0, n_aif = 0, n_spd = 0, n_null = 0;
   reg [8*8-1:0] vendor;
   reg [16*8-1:0] product;
   reg [7:0] pb [0:27];
   integer n_samples = 0, n_islands = 0, n_vgb = 0, frame_samples = 0, iec = -1;
   integer fd, i, k, sum, pkt_clk = 0, gb_run = 0;
   reg [31:0] hdr;
   reg [63:0] sub [0:3];
   reg [4:0]  t0, t1, t2;
   reg        in_island = 0;
   reg signed [15:0] sl, sr;
   reg signed [15:0] samples [0:4095];

   task error(input [8*64-1:0] msg);
      begin
         errors = errors + 1;
         if (errors < 20) $display("ERROR @%0t: %0s", $time, msg);
      end
   endtask

   task packet;
      begin
         if (!ecc_ok({32'd0, hdr}, 24)) error("header ECC");
         for (k = 0; k < 4; k = k + 1)
           if (!ecc_ok(sub[k], 56)) error("subpacket ECC");
         case (hdr[7:0])
           8'h00: n_null = n_null + 1;
           8'h01:
             begin
                n_acr = n_acr + 1;
                if ({sub[0][11:8], sub[0][23:16], sub[0][31:24]} != 25200 ||
                    {sub[0][35:32], sub[0][47:40], sub[0][55:48]} != 6144)
                  error("ACR N/CTS");
             end
           8'h02:
             begin
                n_audio_pkt = n_audio_pkt + 1;
                for (k = 0; k < 4; k = k + 1)
                  if (hdr[8+k])
                    begin
                       sl = sub[k][23:8];
                       sr = sub[k][47:32];
                       if (^{sub[k][50:48], sub[k][23:0]} != sub[k][51]) error("left parity");
                       if (^{sub[k][54:52], sub[k][47:24]} != sub[k][55]) error("right parity");
                       if (hdr[20+k]) begin
                          if (iec >= 0 && iec != 192) error("IEC block length");
                          iec = 0;
                       end
                       if (iec >= 0) iec = iec + 1;
                       if (n_samples < 4096) samples[n_samples] = sl;
                       if (sl != sr) error("left != right");
                       $fwrite(fd, "%0d %0d\n", sl, sr);
                       n_samples = n_samples + 1;
                       frame_samples = frame_samples + 1;
                    end
             end
           8'h82, 8'h83, 8'h84:
             begin
                sum = hdr[7:0] + hdr[15:8] + hdr[23:16];
                for (k = 0; k < 4; k = k + 1)
                  for (i = 0; i < 7; i = i + 1)
                    sum = sum + sub[k][i*8 +: 8];
                if (sum[7:0] != 0) begin error("InfoFrame checksum"); $display("  hdr %h sub0 %h y=%0d", hdr[23:0], sub[0][55:0], dut.ypos); end
                if (hdr[7:0] == 8'h82)
                  begin
                     n_avi = n_avi + 1;
                     if (sub[0][39:32] != 1) error("AVI VIC");
                     if (n_avi > 1)
                       begin
                          $display("frame %0d: %0d audio samples", n_avi-1, frame_samples);
                          if (frame_samples != 800) error("samples per frame");
                       end
                     frame_samples = 0;
                  end
                else if (hdr[7:0] == 8'h83)
                  begin
                     for (k = 0; k < 4; k = k + 1)
                       for (i = 0; i < 7; i = i + 1)
                         pb[k*7+i] = sub[k][i*8 +: 8];
                     for (i = 0; i < 8; i = i + 1) vendor[(7-i)*8 +: 8] = pb[1+i];
                     for (i = 0; i < 16; i = i + 1) product[(15-i)*8 +: 8] = pb[9+i];
                     if (n_spd == 0)
                       $display("SPD: vendor \"%0s\" product \"%0s\" source type 0x%02h",
                                vendor, product, pb[25]);
                     if (hdr[23:16] != 25) error("SPD length");
                     n_spd = n_spd + 1;
                  end
                else
                  n_aif = n_aif + 1;
             end
           default: error("unknown packet type");
         endcase
      end
   endtask

   always @(posedge dut.clk_pixel)
     if (!rst)
       begin
          t0 = terc4(dut.tmds_b);
          t1 = terc4(dut.tmds_g);
          t2 = terc4(dut.tmds_r);
          if (dut.tmds_g == GB_DATA && dut.tmds_r == GB_VID02)
            n_vgb = n_vgb + 1;
          if (dut.tmds_g == GB_DATA && dut.tmds_r == GB_DATA && t0[4])
            begin
               // data island guard band: leading starts an island, trailing ends it
               if (in_island)
                 begin
                    if (pkt_clk % 32 != 0) error("partial packet");
                    in_island = 0;
                 end
               gb_run = gb_run + 1;
               pkt_clk = 0;
            end
          else if (t0[4] && t1[4] && t2[4])
            begin
               if (!in_island)
                 begin
                    if (gb_run != 2) error("leading guard band");
                    n_islands = n_islands + 1;
                 end
               if (t0[3] != (in_island || pkt_clk != 0)) error("ch0 bit 3");
               in_island = 1;
               gb_run = 0;
               i = pkt_clk % 32;
               hdr[i] = t0[2];
               for (k = 0; k < 4; k = k + 1)
                 begin
                    sub[k][2*i] = t1[k];
                    sub[k][2*i+1] = t2[k];
                 end
               pkt_clk = pkt_clk + 1;
               if (i == 31)
                 packet;
            end
          else
            begin
               if (in_island) error("island ended without guard band");
               in_island = 0;
               gb_run = 0;
            end
       end

   integer phase, best, ideal, maxerr;
   initial
     begin
        fd = $fopen("audio.txt", "w");
        #1000 rst = 0;
        #(`SIM_MS * 1000000);
        $fclose(fd);

        // Expect a 12-sample period sine: x[n] = 16384 sin(2 pi (n + phase) / 12)
        best = 0;
        maxerr = 99999;
        for (phase = 0; phase < 12; phase = phase + 1)
          begin
             k = 0;
             for (i = 0; i < n_samples && i < 4096; i = i + 1)
               begin
                  ideal = $rtoi($floor(16384.0 * $sin(2.0 * 3.14159265358979 * (i + phase) / 12.0) + 0.5));
                  if (samples[i] - ideal > k) k = samples[i] - ideal;
                  if (ideal - samples[i] > k) k = ideal - samples[i];
               end
             if (k < maxerr) begin maxerr = k; best = phase; end
          end

        $display("islands %0d, video guard bands %0d", n_islands, n_vgb);
        $display("packets: audio %0d, ACR %0d, AVI %0d, AudioInfo %0d, SPD %0d, null %0d",
                 n_audio_pkt, n_acr, n_avi, n_aif, n_spd, n_null);
        if (n_spd == 0) error("no SPD InfoFrame");
        $display("audio samples %0d in %0d ms -> %0d Hz sample rate",
                 n_samples, `SIM_MS, n_samples * 1000 / `SIM_MS);
        $display("sine fit: phase %0d, max error %0d LSB", best, maxerr);
        if (maxerr > 1) error("not a 4 kHz sine");
        if (errors == 0) $display("PASS");
        else $display("FAIL: %0d errors", errors);
        $finish;
     end
endmodule

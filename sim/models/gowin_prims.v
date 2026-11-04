// Simulation models of the Gowin GW2A primitives the TetrIC designs use
// (behavioural, for iverilog / Verilator; not timing accurate):
//
//   RAM16SDP4   16 x 4 LUT RAM, synchronous write, asynchronous read
//   rPLL        CLKOUT = CLKIN * (FBDIV_SEL + 1) / (IDIV_SEL + 1), measured
//               from CLKIN; CLKOUTP = CLKOUT; CLKOUTD = source / DYN_SDIV_SEL,
//               CLKOUTD3 = source / 3, source CLKOUT or CLKOUTP (CLKOUTD_SRC,
//               CLKOUTD3_SRC). The *_BYPASS settings pass CLKIN through.
//               LOCK after 16 CLKIN periods. Phase, duty and dynamic
//               settings are ignored.
//   CLKDIV      HCLKIN / DIV_MODE ("2", "4", "5", "8")
//   OSER10      not modelled (Q = 0): test benches check the 10 bit words
//   TLVDS_OBUF  O = I, OB = ~I
`timescale 1ns / 1ps

module RAM16SDP4(DI, WRE, CLK, WAD, RAD, DO);
   parameter INIT_0 = 16'h0000;
   parameter INIT_1 = 16'h0000;
   parameter INIT_2 = 16'h0000;
   parameter INIT_3 = 16'h0000;

   input [3:0]  DI;
   input        WRE;
   input        CLK;
   input [3:0]  WAD;
   input [3:0]  RAD;
   output [3:0] DO;

   reg [3:0]    MEM [0:15];
   integer      idx;
   initial
     for (idx = 0; idx < 16; idx = idx + 1)
       MEM[idx] = {INIT_3[idx], INIT_2[idx], INIT_1[idx], INIT_0[idx]};

   assign DO = MEM[RAD];

   always @(posedge CLK)
     if (WRE)
       MEM[WAD] <= DI;
endmodule // RAM16SDP4


module rPLL(output CLKOUT, output reg LOCK = 0,
            output CLKOUTP, output CLKOUTD, output CLKOUTD3,
            input RESET, input RESET_P, input CLKIN, input CLKFB,
            input [5:0] FBDSEL, input [5:0] IDSEL, input [5:0] ODSEL,
            input [3:0] PSDA, input [3:0] DUTYDA, input [3:0] FDLY);
   parameter FCLKIN = "27";
   parameter DYN_IDIV_SEL = "false";
   parameter IDIV_SEL = 0;
   parameter DYN_FBDIV_SEL = "false";
   parameter FBDIV_SEL = 0;
   parameter DYN_ODIV_SEL = "false";
   parameter ODIV_SEL = 8;
   parameter PSDA_SEL = "0000";
   parameter DYN_DA_EN = "false";
   parameter DUTYDA_SEL = "1000";
   parameter CLKOUT_FT_DIR = 1'b1;
   parameter CLKOUTP_FT_DIR = 1'b1;
   parameter CLKOUT_DLY_STEP = 0;
   parameter CLKOUTP_DLY_STEP = 0;
   parameter CLKFB_SEL = "internal";
   parameter CLKOUT_BYPASS = "false";
   parameter CLKOUTP_BYPASS = "false";
   parameter CLKOUTD_BYPASS = "false";
   parameter DYN_SDIV_SEL = 2;
   parameter CLKOUTD_SRC = "CLKOUT";
   parameter CLKOUTD3_SRC = "CLKOUT";
   parameter DEVICE = "GW2A-18C";

   // input period, measured
   realtime t_last = 0, t_in = 0;
   integer  n_in = 0;
   always @(posedge CLKIN)
     begin
        if (t_last > 0)
          t_in = $realtime - t_last;
        t_last = $realtime;
        n_in = n_in + 1;
        if (n_in == 16 && !RESET)
          LOCK <= 1;
     end

   always @(posedge RESET)
     begin
        LOCK <= 0;
        n_in = 0;
     end

   reg vco_out = 0;
   initial
     begin
        wait (t_in > 0);
        forever
          begin
             #(t_in * (IDIV_SEL + 1) / (FBDIV_SEL + 1) / 2.0);
             vco_out = RESET ? 1'b0 : ~vco_out;
          end
     end

   assign CLKOUT  = (CLKOUT_BYPASS == "true")  ? CLKIN : vco_out;
   assign CLKOUTP = (CLKOUTP_BYPASS == "true") ? CLKIN : vco_out;

   // dividers: toggle every n/2 source periods (n even), or every n
   // source edges for n = 3 (1/3 duty is not modelled)
   wire d_src  = (CLKOUTD_SRC == "CLKOUTP")  ? CLKOUTP : CLKOUT;
   wire d3_src = (CLKOUTD3_SRC == "CLKOUTP") ? CLKOUTP : CLKOUT;
   reg  clkd = 0, clkd3 = 0;
   integer nd = 0, nd3 = 0;
   always @(posedge d_src or negedge d_src)
     begin
        nd = nd + 1;
        if (nd >= DYN_SDIV_SEL)
          begin
             nd = 0;
             clkd = ~clkd;
          end
     end
   always @(posedge d3_src or negedge d3_src)
     begin
        nd3 = nd3 + 1;
        if (nd3 >= 3)
          begin
             nd3 = 0;
             clkd3 = ~clkd3;
          end
     end
   assign CLKOUTD  = (CLKOUTD_BYPASS == "true") ? CLKIN : clkd;
   assign CLKOUTD3 = clkd3;
endmodule // rPLL


module CLKDIV(output reg CLKOUT = 0, input HCLKIN, input RESETN, input CALIB);
   parameter DIV_MODE = "2";
   parameter GSREN = "false";

   localparam integer DIV = (DIV_MODE == "8") ? 8 : (DIV_MODE == "5") ? 5 :
                            (DIV_MODE == "4") ? 4 : 2;
   integer cnt = 0;
   always @(posedge HCLKIN or negedge RESETN)
     if (!RESETN)
       begin
          cnt <= 0;
          CLKOUT <= 0;
       end
     else
       begin
          cnt <= (cnt == DIV - 1) ? 0 : cnt + 1;
          CLKOUT <= cnt < (DIV + 1) / 2;    // 3/5 high for DIV_MODE "5"
       end
endmodule // CLKDIV


module OSER10(output Q, input D0, D1, D2, D3, D4, D5, D6, D7, D8, D9,
              input PCLK, input FCLK, input RESET);
   parameter GSREN = "false";
   parameter LSREN = "true";
   assign Q = 1'b0;     // serializer not modelled, test benches use the 10 bit words
endmodule // OSER10


module TLVDS_OBUF(input I, output O, output OB);
   assign O = I;
   assign OB = ~I;
endmodule // TLVDS_OBUF

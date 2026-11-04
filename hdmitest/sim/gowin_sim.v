// Minimal simulation models of the Gowin primitives used by hdmitest.
`timescale 1ns / 1ps

// Free running 126 MHz output, ignores the configuration
module rPLL(output reg CLKOUT = 0, output reg LOCK = 0,
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

   always #3.968 CLKOUT = ~CLKOUT;
   initial #200 LOCK = 1;
   assign CLKOUTP = CLKOUT;
   assign CLKOUTD = 0;
   assign CLKOUTD3 = 0;
endmodule

module CLKDIV(output reg CLKOUT = 0, input HCLKIN, input RESETN, input CALIB);
   parameter DIV_MODE = "2";
   reg [2:0] cnt = 0;
   always @(posedge HCLKIN)
     begin
        cnt <= cnt == 4 ? 0 : cnt + 1;
        CLKOUT <= cnt < 2 || cnt == 4;   // 3/5 high, period = 5 HCLKIN
     end
endmodule

module OSER10(output Q, input D0, D1, D2, D3, D4, D5, D6, D7, D8, D9,
              input PCLK, input FCLK, input RESET);
   assign Q = 1'b0;   // serializer not modelled, testbench uses the 10 bit words
endmodule

module TLVDS_OBUF(input I, output O, output OB);
   assign O = I;
   assign OB = ~I;
endmodule

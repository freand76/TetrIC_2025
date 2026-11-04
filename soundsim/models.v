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

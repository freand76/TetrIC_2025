module processor_ram(clk, rst, w_strobe, w_addr, w_data, r_addr, r_data);

   input clk, rst;
   input w_strobe;
   input [9:0] w_addr, r_addr;
   input [31:0] w_data;
   output [31:0] r_data;

   assign gnd = 1'b0;
   assign vcc = 1'b1;

   DPB mem1(.CLKA(clk),
            .OCEA(vcc),
            .CEA(vcc),
            .RESETA(rst),
            .WREA(w_strobe),
            .ADA({w_addr, gnd, gnd, vcc, vcc}),
            .DIA(w_data[31:16]),
            .BLKSELA(3'b000),
            .CLKB(clk),
            .OCEB(vcc),
            .CEB(vcc),
            .RESETB(rst),
            .WREB(gnd),
            .ADB({r_addr, gnd, gnd, vcc, vcc}),
            .DIB({16{gnd}}),
            .DOB(r_data[31:16]),
            .BLKSELB(3'b000));

   defparam mem1.READ_MODE0 = 1'b0;
   defparam mem1.READ_MODE1 = 1'b0;
   defparam mem1.WRITE_MODE0 = 2'b00;
   defparam mem1.WRITE_MODE1 = 2'b00;
   defparam mem1.BIT_WIDTH_0 = 16;
   defparam mem1.BIT_WIDTH_1 = 16;
   defparam mem1.BLK_SEL_0 = 3'b000;
   defparam mem1.BLK_SEL_1 = 3'b000;
   defparam mem1.RESET_MODE = "SYNC";

   DPB mem2(.CLKA(clk),
            .OCEA(vcc),
            .CEA(vcc),
            .RESETA(rst),
            .WREA(w_strobe),
            .ADA({w_addr, gnd, gnd, vcc, vcc}),
            .DIA(w_data[15:0]),
            .BLKSELA(3'b000),
            .CLKB(clk),
            .OCEB(vcc),
            .CEB(vcc),
            .RESETB(rst),
            .WREB(gnd),
            .ADB({r_addr, gnd, gnd, vcc, vcc}),
            .DIB({16{gnd}}),
            .DOB(r_data[15:0]),
            .BLKSELB(3'b000));

   defparam mem2.READ_MODE0 = 1'b0;
   defparam mem2.READ_MODE1 = 1'b0;
   defparam mem2.WRITE_MODE0 = 2'b00;
   defparam mem2.WRITE_MODE1 = 2'b00;
   defparam mem2.BIT_WIDTH_0 = 16;
   defparam mem2.BIT_WIDTH_1 = 16;
   defparam mem2.BLK_SEL_0 = 3'b000;
   defparam mem2.BLK_SEL_1 = 3'b000;
   defparam mem2.RESET_MODE = "SYNC";

endmodule

// Simulation model of a PlayStation (digital) gamepad.
// Answers FF 41 5A B1 B2 (LSB first), data changes on the falling clock edge.
// buttons1 / buttons2 are active low (see gamepad.v).
`timescale 1ns/1ps
module ps2pad_model(
                    input      clk,
                    input      cs,
                    input      mosi,
                    output reg miso
                    );
   reg [7:0] buttons1 = 8'hff;
   reg [7:0] buttons2 = 8'hff;
   integer   bitc;
   wire [39:0] resp = {buttons2, buttons1, 8'h5a, 8'h41, 8'hff};   // byte 0 in [7:0]
   initial miso = 1;
   always @(negedge cs) bitc = 0;
   always @(negedge clk) if (!cs && bitc < 40) miso = resp[bitc];
   always @(posedge clk) if (!cs) bitc = bitc + 1;
   always @(posedge cs) miso = 1;
endmodule

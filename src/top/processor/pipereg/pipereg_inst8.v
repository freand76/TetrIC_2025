module pipereg_inst8(clk, nreset, enable, D, Q);

   input clk, nreset, enable;
   input [7:0] D;
   output [7:0] Q;


   pipereg #( .WIDTH(8) ) pipereg_instance
     (
      .clk(clk),
      .nreset(nreset),
      .enable(enable),
      .D(D),
      .Q(Q)
      );

endmodule

module pipereg_inst8(clk, n_reset, enable, D, Q);

   input clk, n_reset, enable;
   input [7:0] D;
   output [7:0] Q;


   pipereg #( .WIDTH(8) ) pipereg_instance
     (
      .clk(clk),
      .n_reset(n_reset),
      .enable(enable),
      .D(D),
      .Q(Q)
      );

endmodule

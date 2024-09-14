module pipereg #(parameter WIDTH = 8)
(
 input              clk, nreset, enable,
 input [WIDTH-1:0]  D,
 output [WIDTH-1:0] Q
);

   reg [WIDTH-1:0]  val;

   assign Q = val;

   always @(posedge clk or negedge nreset)
     begin
        if(!nreset)
          val <= 0;
        else if (enable)
          val <= D;
     end
endmodule

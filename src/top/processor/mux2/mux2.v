module mux2(A, B, sel, O);

   input [31:0] A, B;
   input        sel;

   output [31:0] O;

   always @ (A, B, sel)
     begin
        case(sel)
          1'b0 : O <= A;
          1'b1 : O <= B;
          default: O <= A;
        endcase
     end

endmodule

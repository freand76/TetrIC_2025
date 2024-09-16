module signext(A, ctrl, O);

   input [15:0] A;
   input [1:0]  ctrl;

   output reg [31:0] O;

   wire [31:0]       sign_ext;
   wire [31:0]       one_ext;
   wire [31:0]       zero_ext;

   assign sign_ext = {{16{A[15]}}, A};
   assign one_ext = {{16{1'b1}}, A};
   assign zero_ext = {{16{1'b0}}, A};

   always @ (A, ctrl)
     begin
        O <= zero_ext;
        case(ctrl)
          2'b00 : O <= sign_ext;
          2'b10 : O <= one_ext;
          default: O <= zero_ext;
        endcase
     end
endmodule

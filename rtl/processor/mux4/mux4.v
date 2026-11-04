module mux4  #(parameter WIDTH = 32) (A, B, C, D, sel, O);

    input [WIDTH-1:0] A, B, C, D;
    input [1:0]       sel;

    output reg [WIDTH-1:0] O;

    always @ (A, B, C, D, sel)
        begin
            case(sel)
                2'b00 : O <= A;
                2'b01 : O <= B;
                2'b10 : O <= C;
                2'b11 : O <= D;
                default: O <= A;
            endcase // case (sel)
        end

endmodule

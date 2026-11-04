module pipereg #(parameter WIDTH = 8)
    (
        input              clk, n_reset, enable,
        input [WIDTH-1:0]  D,
        output [WIDTH-1:0] Q
    );

    reg [WIDTH-1:0]     val;

    assign Q = val;

    always @(posedge clk or negedge n_reset)
        begin
            if(!n_reset)
                val <= 0;
            else if (enable)
                val <= D;
        end
endmodule

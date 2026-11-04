// Instruction cache data memory: WORDS x 32 bit LUT RAM (RAM16SDP4 cells),
// synchronous write (clk_wr), asynchronous read.
module icache_mem
    #(
        parameter WORDS = 16,               // multiple of 16
        parameter AW    = 4                 // log2(WORDS)
    )
        (
            input [31:0]    wr_data,
            input           wr_en,
            input           clk_wr,
            input [AW-1:0]  wr_addr,
            input [AW-1:0]  rd_addr,
            output [31:0]   rd_data
        );

    localparam BLOCKS = WORDS / 16;

    wire [31:0] blk_data [0:BLOCKS-1];

    genvar b, n;
    generate
        for (b = 0; b < BLOCKS; b = b + 1) begin : blk
            wire we = wr_en && ((BLOCKS == 1) || (wr_addr[AW-1:4] == b));
            for (n = 0; n < 8; n = n + 1) begin : nib
                RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000))
                    ram(.DI(wr_data[4*n+3:4*n]), .DO(blk_data[b][4*n+3:4*n]),
                        .WRE(we), .CLK(clk_wr), .WAD(wr_addr[3:0]), .RAD(rd_addr[3:0]));
            end
        end
    endgenerate

    generate
        if (BLOCKS == 1)
            assign rd_data = blk_data[0];
        else
            assign rd_data = blk_data[rd_addr[AW-1:4]];
    endgenerate

endmodule // icache_mem

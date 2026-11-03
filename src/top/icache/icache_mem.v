module icache_mem(
                  input [31:0]  wr_data,
                  input         wr_en,
                  input         clk_wr,
                  input [3:0]   wr_addr,
                  input [3:0]   rd_addr,
                  output [31:0] rd_data
                  );

   RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) icache_inst_0(.DI(wr_data[31:28]), .DO(rd_data[31:28]),
                           .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr), .RAD(rd_addr));
   RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) icache_inst_1(.DI(wr_data[27:24]), .DO(rd_data[27:24]),
                           .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr), .RAD(rd_addr));
   RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) icache_inst_2(.DI(wr_data[23:20]), .DO(rd_data[23:20]),
                           .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr), .RAD(rd_addr));
   RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) icache_inst_3(.DI(wr_data[19:16]), .DO(rd_data[19:16]),
                           .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr), .RAD(rd_addr));
   RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) icache_inst_4(.DI(wr_data[15:12]), .DO(rd_data[15:12]),
                           .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr), .RAD(rd_addr));
   RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) icache_inst_5(.DI(wr_data[11:8]), .DO(rd_data[11:8]),
                           .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr), .RAD(rd_addr));
   RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) icache_inst_6(.DI(wr_data[7:4]), .DO(rd_data[7:4]),
                           .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr), .RAD(rd_addr));
   RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) icache_inst_7(.DI(wr_data[3:0]), .DO(rd_data[3:0]),
                           .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr), .RAD(rd_addr));

endmodule // icache_mem

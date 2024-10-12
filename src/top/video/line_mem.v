module pix32_mem(
                 input [4:0]   pixel_addr,
                 output [15:0] pixel_data,

                 input         clk_wr,
                 input         wr_en,
                 input [3:0]   wr_addr,
                 input [31:0]  wr_data
                 );

   wire [15:0]                 lpixel, rpixel;

   RAM16SDP4 pix16_data_31_28(.DI(wr_data[31:28]), .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr[3:0]), .RAD(pixel_addr[4:1]), .DO(lpixel[15:12]));
   RAM16SDP4 pix16_data_27_24(.DI(wr_data[27:24]), .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr[3:0]), .RAD(pixel_addr[4:1]), .DO(lpixel[11:8]));
   RAM16SDP4 pix16_data_23_20(.DI(wr_data[23:20]), .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr[3:0]), .RAD(pixel_addr[4:1]), .DO(lpixel[7:4]));
   RAM16SDP4 pix16_data_19_16(.DI(wr_data[19:16]), .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr[3:0]), .RAD(pixel_addr[4:1]), .DO(lpixel[3:0]));

   RAM16SDP4 pix16_data_15_12(.DI(wr_data[15:12]), .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr[3:0]), .RAD(pixel_addr[4:1]), .DO(rpixel[15:12]));
   RAM16SDP4 pix16_data_11_08(.DI(wr_data[11:8]), .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr[3:0]), .RAD(pixel_addr[4:1]), .DO(rpixel[11:8]));
   RAM16SDP4 pix16_data_07_04(.DI(wr_data[7:4]), .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr[3:0]), .RAD(pixel_addr[4:1]), .DO(rpixel[7:4]));
   RAM16SDP4 pix16_data_03_00(.DI(wr_data[3:0]), .WRE(wr_en), .CLK(clk_wr), .WAD(wr_addr[3:0]), .RAD(pixel_addr[4:1]), .DO(rpixel[3:0]));

   assign pixel_data = pixel_addr[0] ? rpixel : lpixel;

endmodule // pix32_mem


module line_mem(
                input [8:0]       pixel_addr,
                output reg [15:0] pixel_data,

                input             clk_wr,
                input             wr_en,
                input [7:0]       wr_addr,
                input [31:0]      wr_data

                );

   wire [15:0]                    pix_data0, pix_data1, pix_data2, pix_data3, pix_data4, pix_data5, pix_data6, pix_data7, pix_data8, pix_data9;
   wire                           wr_en0, wr_en1, wr_en2, wr_en3, wr_en4, wr_en5, wr_en6, wr_en7, wr_en8, wr_en9;

   assign wr_en0 = wr_addr[7:4] == 4'b0000 ? wr_en : 1'b0;
   assign wr_en1 = wr_addr[7:4] == 4'b0001 ? wr_en : 1'b0;
   assign wr_en2 = wr_addr[7:4] == 4'b0010 ? wr_en : 1'b0;
   assign wr_en3 = wr_addr[7:4] == 4'b0010 ? wr_en : 1'b0;
   assign wr_en4 = wr_addr[7:4] == 4'b0100 ? wr_en : 1'b0;
   assign wr_en5 = wr_addr[7:4] == 4'b0101 ? wr_en : 1'b0;
   assign wr_en6 = wr_addr[7:4] == 4'b0110 ? wr_en : 1'b0;
   assign wr_en7 = wr_addr[7:4] == 4'b0111 ? wr_en : 1'b0;
   assign wr_en8 = wr_addr[7:4] == 4'b1000 ? wr_en : 1'b0;
   assign wr_en9 = wr_addr[7:4] == 4'b1001 ? wr_en : 1'b0;

   pix32_mem mem_inst0(.pixel_addr(pixel_addr[4:0]), .pixel_data(pix_data0), .clk_wr(clk_wr), .wr_en(wr_en0), .wr_addr(wr_addr[3:0]),.wr_data(wr_data));
   pix32_mem mem_inst1(.pixel_addr(pixel_addr[4:0]), .pixel_data(pix_data1), .clk_wr(clk_wr), .wr_en(wr_en1), .wr_addr(wr_addr[3:0]),.wr_data(wr_data));
   pix32_mem mem_inst2(.pixel_addr(pixel_addr[4:0]), .pixel_data(pix_data2), .clk_wr(clk_wr), .wr_en(wr_en2), .wr_addr(wr_addr[3:0]),.wr_data(wr_data));
   pix32_mem mem_inst3(.pixel_addr(pixel_addr[4:0]), .pixel_data(pix_data3), .clk_wr(clk_wr), .wr_en(wr_en3), .wr_addr(wr_addr[3:0]),.wr_data(wr_data));
   pix32_mem mem_inst4(.pixel_addr(pixel_addr[4:0]), .pixel_data(pix_data4), .clk_wr(clk_wr), .wr_en(wr_en4), .wr_addr(wr_addr[3:0]),.wr_data(wr_data));
   pix32_mem mem_inst5(.pixel_addr(pixel_addr[4:0]), .pixel_data(pix_data5), .clk_wr(clk_wr), .wr_en(wr_en5), .wr_addr(wr_addr[3:0]),.wr_data(wr_data));
   pix32_mem mem_inst6(.pixel_addr(pixel_addr[4:0]), .pixel_data(pix_data6), .clk_wr(clk_wr), .wr_en(wr_en6), .wr_addr(wr_addr[3:0]),.wr_data(wr_data));
   pix32_mem mem_inst7(.pixel_addr(pixel_addr[4:0]), .pixel_data(pix_data7), .clk_wr(clk_wr), .wr_en(wr_en7), .wr_addr(wr_addr[3:0]),.wr_data(wr_data));
   pix32_mem mem_inst8(.pixel_addr(pixel_addr[4:0]), .pixel_data(pix_data8), .clk_wr(clk_wr), .wr_en(wr_en8), .wr_addr(wr_addr[3:0]),.wr_data(wr_data));
   pix32_mem mem_inst9(.pixel_addr(pixel_addr[4:0]), .pixel_data(pix_data9), .clk_wr(clk_wr), .wr_en(wr_en9), .wr_addr(wr_addr[3:0]),.wr_data(wr_data));

   always @ (*)
     begin
        case(pixel_addr[8:5])
          0 : pixel_data <= pix_data0;
          1 : pixel_data <= pix_data1;
          2 : pixel_data <= pix_data2;
          3 : pixel_data <= pix_data3;
          4 : pixel_data <= pix_data4;
          5 : pixel_data <= pix_data5;
          6 : pixel_data <= pix_data6;
          7 : pixel_data <= pix_data7;
          8 : pixel_data <= pix_data8;
          9 : pixel_data <= pix_data9;
          default : pixel_data <= pix_data0;
        endcase // case (pixel_addr[8:5)
     end
endmodule // line_mem

module regbank(clk, n_reset, r1_sel, r2_sel, rd_sel, w_enable, w_data, r1_data, r2_data);

    input        clk, n_reset;

    input [4:0]  r1_sel, r2_sel, rd_sel;
    input        w_enable;
    input [31:0] w_data;

    output [31:0] r1_data, r2_data;

    wire              wr_en_lo; // Register 0 to 15
    wire              wr_ee_hi; // Register 31 to 16

    wire [31:0]       r1_data_lo, r1_data_hi;
    wire [31:0]       r2_data_lo, r2_data_hi;

    assign wr_en_lo = w_enable & !rd_sel[4];
    assign wr_en_hi = w_enable & rd_sel[4];

    `ifdef IVERLOG
    // simulation trace, +trace to turn it on
    reg trace_on = 0;
    initial trace_on = $test$plusargs("trace");
    always @ (posedge clk)
        if (trace_on && w_enable && (rd_sel != 0))
        $display("REGDATA %x ==> %d", w_data, rd_sel);
    `endif

    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_31_28_lo(.DI(w_data[31:28]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_lo[31:28]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_27_24_lo(.DI(w_data[27:24]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_lo[27:24]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_23_20_lo(.DI(w_data[23:20]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_lo[23:20]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_19_16_lo(.DI(w_data[19:16]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_lo[19:16]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_15_12_lo(.DI(w_data[15:12]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_lo[15:12]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_11_08_lo(.DI(w_data[11:8]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_lo[11:8]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_07_04_lo(.DI(w_data[7:4]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_lo[7:4]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_03_00_lo(.DI(w_data[3:0]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_lo[3:0]));

    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_31_28_hi(.DI(w_data[31:28]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_hi[31:28]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_27_24_hi(.DI(w_data[27:24]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_hi[27:24]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_23_20_hi(.DI(w_data[23:20]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_hi[23:20]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_19_16_hi(.DI(w_data[19:16]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_hi[19:16]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_15_12_hi(.DI(w_data[15:12]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_hi[15:12]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_11_08_hi(.DI(w_data[11:8]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_hi[11:8]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_07_04_hi(.DI(w_data[7:4]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_hi[7:4]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r1_03_00_hi(.DI(w_data[3:0]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r1_sel[3:0]), .DO(r1_data_hi[3:0]));

    // write-through: a register written this cycle (WB) reads as the new value
    // (as the register file of the original VHDL design, reg.vhd)
    wire w_r1 = w_enable && (rd_sel == r1_sel);
    wire w_r2 = w_enable && (rd_sel == r2_sel);

    assign r1_data = (r1_sel == 0) ? 0 : w_r1 ? w_data : (r1_sel[4] ? r1_data_hi : r1_data_lo);

    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_31_28_lo(.DI(w_data[31:28]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_lo[31:28]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_27_24_lo(.DI(w_data[27:24]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_lo[27:24]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_23_20_lo(.DI(w_data[23:20]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_lo[23:20]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_19_16_lo(.DI(w_data[19:16]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_lo[19:16]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_15_12_lo(.DI(w_data[15:12]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_lo[15:12]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_11_08_lo(.DI(w_data[11:8]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_lo[11:8]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_07_04_lo(.DI(w_data[7:4]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_lo[7:4]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_03_00_lo(.DI(w_data[3:0]), .WRE(wr_en_lo), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_lo[3:0]));

    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_31_28_hi(.DI(w_data[31:28]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_hi[31:28]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_27_24_hi(.DI(w_data[27:24]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_hi[27:24]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_23_20_hi(.DI(w_data[23:20]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_hi[23:20]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_19_16_hi(.DI(w_data[19:16]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_hi[19:16]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_15_12_hi(.DI(w_data[15:12]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_hi[15:12]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_11_08_hi(.DI(w_data[11:8]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_hi[11:8]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_07_04_hi(.DI(w_data[7:4]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_hi[7:4]));
    RAM16SDP4 #(.INIT_0(16'h0000), .INIT_1(16'h0000), .INIT_2(16'h0000), .INIT_3(16'h0000)) r2_03_00_hi(.DI(w_data[3:0]), .WRE(wr_en_hi), .CLK(clk), .WAD(rd_sel[3:0]), .RAD(r2_sel[3:0]), .DO(r2_data_hi[3:0]));

    assign r2_data = (r2_sel == 0) ? 0 : w_r2 ? w_data : (r2_sel[4] ? r2_data_hi : r2_data_lo);

endmodule // regbank

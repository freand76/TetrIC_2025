`timescale 1ns / 1ns

module sdram_test_top;

   reg clk;
   reg rst_n;

   wire clk_sdram;

   initial
     begin
        clk = 0;
        rst_n = 0;
        #9 rst_n = 1;
     end

   always #5 clk = ~clk;
   assign clk_sdram = !clk;

   wire sdram_clk, sdram_ncs, sdram_nwe, sdram_ncas, sdram_nras;
   wire [1:0] sdram_ba;
   wire [10:0] sdram_a;
   wire [31:0] sdram_dq;

   reg [22:0]  address;
   reg [31:0]  din;
   wire [31:0] dout;
   wire        sel;
   reg         read, write;
   wire        read_ack;
   wire        write_ack;

   assign sel = 1;

   initial
     begin
        $display("Hello, World");
        read <= 0;
        write <= 0;
        address <= 0;
        din <= 0;
        #100000;
        din <= 32'hfedebeda;
        write <= 1;
        wait(write_ack);
        write <= 0;
        din <= 32'h12345678;

        #1000;

        read <= 1;
        wait(read_ack);
        read <= 0;

        #1000;
        address <= 4;
        write <= 1;
        wait(write_ack);
        write <= 0;

        #1000;

        read <= 1;
        wait(read_ack);
        read <= 0;

        #1000;
        address <= 0;
        read <= 1;
        wait(read_ack);
        read <= 0;

        #100000;
        $finish;
     end

   always @ (write_ack)
     begin
        if (write_ack)
          $display("Write ACK");
     end

   always @ (read_ack)
     begin
        if (read_ack)
          $display("Read ACK %x", dout);
     end

   sdram_model sdram_model
     (
      .in_CLK(sdram_clk),
      .in_CS(sdram_ncs),
      .in_write_en(sdram_nwe),
      .in_CAS(sdram_ncas),
      .in_RAS(sdram_nras),
      .in_bank_select(sdram_ba),
      .in_sdram_addr(sdram_a),
      .inout_sdram_data(sdram_dq)
      );

   sdram_wrap sdram_wrap
     (
      .SDRAM_DQ(sdram_dq),
      .SDRAM_A(sdram_a),
      .SDRAM_BA(sdram_ba),
      .SDRAM_nCS(sdram_ncs),
      .SDRAM_nWE(sdram_nwe),
      .SDRAM_nRAS(sdram_nras),
      .SDRAM_nCAS(sdram_ncas),
      .SDRAM_CLK(sdram_clk),

      .clk(clk),
      .clk_sdram(clk_sdram),
      .resetn(rst_n),
      .sel(sel),
      .read(read),
      .read_ack(read_ack),
      .write(write),
      .write_ack(write_ack),
      .addr(address),
      .din(din),
      .dout(dout)
      );

endmodule // iverilog_top

`timescale 1ns / 1ns

module iverilog_top;

   reg clk;
   reg rst_n;

   initial
     begin
        $display("Hello, World");
        #1000000
          $finish;
     end

   initial
     begin
        clk = 0;
        rst_n = 0;
        #9 rst_n = 1;
     end

   always #5 clk = ~clk;

   wire [5:0] led;

   wire       mspi_cs, mspi_clk, mspi_di, mspi_do;

   top top(.clk(clk),
           .rst_n(rst_n),
           .led(led),
           .mspi_cs(mspi_cs),
           .mspi_clk(mspi_clk),
           .mspi_di(mspi_di),
           .mspi_do(mspi_do));

   W25Q64JVxxIM spi_flash(.CSn(mspi_cs),
                          .CLK(mspi_clk),
                          .DIO(mspi_di),
                          .DO(mspi_do),
                          .RESETn(!rst));
endmodule


module uart_tx
  #(
    parameter CLK_FRE = 50, //clock frequency(Mhz)
    parameter BAUD_RATE = 115200 //serial baud rate
    )
   (
    input       clk, //clock input
    input       rst_n, //asynchronous reset input, low active
    input [7:0] tx_data, //data to send
    input       tx_data_valid, //data to be sent is valid
    output reg  tx_data_ready, //send ready
    output      tx_pin            //serial data output
    );

   initial
     begin
        tx_data_ready <= 1;
     end

   always @ (posedge tx_data_valid)
     begin
        $display("UART: %x [%c] (time is %0t)", tx_data, tx_data, $time);
        tx_data_ready <= 0;
        #1000
          tx_data_ready <= 1;
     end

endmodule

module processor_ram(clk, rst, w_strobe, w_addr, w_data, r_addr, r_data);

   input clk, rst;
   input w_strobe;
   input [9:0] w_addr, r_addr;
   input [31:0] w_data;
   output reg [31:0] r_data;

   reg [31:0]    memory[1024];

   integer       idx;

   always@(posedge clk or posedge rst)
     begin
        if (rst)
          begin
             r_data <= 0;
             for(idx = 0; idx < 4096; idx=idx+1)
               memory[idx] <= 0;
          end
        else
          begin
             r_data <= memory[r_addr];
             if (w_strobe)
               begin
                  memory[w_addr] <= w_data;
               end
          end
     end // always@ (posedge clk or posedge rst)

endmodule


module RAM16SDP4(DI, WRE, CLK, WAD, RAD, DO);

   input [3:0] DI;
   input       WRE;
   input       CLK;
   input [3:0] WAD;
   input [3:0] RAD;
   output [3:0] DO;

   reg [3:0]   MEM[16];

   assign DO = MEM[RAD];

   integer     idx;

   initial
     begin
        for (idx = 0; idx < 16; idx = idx + 1)
          MEM[idx] = 0;
     end

   always @(posedge CLK)
     begin
        if (WRE)
          MEM[WAD] <= DI;
     end
endmodule // RAM16SDP4

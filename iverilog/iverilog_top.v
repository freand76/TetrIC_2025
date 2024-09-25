`timescale 1ns / 1ns

module iverilog_top;

   reg clk;
   reg rst;

   initial
     begin
        $display("Hello, World");
        #10000000
          $finish;
     end

   initial
     begin
        clk = 0;
        rst = 1;
        #9 rst = 0;
     end

   always #5 clk = ~clk;

   wire [5:0] led;

   wire       mspi_cs, mspi_clk, mspi_di, mspi_do;
   wire [31:0] debug_pc, debug_data, debug_data2;

   top top(.clk(clk),
           .rst(rst),
           .led(led),
           .mspi_cs(mspi_cs),
           .mspi_clk(mspi_clk),
           .mspi_di(mspi_di),
           .mspi_do(mspi_do)

//           .debug_pc(debug_pc),
//           .debug_data(debug_data),
//           .debug_data2(debug_data2)
           );

   W25Q64JVxxIM spi_flash(.CSn(mspi_cs),
                          .CLK(mspi_clk),
                          .DIO(mspi_di),
                          .DO(mspi_do),
                          .RESETn(!rst));

   always @( debug_pc)
     begin
        $display("PC: %x:%x:%x", debug_pc, debug_data, debug_data2);
        if (debug_pc == 32'h00ffffff)
          $finish;
     end
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
        $display("UART: %x (time is %0t)", tx_data, $time);
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
   output [31:0] r_data;

   reg [31:0]    memory[1024];

   integer       idx;

   always@(posedge clk or posedge rst)
     begin
        if (rst)
          begin
             for(idx = 0; idx < 4096; idx=idx+1)
               memory[idx] <= 0;
          end
        else
          begin
             if (w_strobe)
               begin
                  memory[w_addr] <= w_data;
               end
          end
     end // always@ (posedge clk or posedge rst)

   assign r_data = memory[r_addr];
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

   always @(posedge CLK)
     begin
        if (WRE)
          MEM[WAD] <= DI;
     end
endmodule // RAM16SDP4

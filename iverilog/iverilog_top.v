`timescale 1ns / 1ns

module iverilog_top;

   reg clk;
   reg rst;

   initial
     begin
        $display("Hello, World");
        #1000000
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

   top top(.clk(clk),
           .rst(rst),
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

   always @ (tx_data_valid)
     begin
        if (tx_data_valid)
          begin
             $display("UART: %x", tx_data);
             tx_data_ready <= tx_data_valid;
          end
     end

endmodule

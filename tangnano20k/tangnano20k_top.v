module tangnano20k_top(
                       // Clock and Reset
                       input        sys_clk,
                       input        rst,

                       // UART Tx
                       output       uart_tx,

                       // LED (Active LOW)
                       output [5:0] led,

                       // spi flash interface
                       output       mspi_cs,
                       output       mspi_clk,
                       output       mspi_di,
                       input        mspi_do);

   wire                             rst_n = !rst;
   wire                             clk, clk_sdram;

   main_pll main_pll(
                     .clkout(clk),           // Main clock
                     .clkoutp(clk_sdram),    // Phase shifted clock for SDRAM
                     .clkin(sys_clk)         // 27Mhz system clock
                     );

   top top(.clk(clk),
           .rst_n(rst_n),
           .uart_tx(uart_tx),
           .led(led),
           .mspi_cs(mspi_cs),
           .mspi_clk(mspi_clk),
           .mspi_di(mspi_di),
           .mspi_do(mspi_do));

endmodule // tangnano20k_top

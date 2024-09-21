module uart_test(
                 // Clock and Reset
                 input        clk,
                 input        rst,

                 // UART Tx
                 output       uart_tx,

                 // LED (Active LOW)
                 output [5:0] led,

                 // spi flash interface
                 output       mspi_cs,
                 output       mspi_clk,
                 output       mspi_di,
                 input        mspi_do
                 );

   parameter                  CLK_FRE  = 27;//Mhz
   parameter                  UART_FRE = 115200;
   localparam                 IDLE =  0;
   localparam                 READFLASH1 = 1;
   localparam                 READFLASH2 = 2;
   localparam                 SEND =  3;   //send
   localparam                 WAIT =  4;   //wait 1 second and send uart received data
   reg [7:0]                  tx_data;
   reg [7:0]                  tx_str;
   reg                        tx_data_valid;
   wire                       tx_data_ready;
   reg [7:0]                  tx_cnt;
   reg [31:0]                 wait_cnt;
   reg [3:0]                  state;

   wire                       rst_n = !rst;

   wire [7:0]                 flash_dout;
   reg [23:0]                 flash_addr;
   reg                        flash_cs;
   reg                        flash_read;

   assign led[3:0] = flash_addr[3:0];

   always@(posedge clk or negedge rst_n)
     begin
        if(rst_n == 1'b0)
          begin
             wait_cnt <= 32'd0;
             tx_data <= 8'd0;
             state <= IDLE;
             tx_cnt <= 8'd0;
             tx_data_valid <= 1'b0;
             flash_addr <= 24'h500000;
             flash_read <= 0;
          end
        else
          case(state)
            IDLE:
              begin
                 tx_data_valid <= 1'b0;
                 wait_cnt <= 32'd0;
                 state <= WAIT;
              end
            READFLASH1:
              begin
                 flash_read <= 1;
                 if (flash_busy)
                   state <= READFLASH2;
              end
            READFLASH2:
              begin
                 tx_data_valid <= 1'b0;
                 if (!flash_busy)
                   begin
                      state <= SEND;
                   end
              end
            SEND:
              begin
                 flash_read <= 0;
                 flash_addr <= flash_addr + 1;
                 state <= WAIT;
                 wait_cnt <= 0;
                 tx_data_valid <= 1'b1;
                 tx_data <= flash_dout[7:0];
              end
            WAIT:
              begin
                 tx_data_valid <= 1'b0;
                 wait_cnt <= wait_cnt + 32'd1;
                 if(wait_cnt >= CLK_FRE * 1000_00) // wait for 100ms
                   state <= READFLASH1;
              end
            default:
              state <= IDLE;
          endcase
     end

   assign led[5] = flash_busy;
   assign led[4] = flash_busy;

   flash_reader flash_reader (
                .clk       (clk),
                .n_reset   (rst_n),
                .address   (flash_addr),
                .read      (flash_read),
                .data_out  (flash_dout),
                .busy      (flash_busy),

                .spi_cs    (mspi_cs),
                .spi_clk   (mspi_clk),
                .spi_mosi  (mspi_di),
                .spi_miso  (mspi_do)
                );
   uart_tx#
     (
      .CLK_FRE(CLK_FRE),
      .BAUD_RATE(UART_FRE)
      ) uart_tx_inst
       (
        .clk            (clk),
        .rst_n          (rst_n),
        .tx_data        (tx_data),
        .tx_data_valid  (tx_data_valid),
        .tx_data_ready  (tx_data_ready),
        .tx_pin         (uart_tx)
        );
endmodule

module top(
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

`ifdef IVERLOG
   parameter            FLASH_START = 24'h000000;
`else
   parameter            FLASH_START = 24'h500000;
`endif

   parameter            CLK_FRE  = 27;//Mhz
   parameter            UART_FRE = 115200;


   reg [7:0]            tx_data;
   reg                  tx_data_valid;
   wire                 tx_data_ready;
   reg [31:0]           wait_cnt;
   reg [3:0]            state;

   wire                 rst_n = !rst;

   wire                 flash_done;
   wire                 flash_strobe;
   wire [31:0]          flash_data_out;

   reg [4:0]            led_cnt;

   assign led[0] = !led_cnt[0];
   assign led[1] = !led_cnt[1];
   assign led[2] = !led_cnt[2];
   assign led[3] = !led_cnt[3];
   assign led[4] = !led_cnt[4];
   assign led[5] = !flash_done;

   always@(posedge clk or negedge rst_n)
     begin
        if(rst_n == 1'b0)
          begin
             led_cnt <= 0;
          end
        else
          if (flash_strobe)
            begin
               led_cnt <= led_cnt + 1;
            end
     end // always@ (posedge clk or negedge rst_n)

   flash_reader flash_reader(.clk(clk),
                             .n_reset(rst_n),
                             .address(FLASH_START),
                             .word_count(24'h000100),
                             .strobe(flash_strobe),
                             .done(flash_done),
                             .data_out(flash_data_out),
                             .spi_cs(mspi_cs),
                             .spi_clk(mspi_clk),
                             .spi_mosi(mspi_di),
                             .spi_miso(mspi_do));

   reg [31:0] uart_data;
   reg [7:0]  uart_cnt;

   reg [9:0]  mem_write_addr;
   reg [9:0]  mem_read_addr;

   always@(posedge clk or negedge rst_n)
     begin
        if(!rst_n)
          mem_write_addr <= 0;
        else
          if (flash_strobe)
            mem_write_addr <= mem_write_addr + 1;
     end

   always@(posedge clk or negedge rst_n)
     begin
        if(!rst_n)
          begin
             state <= 0;
             uart_data <= 0;
             tx_data <= 0;
             tx_data_valid <= 0;
             uart_cnt <= 0;
             mem_read_addr <= 0;
          end
        else
          case(state)
            0:
              begin
                 if (flash_done)
                   begin
                      state <= 1;
                      uart_data <= read_data;
                   end
              end
            1:
              begin
                 tx_data_valid <= 1;
                 if (uart_cnt > 200)
                   begin
                      tx_data <= 8'h0a;
                      state <= 15;
                   end
                 else
                   begin
                      tx_data <= uart_data[31:24];
                      state <= 2;
                   end
              end
            2 :
              begin
                 uart_cnt <= uart_cnt + 1;
                 tx_data_valid <= 0;
                 state <= 3;
              end
            3 : state <= 4;
            4 : state <= 5;
            5 : state <= 6;
            6 : state <= 7;
            7 :
            begin
               if (uart_cnt[1:0] == 2'b00)
                 begin
                    mem_read_addr <= mem_read_addr + 1;
                    state <= 14;
                 end
               else
                 state <= 8;
            end
            8 : state <= 9;
            9 :
              begin
                 if (tx_data_ready)
                   begin
                      uart_data <= { uart_data[23:0], 8'b00000000 };
                      state <= 1;
                   end
              end
            14 :
              begin
                 if (tx_data_ready)
                   state <= 0;
              end
            15:
              begin
                 tx_data_valid <= 0;
              end
            default:
              begin
                 tx_data_valid <= 0;
              end
          endcase // case (state)
     end // always@ (posedge clk or negedge rst_n)

   processor_ram processor_ram(.clk(clk),
                               .rst(rst),
                               .w_strobe(flash_strobe),
                               .w_addr(mem_write_addr),
                               .w_data(flash_data_out),
                               .r_addr(mem_read_addr),
                               .r_data(read_data));

   wire  [31:0] read_data;

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

module flash_reader(clk, n_reset, address, read, busy, data_out, spi_cs, spi_clk, spi_mosi, spi_miso, state);

   input clk, n_reset;
   input [23:0] address;

   input        read;
   output reg   busy;
   output reg [7:0] data_out;

   output reg   spi_cs, spi_clk, spi_mosi;
   input        spi_miso;

   output reg [3:0]    state;

   reg [7:0]    mosi_shift;
   reg [7:0]    miso_shift;

   localparam   INIT    =  0;
   localparam   CS_LOW  =  2;
   localparam   COMMAND =  3;
   localparam   COMMAND_WAIT =  4;
   localparam   ADDR1        =  5;
   localparam   ADDR1_WAIT   =  6;
   localparam   ADDR2        =  7;
   localparam   ADDR2_WAIT   =  8;
   localparam   ADDR3        =  9;
   localparam   ADDR3_WAIT   =  10;
   localparam   DATA         =  11;
   localparam   DATA_WAIT    =  12;
   localparam   CS_HIGH      =  13;

   reg          start_shifter;
   reg          shifter_done;

   reg [7:0]    mosi_data;
   reg [1:0]    mosi_sel;

   always @ (mosi_sel, address)
     begin
        case(mosi_sel)
          0 : mosi_data <= 8'h03;
          1 : mosi_data <= address[23:16];
          2 : mosi_data <= address[15:8];
          3 : mosi_data <= address[7:0];
        endcase // case (mosi_sel)
     end

   always @ (posedge clk, negedge n_reset)
     begin
        start_shifter <= 0;

        if (!n_reset)
          begin
             spi_cs <= 1'b1;
             data_out <= 0;
             mosi_sel <= 0;
             state <= INIT;
             busy <= 0;
          end
        else
          begin
             case(state)
               INIT:
                 if (read)
                   begin
                      state <= CS_LOW;
                      busy <= 1;
                   end
               CS_LOW:
                 begin
                    spi_cs <= 1'b0;
                    state <= COMMAND;
                 end
               COMMAND:
                 begin
                    mosi_sel <= 0;
                    start_shifter <= 1;
                    if (!shifter_done)
                      state <= COMMAND_WAIT;
                 end
               COMMAND_WAIT:
                 begin
                    start_shifter <= 0;
                    if (shifter_done)
                      state <= ADDR1;
                 end
               ADDR1:
                   begin
                      mosi_sel <= 1;
                      start_shifter <= 1;
                      if (!shifter_done)
                        state <= ADDR1_WAIT;
                   end
               ADDR1_WAIT:
                 begin
                    start_shifter <= 0;
                    if (shifter_done)
                      state <= ADDR2;
                 end
               ADDR2:
                   begin
                      mosi_sel <= 2;
                      start_shifter <= 1;
                      if (!shifter_done)
                        state <= ADDR2_WAIT;
                   end
               ADDR2_WAIT:
                 begin
                    start_shifter <= 0;
                    if (shifter_done)
                      state <= ADDR3;
                 end
               ADDR3:
                   begin
                      mosi_sel <= 3;
                      start_shifter <= 1;
                      if (!shifter_done)
                        state <= ADDR3_WAIT;
                   end
               ADDR3_WAIT:
                 begin
                    start_shifter <= 0;
                    if (shifter_done)
                      state <= DATA;
                 end
               DATA:
                   begin
                      start_shifter <= 1;
                      if (!shifter_done)
                        state <= DATA_WAIT;
                   end
               DATA_WAIT:
                 begin
                    start_shifter <= 0;
                    if (shifter_done)
                      begin
                         state <= CS_HIGH;
                         data_out <= miso_shift;
                         busy <= 0;
                      end
                 end
               CS_HIGH:
                 begin
                    spi_cs <= 1'b1;
                    state <= INIT;
                 end
             endcase // case (state)
          end // else: !if(!n_reset)
     end // always @ (clk, rst_n)

   reg [1:0] shifter_state;
   reg [2:0] bit_count;

   always @ (posedge clk, negedge n_reset)
     begin
        if (!n_reset)
          begin
             spi_mosi <= 1'b0;
             spi_clk <= 1'b1;
             shifter_done <= 1'b0;
             shifter_state <= 1'b0;
             bit_count <= 3'b000;
          end
        else
          begin
             case(shifter_state)
               0 : // IDLE
                 begin
                    if (start_shifter)
                      begin
                         mosi_shift <= mosi_data;
                         shifter_state <= 1;
                         shifter_done <= 1'b0;
                      end
                 end
               1 : // LOW CLK
                 begin
                    spi_clk <= 1'b0;
                    spi_mosi <= mosi_shift[7];
                    mosi_shift[7:0] <= { mosi_shift[6:0], 1'b0 };
                    shifter_state <= 2;
                    bit_count <= bit_count + 3'b001;
                 end
               2 : // HIGH CLK
                 begin
                    spi_clk <= 1'b1;
                    miso_shift[7:0] <= { miso_shift[6:0], spi_miso };

                    if (bit_count == 3'b000)
                      begin
                         bit_count <= 3'b000;
                         shifter_done <= 1'b1;
                         shifter_state <= 0;
                      end
                    else
                      shifter_state <= 1;
                 end
             endcase // case (shifter_state)
          end // else: !if(!n_reset)
     end

endmodule // flash_reader

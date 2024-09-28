module top(
           // Clock and Reset
           input         clk,
           input         rst,

           // UART Tx
           output        uart_tx,

           // LED (Active LOW)
           output [5:0]  led,

`ifdef IVERLOG
           output [31:0] debug_pc,
           output [31:0] debug_data,
           output [31:0] debug_data2,
`endif
           // spi flash interface
           output        mspi_cs,
           output        mspi_clk,
           output        mspi_di,
           input         mspi_do);

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
                             .word_count(24'h000400),
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
            begin
               mem_write_addr <= mem_write_addr + 1;
            end
     end

   wire [31:0] dmem_data_out;
   wire [31:0] mem_data_out;
   wire [31:0] imem_addr_out, dmem_addr_out;
   wire        dmem_req, dmem_wr;
   wire        n_stall;

   reg         n_mem_stall;
   reg         dmem_ack,  imem_ack;
   reg [2:0]   arb_state;

   assign n_stall = flash_done & n_mem_stall;

   always@(posedge clk or negedge rst_n)
     begin
        if(!rst_n)
          begin
             arb_state <= 0;
             imem_ack <= 0;
             dmem_ack <= 0;
             n_mem_stall <= 0;
          end
        else
          begin
             case(arb_state)
               0 :
                 begin
                    if (flash_done)
                      begin
                         if (dmem_req & dmem_wr)
                           begin
                              // WRITE DMEM
                              arb_state <= 7;
                              dmem_ack <= 1;
                              imem_ack <= 0;
                              n_mem_stall <= 1;
                           end
                         else if (dmem_req & !dmem_wr)
                           begin
                              // READ DMEM
                              arb_state <= 7;
                              dmem_ack <= 1;
                              imem_ack <= 0;
                              n_mem_stall <= 1;
                           end
                         else
                           begin
                              arb_state <= 7;
                              dmem_ack <= 0;;
                              imem_ack <= 1;
                              n_mem_stall <= 1;
                           end // else: !if(dmem_req & dmem_wr)
                      end // if (flash_done)
                 end
               7:
                 begin
                    arb_state <= 0;
                    dmem_ack <= 0;
                    imem_ack <= 0;
                    n_mem_stall <= 0;
                 end
             endcase // case (arb_state)
          end
     end

   processor processor(.clk(clk),
                       .n_reset(rst_n),
                       .n_ext_stall(n_stall),
                       .imem_addr_out(imem_addr_out),
                       .imem_data_in(mem_data_out),
                       .imem_ack(1'b1),
                       .dmem_addr_out(dmem_addr_out),
                       .dmem_data_in(32'hfedebeda),
                       .dmem_req(dmem_req),
                       .dmem_wr(dmem_wr),
                       .dmem_ack(dmem_ack),
                       .dmem_data_out(dmem_data_out),
                       .mfc0({{31{1'b0}}, tx_data_ready}),
                       .debug_pc(debug_pc),
                       .debug_data(debug_data),
                       .debug_data2(debug_data2));

   assign mem_read_addr = imem_addr_out[9:0];

   processor_ram processor_ram(.clk(clk),
                               .rst(rst),
                               .w_strobe(flash_strobe),
                               .w_addr(mem_write_addr),
                               .w_data(flash_data_out),
                               .r_addr(mem_read_addr),
                               .r_data(mem_data_out));

   always@(posedge clk or negedge rst_n)
     begin
        if(!rst_n)
          begin
             tx_data <= 0;
             tx_data_valid <= 0;
          end
        else
          if (dmem_req && dmem_wr && dmem_addr_out[31:28] == 4'hf)
            begin
               tx_data <= dmem_data_out[7:0];
               tx_data_valid <= 1;
            end
          else
            begin
               tx_data_valid <= 0;
            end
     end

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

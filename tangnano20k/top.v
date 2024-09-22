module top(
           // Clock and Reset
           input         clk,
           input         rst,

           // UART Tx
           output        uart_tx,

           // LED (Active LOW)
           output [5:0]  led,

           // spi flash interface
           output        mspi_cs,
           output        mspi_clk,
           output        mspi_di,
           input         mspi_do,

`ifdef IVERLOG
           // DEBUG
           output [31:0] debug_pc,
           output [31:0] debug_data,
           output [31:0] debug_data2
`endif
           );

`ifdef IVERLOG
   parameter             FLASH_START = 24'h000000;
`else
   parameter             FLASH_START = 24'h500000;
`endif

   parameter             CLK_FRE  = 27;//Mhz
   parameter             UART_FRE = 115200;


   reg [7:0]             tx_data;
   reg                   tx_data_valid;
   wire                  tx_data_ready;

   wire                  rst_n = !rst;

   wire                  flash_done;
   wire                  flash_strobe;
   wire [31:0]           flash_data_out;

   reg [4:0]             led_cnt;

   assign led = debug_pc[5:0];

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

   wire [31:0]           dmem_data_out;
   wire                  dmem_req;
   wire                  dmem_wr;

   wire [31:0]           imem_addr_out;
   wire [31:0]           current_instruction;
   wire [31:0]           dmem_addr_out;

   processor processor(.clk(clk),
                       .n_reset(rst_n),
                       .n_ext_stall(flash_done),
                       .imem_addr_out(imem_addr_out),
                       .imem_data_in(current_instruction),
                       .imem_ack(flash_done),
                       .dmem_addr_out(dmem_addr_out),
                       .dmem_data_in(32'hfedebeda),
                       .dmem_data_out(dmem_data_out),
                       .dmem_req(dmem_req),
                       .dmem_wr(dmem_wr),
                       .dmem_ack(1'b1),
                       .debug_pc(debug_pc));
                       //.debug_data(debug_data),
                       //.debug_data2(debug_data2));

   assign debug_data = current_instruction;
   assign debug_data2 = dmem_data_out;

   reg [9:0]             mem_write_addr;
   reg [9:0]             mem_read_addr;

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
             tx_data <= 8'h00;
             tx_data_valid <= 0;
          end
        else
          if (dmem_req)
            begin
               $display("DMEM_REQ");
               
               tx_data <= dmem_data_out[7:0];
               tx_data_valid <= 1;
            end
          else
            tx_data_valid <= 0;
     end

   processor_ram processor_ram(.clk(clk),
                               .rst(rst),
                               .w_strobe(flash_strobe),
                               .w_addr(mem_write_addr),
                               .w_data(flash_data_out),
                               .r_addr(imem_addr_out[9:0]),
                               .r_data(current_instruction));

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

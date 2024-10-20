module top(
           // Clock and Reset
           input        clk_cpu,
           input        clk_pixel,
           input        rst_n,

           // UART Tx
           output       uart_tx,

           // LED (Active LOW)
           output [5:0] led,

           // spi flash interface
           output       mspi_cs,
           output       mspi_clk,
           output       mspi_di,
           input        mspi_do,

           output [9:0] tmds_r,
           output [9:0] tmds_g,
           output [9:0] tmds_b
);

`ifdef IVERLOG
   parameter            FLASH_START = 24'h000000;
`else
   parameter            FLASH_START = 24'h500000;
`endif

   parameter            CLK_FRE  = 25200000; //Hz
   parameter            UART_FRE = 115200;


   wire                 tx_data_ready;

   wire                 flash_done;
   wire                 flash_strobe;
   wire [31:0]          flash_data_out;

   reg [4:0]            led_cnt;

   wire                 mem_strobe, video_strobe;
   wire [31:0]          mem_write_data;
   wire [9:0]           mem_write_addr;

   wire                 ram_sel, uart_sel, video_sel;

   reg [18:0]           memcpy_write_addr;
   reg [9:0]            mem_read_addr;

   wire [31:0]          dmem_data_out;
   wire [31:0]          mem_data_out;
   wire [23:0]          imem_addr_out, dmem_addr_out;
   wire                 dmem_req, dmem_wr;

   wire                 proc_stall_n;
   wire                 imem_ack;
   wire                 proc_write_strobe;
   reg [31:0]           mem_read_reg;

   wire [19:0]          icache_read_addr;
   wire [31:0]          icache_imem_data_out;
   wire                 icache_ram_rd;

   assign led[0] = !led_cnt[0];
   assign led[1] = !led_cnt[1];
   assign led[2] = !led_cnt[2];
   assign led[3] = !led_cnt[3];
   assign led[4] = !led_cnt[4];
   assign led[5] = !flash_done;

   always@(posedge clk_cpu or negedge rst_n)
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

   flash_reader flash_reader(.clk(clk_cpu),
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

   always@(posedge clk_cpu or negedge rst_n)
     begin
        if(!rst_n)
          memcpy_write_addr <= 0;
        else
          if (flash_strobe)
            begin
               memcpy_write_addr <= memcpy_write_addr + 1;
            end
     end

   memory_arbiter memory_arbiter(
                                 .clk_cpu(clk_cpu),
                                 .rst_n(rst_n),
                                 .halt_n(flash_done),
                                 .dmem_req(dmem_req),
                                 .dmem_wr(dmem_wr),
                                 .memory_ack(1'b1),
                                 .write_address(dmem_addr_out),
                                 .stall_n(proc_stall_n),
                                 .wr_strobe(proc_write_strobe),
                                 .video_sel(video_sel),
                                 .uart_sel(uart_sel),
                                 .ram_sel(ram_sel)
                                 );

   assign mem_read_addr = imem_ack ? dmem_addr_out[9:0] : icache_read_addr[9:0];
   assign mem_write_addr = flash_done ? dmem_addr_out[9:0] : memcpy_write_addr[9:0];
   assign mem_write_data = flash_done ? dmem_data_out : flash_data_out;
   assign mem_strobe = flash_done ? (dmem_wr & ram_sel & imem_ack) : flash_strobe;

   processor_ram processor_ram(.clk(clk_cpu),
                               .rst(rst),
                               .w_strobe(mem_strobe),
                               .w_addr(mem_write_addr),
                               .w_data(mem_write_data),
                               .r_addr(mem_read_addr),
                               .r_data(mem_data_out));

   icache icache(
              .rst_n(rst_n),
              .halt_n(flash_done),
              .imem_addr(imem_addr_out[19:0]),
              .imem_data(icache_imem_data_out),
              .imem_ack(imem_ack),
              .ram_clk(clk_cpu),
              .ram_addr(icache_read_addr),
              .ram_data(mem_data_out),
              .ram_data_ready(1'b1),
              .ram_rd(icache_ram_rd)
              );

   processor processor(.clk(clk_cpu),
                       .n_reset(rst_n),
                       .imem_addr_out(imem_addr_out),
                       .imem_data_in(icache_imem_data_out),
                       .imem_ack(imem_ack & proc_stall_n),
                       .dmem_addr_out(dmem_addr_out),
                       .dmem_data_in(mem_data_out),
                       .dmem_req(dmem_req),
                       .dmem_wr(dmem_wr),
                       .dmem_data_out(dmem_data_out),
                       .mfc0({{31{1'b0}}, tx_data_ready}));

   always@(posedge clk_cpu)
     begin
        if (proc_write_strobe)
          $display("PROC_WRITE: %x == %x", dmem_data_out, dmem_addr_out);
     end

   video video(.clk_pixel(clk_pixel),
               .clk_cpu(clk_cpu),
               .rst_n(rst_n),
               .addr_in(dmem_addr_out),
               .data_in(dmem_data_out),
               .sel(video_sel),
               .wr(proc_write_strobe),
               .tmds_r(tmds_r),
               .tmds_g(tmds_g),
               .tmds_b(tmds_b));

   uart_tx#
     (
      .CLK_FRE(CLK_FRE),
      .BAUD_RATE(UART_FRE)
      ) uart_tx_inst
       (
        .clk            (clk_cpu),
        .rst_n          (rst_n),
        .tx_data        (dmem_data_out[7:0]),
        .tx_data_valid  (proc_write_strobe & uart_sel),
        .tx_data_ready  (tx_data_ready),
        .tx_pin         (uart_tx)
        );
endmodule

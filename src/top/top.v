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

   // UART PARAMETERS
   parameter            CLK_FRE  = 25200000; //Hz
   parameter            UART_FRE = 115200;

   // DEBUG
   reg [4:0]            led_cnt;

   // UART
   wire                 uart_tx_data_ready;

   // FLASH READER
   wire                 flash_done;
   wire                 flash_strobe;
   wire [31:0]          flash_data_out;
   wire [23:0]          flash_mem_address;

   // ARBITER
   wire                 arbiter_uart_sel;
   wire                 arbiter_video_sel;
   wire                 arbiter_write_strobe;
   wire                 arbiter_proc_stall_n;

   // PROCESSOR
   wire [31:0]          proc_dmem_data_out;
   wire [31:0]          proc_dmem_data_in;
   wire [23:0]          proc_imem_addr_out;
   wire [23:0]          proc_dmem_addr_out;
   wire                 proc_dmem_req;
   wire                 proc_dmem_wr;

   // MEMCTRL
   wire [19:0]          mem_ctrl_memory_addr;
   wire                 mem_ctrl_memory_ack;
   wire                 mem_ctrl_write_strobe;
   wire [31:0]          mem_ctrl_memory_data_out;

   // ICACHE
   wire                 icache_imem_ack;
   wire [31:0]          icache_imem_data_out;
   wire                 icache_req_data_16;
   wire [19:0]          icache_req_address;
   wire [31:0]          icache_rsp_data;
   wire                 icache_rsp_data_strobe;

   // RAM
   wire [9:0]           ram_read_addr;
   wire [9:0]           ram_write_addr;
   wire                 ram_write_strobe;
   wire [31:0]          ram_write_data;
   wire [31:0]          ram_read_data;

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
                             .word_count(24'h00400),
                             .mem_address(flash_mem_address),
                             .strobe(flash_strobe),
                             .done(flash_done),
                             .data_out(flash_data_out),
                             .spi_cs(mspi_cs),
                             .spi_clk(mspi_clk),
                             .spi_mosi(mspi_di),
                             .spi_miso(mspi_do));

   assign ram_read_addr = mem_ctrl_memory_addr[9:0];
   assign ram_write_addr = flash_done ? mem_ctrl_memory_addr[9:0] : flash_mem_address[9:0];
   assign ram_write_data = flash_done ? mem_ctrl_memory_data_out : flash_data_out;
   assign ram_write_strobe = flash_done ? mem_ctrl_write_strobe : flash_strobe;

   processor_ram processor_ram(.clk(clk_cpu),
                               .rst(rst),
                               .w_strobe(ram_write_strobe),
                               .w_addr(ram_write_addr),
                               .w_data(ram_write_data),
                               .r_addr(ram_read_addr),
                               .r_data(ram_read_data));

   memory_controller memory_controller(
                                       .clk_cpu(clk_cpu),
                                       .clk_ram(clk_cpu),
                                       .rst_n(rst_n),
                                       // ICACHE signals
                                       .icache_req_data_16(icache_req_data_16),
                                       .icache_req_address(icache_req_address),
                                       .icache_rsp_data(icache_rsp_data),
                                       .icache_rsp_data_strobe(icache_rsp_data_strobe),

                                       // ARBITER signals
                                       .arbiter_ram_read_access(arbiter_ram_read_access),
                                       .arbiter_ram_write_access(arbiter_ram_write_access),
                                       .arbiter_memory_ack(mem_ctrl_memory_ack),

                                       // PROCESSOR signals
                                       .proc_dmem_addr(proc_dmem_addr_out[19:0]),
                                       .proc_dmem_data_out(proc_dmem_data_out),
                                       .proc_dmem_data_in(proc_dmem_data_in),
                                       .proc_dmem_req(proc_dmem_req),
                                       .proc_dmem_wr(proc_dmem_wr),

                                       // Memory Signals
                                       .memory_addr(mem_ctrl_memory_addr),
                                       .memory_write_strobe(mem_ctrl_write_strobe),
                                       .memory_data_in(ram_read_data),
                                       .memory_data_out(mem_ctrl_memory_data_out)
                                       );

   icache icache(
                 .clk_cpu(clk_cpu),
                 .clk_ram(clk_cpu),
                 .rst_n(rst_n),
                 .halt_n(flash_done),
                 // To memory controller
                 .req_data_16(icache_req_data_16),
                 .req_address(icache_req_address),
                 .rsp_data(icache_rsp_data),
                 .rsp_data_strobe(icache_rsp_data_strobe),
                 // To processor
                 .imem_addr(proc_imem_addr_out[19:0]),
                 .imem_data(icache_imem_data_out),
                 .imem_ack(icache_imem_ack)
                 );

   memory_arbiter memory_arbiter(
                                 .clk_cpu(clk_cpu),
                                 .rst_n(rst_n),
                                 .halt_n(flash_done),
                                 .imem_ack(icache_imem_ack),
                                 .dmem_req(proc_dmem_req),
                                 .dmem_wr(proc_dmem_wr),
                                 .memory_ack(mem_ctrl_memory_ack),
                                 .write_address(proc_dmem_addr_out),
                                 .stall_n(arbiter_proc_stall_n),
                                 .ram_read_access(arbiter_ram_read_access),
                                 .ram_write_access(arbiter_ram_write_access),
                                 .peripheral_write_strobe(arbiter_write_strobe),
                                 .video_sel(arbiter_video_sel),
                                 .uart_sel(arbiter_uart_sel)
                                 );

   processor processor(.clk(clk_cpu),
                       .n_reset(rst_n),
                       .imem_addr_out(proc_imem_addr_out),
                       .imem_data_in(icache_imem_data_out),
                       .imem_ack(icache_imem_ack & arbiter_proc_stall_n),
                       .dmem_addr_out(proc_dmem_addr_out),
                       .dmem_data_in(proc_dmem_data_in),
                       .dmem_req(proc_dmem_req),
                       .dmem_wr(proc_dmem_wr),
                       .dmem_data_out(proc_dmem_data_out),
                       .mfc0({{31{1'b0}}, uart_tx_data_ready}));

   always@(posedge clk_cpu)
     begin
        if (arbiter_write_strobe)
          $display("PERIPHERAL_WRITE: (%d:%d) %x == %x (%d:%d)", proc_dmem_req, proc_dmem_wr,
                   proc_dmem_data_out, proc_dmem_addr_out,
                   arbiter_uart_sel, arbiter_video_sel);
     end

   video video(.clk_pixel(clk_pixel),
               .clk_cpu(clk_cpu),
               .rst_n(rst_n),
               .addr_in(proc_dmem_addr_out),
               .data_in(proc_dmem_data_out),
               .sel(arbiter_video_sel),
               .wr(arbiter_write_strobe),
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
        .tx_data        (proc_dmem_data_out[7:0]),
        .tx_data_valid  (arbiter_write_strobe & arbiter_uart_sel),
        .tx_data_ready  (uart_tx_data_ready),
        .tx_pin         (uart_tx)
        );
endmodule

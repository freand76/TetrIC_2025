module top(
           // Clock and Reset
           input         clk_cpu,
           input         clk_pixel,
           input         clk_ram,       // SDRAM controller clock
           input         rst_n,

           // UART Tx
           output       uart_tx,

           // LED (Active LOW)
           output [5:0] led,

           // spi flash interface
           output       mspi_cs,
           output       mspi_clk,
           output       mspi_di,
           input        mspi_do,

           // SDRAM (O_sdram_clk is driven with clk_ram by the board top)
           output        O_sdram_cke,
           output        O_sdram_cs_n,
           output        O_sdram_cas_n,
           output        O_sdram_ras_n,
           output        O_sdram_wen_n,
           inout [31:0]  IO_sdram_dq,
           output [10:0] O_sdram_addr,
           output [1:0]  O_sdram_ba,
           output [3:0]  O_sdram_dqm,

           output [9:0] tmds_r,
           output [9:0] tmds_g,
           output [9:0] tmds_b
           );

`ifdef IVERLOG
   parameter            FLASH_START = 24'h000000;
   parameter            COPY_WORDS  = 24'h000400;  // keep simulation short
`else
   parameter            FLASH_START = 24'h500000;
   parameter            COPY_WORDS  = 24'd262144;  // 1 MByte flash -> SDRAM address 0
`endif
   parameter            SDRAM_FREQ_KHZ = 50_400;

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
   wire                 mem_ctrl_memory_ack;
   wire                 arbiter_ram_read_access;
   wire                 arbiter_ram_write_access;
   wire                 sdram_ready;      // clk_cpu
   wire                 copy_done;        // clk_cpu: flash copied to SDRAM
   wire                 copy_done_ram;    // clk_ram

   // ICACHE
   wire                 icache_imem_ack;
   wire [31:0]          icache_imem_data_out;
   wire                 icache_req;
   wire [19:0]          icache_req_address;
   wire                 icache_req_ack;
   wire [31:0]          icache_rsp_data;
   wire                 icache_rsp_data_strobe;

   // VIDEO
   wire                 video_req;
   wire [19:0]          video_req_address;
   wire [8:0]           video_req_len;
   wire [31:0]          video_status;
   wire                 video_req_ack;
   wire [31:0]          video_rsp_data;
   wire                 video_rsp_data_strobe;

   // CPU domain reset
   wire                 rst_cpu_n;
   reset_sync rs_cpu(.clk(clk_cpu), .rst_n_in(rst_n), .rst_n_out(rst_cpu_n));

   assign led[0] = !led_cnt[0];
   assign led[1] = !led_cnt[1];
   assign led[2] = !led_cnt[2];
   assign led[3] = !led_cnt[3];
   assign led[4] = !led_cnt[4];
   assign led[5] = !copy_done;

   always@(posedge clk_cpu or negedge rst_cpu_n)
     begin
        if(rst_cpu_n == 1'b0)
          begin
             led_cnt <= 0;
          end
        else
          if (flash_strobe)
            begin
               led_cnt <= led_cnt + 1;
            end
     end // always@ (posedge clk or negedge rst_n)

   // Copy COPY_WORDS words from flash to SDRAM, once the SDRAM is initialised
   flash_reader flash_reader(.clk(clk_cpu),
                             .n_reset(rst_cpu_n),
                             .start(sdram_ready),
                             .address(FLASH_START),
                             .word_count(COPY_WORDS),
                             .mem_address(flash_mem_address),
                             .strobe(flash_strobe),
                             .done(flash_done),
                             .data_out(flash_data_out),
                             .spi_cs(mspi_cs),
                             .spi_clk(mspi_clk),
                             .spi_mosi(mspi_di),
                             .spi_miso(mspi_do));

   memory_controller #(.SDRAM_FREQ_KHZ(SDRAM_FREQ_KHZ),
                       .COPY_WORDS(COPY_WORDS))
   memory_controller(
                     .clk_cpu(clk_cpu),
                     .clk_ram(clk_ram),
                     .rst_n(rst_n),
                     // FLASH copy
                     .flash_strobe(flash_strobe),
                     .flash_mem_address(flash_mem_address),
                     .flash_data(flash_data_out),
                     .sdram_ready_cpu(sdram_ready),
                     .copy_done_cpu(copy_done),
                     .copy_done_ram(copy_done_ram),

                     // ICACHE signals
                     .icache_req(icache_req),
                     .icache_req_address(icache_req_address),
                     .icache_req_ack(icache_req_ack),
                     .icache_rsp_data(icache_rsp_data),
                     .icache_rsp_data_strobe(icache_rsp_data_strobe),

                     // VIDEO signals
                     .video_req(video_req),
                     .video_req_address(video_req_address),
                     .video_req_len(video_req_len),
                     .video_req_ack(video_req_ack),
                     .video_rsp_data(video_rsp_data),
                     .video_rsp_data_strobe(video_rsp_data_strobe),

                     // ARBITER signals
                     .arbiter_ram_read_access(arbiter_ram_read_access),
                     .arbiter_ram_write_access(arbiter_ram_write_access),
                     .arbiter_memory_ack(mem_ctrl_memory_ack),

                     // PROCESSOR signals
                     .proc_dmem_addr(proc_dmem_addr_out[19:0]),
                     .proc_dmem_data_out(proc_dmem_data_out),
                     .proc_dmem_data_in(proc_dmem_data_in),

                     // SDRAM
                     .sdram_dq(IO_sdram_dq),
                     .sdram_addr(O_sdram_addr),
                     .sdram_ba(O_sdram_ba),
                     .sdram_cs_n(O_sdram_cs_n),
                     .sdram_wen_n(O_sdram_wen_n),
                     .sdram_ras_n(O_sdram_ras_n),
                     .sdram_cas_n(O_sdram_cas_n),
                     .sdram_cke(O_sdram_cke),
                     .sdram_dqm(O_sdram_dqm)
                     );

   icache icache(
                 .clk_cpu(clk_cpu),
                 .clk_ram(clk_ram),
                 .rst_n(rst_n),
                 .halt_n(copy_done),
                 // To memory controller
                 .req(icache_req),
                 .req_address(icache_req_address),
                 .req_ack(icache_req_ack),
                 .rsp_data(icache_rsp_data),
                 .rsp_data_strobe(icache_rsp_data_strobe),
                 // To processor
                 .imem_addr(proc_imem_addr_out[19:0]),
                 .imem_data(icache_imem_data_out),
                 .imem_ack(icache_imem_ack)
                 );

   memory_arbiter memory_arbiter(
                                 .clk_cpu(clk_cpu),
                                 .rst_n(rst_cpu_n),
                                 .halt_n(copy_done),
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
                       .n_reset(rst_cpu_n),
                       .imem_addr_out(proc_imem_addr_out),
                       .imem_data_in(icache_imem_data_out),
                       .imem_ack(icache_imem_ack & arbiter_proc_stall_n),
                       .dmem_addr_out(proc_dmem_addr_out),
                       .dmem_data_in(proc_dmem_data_in),
                       .dmem_req(proc_dmem_req),
                       .dmem_wr(proc_dmem_wr),
                       .dmem_data_out(proc_dmem_data_out),
                       .mfc0({{31{1'b0}}, uart_tx_data_ready}),
                       .mfc1(video_status));

`ifdef IVERLOG
   always@(posedge clk_cpu)
     begin
        if (arbiter_write_strobe)
          $display("PERIPHERAL_WRITE: (%d:%d) %x == %x (%d:%d)", proc_dmem_req, proc_dmem_wr,
                   proc_dmem_data_out, proc_dmem_addr_out,
                   arbiter_uart_sel, arbiter_video_sel);
        if (proc_dmem_req && proc_dmem_wr && (proc_dmem_addr_out[23:20] == 4'h8))
          begin
             #100
             $finish;
          end
     end
`endif

   video video(.clk_pixel(clk_pixel),
               .clk_cpu(clk_cpu),
               .clk_ram(clk_ram),
               .rst_n(rst_n),
               .enable(copy_done_ram),
               .frame_counter(),
               .status(video_status),
               // To memory controller
               .req(video_req),
               .req_address(video_req_address),
               .req_len(video_req_len),
               .req_ack(video_req_ack),
               .rsp_data(video_rsp_data),
               .rsp_data_strobe(video_rsp_data_strobe),
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
        .rst_n          (rst_cpu_n),
        .tx_data        (proc_dmem_data_out[7:0]),
        .tx_data_valid  (arbiter_write_strobe & arbiter_uart_sel),
        .tx_data_ready  (uart_tx_data_ready),
        .tx_pin         (uart_tx)
        );
endmodule

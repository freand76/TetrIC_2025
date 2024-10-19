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

   reg [9:0]            memcpy_write_addr;
   reg [9:0]            mem_read_addr;

   wire [31:0]          dmem_data_out;
   wire [31:0]          mem_data_out;
   wire [31:0]          imem_addr_out, dmem_addr_out;
   wire                 dmem_req, dmem_wr;

   wire                 proc_write;
   wire                 proc_read;
   wire                 proc_stall_n;
   wire                 imem_ack;
   reg                  load_read_reg;
   reg                  proc_write_strobe;
   reg [31:0]           mem_read_reg;

   reg [1:0]            arb_state;

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

   assign proc_write = (dmem_req & dmem_wr & imem_ack);
   assign proc_read = (dmem_req & !dmem_wr);
   assign proc_stall_n = !(proc_read & ((arb_state == 1) || (arb_state == 2)));

   always@(posedge clk_cpu or negedge rst_n)
     begin
        if(!rst_n)
          begin
             arb_state <= 0;
             load_read_reg <= 0;
             proc_write_strobe <= 0;
          end
        else
          begin
             case(arb_state)
               0 :
                 begin
                    // WAIT FOR NVM to RAM copy
                    if (flash_done)
                      begin
                         arb_state <= 1;
                      end // if (flash_done)
                 end
               1 :
                 begin
                    if (dmem_req)
                      begin
                         // DMEM READ (Address out)
                         arb_state <= 2;
                         load_read_reg <= !dmem_wr;
                         proc_write_strobe <= dmem_wr;
                      end
                 end
               2:
                 begin
                    load_read_reg <= 0;
                    proc_write_strobe <= 0;
                    if (dmem_wr)
                      arb_state <= 1;
                    else
                      arb_state <= 3;
                 end
               3:
                 begin
                    // DMEM READ (Data to Reg) + IMEM ACK
                    if (!dmem_req)
                      begin
                         arb_state <= 1;
                      end
                 end
             endcase // case (arb_state)
          end
     end

   always@(posedge clk_cpu)
     begin
        if (load_read_reg)
          mem_read_reg <= mem_data_out;
     end

   assign ram_sel = dmem_addr_out[31:28] == 4'h0;
   assign video_sel = dmem_addr_out[31:28] == 4'he;
   assign uart_sel = dmem_addr_out[31:28] == 4'hf;

   assign mem_read_addr = ((arb_state == 1) & dmem_req & !dmem_wr) ?
                          dmem_addr_out[9:0] : icache_read_addr[9:0];
   assign mem_write_addr = flash_done ? dmem_addr_out[9:0] : memcpy_write_addr;
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
                       .dmem_data_in(mem_read_reg),
                       .dmem_req(dmem_req),
                       .dmem_wr(dmem_wr),
                       .dmem_data_out(dmem_data_out),
                       .mfc0({{31{1'b0}}, tx_data_ready}));

   always@(posedge clk_cpu)
     begin
        if (proc_write)
          $display("PROC_WRITE: %x == %x", dmem_data_out, dmem_addr_out);
     end

   video video(.clk_pixel(clk_pixel),
               .clk_cpu(clk_cpu),
               .rst_n(rst_n),
               .addr_in(dmem_addr_out),
               .data_in(dmem_data_out),
               .sel(video_sel),
               .wr(proc_write),
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

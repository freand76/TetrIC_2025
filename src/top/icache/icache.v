module icache(
              // Global reset / halt
              input         clk_cpu,
              input         clk_ram,
              input         rst_n,
              input         halt_n,

              // Memory Controller interface
              output reg    req_data_16,
              output [19:0] req_address,
              input [31:0]  rsp_data,
              input         rsp_data_strobe,

              // Processor interface
              input [19:0]  imem_addr,
              output [31:0] imem_data,
              output        imem_ack
              );

   wire                     cache_valid;
   reg [15:0]               cache_high_addr;
   reg [3:0]                cache_wr_addr;

   reg                      cache_write_enable;
   wire                     cache_addr_match;

   reg [1:0]                icache_state;

   always @ (posedge clk_ram)
     begin
        if (rsp_data_strobe)
          $display("ICACHE WR: %x:%x %x", imem_addr[19:4], cache_wr_addr, rsp_data);
     end

   localparam CACHE_STATE_INVALID = 0;
   localparam CACHE_STATE_READ = 1;
   localparam CACHE_STATE_VALID = 2;

   assign req_address = { cache_high_addr, 4'b0000 };

   assign cache_addr_match = (cache_high_addr == imem_addr[19:4]);
   assign cache_valid = (icache_state == CACHE_STATE_VALID);
   assign imem_ack = cache_valid & cache_addr_match;

   icache_mem icache_mem(
                         .wr_data(rsp_data),
                         .wr_en(rsp_data_strobe),
                         .clk_wr(clk_ram),
                         .wr_addr(cache_wr_addr),
                         .rd_addr(imem_addr[3:0]),
                         .rd_data(imem_data)
                  );

   always @ (posedge clk_ram, negedge rst_n)
     begin
        if (!rst_n)
          begin
             icache_state <= 0;
             cache_high_addr <= 0;
             cache_wr_addr <= 0;
             cache_write_enable <= 0;
          end
        else
          begin
             case(icache_state)
               CACHE_STATE_INVALID :
                 begin
                    if (halt_n)
                      begin
                         cache_high_addr <= imem_addr[19:4];
                         req_data_16 <= 1;
                         cache_wr_addr <= 0;
                         icache_state <= CACHE_STATE_READ;
                      end
                 end
               CACHE_STATE_READ:
                 begin
                    // First address out
                    icache_state <= CACHE_STATE_READ;
                    if (rsp_data_strobe)
                      begin
                         req_data_16 <= 0;
                         cache_wr_addr <= cache_wr_addr + 1;
                         if (cache_wr_addr == 4'b1111)
                           begin
                              icache_state <= CACHE_STATE_VALID;
                           end
                      end
                 end
               CACHE_STATE_VALID :
                 begin
                    if (!cache_addr_match)
                      begin
                         icache_state <= CACHE_STATE_INVALID;
                      end
                 end
             endcase // case (icache_state)
          end
     end

endmodule // icache

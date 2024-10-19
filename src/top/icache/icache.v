module icache(
              // Global reset / halt
              input         rst_n,
              input         halt_n,

              // Processor interface
              input [19:0]  imem_addr,
              output [31:0] imem_data,
              output        imem_ack,

              // Memory Interface
              input         ram_clk,
              output [19:0] ram_addr,
              input [31:0]  ram_data,
              input         ram_data_ready,
              output        ram_rd
              );

   wire                     cache_valid;
   reg [15:0]               cache_high_addr;
   reg [3:0]                cache_low_addr;
   reg [3:0]                cache_wr_addr;

   reg                      cache_write_enable;
   wire                     cache_addr_match;

   reg [1:0]                icache_state;

   always @ (posedge ram_clk)
     begin
        if (cache_write_enable)
          $display("ICACHE WR: %x:%x %x", imem_addr[19:4], cache_wr_addr, ram_data);
     end

   localparam CACHE_STATE_INVALID = 0;
   localparam CACHE_STATE_READ = 1;
   localparam CACHE_STATE_VALID = 2;

   assign cache_addr_match = (cache_high_addr == imem_addr[19:4]);
   assign cache_valid = (icache_state == CACHE_STATE_VALID);
   assign imem_ack = cache_valid & cache_addr_match;

   assign ram_addr = { cache_high_addr, cache_low_addr};

   icache_mem icache_mem(
                         .wr_data(ram_data),
                         .wr_en(cache_write_enable),
                         .clk_wr(ram_clk),
                         .wr_addr(cache_wr_addr),
                         .rd_addr(imem_addr[3:0]),
                         .rd_data(imem_data)
                  );

   always @ (posedge ram_clk, negedge rst_n)
     begin
        if (!rst_n)
          begin
             icache_state <= 0;
             cache_high_addr <= 0;
             cache_low_addr <= 0;
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
                         cache_low_addr <= 0;
                         icache_state <= CACHE_STATE_READ;
                      end
                 end
               CACHE_STATE_READ:
                 begin
                    // First address out
                    icache_state <= CACHE_STATE_READ;
                    cache_wr_addr <= cache_low_addr;
                    cache_write_enable <= 1;
                    cache_low_addr <= cache_low_addr + 1'b1;
                    if (cache_low_addr == 4'b1111)
                      begin
                         icache_state <= CACHE_STATE_VALID;
                      end
                 end
               CACHE_STATE_VALID :
                 begin
                    cache_write_enable <= 0;
                    if (!cache_addr_match)
                      begin
                         icache_state <= CACHE_STATE_INVALID;
                      end
                 end
             endcase // case (icache_state)
          end
     end

endmodule // icache

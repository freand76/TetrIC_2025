module memory_controller(
                         input             clk_cpu,
                         input             clk_ram,
                         input             rst_n,
                         // ICACHE signals
                         input             icache_req_data_16,
                         input [19:0]      icache_req_address,
                         output [31:0]     icache_rsp_data,
                         output reg        icache_rsp_data_strobe,

                         // Memopry signals
                         output reg [19:0] memory_read_addr,
                         input [31:0]      memory_data_in
                         );

   assign icache_rsp_data = memory_data_in;

   localparam                              IDLE = 0;
   localparam                              READ_ICACHE_BURST = 1;
   localparam                              READ_ICACHE_BURST_END = 2;

   reg [3:0]                               mem_ctrl_state;
   reg [3:0]                               read_count;

   always @ (posedge clk_ram, negedge rst_n)
     begin
        if (!rst_n)
          begin
             mem_ctrl_state <= IDLE;
             memory_read_addr <= 0;
             read_count <= 0;
             icache_rsp_data_strobe <= 0;
          end
        else
          case(mem_ctrl_state)
            IDLE :
              begin
                 if (icache_req_data_16)
                   begin
                      mem_ctrl_state <= READ_ICACHE_BURST;
                      memory_read_addr <= icache_req_address;
                      read_count <= 0;
                   end
              end
            READ_ICACHE_BURST:
              begin
                 icache_rsp_data_strobe <= 1;
                 read_count <= read_count + 1;
                 memory_read_addr <= memory_read_addr + 1;
                 if (read_count == 4'hf)
                   begin
                      mem_ctrl_state <= READ_ICACHE_BURST_END;
                   end
              end
            READ_ICACHE_BURST_END:
              begin
                 icache_rsp_data_strobe <= 0;
                 mem_ctrl_state <= IDLE;
              end
          endcase // case (mem_ctrl_state)
     end
endmodule

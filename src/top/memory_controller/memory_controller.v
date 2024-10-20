module memory_controller(
                         input             clk_cpu,
                         input             clk_ram,
                         input             rst_n,
                         // ICACHE signals
                         input             icache_req_data_16,
                         input [19:0]      icache_req_address,
                         output [31:0]     icache_rsp_data,
                         output reg        icache_rsp_data_strobe,

                         // ARBITER signals
                         input             arbiter_ram_sel,
                         input             arbiter_wr_strobe,
                         output reg        arbiter_memory_ack,

                         // PROCESSOR signals
                         input [19:0]      proc_dmem_addr,
                         input [31:0]      proc_dmem_data_out,
                         output reg [31:0] proc_dmem_data_in,
                         input             proc_dmem_req,
                         input             proc_dmem_wr,

                         // MEMORY signals
                         output reg [19:0] memory_addr,
                         output            memory_write_strobe,
                         input [31:0]      memory_data_in
                         );

   assign memory_write_strobe = arbiter_wr_strobe & arbiter_ram_sel;
   assign icache_rsp_data = memory_data_in;
   assign proc_dmem_data_in = memory_data_in;

   localparam                              IDLE = 0;
   localparam                              READ_ICACHE_BURST = 1;
   localparam                              READ_ICACHE_BURST_END = 2;
   localparam                              READ_DMEM_SINGLE = 3;
   localparam                              READ_DMEM_SINGLE_ACK = 4;
   localparam                              WRITE_DMEM_SINGLE = 5;
   localparam                              WRITE_DMEM_SINGLE_ACK = 6;

   reg [3:0]                               mem_ctrl_state;
   reg [3:0]                               read_count;

   always @ (posedge clk_ram, negedge rst_n)
     begin
        if (!rst_n)
          begin
             mem_ctrl_state <= IDLE;
             memory_addr <= 0;
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
                      memory_addr <= icache_req_address;
                      read_count <= 0;
                   end
                 else if (proc_dmem_req && !proc_dmem_wr)
                   begin
                      // READ
                      mem_ctrl_state <= READ_DMEM_SINGLE;
                      memory_addr <= proc_dmem_addr;
                   end
                 else if (proc_dmem_req && proc_dmem_wr)
                   begin
                      // WRITE
                      mem_ctrl_state <= WRITE_DMEM_SINGLE;
                      memory_addr <= proc_dmem_addr;
                   end
              end
            READ_ICACHE_BURST:
              begin
                 icache_rsp_data_strobe <= 1;
                 read_count <= read_count + 1;
                 memory_addr <= memory_addr + 1;
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
            READ_DMEM_SINGLE:
              begin
                 // Data Ready one clock after address
                 arbiter_memory_ack <= 1;
                 mem_ctrl_state <= READ_DMEM_SINGLE_ACK;
              end
            READ_DMEM_SINGLE_ACK:
              begin
                 arbiter_memory_ack <= 0;
                 mem_ctrl_state <= IDLE;
              end
            WRITE_DMEM_SINGLE:
              begin
                 // Data Ready one clock after address
                 arbiter_memory_ack <= 1;
                 mem_ctrl_state <= WRITE_DMEM_SINGLE_ACK;
              end
            WRITE_DMEM_SINGLE_ACK:
              begin
                 arbiter_memory_ack <= 0;
                 mem_ctrl_state <= IDLE;
              end
          endcase // case (mem_ctrl_state)
     end
endmodule

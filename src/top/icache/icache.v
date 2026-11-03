// Instruction cache: direct mapped, 2 lines x 8 words (the 16 word icache_mem).
//
//   imem_addr[19:4] : tag
//   imem_addr[3]    : line
//   imem_addr[2:0]  : word in line
//
// A miss requests an 8 word burst from the memory controller. The request is
// started from clk_cpu with a toggle; the fill itself (memory controller
// handshake and icache_mem writes) runs in clk_ram, and a toggle back marks
// the line valid. icache_mem is LUT RAM with asynchronous read, so the
// processor side reads it directly in clk_cpu.

module icache(
              // Global reset / halt
              input             clk_cpu,
              input             clk_ram,
              input             rst_n,
              input             halt_n,      // clk_cpu: low until memory is ready

              // Memory Controller interface (clk_ram)
              output reg        req,
              output reg [19:0] req_address,
              input             req_ack,
              input [31:0]      rsp_data,
              input             rsp_data_strobe,

              // Processor interface (clk_cpu)
              input [19:0]      imem_addr,
              output [31:0]     imem_data,
              output            imem_ack
              );

   wire rst_cpu_n, rst_ram_n;
   reset_sync rs_cpu(.clk(clk_cpu), .rst_n_in(rst_n), .rst_n_out(rst_cpu_n));
   reset_sync rs_ram(.clk(clk_ram), .rst_n_in(rst_n), .rst_n_out(rst_ram_n));

   // ============================ clk_cpu ==============================
   reg [15:0] tag0, tag1;
   reg        valid0, valid1;
   reg        filling;
   reg        fill_line;          // line being filled
   reg [16:0] fill_addr;          // imem_addr[19:3] of the line being filled
   reg        fill_tog;
   reg        done_tog;           // clk_ram
   wire       done_ev;

   wire       line = imem_addr[3];
   wire       hit  = line ? (valid1 && tag1 == imem_addr[19:4])
                          : (valid0 && tag0 == imem_addr[19:4]);

   assign imem_ack = hit;

   sync_toggle st_done(.clk(clk_cpu), .rst_n(rst_cpu_n), .toggle(done_tog), .pulse(done_ev));

   always @(posedge clk_cpu or negedge rst_cpu_n)
     if (!rst_cpu_n)
       begin
          tag0 <= 0;
          tag1 <= 0;
          valid0 <= 0;
          valid1 <= 0;
          filling <= 0;
          fill_line <= 0;
          fill_addr <= 0;
          fill_tog <= 0;
       end
     else
       begin
          if (filling)
            begin
               if (done_ev)
                 begin
                    filling <= 0;
                    if (fill_line) valid1 <= 1;
                    else           valid0 <= 1;
                 end
            end
          else if (halt_n && !hit)
            begin
               filling <= 1;
               fill_line <= line;
               fill_addr <= imem_addr[19:3];
               fill_tog <= ~fill_tog;
               if (line)
                 begin
                    tag1 <= imem_addr[19:4];
                    valid1 <= 0;
                 end
               else
                 begin
                    tag0 <= imem_addr[19:4];
                    valid0 <= 0;
                 end
            end
       end

   // ============================ clk_ram ==============================
   wire       fill_ev;
   reg        wr_line;
   reg [2:0]  wr_cnt;

   sync_toggle st_fill(.clk(clk_ram), .rst_n(rst_ram_n), .toggle(fill_tog), .pulse(fill_ev));

   always @(posedge clk_ram or negedge rst_ram_n)
     if (!rst_ram_n)
       begin
          req <= 0;
          req_address <= 0;
          wr_line <= 0;
          wr_cnt <= 0;
          done_tog <= 0;
       end
     else
       begin
          if (fill_ev)
            begin
               // fill_addr / fill_line are stable until done_tog toggles
               req <= 1;
               req_address <= {fill_addr, 3'b000};
               wr_line <= fill_line;
               wr_cnt <= 0;
            end
          else if (req_ack)
            req <= 0;

          if (rsp_data_strobe)
            begin
               wr_cnt <= wr_cnt + 1;
               if (wr_cnt == 3'd7)
                 done_tog <= ~done_tog;
            end
       end

`ifdef ICACHE_DEBUG
   always @(posedge clk_ram)
     if (rsp_data_strobe)
       $display("ICACHE WR: %x:%x %x", req_address[19:3], wr_cnt, rsp_data);
`endif

   icache_mem icache_mem(
                         .wr_data(rsp_data),
                         .wr_en(rsp_data_strobe),
                         .clk_wr(clk_ram),
                         .wr_addr({wr_line, wr_cnt}),
                         .rd_addr(imem_addr[3:0]),
                         .rd_data(imem_data)
                         );

endmodule // icache

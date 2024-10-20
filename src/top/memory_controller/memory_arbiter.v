module memory_arbiter(
                      // CPU clock
                      input        clk_cpu,
                      // Global reset
                      input        rst_n,

                      input        halt_n,

                      input        dmem_req, // High from processor for data access
                      input        dmem_wr, // High from processor for data write acess
                      input        memory_ack, // High from memory when data access is done

                      input [23:0] write_address,

                      // STALL CPU
                      output       stall_n,

                      // OUTPUT
                      output reg   wr_strobe,
                      output       video_sel,
                      output       uart_sel,
                      output       ram_sel
                      );

   localparam                      HALTED = 0;
   localparam                      IDLE = 1;
   localparam                      WRITE_STROBE = 2;
   localparam                      READ_ACCESS = 3;

   reg [1:0]                       arb_state;

   wire                            read_stall, write_stall;

   assign read_stall = (dmem_req && (arb_state == IDLE));
   assign write_stall = (dmem_req  && (arb_state == IDLE));
   assign stall_n = !(read_stall | write_stall);

   assign ram_sel = write_address[23:20] == 4'h0;
   assign video_sel = write_address[23:20] == 4'he;
   assign uart_sel = write_address[23:20] == 4'hf;

   always@(posedge clk_cpu or negedge rst_n)
     begin
        if(!rst_n)
          begin
             arb_state <= 0;
             wr_strobe <= 0;
          end
        else
          begin
             case(arb_state)
               HALTED :
                 begin
                    // WAIT FOR NVM to RAM copy
                    if (halt_n)
                      begin
                         arb_state <= IDLE;
                      end // if (flash_done)
                 end
               IDLE :
                 begin
                    if (dmem_req & !dmem_wr & ram_sel)
                      begin
                         // READ RAM
                         if (memory_ack)
                           begin
                              arb_state <= READ_ACCESS;
                           end
                      end
                    else if (dmem_req & dmem_wr & ram_sel)
                      begin
                         // Write RAM (ack needed before we can go ahead)
                         if (memory_ack)
                           begin
                              wr_strobe <= dmem_wr;
                              arb_state <= WRITE_STROBE;
                           end
                      end
                    else if (dmem_req & dmem_wr &!ram_sel)
                      begin
                         // Write Peripheral (no ack needed, they are always ready)
                         wr_strobe <= dmem_wr;
                         arb_state <= WRITE_STROBE;
                      end
                 end // case: IDLE
               WRITE_STROBE:
                 begin
                    wr_strobe <= 0;
                    arb_state <= IDLE;
                 end
               READ_ACCESS:
                 begin
                    // DMEM READ low
                    if (!dmem_req)
                      begin
                         arb_state <= IDLE;
                      end
                 end
             endcase // case (arb_state)
          end
     end

endmodule // memory_arbiter

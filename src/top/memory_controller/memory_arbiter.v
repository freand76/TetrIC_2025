module memory_arbiter(
                      // CPU clock
                      input        clk_cpu,
                      // Global reset
                      input        rst_n,

                      input        halt_n,

                      input        imem_ack, // High when processor consumes instructions
                      input        dmem_req, // High from processor for data access
                      input        dmem_wr, // High from processor for data write acess
                      input        memory_ack, // High from memory when data access is done

                      input [23:0] write_address,

                      // STALL CPU
                      output       stall_n,

                      // OUTPUT
                      output reg   ram_read_access,
                      output reg   ram_write_access,
                      output reg   peripheral_write_strobe,
                      output       video_sel,
                      output       uart_sel
                      );

   localparam                      HALTED = 0;
   localparam                      IDLE = 1;
   localparam                      PERIPHERAL = 2;
   localparam                      DONE = 3;

   reg [1:0]                       arb_state;
   wire                            ram_sel;

   assign stall_n = !(dmem_req && (arb_state == IDLE));

   assign ram_sel = write_address[23:20] == 4'h0;
   assign video_sel = write_address[23:20] == 4'he;
   assign uart_sel = write_address[23:20] == 4'hf;

   always@(posedge clk_cpu or negedge rst_n)
     begin
        if(!rst_n)
          begin
             arb_state <= 0;
             ram_write_access <= 0;
             ram_read_access <= 0;
             peripheral_write_strobe <= 0;
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
                      end
                 end
               IDLE :
                 begin
                    if (imem_ack & dmem_req & !dmem_wr & ram_sel)
                      begin
                         // READ RAM
                         ram_read_access <= 1;
                         if (memory_ack)
                           begin
                              ram_read_access <= 0;
                              arb_state <= DONE;
                           end
                      end
                    else if (imem_ack & dmem_req & dmem_wr & ram_sel)
                      begin
                         // Write RAM (ack needed before we can go ahead)
                         ram_write_access <= 1;
                         if (memory_ack)
                           begin
                              ram_write_access <= 0;
                              arb_state <= DONE;
                           end
                      end
                    else if (imem_ack & dmem_req & dmem_wr & !ram_sel)
                      begin
                         // Write Peripheral (no ack needed, they are always ready)
                         peripheral_write_strobe <= 1;
                         arb_state <= PERIPHERAL;
                      end
                 end // case: IDLE
               PERIPHERAL:
                 begin
                    peripheral_write_strobe <= 0;
                    arb_state <= IDLE;
                 end
               DONE :
                 begin
                    arb_state <= IDLE;
                 end
             endcase // case (arb_state)
          end
     end

endmodule // memory_arbiter

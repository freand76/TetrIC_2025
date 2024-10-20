module video_dma(
                 // Global clk / reset
                 input             clk_cpu,
                 input             rst_n,

                 input             halt_n,

                 input [19:0]      video_address,
                 input [8:0]       line,
                 input             line_end,
                 input             frame_end,

                 // MEMORY CONTROLLER REQUEST
                 output reg        req_16,
                 output reg [19:0] req_address,
                 input [31:0]      rsp_data,
                 input             rsp_data_strobe,

                 // LINE MEM INTERFACE
                 output reg [7:0]  line_addr,
                 output [31:0]     line_data,
                 output            line_strobe_odd,
                 output            line_strobe_even
                 );

   reg                             current_line;
   reg                             even_line_empty;
   reg                             odd_line_empty;

   reg [3:0]                      req_count;
   reg [8:1]                      wait_line;
   reg [4:0]                      dma_state;
   localparam                     FRAME_START = 0;
   localparam                     LINE_START = 1;
   localparam                     DMA_START = 2;
   localparam                     DMA_LOAD = 3;
   localparam                     LINE_DONE = 4;

   assign line_strobe_even = rsp_data_strobe & !current_line;
   assign line_strobe_odd = rsp_data_strobe & current_line;
   assign line_data = rsp_data;

   always @ (posedge clk_cpu)
     begin
        if (line_strobe_even | line_strobe_odd)
          $display("WRITE_VIDEO %x (%d) => %d %d %d %d %x",
                   req_address, line,
                   current_line, line_strobe_even, line_strobe_odd,
                   line_addr, line_data);
     end

   always @ (posedge clk_cpu)
     begin
        if (!rst_n)
          begin
             req_16 <= 0;
             req_address <= video_address;
             req_count <= 0;
             line_addr <= 0;

             current_line <= 0; // 0 is even, 1 is odd
             even_line_empty <= 1;
             odd_line_empty <= 1;
             line_addr <= 0;
             dma_state <= FRAME_START;
          end
        else
          if (frame_end | !halt_n)
            begin
               dma_state <= FRAME_START;
            end
          else
            begin
               case(dma_state)
                 FRAME_START :
                   begin
                      req_address <= video_address;
                      dma_state <= LINE_START;
                   end
                 LINE_START :
                   begin
                      line_addr <= 0;
                      dma_state <= DMA_START;
                   end
                 DMA_START :
                   begin
                      req_16 <= 1;
                      req_count <= 0;
                      dma_state <= DMA_LOAD;
                   end
                 DMA_LOAD :
                   begin
                      if (rsp_data_strobe)
                        begin
                           req_16 <= 0;
                           line_addr <= line_addr + 1;
                           req_count <= req_count + 1;
                           if (req_count == 4'hf)
                             begin
                                req_address <= req_address + 20'h00010;
                                if (line_addr == 159)
                                  begin
                                     if (!current_line)
                                       begin
                                          $display("WRITE_VIDEO EVEN DONE");
                                          even_line_empty <= 0;
                                       end
                                     else
                                       begin
                                          $display("WRITE_VIDEO ODD DONE");
                                          odd_line_empty <= 0;
                                       end

                                     current_line <= !current_line;
                                     dma_state <= LINE_DONE;
                                  end
                                else
                                  begin
                                     dma_state <= DMA_START;
                                  end
                             end
                        end
                   end
                 LINE_DONE :
                   begin
                      // DEBUG START: Because the memory is small
                      if (even_line_empty)
                        begin
                           $display("WRITE_VIDEO Even Restart %d:%x", even_line_empty, video_address);
                           req_address <= video_address;
                        end
                      else if (odd_line_empty)
                        begin
                           $display("WRITE_VIDEO Odd Restart %d:%x", odd_line_empty, video_address + 20'h100);
                           req_address <= video_address + 20'h100;
                        end
                      // DEBUG END: Because the memory is small

                      if (even_line_empty | odd_line_empty)
                        begin
                           $display("WRITE_VIDEO Restart %d:%d", even_line_empty, odd_line_empty);
                           dma_state <= LINE_START;
                        end
                      if (line_end)
                        begin
                           if (line[0] == 1'b0)
                             even_line_empty <= 1;
                           else
                             odd_line_empty <= 1;
                        end
                   end
               endcase // case (dma_state)
            end
     end // always @ (posedge clk_ram)

endmodule

module sdram_wrap
  #(
    // Clock frequency, max 66.7Mhz with current set of T_xx/CAS parameters.
    parameter ROW_WIDTH = 11, // 2K rows
    parameter COL_WIDTH = 8, // 256 words per row (1Kbytes)
    parameter BANK_WIDTH = 2 // 4 banks
    )
   (
    inout [31:0]            SDRAM_DQ,
    output [ROW_WIDTH-1:0]  SDRAM_A,
    output [BANK_WIDTH-1:0] SDRAM_BA,
    output                  SDRAM_nCS,
    output                  SDRAM_nWE,
    output                  SDRAM_nRAS,
    output                  SDRAM_nCAS,
    output                  SDRAM_CLK,
    output                  SDRAM_CKE,
    output [3:0]            SDRAM_DQM,

    // Logic side interface
    input                   clk,
    input                   clk_sdram,
    input                   resetn,
    input                   sel,
    input                   read,
    output                  read_ack,
    input                   write,
    output                  write_ack,
    input [22:0]            addr,
    input [31:0]            din,
    output reg [31:0]       dout
    );

   localparam               FREQ=27_000_000;
   localparam               REFRESH_COUNT=FREQ/1000/1000*15;     // 15us refresh

   wire [31:0]              dout_wire;
   wire                     busy, data_ready;
   wire                     refresh;
   wire                     rd, wr;

   sdram #(.FREQ(FREQ)) u_sdram
     (
      .clk(clk),
      .clk_sdram(clk_sdram),
      .resetn(resetn),
      .addr(addr),
      .rd(rd),
      .wr(wr),
      .refresh(refresh),
      .din(din),
      .dout(dout_wire),
      .data_ready(data_ready),
      .busy(busy),

      .SDRAM_DQ(SDRAM_DQ),
      .SDRAM_A(SDRAM_A),
      .SDRAM_BA(SDRAM_BA),
      .SDRAM_nCS(SDRAM_nCS),
      .SDRAM_nWE(SDRAM_nWE),
      .SDRAM_nRAS(SDRAM_nRAS),
      .SDRAM_nCAS(SDRAM_nCAS),
      .SDRAM_CLK(SDRAM_CLK),
      .SDRAM_CKE(SDRAM_CKE),
      .SDRAM_DQM(SDRAM_DQM)
      );

   reg                      refresh_needed;
   wire                     refresh_executed;
   reg [11:0]               refresh_time;
   reg [1:0]                state;
   localparam               IDLE = 0;
   localparam               REFRESH = 1;
   localparam               READ = 2;
   localparam               WRITE = 3;

   assign refresh = (!busy & refresh_needed & !refresh_executed) && (state == IDLE);
   assign refresh_executed = !busy && (state == REFRESH);
   assign read_ack = !busy && (state == READ);
   assign write_ack = !busy && (state == WRITE);

   assign rd = !busy & read & sel & (state == IDLE);
   assign read_ack = !busy && (state == READ);
   assign wr = !busy & write & sel & (state == IDLE);
   assign write_ack = !busy && (state == WRITE);

   always @(posedge clk, negedge resetn)
     begin
        if (!resetn)
          begin
             state <= 0;
             dout <= 0;
          end
        else
          begin
             if (data_ready)
               begin
                  dout <= dout_wire;
               end

             case(state)
               IDLE:
                 begin
                    if (!busy)
                      begin
                         if (refresh)
                           begin
                              state <= REFRESH;
                           end
                         else if (rd)
                           begin
                              state <= READ;
                           end
                         else if (wr)
                           begin
                              state <= WRITE;
                           end
                      end
                 end
               REFRESH :
                 begin
                    if (!busy)
                      begin
                         state <= IDLE;
                      end
                 end
               READ :
                 begin
                    if (!busy)
                      begin
                         state <= IDLE;
                      end
                 end
               WRITE :
                 begin
                    if (!busy)
                      begin
                         state <= IDLE;
                      end
                 end
             endcase // case (state)
          end
     end

   always @(posedge clk, negedge resetn)
     begin
        if (!resetn)
          begin
             refresh_time <= 0;
             refresh_needed <= 0;
          end
        else
          begin
             refresh_time <= refresh_time == (REFRESH_COUNT*2-2) ? (REFRESH_COUNT*2-2) : refresh_time + 1;
             if (refresh_time == REFRESH_COUNT)
               begin
                  refresh_needed <= 1;
               end

             if (refresh_executed)
               begin
                  refresh_time <= refresh_time - REFRESH_COUNT;
                  refresh_needed <= 0;
               end
          end
     end

endmodule // sdram_wrap

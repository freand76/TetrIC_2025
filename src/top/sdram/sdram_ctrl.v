// SDR SDRAM controller with full-page read bursts for the Tang Nano 20K
// (GW2AR-18 embedded 64Mbit SDRAM: 4 banks x 2K rows x 256 columns x 32 bit).
//
// * Mode register: full-page burst, sequential, "burst read / single write"
//   (A9=1). Writes are therefore always single 32-bit words.
// * Read bursts of 1..256 words from any word address. A burst that crosses a
//   row boundary is split into segments (ACTIVE / READ / PRECHARGE per row).
//   A full page burst is terminated with a PRECHARGE issued exactly so that the
//   last wanted word is still delivered (PRECHARGE at READ + len cycles).
// * Auto refresh is generated internally (default every 7.8us) and has
//   priority over reads and writes. Refreshes owed during a long burst are
//   counted and executed afterwards, so the average rate is exact.
// * All timings are derived from FREQ_KHZ.
//
// Word address mapping: addr[7:0] = column, addr[18:8] = row, addr[20:19] = bank
// (i.e. byte address = word address * 4, same mapping as the old sdram.v).
//
// Read data timing: the READ command is registered onto the pins at edge R.
// Word n of the segment is captured from DQ at edge R + RD_DELAY + n and shows
// up on rd_data/rd_valid in the following cycle. RD_DELAY = CAS + 1 + RD_EXTRA
// (RD_EXTRA can be used to tune the capture point on real hardware).
//
`timescale 1ns / 1ps

module sdram_ctrl
  #(
    parameter FREQ_KHZ    = 50_400,
    parameter CAS         = (FREQ_KHZ > 80_000) ? 3 : 2,
    parameter RD_EXTRA    = 0,
    parameter INIT_US     = 200,
    parameter REFRESH_NS  = 7_800,
    // Chip timings (ns), conservative values for a -6/-7 grade SDR SDRAM
    parameter NS_RCD      = 20,
    parameter NS_RP       = 20,
    parameter NS_RAS      = 45,
    parameter NS_RC       = 65,
    parameter NS_RFC      = 70,
    parameter NS_WR       = 15
    )
   (
    input             clk,
    input             rst_n,
    output reg        ready,         // init done

    // single word write port (wr_req is held until wr_ack)
    input             wr_req,
    input [20:0]      wr_addr,
    input [31:0]      wr_data,
    output reg        wr_ack,

    // burst read port (rd_req is held until rd_ack)
    input             rd_req,
    input [20:0]      rd_addr,
    input [8:0]       rd_len,        // 1..256 words
    output reg        rd_ack,
    output reg        rd_valid,
    output reg [31:0] rd_data,

    // SDRAM pins
    inout [31:0]      SDRAM_DQ,
    output reg [10:0] SDRAM_A,
    output reg [1:0]  SDRAM_BA,
    output            SDRAM_nCS,
    output reg        SDRAM_nWE,
    output reg        SDRAM_nRAS,
    output reg        SDRAM_nCAS,
    output            SDRAM_CKE,
    output reg [3:0]  SDRAM_DQM
    );

   // ns -> clock cycles (rounded up, at least 1)
   function integer cyc;
      input integer ns;
      integer c;
      begin
         c = (ns * FREQ_KHZ + 999_999) / 1_000_000;
         cyc = (c < 1) ? 1 : c;
      end
   endfunction

   localparam T_RCD  = cyc(NS_RCD);
   localparam T_RP   = cyc(NS_RP);
   localparam T_RAS  = cyc(NS_RAS);
   localparam T_RC   = cyc(NS_RC);
   localparam T_RFC  = cyc(NS_RFC);
   localparam T_WR   = (cyc(NS_WR) < 2) ? 2 : cyc(NS_WR);
   localparam T_MRD  = 2;
   // Minimum cycles from READ/WRITE to PRECHARGE so that tRAS and tRC hold
   localparam T_RAS_FROM_CMD = (T_RAS > T_RCD) ? T_RAS - T_RCD : 1;
   localparam T_RC_FROM_CMD  = (T_RC > T_RCD + T_RP) ? T_RC - T_RCD - T_RP : 1;
   localparam T_MIN_PRE      = (T_RAS_FROM_CMD > T_RC_FROM_CMD) ? T_RAS_FROM_CMD : T_RC_FROM_CMD;

   localparam INIT_CYCLES = INIT_US * FREQ_KHZ / 1000;
   localparam REF_CYCLES  = REFRESH_NS * FREQ_KHZ / 1_000_000;
   localparam RD_DELAY    = CAS + 1 + RD_EXTRA;

   // A10=0 reserved, A9=1 single write, A8:7=00, A6:4=CAS, A3=0 sequential, A2:0=111 full page
   localparam [10:0] MODE_REG = {1'b0, 1'b1, 2'b00, CAS[2:0], 1'b0, 3'b111};

   // RAS# CAS# WE#
   localparam [2:0] CMD_MRS  = 3'b000;
   localparam [2:0] CMD_REF  = 3'b001;
   localparam [2:0] CMD_PRE  = 3'b010;
   localparam [2:0] CMD_ACT  = 3'b011;
   localparam [2:0] CMD_WR   = 3'b100;
   localparam [2:0] CMD_RD   = 3'b101;
   localparam [2:0] CMD_NOP  = 3'b111;

   assign SDRAM_nCS = 1'b0;
   assign SDRAM_CKE = 1'b1;

   // DQ tristate
   reg               dq_oe;
   reg [31:0]        dq_out;
   assign SDRAM_DQ = dq_oe ? dq_out : 32'bz;

   localparam [3:0] S_INIT    = 4'd0,
                    S_PREALL  = 4'd1,
                    S_INITREF = 4'd2,
                    S_MRS     = 4'd3,
                    S_WAIT    = 4'd4,
                    S_IDLE    = 4'd5,
                    S_RD_ACT  = 4'd6,
                    S_RD_CMD  = 4'd7,
                    S_RD_BURST= 4'd8,
                    S_WR_CMD  = 4'd9,
                    S_WR_HOLD = 4'd10;

   reg [3:0]         state, next_after_wait;
   reg [15:0]        timer;
   reg [3:0]         init_refs;

   reg [20:0]        cur_addr;    // current segment address
   reg [8:0]         remaining;   // words left in the whole request
   reg [8:0]         seg_len;     // words in current segment
   reg [8:0]         cnt;         // cycles since READ/WRITE command
   reg [31:0]        wdata;

   // refresh bookkeeping
   reg [15:0]        ref_timer;
   reg [2:0]         ref_pending;
   reg               ref_done;    // pulse: one refresh executed

   // read data pipeline
   reg [RD_DELAY-1:0] rd_pipe;
   // one token per wanted word, at edges READ .. READ+seg_len-1
   wire               rd_token = ((state == S_RD_CMD) && (timer == 0)) ||
                                 ((state == S_RD_BURST) && (cnt < seg_len));

   // segment length for current address: min(remaining, 256 - column)
   wire [8:0]        col_room = 9'd256 - {1'b0, cur_addr[7:0]};
   wire [8:0]        this_seg = (remaining < col_room) ? remaining : col_room;

   wire [8:0]        rd_pre_at  = (seg_len > T_MIN_PRE) ? seg_len : T_MIN_PRE[8:0];
   localparam [8:0]  WR_PRE_AT  = (T_WR > T_MIN_PRE) ? T_WR : T_MIN_PRE;

   always @(posedge clk)
     begin
        if (!rst_n)
          begin
             state <= S_INIT;
             timer <= INIT_CYCLES;
             init_refs <= 0;
             ready <= 0;
             {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;
             SDRAM_A <= 0;
             SDRAM_BA <= 0;
             SDRAM_DQM <= 4'hF;
             dq_oe <= 0;
             dq_out <= 0;
             wr_ack <= 0;
             rd_ack <= 0;
             ref_done <= 0;
             cnt <= 0;
             seg_len <= 0;
             remaining <= 0;
             cur_addr <= 0;
             wdata <= 0;
             next_after_wait <= S_IDLE;
          end
        else
          begin
             // defaults
             {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_NOP;
             wr_ack <= 0;
             rd_ack <= 0;
             ref_done <= 0;
             dq_oe <= 0;

             case (state)
               S_INIT:  // wait >= 200us after power up (NOPs)
                 begin
                    timer <= timer - 1;
                    if (timer == 0)
                      state <= S_PREALL;
                 end

               S_PREALL:
                 begin
                    {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRE;
                    SDRAM_A[10] <= 1'b1;            // all banks
                    timer <= T_RP - 1;
                    next_after_wait <= S_INITREF;
                    state <= S_WAIT;
                 end

               S_INITREF: // 8 auto refresh cycles
                 begin
                    {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_REF;
                    init_refs <= init_refs + 1;
                    timer <= T_RFC - 1;
                    next_after_wait <= (init_refs == 7) ? S_MRS : S_INITREF;
                    state <= S_WAIT;
                 end

               S_MRS:
                 begin
                    {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_MRS;
                    SDRAM_BA <= 2'b00;
                    SDRAM_A <= MODE_REG;
                    SDRAM_DQM <= 4'h0;
                    timer <= T_MRD - 1;
                    next_after_wait <= S_IDLE;
                    state <= S_WAIT;
                 end

               S_WAIT:  // NOPs, then continue
                 begin
                    if (timer == 0)
                      begin
                         state <= next_after_wait;
                         if (next_after_wait == S_IDLE)
                           ready <= 1'b1;
                      end
                    else
                      timer <= timer - 1;
                 end

               S_IDLE:
                 begin
                    if (ref_pending != 0)
                      begin
                         {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_REF;
                         ref_done <= 1;
                         timer <= T_RFC - 1;
                         next_after_wait <= S_IDLE;
                         state <= S_WAIT;
                      end
                    else if (rd_req)
                      begin
                         rd_ack <= 1;
                         cur_addr <= rd_addr;
                         remaining <= (rd_len == 0) ? 9'd1 : rd_len;
                         state <= S_RD_ACT;
                      end
                    else if (wr_req)
                      begin
                         wr_ack <= 1;
                         cur_addr <= wr_addr;
                         wdata <= wr_data;
                         {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_ACT;
                         SDRAM_BA <= wr_addr[20:19];
                         SDRAM_A  <= wr_addr[18:8];
                         timer <= T_RCD - 1;
                         state <= S_WR_CMD;
                      end
                 end

               // ---------------- burst read ----------------
               S_RD_ACT:  // activate row of the current segment
                 begin
                    {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_ACT;
                    SDRAM_BA <= cur_addr[20:19];
                    SDRAM_A  <= cur_addr[18:8];
                    seg_len <= this_seg;
                    timer <= T_RCD - 1;
                    state <= S_RD_CMD;
                 end

               S_RD_CMD:
                 begin
                    if (timer == 0)
                      begin
                         {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_RD;
                         SDRAM_A <= {3'b000, cur_addr[7:0]};  // A10=0: no auto precharge
                         cnt <= 1;
                         state <= S_RD_BURST;
                      end
                    else
                      timer <= timer - 1;
                 end

               S_RD_BURST: // data streaming, terminate with PRECHARGE at READ+seg_len
                 begin
                    cnt <= cnt + 1;
                    if (cnt == rd_pre_at)
                      begin
                         {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRE;
                         SDRAM_A[10] <= 1'b0;                 // this bank only
                         remaining <= remaining - seg_len;
                         cur_addr <= cur_addr + seg_len;
                         timer <= T_RP - 1;
                         next_after_wait <= (remaining == seg_len) ? S_IDLE : S_RD_ACT;
                         state <= S_WAIT;
                      end
                 end

               // ---------------- single write ----------------
               S_WR_CMD:
                 begin
                    if (timer == 0)
                      begin
                         {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_WR;
                         SDRAM_A <= {3'b000, cur_addr[7:0]};  // A10=0: no auto precharge
                         dq_out <= wdata;
                         dq_oe <= 1;
                         cnt <= 1;
                         state <= S_WR_HOLD;
                      end
                    else
                      timer <= timer - 1;
                 end

               S_WR_HOLD:
                 begin
                    cnt <= cnt + 1;
                    if (cnt == WR_PRE_AT)
                      begin
                         {SDRAM_nRAS, SDRAM_nCAS, SDRAM_nWE} <= CMD_PRE;
                         SDRAM_A[10] <= 1'b0;
                         timer <= T_RP - 1;
                         next_after_wait <= S_IDLE;
                         state <= S_WAIT;
                      end
                 end

               default:
                 state <= S_IDLE;
             endcase
          end
     end

   // Read capture pipeline
   always @(posedge clk)
     begin
        if (!rst_n)
          begin
             rd_pipe <= 0;
             rd_valid <= 0;
             rd_data <= 0;
          end
        else
          begin
             rd_pipe <= {rd_pipe[RD_DELAY-2:0], rd_token};
             rd_valid <= rd_pipe[RD_DELAY-1];
             if (rd_pipe[RD_DELAY-1])
               rd_data <= SDRAM_DQ;
          end
     end

   // Refresh request generation
   always @(posedge clk)
     begin
        if (!rst_n || !ready)
          begin
             ref_timer <= 0;
             ref_pending <= 0;
          end
        else
          begin
             if (ref_timer == REF_CYCLES - 1)
               ref_timer <= 0;
             else
               ref_timer <= ref_timer + 1;

             case ({ref_timer == REF_CYCLES - 1, ref_done})
               2'b10: ref_pending <= (ref_pending == 3'd7) ? 3'd7 : ref_pending + 1;
               2'b01: ref_pending <= ref_pending - 1;
               default: ;
             endcase
          end
     end

endmodule // sdram_ctrl

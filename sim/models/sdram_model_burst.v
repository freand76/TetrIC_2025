// Behavioural SDR SDRAM model with burst support (simulation only).
//
// Geometry matches the GW2AR-18 embedded SDRAM: 4 banks x 2048 rows x 256
// columns x 32 bit (8 MByte).
//
// Supported:
//  * MODE REGISTER SET: burst length 1/2/4/8/full page, sequential/interleaved
//    burst type (interleaved treated as sequential), CAS latency 2/3,
//    write burst mode (A9=1: single location write).
//  * ACTIVE, READ, WRITE (with or without auto precharge, not for full page),
//    PRECHARGE (single / all), BURST TERMINATE, AUTO REFRESH, NOP.
//  * Read bursts terminated by PRECHARGE, BURST TERMINATE or a new READ/WRITE
//    behave like a real device: words already "in flight" (CL-1 cycles) are
//    still output.
//  * DQM: write masking (latency 0) and read output masking (latency 2).
//  * Output timing: data is driven tAC after the clock edge and held until
//    tOH after the next edge; in between the bus is 'x'. Sampling at the
//    wrong time therefore gives x's in the controller.
//  * Timing checks (tRCD, tRP, tRAS, tRC, tRFC, tRRD, tWR, tMRD, refresh
//    interval) and protocol checks. Violations are printed and counted in
//    `errors`.
//
// The memory array `mem` is indexed by {bank, row, column} and can be accessed
// hierarchically from the test bench (backdoor load/check).

`timescale 1ns / 1ps

module sdram_model_burst
    #(
        parameter real TAC    = 5.4,     // access time from clock (CL=3)
        parameter real TOH    = 2.5,     // output hold time
        parameter real T_RCD  = 18.0,
        parameter real T_RP   = 18.0,
        parameter real T_RAS  = 42.0,
        parameter real T_RC   = 60.0,
        parameter real T_RFC  = 60.0,
        parameter real T_RRD  = 12.0,
        parameter integer T_WR_CLK  = 2, // write recovery in clocks
        parameter integer T_MRD_CLK = 2,
        parameter real T_REF_MAX = 70_200.0, // max gap between refreshes (9 x 7.8us)
        parameter      VERBOSE = 0
    )
        (
            input        clk,
            input        cke,
            input        cs_n,
            input        ras_n,
            input        cas_n,
            input        we_n,
            input [1:0]  ba,
            input [10:0] a,
            input [3:0]  dqm,
            inout [31:0] dq
        );

    localparam COLS = 256;

    reg [31:0]    mem [0:(1<<21)-1];

    integer       errors = 0;
    integer       n_refresh = 0;
    integer       n_reads = 0;    // words read
    integer       n_writes = 0;   // words written
    integer       n_cmd_rd = 0;
    integer       n_cmd_wr = 0;
    integer       n_cmd_act = 0;

    // ---------------- mode register ----------------
    reg           mode_set = 0;
    integer       burst_len = 1;  // 256 = full page
    integer       cas_lat = 2;
    reg           wb_single = 0;

    // ---------------- bank state ----------------
    reg           bank_active [0:3];
    reg [10:0]    bank_row    [0:3];
    real          t_act       [0:3];
    real          t_pre       [0:3];
    integer       c_wr        [0:3];  // clock of last write data
    reg           bank_ap     [0:3];  // auto precharge pending at end of burst
    real          t_last_act_any = -1.0e9;
    real          t_last_ref = -1.0e9;
    real          t_first_ref = -1.0;
    integer       c_mrs = -1000;
    integer       clk_cnt = 0;

    // ---------------- burst state ----------------
    reg           b_rd = 0, b_wr = 0;
    reg [1:0]     b_bank;
    reg [7:0]     b_col;
    integer       b_left = 0;
    integer       b_start_col;
    reg           b_ap = 0;

    // read output pipeline (index 0 = word generated this edge)
    reg [31:0]    p_data [0:3];
    reg           p_valid[0:3];
    reg [3:0]     dqm_d1 = 4'hF, dqm_d2 = 4'hF;

    `ifdef VERILATOR
    // for Verilator (no delayed tristate assignments): drive per byte with an enable
    reg [31:0]    dq_v = 0;
    reg [3:0]     dq_oe = 0;
    assign dq[31:24] = dq_oe[3] ? dq_v[31:24] : 8'bz;
    assign dq[23:16] = dq_oe[2] ? dq_v[23:16] : 8'bz;
    assign dq[15:8]  = dq_oe[1] ? dq_v[15:8]  : 8'bz;
    assign dq[7:0]   = dq_oe[0] ? dq_v[7:0]   : 8'bz;
    `else
    reg [31:0]    dq_r = 32'bz;
    assign dq = dq_r;
    `endif

    integer       i;
    initial
        begin
            for (i = 0; i < 4; i = i + 1)
                begin
                    bank_active[i] = 0;
                    bank_row[i] = 0;
                    t_act[i] = -1.0e9;
                    t_pre[i] = -1.0e9;
                    c_wr[i] = -1000;
                    bank_ap[i] = 0;
                    p_data[i] = 0;
                    p_valid[i] = 0;
                end
        end

    task err;
        input [8*96-1:0] msg;
        begin
            errors = errors + 1;
            $display("%t SDRAM MODEL ERROR: %0s", $realtime, msg);
        end
    endtask

    function [20:0] idx;
        input [1:0] bk;
        input [10:0] row;
        input [7:0] col;
        idx = {bk, row, col};
    endfunction

    wire [2:0] cmd = {ras_n, cas_n, we_n};
    localparam [2:0] C_MRS = 3'b000, C_REF = 3'b001, C_PRE = 3'b010, C_ACT = 3'b011,
        C_WR = 3'b100, C_RD = 3'b101, C_BST = 3'b110, C_NOP = 3'b111;

    // close bank: used by PRECHARGE and auto precharge
    task close_bank;
        input integer bk;
        begin
            if (bank_active[bk])
                begin
                    if ($realtime - t_act[bk] < T_RAS - 0.001)
                        err("tRAS violation (ACTIVE to PRECHARGE)");
                    if (clk_cnt - c_wr[bk] < T_WR_CLK)
                        err("tWR violation (WRITE to PRECHARGE)");
                end
            bank_active[bk] = 0;
            t_pre[bk] = $realtime;
        end
    endtask

    task end_burst;
        begin
            if ((b_rd || b_wr) && b_ap)
                close_bank(b_bank);
            b_rd = 0;
            b_wr = 0;
            b_left = 0;
            b_ap = 0;
        end
    endtask

    reg [31:0] word;
    reg        wvalid;
    integer    k;
    reg [31:0] wmask;

    // commands count after the first NOP (power-up: the controller drives NOP
    // while it waits; before reset its outputs can look like any command)
    reg        powered_up = 0;

    always @(posedge clk)
        begin
            clk_cnt = clk_cnt + 1;
            if (cke && !cs_n && cmd == C_NOP)
                powered_up = 1;
            if (cke && !cs_n && powered_up)
                begin
                    case (cmd)
                        C_MRS:
                            begin
                                for (k = 0; k < 4; k = k + 1)
                                    if (bank_active[k]) err("MRS with active bank");
                                case (a[2:0])
                                    3'b000: burst_len = 1;
                                    3'b001: burst_len = 2;
                                    3'b010: burst_len = 4;
                                    3'b011: burst_len = 8;
                                    3'b111: burst_len = COLS;
                                    default: err("reserved burst length");
                                endcase
                                cas_lat = a[6:4];
                                if (cas_lat != 2 && cas_lat != 3) err("unsupported CAS latency");
                                wb_single = a[9];
                                mode_set = 1;
                                c_mrs = clk_cnt;
                                if (VERBOSE)
                                    $display("%t SDRAM MODEL: MRS BL=%0d CL=%0d WB_single=%0d", $realtime, burst_len, cas_lat, wb_single);
                            end

                        C_REF:
                            begin
                                for (k = 0; k < 4; k = k + 1)
                                    if (bank_active[k]) err("REFRESH with active bank");
                                for (k = 0; k < 4; k = k + 1)
                                    if ($realtime - t_pre[k] < T_RP - 0.001) err("tRP violation (PRECHARGE to REFRESH)");
                                if ($realtime - t_last_ref < T_RFC - 0.001) err("tRFC violation (REFRESH to REFRESH)");
                                if ($realtime - t_last_act_any < T_RC - 0.001) err("tRC violation (ACTIVE to REFRESH)");
                                if (mode_set && t_last_ref > 0 && ($realtime - t_last_ref > T_REF_MAX))
                                    err("refresh interval too long");
                                if (t_first_ref < 0) t_first_ref = $realtime;
                                t_last_ref = $realtime;
                                n_refresh = n_refresh + 1;
                            end

                        C_ACT:
                            begin
                                if (!mode_set) err("ACTIVE before MRS");
                                if (bank_active[ba]) err("ACTIVE to already active bank");
                                if ($realtime - t_pre[ba] < T_RP - 0.001) err("tRP violation (PRECHARGE to ACTIVE)");
                                if ($realtime - t_act[ba] < T_RC - 0.001) err("tRC violation (ACTIVE to ACTIVE same bank)");
                                if ($realtime - t_last_act_any < T_RRD - 0.001) err("tRRD violation");
                                if ($realtime - t_last_ref < T_RFC - 0.001) err("tRFC violation (REFRESH to ACTIVE)");
                                if (clk_cnt - c_mrs < T_MRD_CLK) err("tMRD violation");
                                bank_active[ba] = 1;
                                bank_row[ba] = a;
                                t_act[ba] = $realtime;
                                t_last_act_any = $realtime;
                                n_cmd_act = n_cmd_act + 1;
                            end

                        C_RD, C_WR:
                            begin
                                end_burst;  // interrupts any running burst
                                if (!bank_active[ba]) err("READ/WRITE to idle bank");
                                if ($realtime - t_act[ba] < T_RCD - 0.001) err("tRCD violation");
                                if (a[10] && burst_len == COLS) err("auto precharge with full page burst");
                                b_bank = ba;
                                b_col = a[7:0];
                                b_start_col = a[7:0];
                                b_ap = a[10];
                                if (cmd == C_RD)
                                    begin
                                        b_rd = 1;
                                        b_left = burst_len;
                                        n_cmd_rd = n_cmd_rd + 1;
                                    end
                                else
                                    begin
                                        b_wr = 1;
                                        b_left = wb_single ? 1 : burst_len;
                                        n_cmd_wr = n_cmd_wr + 1;
                                    end
                            end

                        C_PRE:
                            begin
                                // terminates a burst to that bank (read data in flight still comes out)
                                if ((b_rd || b_wr) && (a[10] || b_bank == ba))
                                    begin
                                        b_rd = 0; b_wr = 0; b_left = 0; b_ap = 0;
                                    end
                                if (a[10])
                                    for (k = 0; k < 4; k = k + 1) close_bank(k);
                                else
                                    close_bank(ba);
                            end

                        C_BST:
                            begin
                                b_rd = 0; b_wr = 0; b_left = 0; b_ap = 0;
                            end

                        default: ;
                    endcase
                end // if (cke && !cs_n)

            // ---- data phase of the current burst ----
            wvalid = 0;
            word = 32'bx;
            if (b_wr && b_left > 0)
                begin
                    wmask = {{8{~dqm[3]}}, {8{~dqm[2]}}, {8{~dqm[1]}}, {8{~dqm[0]}}};
                    if (^(dq & wmask) === 1'bx)
                        err("write data contains x/z");
                    mem[idx(b_bank, bank_row[b_bank], b_col)] =
                        (mem[idx(b_bank, bank_row[b_bank], b_col)] & ~wmask) | (dq & wmask);
                    if (VERBOSE > 1)
                        $display("%t SDRAM MODEL: WR %0d:%0d:%0d = %08x", $realtime, b_bank, bank_row[b_bank], b_col, dq);
                    c_wr[b_bank] = clk_cnt;
                    n_writes = n_writes + 1;
                end
            else if (b_rd && b_left > 0)
                begin
                    word = mem[idx(b_bank, bank_row[b_bank], b_col)];
                    wvalid = 1;
                    n_reads = n_reads + 1;
                end

            if ((b_rd || b_wr) && b_left > 0)
                begin
                    b_left = b_left - 1;
                    if (burst_len == COLS)
                        b_col = b_col + 1;  // wraps within the row
                    else
                        b_col = (b_start_col & ~(burst_len - 1)) | ((b_col + 1) & (burst_len - 1));
                    if (b_left == 0)
                        end_burst;
                end

            // ---- read output pipeline ----
            for (k = 3; k > 0; k = k - 1)
                begin
                    p_data[k] = p_data[k-1];
                    p_valid[k] = p_valid[k-1];
                end
            p_data[0] = word;
            p_valid[0] = wvalid;

            // word to put on the bus now (valid at the next edge)
            `ifdef VERILATOR
            if (p_valid[cas_lat-1])
                begin
                    dq_v <= #(TAC) p_data[cas_lat-1];
                    dq_oe <= #(TAC) ~dqm_d1;
                end
            else
                dq_oe <= #(TOH) 4'b0000;
            `else
            if (p_valid[cas_lat-1])
                begin
                    dq_r <= #(TOH) 32'bx;
                    dq_r <= #(TAC) {dqm_d1[3] ? 8'bz : p_data[cas_lat-1][31:24],
                        dqm_d1[2] ? 8'bz : p_data[cas_lat-1][23:16],
                        dqm_d1[1] ? 8'bz : p_data[cas_lat-1][15:8],
                        dqm_d1[0] ? 8'bz : p_data[cas_lat-1][7:0]};
                end
            else
                dq_r <= #(TOH) 32'bz;
            `endif

            // DQM read latency 2: value sampled at edge k masks data valid at edge k+2
            dqm_d2 = dqm_d1;
            dqm_d1 = dqm;
        end

    task report;
        begin
            $display("SDRAM MODEL: %0d ACT, %0d READ cmds (%0d words), %0d WRITE cmds (%0d words), %0d refreshes, %0d errors",
                n_cmd_act, n_cmd_rd, n_reads, n_cmd_wr, n_writes, n_refresh, errors);
            if (n_refresh > 1)
                $display("SDRAM MODEL: average refresh interval %0.1f ns",
                    (t_last_ref - t_first_ref) / (n_refresh - 1));
        end
    endtask

endmodule // sdram_model_burst

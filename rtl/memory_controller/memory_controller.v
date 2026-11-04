// Memory controller: SDRAM shared between
//   * flash copy (single word writes, only before copy_done)
//   * video line fetch    (burst reads, 1..160 words) - highest read priority
//   * sound sample fetch  (single word reads)
//   * icache line fill    (8 word burst reads)
//   * processor DMEM      (single word read/write)
//
// Requests are served one at a time and are never interrupted, so video has
// top priority but a running icache burst is always completed first.
//
// Clock domains:
//   clk_cpu : flash words, arbiter / DMEM interface
//   clk_ram : SDRAM controller, icache and video request interfaces
// Everything crossing between them uses toggle handshakes. The held data
// (address / data registers) is only sampled after the toggle has been
// synchronised, and is not changed until the transfer has been acknowledged.
//
// All addresses are 32-bit word addresses. RAM (processor address 0x0xxxxx)
// is SDRAM word address 0x000000 - 0x0fffff (4 MByte).

module memory_controller
    #(
        parameter SDRAM_FREQ_KHZ = 50_400,
        parameter SDRAM_INIT_US  = 200,
        parameter COPY_WORDS     = 262144   // flash words copied to SDRAM address 0
    )
        (
            input             clk_cpu,
            input             clk_ram,
            input             rst_n,

            // FLASH copy (clk_cpu)
            input             flash_strobe,
            input [23:0]      flash_mem_address,
            input [31:0]      flash_data,
            output            sdram_ready_cpu,   // SDRAM initialised (start flash copy)
            output            copy_done_cpu,     // all flash words written to SDRAM
            output reg        copy_done_ram,

            // ICACHE (clk_ram), req is held until req_ack
            input             icache_req,
            input [19:0]      icache_req_address,
            output reg        icache_req_ack,
            output [31:0]     icache_rsp_data,
            output            icache_rsp_data_strobe,

            // VIDEO (clk_ram), req is held until req_ack
            input             video_req,
            input [19:0]      video_req_address,
            input [8:0]       video_req_len,     // 1..256 words
            output reg        video_req_ack,
            output [31:0]     video_rsp_data,
            output            video_rsp_data_strobe,

            // SOUND (clk_ram), req is held until req_ack, one word
            input             sound_req,
            input [19:0]      sound_req_address,
            output reg        sound_req_ack,
            output [31:0]     sound_rsp_data,
            output            sound_rsp_data_strobe,

            // ARBITER / PROCESSOR (clk_cpu)
            input             arbiter_ram_read_access,
            input             arbiter_ram_write_access,
            output reg        arbiter_memory_ack,
            input [19:0]      proc_dmem_addr,
            input [31:0]      proc_dmem_data_out,
            output [31:0]     proc_dmem_data_in,

            // SDRAM pins
            inout [31:0]      sdram_dq,
            output [10:0]     sdram_addr,
            output [1:0]      sdram_ba,
            output            sdram_cs_n,
            output            sdram_wen_n,
            output            sdram_ras_n,
            output            sdram_cas_n,
            output            sdram_cke,
            output [3:0]      sdram_dqm
        );

    localparam [8:0]  ICACHE_LEN = 9'd8;
    localparam [23:0] COPY_WORDS24 = COPY_WORDS;

    wire rst_cpu_n, rst_ram_n;
    reset_sync rs_cpu(.clk(clk_cpu), .rst_n_in(rst_n), .rst_n_out(rst_cpu_n));
    reset_sync rs_ram(.clk(clk_ram), .rst_n_in(rst_n), .rst_n_out(rst_ram_n));

    // ============================ clk_cpu ==============================

    // ---- flash words: hold + toggle (one word every 64 clk_cpu) ----
    reg [19:0] fl_addr_h;
    reg [31:0] fl_data_h;
    reg        fl_tog;
    always @(posedge clk_cpu or negedge rst_cpu_n)
        if (!rst_cpu_n)
        begin
            fl_addr_h <= 0;
            fl_data_h <= 0;
            fl_tog <= 0;
        end
    else if (flash_strobe)
        begin
            fl_addr_h <= flash_mem_address[19:0];
            fl_data_h <= flash_data;
            fl_tog <= ~fl_tog;
        end

    // ---- DMEM writes: posted through an asynchronous FIFO ----
    // A store is acknowledged as soon as it is in the FIFO (8 entries); the
    // clk_ram side writes it to SDRAM in the background. Pointers cross the
    // clock domains as Gray code. A load waits until the FIFO is empty, so
    // it always sees the earlier stores (the SDRAM controller executes the
    // requests in order).
    localparam WF_DEPTH = 8;
    reg [51:0] wf_mem [0:WF_DEPTH-1];   // {addr, data}, written in clk_cpu
    reg [3:0]  wf_wptr, wf_wptr_gray;   // clk_cpu (one extra bit for full/empty)
    reg [3:0]  wf_rptr, wf_rptr_gray;   // clk_ram
    reg [3:0]  wf_rptr_gray_s1, wf_rptr_gray_cpu;   // rptr synchronised to clk_cpu
    reg [3:0]  wf_wptr_gray_s1, wf_wptr_gray_ram;   // wptr synchronised to clk_ram
    wire [3:0] wf_wptr_next = wf_wptr + 4'd1;
    wire       wf_full  = (wf_wptr_gray == {~wf_rptr_gray_cpu[3:2], wf_rptr_gray_cpu[1:0]});
    wire       wf_empty_cpu = (wf_wptr_gray == wf_rptr_gray_cpu);

    always @(posedge clk_cpu or negedge rst_cpu_n)
        if (!rst_cpu_n)
        begin
            wf_rptr_gray_s1 <= 0;
            wf_rptr_gray_cpu <= 0;
        end
    else
        begin
            wf_rptr_gray_s1 <= wf_rptr_gray;
            wf_rptr_gray_cpu <= wf_rptr_gray_s1;
        end

    // ---- DMEM reads: hold + toggle, ack toggle back ----
    reg        dm_tog;
    reg        dm_busy;
    reg        dm_waitdrop;
    reg        dm_wr_h;
    reg [19:0] dm_addr_h;
    reg [31:0] dm_data_h;
    reg [31:0] dm_rdata;      // clk_ram register, stable when the ack arrives
    reg        dm_ack_tog;    // clk_ram
    wire       dm_ack_cpu;

    assign proc_dmem_data_in = dm_rdata;

    wire wf_push = !dm_busy && !dm_waitdrop && arbiter_ram_write_access && !wf_full;
    always @(posedge clk_cpu)
        if (wf_push)
        wf_mem[wf_wptr[2:0]] <= {proc_dmem_addr, proc_dmem_data_out};

    sync_toggle st_dm_ack(.clk(clk_cpu), .rst_n(rst_cpu_n), .toggle(dm_ack_tog), .pulse(dm_ack_cpu));

    always @(posedge clk_cpu or negedge rst_cpu_n)
        if (!rst_cpu_n)
        begin
            dm_tog <= 0;
            dm_busy <= 0;
            dm_waitdrop <= 0;
            dm_wr_h <= 0;
            dm_addr_h <= 0;
            dm_data_h <= 0;
            arbiter_memory_ack <= 0;
            wf_wptr <= 0;
            wf_wptr_gray <= 0;
        end
    else
        begin
            arbiter_memory_ack <= 0;
            if (dm_busy)
                begin
                    if (dm_ack_cpu)
                        begin
                            dm_busy <= 0;
                            dm_waitdrop <= 1;
                            arbiter_memory_ack <= 1;
                        end
                end
            else if (dm_waitdrop)
                begin
                    // wait until the arbiter has removed the request
                    if (!arbiter_ram_read_access && !arbiter_ram_write_access)
                        dm_waitdrop <= 0;
                end
            else if (arbiter_ram_write_access)
                begin
                    if (!wf_full)
                        begin
                            wf_wptr <= wf_wptr_next;
                            wf_wptr_gray <= wf_wptr_next ^ (wf_wptr_next >> 1);
                            dm_waitdrop <= 1;
                            arbiter_memory_ack <= 1;
                        end
                end
            else if (arbiter_ram_read_access && wf_empty_cpu)
                begin
                    dm_wr_h <= 1'b0;
                    dm_addr_h <= proc_dmem_addr;
                    dm_data_h <= proc_dmem_data_out;
                    dm_tog <= ~dm_tog;
                    dm_busy <= 1;
                end
        end

    // ---- status back to clk_cpu ----
    wire sdram_ready;
    sync_bit sb_ready(.clk(clk_cpu), .rst_n(rst_cpu_n), .d(sdram_ready),   .q(sdram_ready_cpu));
    sync_bit sb_copy (.clk(clk_cpu), .rst_n(rst_cpu_n), .d(copy_done_ram), .q(copy_done_cpu));

    // ============================ clk_ram ==============================

    wire fl_ev, dm_ev;
    sync_toggle st_fl(.clk(clk_ram), .rst_n(rst_ram_n), .toggle(fl_tog), .pulse(fl_ev));
    sync_toggle st_dm(.clk(clk_ram), .rst_n(rst_ram_n), .toggle(dm_tog), .pulse(dm_ev));

    // SDRAM controller interface
    reg         wr_req;
    reg [20:0]  wr_addr;
    reg [31:0]  wr_data;
    wire        wr_ack;
    reg         rd_req;
    reg [20:0]  rd_addr;
    reg [8:0]   rd_len;
    wire        rd_ack;
    wire        rd_valid;
    wire [31:0] rd_data;

    localparam [2:0] M_FLASH = 3'd0, M_VIDEO = 3'd1, M_ICACHE = 3'd2, M_DMEM = 3'd3, M_WFIFO = 3'd4, M_SOUND = 3'd5;
    localparam [1:0] S_IDLE = 2'd0, S_RD = 2'd1, S_WR = 2'd2;

    reg [1:0]   state;
    reg [2:0]   owner;

    // posted write FIFO, read side
    wire        wf_empty_ram = (wf_rptr_gray == wf_wptr_gray_ram);
    wire [3:0]  wf_rptr_next = wf_rptr + 4'd1;
    wire [51:0] wf_entry = wf_mem[wf_rptr[2:0]];   // stable: written before wptr moved
    reg [8:0]   rd_left;

    reg         fl_pending;
    reg [23:0]  copy_cnt;
    reg         dm_pending;

    // sticky error flags (should never be set)
    reg         copy_overrun;

    assign video_rsp_data         = rd_data;
    assign icache_rsp_data        = rd_data;
    assign sound_rsp_data         = rd_data;
    assign sound_rsp_data_strobe  = rd_valid && (owner == M_SOUND);
    assign video_rsp_data_strobe  = rd_valid && (owner == M_VIDEO);
    assign icache_rsp_data_strobe = rd_valid && (owner == M_ICACHE);

    always @(posedge clk_ram or negedge rst_ram_n)
        if (!rst_ram_n)
        begin
            state <= S_IDLE;
            owner <= M_FLASH;
            rd_left <= 0;
            wr_req <= 0;
            wr_addr <= 0;
            wr_data <= 0;
            rd_req <= 0;
            rd_addr <= 0;
            rd_len <= 0;
            fl_pending <= 0;
            copy_cnt <= 0;
            copy_done_ram <= 0;
            copy_overrun <= 0;
            dm_pending <= 0;
            dm_rdata <= 0;
            dm_ack_tog <= 0;
            video_req_ack <= 0;
            icache_req_ack <= 0;
            sound_req_ack <= 0;
            wf_rptr <= 0;
            wf_rptr_gray <= 0;
            wf_wptr_gray_s1 <= 0;
            wf_wptr_gray_ram <= 0;
        end
    else
        begin
            video_req_ack <= 0;
            icache_req_ack <= 0;
            sound_req_ack <= 0;
            wf_wptr_gray_s1 <= wf_wptr_gray;
            wf_wptr_gray_ram <= wf_wptr_gray_s1;

            if (fl_ev)
                begin
                    if (fl_pending)
                        copy_overrun <= 1;
                    fl_pending <= 1;
                end
            if (dm_ev)
                dm_pending <= 1;

            case (state)
                S_IDLE:
                    begin
                        if (!copy_done_ram)
                            begin
                                // only the flash copy until it is done
                                if (fl_pending)
                                    begin
                                        wr_req <= 1;
                                        wr_addr <= {1'b0, fl_addr_h};
                                        wr_data <= fl_data_h;
                                        owner <= M_FLASH;
                                        state <= S_WR;
                                    end
                            end
                        else if (video_req)
                            begin
                                video_req_ack <= 1;
                                rd_req <= 1;
                                rd_addr <= {1'b0, video_req_address};
                                rd_len <= video_req_len;
                                rd_left <= video_req_len;
                                owner <= M_VIDEO;
                                state <= S_RD;
                            end
                        else if (sound_req && !sound_req_ack)
                            begin
                                sound_req_ack <= 1;
                                rd_req <= 1;
                                rd_addr <= {1'b0, sound_req_address};
                                rd_len <= 9'd1;
                                rd_left <= 9'd1;
                                owner <= M_SOUND;
                                state <= S_RD;
                            end
                        else if (icache_req)
                            begin
                                icache_req_ack <= 1;
                                rd_req <= 1;
                                rd_addr <= {1'b0, icache_req_address};
                                rd_len <= ICACHE_LEN;
                                rd_left <= ICACHE_LEN;
                                owner <= M_ICACHE;
                                state <= S_RD;
                            end
                        else if (!wf_empty_ram)
                            begin
                                // posted DMEM write
                                wr_req <= 1;
                                wr_addr <= {1'b0, wf_entry[51:32]};
                                wr_data <= wf_entry[31:0];
                                owner <= M_WFIFO;
                                state <= S_WR;
                            end
                        else if (dm_pending)
                            begin
                                // DMEM read (the CPU only reads when its writes are done)
                                owner <= M_DMEM;
                                rd_req <= 1;
                                rd_addr <= {1'b0, dm_addr_h};
                                rd_len <= 9'd1;
                                rd_left <= 9'd1;
                                state <= S_RD;
                            end
                    end

                S_RD:
                    begin
                        if (rd_ack)
                            rd_req <= 0;
                        if (rd_valid)
                            begin
                                if (owner == M_DMEM)
                                    dm_rdata <= rd_data;
                                rd_left <= rd_left - 1;
                                if (rd_left == 9'd1)
                                    begin
                                        state <= S_IDLE;
                                        if (owner == M_DMEM)
                                            begin
                                                dm_pending <= 0;
                                                dm_ack_tog <= ~dm_ack_tog;
                                            end
                                    end
                            end
                    end

                S_WR:
                    begin
                        if (wr_ack)
                            begin
                                wr_req <= 0;
                                state <= S_IDLE;
                                if (owner == M_FLASH)
                                    begin
                                        fl_pending <= fl_ev;   // (a new word in the same cycle would be an overrun)
                                        copy_cnt <= copy_cnt + 1;
                                        if (copy_cnt == COPY_WORDS24 - 24'd1)
                                            copy_done_ram <= 1;
                                    end
                                else
                                    begin
                                        // posted write handed to the SDRAM controller
                                        wf_rptr <= wf_rptr_next;
                                        wf_rptr_gray <= wf_rptr_next ^ (wf_rptr_next >> 1);
                                    end
                            end
                    end

                default:
                    state <= S_IDLE;
            endcase
        end

    `ifdef MEMCTRL_DEBUG
    always @(posedge clk_ram)
        begin
            if (state == S_WR && wr_ack && owner == M_WFIFO)
                $display("MEM_WRITE: (%x) <= %x", wr_addr, wr_data);
            if (state == S_RD && rd_valid && owner == M_DMEM)
                $display("MEM_READ: (%x) => %x", rd_addr, rd_data);
        end
    `endif

    sdram_ctrl #(.FREQ_KHZ(SDRAM_FREQ_KHZ),
        .INIT_US(SDRAM_INIT_US))
        sdram(.clk(clk_ram),
            .rst_n(rst_ram_n),
            .ready(sdram_ready),

            .wr_req(wr_req),
            .wr_addr(wr_addr),
            .wr_data(wr_data),
            .wr_ack(wr_ack),

            .rd_req(rd_req),
            .rd_addr(rd_addr),
            .rd_len(rd_len),
            .rd_ack(rd_ack),
            .rd_valid(rd_valid),
            .rd_data(rd_data),

            .SDRAM_DQ(sdram_dq),
            .SDRAM_A(sdram_addr),
            .SDRAM_BA(sdram_ba),
            .SDRAM_nCS(sdram_cs_n),
            .SDRAM_nWE(sdram_wen_n),
            .SDRAM_nRAS(sdram_ras_n),
            .SDRAM_nCAS(sdram_cas_n),
            .SDRAM_CKE(sdram_cke),
            .SDRAM_DQM(sdram_dqm));

endmodule // memory_controller

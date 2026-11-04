`timescale 1ns / 1ps

// Everything except the FPGA specific clock and I/O primitives, so it can be
// simulated directly with iverilog.
module sdram_video_core
    #(
        parameter FLASH_START    = 24'h600000,
        parameter COPY_WORDS     = 24'd262144,
        parameter SDRAM_FREQ_KHZ = 50_400,
        parameter SDRAM_INIT_US  = 200,
        parameter SDRAM_RD_EXTRA = 0
    )
        (
            input         clk_pixel,
            input         clk_sdram,
            input         rst_n,          // async, active low

            output        mspi_cs,
            output        mspi_clk,
            output        mspi_di,
            input         mspi_do,

            inout [31:0]  sdram_dq,
            output [10:0] sdram_addr,
            output [1:0]  sdram_ba,
            output        sdram_cs_n,
            output        sdram_wen_n,
            output        sdram_ras_n,
            output        sdram_cas_n,
            output        sdram_cke,
            output [3:0]  sdram_dqm,

            output [9:0]  tmds_r,
            output [9:0]  tmds_g,
            output [9:0]  tmds_b,
            output [9:0]  xpos,
            output [9:0]  ypos,
            output reg [23:0] rgb_data,
            output        copy_done       // clk_sdram domain
        );

    localparam [8:0]  LINE_WORDS  = 9'd160;   // 320 pixels * 16 bit / 32 bit
    localparam [23:0] COPY_WORDS24 = COPY_WORDS;

    // ================= resets (async assert, sync release) =================
    reg [2:0] rstp_sync, rsts_sync;
    always @(posedge clk_pixel or negedge rst_n)
        if (!rst_n) rstp_sync <= 0;
    else        rstp_sync <= {rstp_sync[1:0], 1'b1};
    always @(posedge clk_sdram or negedge rst_n)
        if (!rst_n) rsts_sync <= 0;
    else        rsts_sync <= {rsts_sync[1:0], 1'b1};
    wire rstp_n = rstp_sync[2];
    wire rsts_n = rsts_sync[2];

    // ======================= clk_pixel domain ===========================

    // ---- SDRAM ready, synchronised from clk_sdram ----
    wire sdram_ready;
    reg [1:0] ready_sync;
    always @(posedge clk_pixel)
        if (!rstp_n) ready_sync <= 0;
    else         ready_sync <= {ready_sync[0], sdram_ready};

    // ---- SPI flash reader ----
    wire [23:0] flash_word_addr;
    wire [31:0] flash_data;
    wire        flash_strobe;
    wire        flash_done;

    flash_reader flash_reader(.clk(clk_pixel),
        .n_reset(rstp_n),
        .start(ready_sync[1]),
        .address(FLASH_START),
        .word_count(COPY_WORDS24),
        .mem_address(flash_word_addr),
        .strobe(flash_strobe),
        .done(flash_done),
        .data_out(flash_data),
        .spi_cs(mspi_cs),
        .spi_clk(mspi_clk),
        .spi_mosi(mspi_di),
        .spi_miso(mspi_do));

    // Hold each flash word and toggle a flag. A new word arrives only every
    // 64 pixel clocks, so the hold registers are stable long enough to be
    // read in the clk_sdram domain after the toggle has been synchronised.
    reg [20:0] fl_addr_h;
    reg [31:0] fl_data_h;
    reg        fl_tog;
    always @(posedge clk_pixel)
        if (!rstp_n)
        begin
            fl_addr_h <= 0;
            fl_data_h <= 0;
            fl_tog <= 0;
        end
    else if (flash_strobe)
        begin
            fl_addr_h <= flash_word_addr[20:0];
            fl_data_h <= flash_data;
            fl_tog <= ~fl_tog;
        end

    // ---- DVI timing ----
    dvi_generator dvi_gen(.clk_pixel(clk_pixel),
        .n_reset(rstp_n),
        .rgb_data(rgb_data),
        .tmds_r(tmds_r),
        .tmds_g(tmds_g),
        .tmds_b(tmds_b),
        .xpos(xpos),
        .ypos(ypos),
        .line_end(),
        .frame_end());

    // ---- line fetch requests ----
    // HDMI lines 2k and 2k+1 show source line k from line memory k[0].
    // At the end of the visible part of HDMI line 2k, request source line k+1
    // into the other line memory (it was last shown on HDMI line 2k-1). Line 0
    // is requested on the last line of the frame (ypos 524).
    // Deadline is the start of HDMI line 2k+2, i.e. ~960 pixel clocks.
    reg [7:0] req_line_h;
    reg       req_tog;
    wire      req_now = (xpos == 10'd640) &&
        ((ypos == 10'd524) || ((ypos < 10'd478) && !ypos[0]));
    always @(posedge clk_pixel)
        if (!rstp_n)
        begin
            req_line_h <= 0;
            req_tog <= 0;
        end
    else if (req_now)
        begin
            req_line_h <= (ypos == 10'd524) ? 8'd0 : ypos[8:1] + 8'd1;
            req_tog <= ~req_tog;
        end

    // ---- pixel output ----
    wire [8:0]  pixel_x = xpos[9:1];
    wire [8:0]  pixel_y = ypos[9:1];
    wire [15:0] pixel_data_even, pixel_data_odd;
    reg [15:0]  pixel_data;

    always @(posedge clk_pixel)
        if (!rstp_n)
        begin
            pixel_data <= 0;
            rgb_data <= 0;
        end
    else
        begin
            pixel_data <= !pixel_y[0] ? pixel_data_even : pixel_data_odd;
            // Expand 16 bit pixel 5-6-5 to 24 bit 8-8-8
            rgb_data <= { pixel_data[15:11], pixel_data[15:13],
                pixel_data[10:5],  pixel_data[10:9],
                pixel_data[4:0],   pixel_data[4:2] };
        end

    // ======================= clk_sdram domain ===========================

    // ---- flash word -> SDRAM write ----
    reg [2:0]  fl_sync;
    reg        wr_pending;
    reg [20:0] wr_addr;
    reg [31:0] wr_data;
    reg [23:0] copy_cnt;
    reg        copy_done_r;
    reg        copy_overrun;   // sticky: a flash word was lost (should never happen)
    wire       wr_ack;

    assign copy_done = copy_done_r;

    always @(posedge clk_sdram)
        if (!rsts_n)
        begin
            fl_sync <= 0;
            wr_pending <= 0;
            wr_addr <= 0;
            wr_data <= 0;
            copy_cnt <= 0;
            copy_done_r <= 0;
            copy_overrun <= 0;
        end
    else
        begin
            fl_sync <= {fl_sync[1:0], fl_tog};
            if (fl_sync[2] ^ fl_sync[1])
                begin
                    wr_addr <= fl_addr_h;   // stable, see above
                    wr_data <= fl_data_h;
                    wr_pending <= 1;
                    if (wr_pending)
                        copy_overrun <= 1;
                end
            else if (wr_ack)
                begin
                    wr_pending <= 0;
                    copy_cnt <= copy_cnt + 1;
                    if (copy_cnt == COPY_WORDS24 - 24'd1)
                        copy_done_r <= 1;
                end
        end

    // ---- line fetch: SDRAM burst -> line memory ----
    reg [2:0]  req_sync;
    reg        rd_pending;
    reg [7:0]  fetch_line;
    reg        fetch_buf;
    reg [7:0]  fetch_cnt;
    reg        lm_we;
    reg        lm_buf;
    reg [7:0]  lm_addr;
    reg [31:0] lm_data;
    reg        fetch_late;      // sticky: request while previous fetch still running
    wire       rd_ack;
    wire       rd_valid;
    wire [31:0] rd_data;

    // word address = line * 160 = line * 128 + line * 32
    wire [20:0] rd_addr = {6'd0, fetch_line, 7'd0} + {8'd0, fetch_line, 5'd0};

    always @(posedge clk_sdram)
        if (!rsts_n)
        begin
            req_sync <= 0;
            rd_pending <= 0;
            fetch_line <= 0;
            fetch_buf <= 0;
            fetch_cnt <= 0;
            lm_we <= 0;
            lm_buf <= 0;
            lm_addr <= 0;
            lm_data <= 0;
            fetch_late <= 0;
        end
    else
        begin
            req_sync <= {req_sync[1:0], req_tog};
            if ((req_sync[2] ^ req_sync[1]) && copy_done_r)
                begin
                    if (rd_pending || fetch_cnt != 0)
                        fetch_late <= 1;
                    fetch_line <= req_line_h;   // stable, next change ~1600 pixel clocks later
                    rd_pending <= 1;
                end
            else if (rd_ack)
                begin
                    rd_pending <= 0;
                    fetch_buf <= fetch_line[0];
                end

            lm_we <= rd_valid;
            lm_data <= rd_data;
            lm_buf <= fetch_buf;
            lm_addr <= fetch_cnt;
            if (rd_valid)
                fetch_cnt <= (fetch_cnt == LINE_WORDS - 1) ? 8'd0 : fetch_cnt + 1;
        end

    // ---- SDRAM controller ----
    sdram_ctrl #(.FREQ_KHZ(SDRAM_FREQ_KHZ),
        .INIT_US(SDRAM_INIT_US),
        .RD_EXTRA(SDRAM_RD_EXTRA))
        sdram(.clk(clk_sdram),
            .rst_n(rsts_n),
            .ready(sdram_ready),

            .wr_req(wr_pending),
            .wr_addr(wr_addr),
            .wr_data(wr_data),
            .wr_ack(wr_ack),

            .rd_req(rd_pending),
            .rd_addr(rd_addr),
            .rd_len(LINE_WORDS),
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

    // ---- line memories: written in clk_sdram domain, read (async) in clk_pixel ----
    line_mem line_mem_even(.pixel_addr(pixel_x),
        .pixel_data(pixel_data_even),
        .clk_wr(clk_sdram),
        .wr_en(lm_we & !lm_buf),
        .wr_addr(lm_addr),
        .wr_data(lm_data));

    line_mem line_mem_odd(.pixel_addr(pixel_x),
        .pixel_data(pixel_data_odd),
        .clk_wr(clk_sdram),
        .wr_en(lm_we & lm_buf),
        .wr_addr(lm_addr),
        .wr_data(lm_data));

endmodule // sdram_video_core

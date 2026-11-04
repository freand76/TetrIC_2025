// Video DMA (clk_ram domain): fetch one line (1..160 words, up to 320 pixels)
// from SDRAM into one of the two line memories.
//
// A line request comes from the pixel clock domain as a toggle, with the
// line's SDRAM word address, length and line memory select held stable (next
// request is ~1600 pixel clocks later).

module video_dma(
    input             clk_ram,
    input             rst_n,       // synchronised to clk_ram
    input             enable,      // memory ready (flash copy done)

    // LINE REQUEST (from clk_pixel)
    input             line_req_tog,
    input [19:0]      line_req_address,
    input [8:0]       line_req_len,
    input             line_req_odd,

    // MEMORY CONTROLLER REQUEST
    output reg        req,
    output reg [19:0] req_address,
    output reg [8:0]  req_len,
    input             req_ack,
    input [31:0]      rsp_data,
    input             rsp_data_strobe,

    // LINE MEM INTERFACE
    output reg [7:0]  line_addr,
    output [31:0]     line_data,
    output            line_strobe_odd,
    output            line_strobe_even,

    output reg        late         // sticky: request while previous still running
);

    wire line_req_ev;
    reg  busy;
    reg  odd;
    reg [8:0] left;

    sync_toggle st_req(.clk(clk_ram), .rst_n(rst_n), .toggle(line_req_tog), .pulse(line_req_ev));

    assign line_data = rsp_data;
    assign line_strobe_even = rsp_data_strobe & !odd;
    assign line_strobe_odd  = rsp_data_strobe & odd;

    always @(posedge clk_ram or negedge rst_n)
        if (!rst_n)
        begin
            req <= 0;
            req_address <= 0;
            req_len <= 0;
            left <= 0;
            line_addr <= 0;
            busy <= 0;
            odd <= 0;
            late <= 0;
        end
    else
        begin
            if (line_req_ev && enable)
                begin
                    if (busy)
                        late <= 1;
                    req <= 1;
                    req_address <= line_req_address;
                    req_len <= line_req_len;
                    left <= line_req_len;
                    odd <= line_req_odd;
                    line_addr <= 0;
                    busy <= 1;
                end
            else
                begin
                    if (req_ack)
                        req <= 0;
                    if (rsp_data_strobe)
                        begin
                            line_addr <= line_addr + 1;
                            left <= left - 1;
                            if (left == 9'd1)
                                busy <= 0;
                        end
                end
        end

endmodule // video_dma

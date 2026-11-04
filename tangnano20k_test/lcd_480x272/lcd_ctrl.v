// Original template by ChatGPT; timings fkdup but otherwise actually OK
module rgb_lcd_ctrl(
                    input            clk, // System clock
                    input            rst_n, // Active low reset
                    output reg [7:0] r, // Red output
                    output reg [7:0] g, // Green output
                    output reg [7:0] b, // Blue output
                    output reg       hsync, // Horizontal sync signal
                    output reg       vsync, // Vertical sync signal
                    output reg       de, // Data enable signal
                    output reg       enabled  // inhibit DE & SYNC for the first few frames
                    );

    // Parameters for display (Fpix = 8 / 9 / 12 MHz [min/typ/max])
    // Fpix = 9MHz, 517x290 -> 60.028 FPS
    localparam H_ACTIVE = 480; // Horizontal active pixels
    localparam H_FP     = 8;   // Horizontal front-porch (pix_clks)
    localparam H_SYNC   = 25;  // HSYNCn pulse width (pix_clks)
    localparam H_BP     = 8;   // Horizontal back-porch (pix_clks)
    //localparam H_TOTAL  = 525; // Total horizontal pixels (including blanking)
    localparam H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP;

    localparam V_ACTIVE = 272; // Vertical active pixels
    localparam V_FP     = 4;
    localparam V_SYNC   = 6;   // lines
    localparam V_BP     = 4;   // lines
    //localparam V_TOTAL  = 286; // Total vertical pixels (including blanking)
    localparam V_TOTAL  = V_ACTIVE + V_FP + V_SYNC + V_BP;

    // Timing counters
    reg [9:0]                        h_count   = 0;  // Horizontal counter
    reg [8:0]                        v_count   = 0;  // Vertical counter
    reg [9:0]                        frame_cnt = 0;  // Signal 'enabled' after a few frames...

   wire [9:0]                        dyn_hc = frame_cnt + h_count;
   wire [9:0]                        dyn_vc = frame_cnt + v_count;

    // Frame generation at 60 FPS
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            h_count   <= 0;
            v_count   <= 0;
            frame_cnt <= 0;
            r         <= 8'b0; // Default color (black)
            g         <= 8'b0;
            b         <= 8'b0;
            hsync     <= 1;
            vsync     <= 1;
            de        <= 0;
            enabled   <= 0;
        end else begin
            enabled   <= enabled | (frame_cnt == 7);
            // Horizontal counter
            if (h_count < H_TOTAL - 1) begin
                h_count <= h_count + 1;
            end else begin
                h_count <= 0;
                // Vertical counter
                if (v_count < V_TOTAL - 1) begin
                    v_count <= v_count + 1;
                end else begin
                    v_count   <= 0;
                    frame_cnt <= frame_cnt + 1;
                end
            end

            // HSYNC timing
            hsync <= (h_count > H_ACTIVE+H_FP-1 && h_count < H_ACTIVE+H_FP+H_SYNC) ? 0 : 1;

            // VSYNC timing
            if (v_count == V_ACTIVE+V_FP-1)
                vsync <= (h_count > H_ACTIVE+H_FP/*+H_SYNC*/-1) ? 0 : 1;  // Start VSYNC at start(end?) of HSYNC
            else if (v_count == V_ACTIVE+V_FP+V_SYNC-1)
                vsync <= (h_count < H_ACTIVE+H_FP+H_SYNC) ? 0 : 1;
            else
                vsync <= (v_count > V_ACTIVE+V_FP-1 && v_count < V_ACTIVE+V_FP+V_SYNC-1) ? 0 : 1;

            // Data Enable signal
            de <= (h_count < H_ACTIVE && v_count < V_ACTIVE) ? enabled : 0;

            // Pixel Data Generation (simple color gradient)
            if (de) begin
                r <= dyn_hc[8] ? ~dyn_hc[7:0] : dyn_hc[7:0];            // Red channel
                g <= dyn_vc[8] ? ~dyn_vc[7:0] : dyn_vc[7:0];            // Green channel
                b <= dyn_vc[8] ? dyn_hc[8:1] : ~dyn_vc+dyn_hc;
           // Blue channel
            end else begin
                r <= 8'b0;                    // No color outside active area
                g <= 8'b0;
                b <= 8'b0;
            end
        end
    end
endmodule  // rgb_lcd_ctrl

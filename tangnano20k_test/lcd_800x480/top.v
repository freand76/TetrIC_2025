// GW2AR-LV18QN88C8/I7

module top(input wire  sys_clk,
    input logic rst,
    output wire p77_LCD_CLK,
    output wire p25_LCD_HSYNC,
    output wire p26_LCD_VSYNC,
    output wire [4:0] LCD_R,
    output wire [5:0] LCD_G,
    output wire [4:0] LCD_B,
    output wire p48_LCD_DEN,
    output wire p49_LCD_BL,
    output wire [5:0] led
);

    // CLOCKS & RESET
    wire               pll_lock;
    wire               clk_pixel;  // 31.5MHz
    wire               rst_n = !rst;
    wire               clk_126M_dummy;
    wire               clk_9M_dummy;

    // LCD
    wire [7:0]         pix_red;
    wire [7:0]         pix_green;
    wire [7:0]         pix_blue;
    wire               lcd_inited;
    wire               lcd_hs;
    wire               lcd_vs;
    wire               lcd_de;

    assign p77_LCD_CLK       = clk_pixel;
    assign LCD_R[4:0]        = pix_red[7:3];
    assign LCD_G[5:0]        = pix_green[7:2];
    assign LCD_B[4:0]        = pix_blue[7:3];
    assign p25_LCD_HSYNC     = lcd_hs | ~lcd_inited;
    assign p26_LCD_VSYNC     = lcd_vs | ~lcd_inited;
    assign p48_LCD_DEN       = lcd_de & lcd_inited;
    assign p49_LCD_BL        = lcd_inited;

    logic [23:0] led_blink;
    assign led[0] = ~led_blink[23];
    assign led[1] = ~led_blink[22];

    always @(posedge clk_pixel)
        begin
            if (!rst_n) begin
                led_blink     <= 24'd0;
            end else begin
                led_blink <= led_blink + 1;
            end
        end // always @ (posedge clk_pixel)

    PLL126M_9M_31M5 lcd_pll(.clkin_27MHz(sys_clk),
        .clkout_126MHz(clk_126M_dummy),
        .clkout_9MHz(clk_9M_dummy),  // bypass 27M clki -> clkout_p/3-output
        .clkout_31M5(clk_pixel),   // 126M / 4
        .lock(pll_lock)
    );

    rgb_lcd_ctrl_800x480 lcd_ctrl(.clk(clk_pixel),
        .rst_n(rst_n),
        .r(pix_red),
        .g(pix_green),
        .b(pix_blue),
        .hsync(lcd_hs /*p25_LCD_HSYNC*/),
        .vsync(lcd_vs /*p26_LCD_VSYNC*/),
        .de(lcd_de /*p48_LCD_DEN*/),
        .enabled(lcd_inited)
    );

endmodule  // top

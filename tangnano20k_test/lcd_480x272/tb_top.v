`timescale 1ns / 1ps

// Based on nice TB-template from ChatGPT
module tb_top;

    // Parameters
    parameter CLK_PERIOD = 36; // 37ns = 27MHz

    // Testbench signals
    reg sys_clk;
    reg rst;
    wire lcd_clk;
    wire [4:0] r;
    wire [5:0] g;
    wire [4:0] b;
    wire hsync;
    wire vsync;
    wire de;
    wire bl;

    wire [5:0] dbg_leds;

    // Instantiate the TOP test module
    top uut (
        .sys_clk(sys_clk),
        .rst(rst),
        .p77_LCD_CLK(lcd_clk),
        .p25_LCD_HSYNC(hsync),
        .p26_LCD_VSYNC(vsync),
        .LCD_R(r),
        .LCD_G(g),
        .LCD_B(b),
        .p48_LCD_DEN(de),
        .p49_LCD_BL(bl),
        .led(dbg_leds)
    );

    // Generate VCD waveforms
    initial begin
        $dumpfile("waveform.vcd"); // Specify the VCD file name
        $dumpvars(0, tb_top); // Dump all variables in the testbench scope
    end

    // Clock generation
    initial begin
        sys_clk = 0;
        forever #(CLK_PERIOD / 2) sys_clk = ~sys_clk; // Toggle clock
    end

    // Reset signal generation
    initial begin
        rst = 1;            // Assert reset
        #(CLK_PERIOD * 5);  // Hold reset for 5 clock cycles
        rst = 0;            // Deassert reset
    end

    // Simulation monitoring
    initial begin
        // Monitor outputs
        $monitor("Time: %0t | R: %h | G: %h | B: %h | LCD_CLK: %b | HSYNC: %b | VSYNC: %b | DE: %b",
            $time, r, g, b, lcd_clk, hsync, vsync, de);

        // Run the simulation for a certain time
        #(CLK_PERIOD * 1000000); // Simulate for 1,000,000 clock cycles. Apprx 100k ~= 1 frame
        $finish; // End the simulation
    end

endmodule

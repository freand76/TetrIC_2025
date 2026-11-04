// SDRAM clock PLL, 50.4 MHz = 2 x pixel clock.
// 50.4 = 27 * 28/15 is not possible directly (PFD would be 1.8 MHz < 3 MHz), so:
// CLKOUT = 27 * 56 / 5 = 302.4 MHz (PFD 5.4 MHz, VCO 604.8 MHz),
// CLKOUTD = CLKOUT / 6 = 50.4 MHz.
module PLL_SDRAM50 (clkout, lock, clkin_27mhz);

    output clkout;
    output lock;
    input  clkin_27mhz;

    wire   clkout_302;
    wire   clkoutp_o;
    wire   clkoutd3_o;
    wire   gw_gnd = 1'b0;

    rPLL rpll_inst (
        .CLKOUT(clkout_302),
        .LOCK(lock),
        .CLKOUTP(clkoutp_o),
        .CLKOUTD(clkout),
        .CLKOUTD3(clkoutd3_o),
        .RESET(gw_gnd),
        .RESET_P(gw_gnd),
        .CLKIN(clkin_27mhz),
        .CLKFB(gw_gnd),
        .FBDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .IDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .ODSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .PSDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .DUTYDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
        .FDLY({gw_gnd,gw_gnd,gw_gnd,gw_gnd})
    );

    defparam rpll_inst.FCLKIN = "27";
    defparam rpll_inst.DYN_IDIV_SEL = "false";
    defparam rpll_inst.IDIV_SEL = 4;      // /5
    defparam rpll_inst.DYN_FBDIV_SEL = "false";
    defparam rpll_inst.FBDIV_SEL = 55;    // *56
    defparam rpll_inst.DYN_ODIV_SEL = "false";
    defparam rpll_inst.ODIV_SEL = 2;      // VCO = 604.8 MHz
    defparam rpll_inst.PSDA_SEL = "0000";
    defparam rpll_inst.DYN_DA_EN = "false";
    defparam rpll_inst.DUTYDA_SEL = "1000";
    defparam rpll_inst.CLKOUT_FT_DIR = 1'b1;
    defparam rpll_inst.CLKOUTP_FT_DIR = 1'b1;
    defparam rpll_inst.CLKOUT_DLY_STEP = 0;
    defparam rpll_inst.CLKOUTP_DLY_STEP = 0;
    defparam rpll_inst.CLKFB_SEL = "internal";
    defparam rpll_inst.CLKOUT_BYPASS = "false";
    defparam rpll_inst.CLKOUTP_BYPASS = "false";
    defparam rpll_inst.CLKOUTD_BYPASS = "false";
    defparam rpll_inst.DYN_SDIV_SEL = 6;  // CLKOUTD = 302.4 / 6 = 50.4 MHz
    defparam rpll_inst.CLKOUTD_SRC = "CLKOUT";
    defparam rpll_inst.CLKOUTD3_SRC = "CLKOUT";
    defparam rpll_inst.DEVICE = "GW2AR-18C";

endmodule

module dvi_pll(clkout_126mhz, lock, clkin_27mhz);

    output clkout_126mhz;
    output lock;
    input clkin_27mhz;

    wire clkoutp_o;
    wire clkoutd_o;
    wire clkoutd3_o;
    wire gw_gnd;

    assign gw_gnd = 1'b0;

    rPLL dvi_rpll_inst (
        .CLKOUT(clkout_126mhz),
        .LOCK(lock),
        .CLKOUTP(clkoutp_o),
        .CLKOUTD(clkoutd_o),
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

    defparam dvi_rpll_inst.FCLKIN = "27";
    defparam dvi_rpll_inst.DYN_IDIV_SEL = "false";
    defparam dvi_rpll_inst.IDIV_SEL = 2;
    defparam dvi_rpll_inst.DYN_FBDIV_SEL = "false";
    defparam dvi_rpll_inst.FBDIV_SEL = 13;
    defparam dvi_rpll_inst.DYN_ODIV_SEL = "false";
    defparam dvi_rpll_inst.ODIV_SEL = 4;
    defparam dvi_rpll_inst.PSDA_SEL = "0000";
    defparam dvi_rpll_inst.DYN_DA_EN = "true";
    defparam dvi_rpll_inst.DUTYDA_SEL = "1000";
    defparam dvi_rpll_inst.CLKOUT_FT_DIR = 1'b1;
    defparam dvi_rpll_inst.CLKOUTP_FT_DIR = 1'b1;
    defparam dvi_rpll_inst.CLKOUT_DLY_STEP = 0;
    defparam dvi_rpll_inst.CLKOUTP_DLY_STEP = 0;
    defparam dvi_rpll_inst.CLKFB_SEL = "internal";
    defparam dvi_rpll_inst.CLKOUT_BYPASS = "false";
    defparam dvi_rpll_inst.CLKOUTP_BYPASS = "false";
    defparam dvi_rpll_inst.CLKOUTD_BYPASS = "false";
    defparam dvi_rpll_inst.DYN_SDIV_SEL = 2;
    defparam dvi_rpll_inst.CLKOUTD_SRC = "CLKOUT";
    defparam dvi_rpll_inst.CLKOUTD3_SRC = "CLKOUT";
    defparam dvi_rpll_inst.DEVICE = "GW1N-9C";

endmodule // dvi_pll

// SDRAM clock PLL, 50.4 MHz = 2 x pixel clock.
// 50.4 = 27 * 28/15 is not possible directly (PFD would be 1.8 MHz < 3 MHz), so:
// CLKOUT = 27 * 56 / 5 = 302.4 MHz (PFD 5.4 MHz, VCO 604.8 MHz),
// CLKOUTD = CLKOUT / 6 = 50.4 MHz.
module sdram_pll(clkout_50mhz, lock, clkin_27mhz);

    output clkout_50mhz;
    output lock;
    input clkin_27mhz;

    wire clkout_302;
    wire clkoutp_o;
    wire clkoutd3_o;
    wire gw_gnd;

    assign gw_gnd = 1'b0;

    rPLL sdram_rpll_inst (
        .CLKOUT(clkout_302),
        .LOCK(lock),
        .CLKOUTP(clkoutp_o),
        .CLKOUTD(clkout_50mhz),
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

    defparam sdram_rpll_inst.FCLKIN = "27";
    defparam sdram_rpll_inst.DYN_IDIV_SEL = "false";
    defparam sdram_rpll_inst.IDIV_SEL = 4;      // /5
    defparam sdram_rpll_inst.DYN_FBDIV_SEL = "false";
    defparam sdram_rpll_inst.FBDIV_SEL = 55;    // *56
    defparam sdram_rpll_inst.DYN_ODIV_SEL = "false";
    defparam sdram_rpll_inst.ODIV_SEL = 2;      // VCO = 604.8 MHz
    defparam sdram_rpll_inst.PSDA_SEL = "0000";
    defparam sdram_rpll_inst.DYN_DA_EN = "false";
    defparam sdram_rpll_inst.DUTYDA_SEL = "1000";
    defparam sdram_rpll_inst.CLKOUT_FT_DIR = 1'b1;
    defparam sdram_rpll_inst.CLKOUTP_FT_DIR = 1'b1;
    defparam sdram_rpll_inst.CLKOUT_DLY_STEP = 0;
    defparam sdram_rpll_inst.CLKOUTP_DLY_STEP = 0;
    defparam sdram_rpll_inst.CLKFB_SEL = "internal";
    defparam sdram_rpll_inst.CLKOUT_BYPASS = "false";
    defparam sdram_rpll_inst.CLKOUTP_BYPASS = "false";
    defparam sdram_rpll_inst.CLKOUTD_BYPASS = "false";
    defparam sdram_rpll_inst.DYN_SDIV_SEL = 6;  // CLKOUTD = 302.4 / 6 = 50.4 MHz
    defparam sdram_rpll_inst.CLKOUTD_SRC = "CLKOUT";
    defparam sdram_rpll_inst.CLKOUTD3_SRC = "CLKOUT";
    defparam sdram_rpll_inst.DEVICE = "GW2AR-18C";

endmodule // sdram_pll

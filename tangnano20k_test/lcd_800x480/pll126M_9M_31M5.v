// GW2AR-LV18QN88C8/I7 - UG286: Gowin Clock User Guide
//         MIN    MAX
// CLKIN : 3MHz   500MHz
// PFD   : 3MHz   500MHz
// VCO   : 500MHz 1250MHz
// CLKOUT: 3.906  625MHz

module PLL126M_9M_31M5 (clkout_126MHz, clkout_9MHz, clkout_31M5, lock, clkin_27MHz);

    // CLKOUT = clkin * 14 / 3; 27M in -> 126M out
    // CLKOUTD = CLKOUT / 4 = 126 / 4 = 31.5M out
    // CLKOUTD3 = CLKOUTP / 3 = CLKIN / 3 = 27 / 3 = 9M out

    output clkout_126MHz;
    output clkout_31M5;
    output clkout_9MHz;
    output lock;
    input clkin_27MHz;

    wire clkoutp_o;
    wire clkoutd_o;
    wire clkoutd3_o;
    wire gw_gnd;

    assign clkout_31M5 = clkoutd_o;  // 126/4 = 31.5MHz (if clkout = 27M *14/3 = 126M)
    assign clkout_9MHz = clkoutd3_o;   // clkoutp = clkin (bypass); d3_src = clkoutp

    assign gw_gnd = 1'b0;

    rPLL rpll_inst (
        .CLKOUT(clkout_126MHz), // 27*14/3 = 126M
        .LOCK(lock),
        .CLKOUTP(clkoutp_o),    // not used (27Mhz = clkin)
        .CLKOUTD(clkoutd_o),    // 126/sdiv = 31.5M
        .CLKOUTD3(clkoutd3_o),  // clkoutp/3 = 9M
        .RESET(gw_gnd),
        .RESET_P(gw_gnd),
        .CLKIN(clkin_27MHz),
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
    defparam rpll_inst.IDIV_SEL = 2;
    defparam rpll_inst.DYN_FBDIV_SEL = "false";
    defparam rpll_inst.FBDIV_SEL = 13;
    defparam rpll_inst.DYN_ODIV_SEL = "false";
    defparam rpll_inst.ODIV_SEL = 4;
    defparam rpll_inst.PSDA_SEL = "0000";
    defparam rpll_inst.DYN_DA_EN = "false";
    defparam rpll_inst.DUTYDA_SEL = "1000";
    defparam rpll_inst.CLKOUT_FT_DIR = 1'b1;
    defparam rpll_inst.CLKOUTP_FT_DIR = 1'b1;
    defparam rpll_inst.CLKOUT_DLY_STEP = 0;
    defparam rpll_inst.CLKOUTP_DLY_STEP = 0;
    defparam rpll_inst.CLKFB_SEL = "internal";
    defparam rpll_inst.CLKOUT_BYPASS = "false";
    defparam rpll_inst.CLKOUTP_BYPASS = "true";
    defparam rpll_inst.CLKOUTD_BYPASS = "false";
    defparam rpll_inst.DYN_SDIV_SEL = 4;
    defparam rpll_inst.CLKOUTD_SRC = "CLKOUT";
    defparam rpll_inst.CLKOUTD3_SRC = "CLKOUTP";
    defparam rpll_inst.DEVICE = "GW2AR-18";

endmodule // PLL126M_9M_31M5

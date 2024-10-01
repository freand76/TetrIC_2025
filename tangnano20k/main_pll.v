module main_pll(clkout, clkoutp, lock, reset, clkin);

   output clkout;
   output clkoutp;
   output lock;
   input  reset;
   input  clkin;

   wire   clkoutp_o;
   wire   clkoutd_o;
   wire   clkoutd3_o;

   rPLL rpll_inst (.CLKOUT(clkout),
                   .LOCK(lock),
                   .CLKOUTP(clkoutp),
                   .CLKOUTD(clkoutd_o),
                   .CLKOUTD3(clkoutd3_o),
                   .RESET(reset),
                   .RESET_P(1'b0),
                   .CLKIN(clkin),
                   .CLKFB(1'b0),
                   .FBDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
                   .IDSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
                   .ODSEL({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
                   .PSDA({1'b0,1'b0,1'b0,1'b0}),
                   .DUTYDA({1'b0,1'b0,1'b0,1'b0}),
                   .FDLY({1'b0,1'b0,1'b0,1'b0})
                   );

   defparam rpll_inst.FBDIV_SEL = 1;
   defparam rpll_inst.IDIV_SEL = 1;
   defparam rpll_inst.ODIV_SEL = 32;

   defparam rpll_inst.FCLKIN = "27";
   defparam rpll_inst.DYN_IDIV_SEL = "false";
   defparam rpll_inst.DYN_FBDIV_SEL = "false";
   defparam rpll_inst.DYN_ODIV_SEL = "false";
   defparam rpll_inst.PSDA_SEL = "1010";
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
   defparam rpll_inst.DYN_SDIV_SEL = 2;
   defparam rpll_inst.CLKOUTD_SRC = "CLKOUT";
   defparam rpll_inst.CLKOUTD3_SRC = "CLKOUT";
   defparam rpll_inst.DEVICE = "GW2A-18C";

endmodule

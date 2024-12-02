YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack
# TODO: if not-exist: wget the GoWIN-crap, extract and pull-out the sim-packs... ?
GOWIN_SIM_PRIM = ../tangnano20k/sim/prim_sim.v



BUILD_DIR=out

VERILOG_FILES = \
	top.v \
	lcd_ctrl_800x480.v \
	pll126M_9M_31M5.v

CST=tangnano20k.cst

all: $(BUILD_DIR)/top.fs

.PHONY: synth
synth: $(BUILD_DIR)/top_synth.json $(BUILD_DIR)/top_vvp

.PHONY: pnr
pnr: $(BUILD_DIR)/top_pnr.json

.PHONY: fs-image
fs-image: $(BUILD_DIR)/top.fs

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

.PHONY: cleaner
cleaner: clean
	rm -f *.vcd
	rm -f *.vcd.gz

$(BUILD_DIR)/top_synth.json : $(VERILOG_FILES)
	mkdir -p $(BUILD_DIR)
	$(YOSYS) -p "read_verilog -sv $^; synth_gowin -json $@"

$(BUILD_DIR)/top_vvp: $(VERILOG_FILES) tb_top.v $(GOWIN_SIM_PRIM)
	mkdir -p $(BUILD_DIR)
	iverilog -g2005-sv -DIVERLOG -o $@ $^

.PHONY: sim
sim: $(BUILD_DIR)/top_vvp tb_top.v $(GOWIN_SIM_PRIM)
#	rm -f *.vcd || true
#	rm -f *.vcd.gz || true
	vvp $(BUILD_DIR)/top_vvp
	gzip *.vcd || true

$(BUILD_DIR)/top_pnr.json : $(BUILD_DIR)/top_synth.json $(CST)
	mkdir -p $(BUILD_DIR)
	$(NEXTPNR) --json $< --write $@ --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=$(CST)

$(BUILD_DIR)/top.fs: $(BUILD_DIR)/top_pnr.json
	$(GOWIN_PACK) -d GW2A-18C -o $@ $<

.PHONY: program-sram-top
program-sram-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -m $<

.PHONY: program-flash-top
program-flash-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -f $<

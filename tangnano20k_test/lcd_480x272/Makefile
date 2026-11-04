YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack
# Gowin primitive models (rPLL)
GOWIN_SIM_PRIM = ../../sim/models/gowin_prims.v

BUILD_DIR=out

VERILOG_FILES = \
	lcd_ctrl.v \
	top.v \
	pll126_9.v

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
# no build dependency: build the bitstream first (make)
program-sram-top:
	@test -f $(BUILD_DIR)/top.fs || { echo "$(BUILD_DIR)/top.fs missing, run make first"; exit 1; }
	openFPGALoader -btangnano20k -m $(BUILD_DIR)/top.fs

.PHONY: program-flash-top
# no build dependency: build the bitstream first (make)
program-flash-top:
	@test -f $(BUILD_DIR)/top.fs || { echo "$(BUILD_DIR)/top.fs missing, run make first"; exit 1; }
	openFPGALoader -btangnano20k -f $(BUILD_DIR)/top.fs

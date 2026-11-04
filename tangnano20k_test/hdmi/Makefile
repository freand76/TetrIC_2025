YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack

BUILD_DIR=out

RTL=../../rtl
MODELS=../../sim/models

VERILOG_FILES = \
	top.v \
	pll126.v \
	$(RTL)/video/dvi/hdmi_generator.v \
	$(RTL)/video/dvi/tmds_channel.v

CST=tangnano20k.cst

all: $(BUILD_DIR)/top.fs

.PHONY: synth
synth: $(BUILD_DIR)/top_synth.json

.PHONY: pnr
pnr: $(BUILD_DIR)/top_pnr.json

.PHONY: fs-image
fs-image: $(BUILD_DIR)/top.fs

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/top_synth.json : $(VERILOG_FILES)
	mkdir -p $(BUILD_DIR)
	$(YOSYS) -p "read_verilog -sv $^; synth_gowin -json $@"

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

# ---- simulation ----
# Decodes the HDMI stream and checks the audio (4 kHz sine) for SIM_MS ms.
SIM_MS ?= 50
SIM_DIR = $(BUILD_DIR)/sim

.PHONY: sim
sim:
	mkdir -p $(SIM_DIR)
	iverilog -g2012 -DSIM_MS=$(SIM_MS) -s tb_hdmi -o $(SIM_DIR)/tb_hdmi.vvp \
		sim/tb_hdmi.v $(MODELS)/gowin_prims.v $(VERILOG_FILES)
	cd $(SIM_DIR) && vvp -n tb_hdmi.vvp

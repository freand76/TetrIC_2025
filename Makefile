YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack

BUILD_DIR=out/

all: $(BUILD_DIR)/uart_top.fs

$(BUILD_DIR)/uart_top_synth.json : tangnano20k/uart_top.v
	mkdir -p $(BUILD_DIR)
	$(YOSYS) -p "read_verilog $^; synth_gowin -json $@"

$(BUILD_DIR)/uart_top_pnr.json : $(BUILD_DIR)/uart_top_synth.json tangnano20k/top.cst
	mkdir -p $(BUILD_DIR)
	$(NEXTPNR) --json $< --write $@ --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=tangnano20k/top.cst

$(BUILD_DIR)/uart_top.fs: $(BUILD_DIR)/uart_top_pnr.json
	$(GOWIN_PACK) -d GW2A-18C -o $@ $<

.PHONY: program-uart_top
program-uart_top: $(BUILD_DIR)/uart_top.fs
	openFPGALoader -btangnano20k -f $<

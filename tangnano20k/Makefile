YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack

BUILD_DIR=out

all: $(BUILD_DIR)/top.fs

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/top_synth.json : top.v uart_tx.v
	mkdir -p $(BUILD_DIR)
	$(YOSYS) -p "read_verilog $^; synth_gowin -json $@"

$(BUILD_DIR)/top_pnr.json : $(BUILD_DIR)/top_synth.json top.cst
	mkdir -p $(BUILD_DIR)
	$(NEXTPNR) --json $< --write $@ --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=top.cst

$(BUILD_DIR)/top.fs: $(BUILD_DIR)/top_pnr.json
	$(GOWIN_PACK) -d GW2A-18C -o $@ $<

.PHONY: program-top
program-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -f $<

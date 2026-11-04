YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack

CST=tangnano20k.cst

BUILD_DIR=out

RTL=../../rtl
MODELS=../../sim/models

VERILOG_FILES = \
	sdram_test_top.v \
	$(RTL)/flash_reader/flash_reader.v \
	sdram.v \
	sdram_wrap.v

IVERILOG_FILES = \
	sdram_model.v \
	$(MODELS)/spi_flash_model.v

TANGNANO_FILES = \
	$(RTL)/uart_tx/uart_tx.v

all: iverilog synth

.PHONY: synth
synth: $(BUILD_DIR)/top_synth.json

.PHONY: iverilog
iverilog: $(BUILD_DIR)/top_vvp

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/top_vvp: $(VERILOG_FILES) $(IVERILOG_FILES)

	mkdir -p $(BUILD_DIR)
	iverilog -g2005-sv -DIVERLOG -o $@ $^ -DSDRAM_DEBUG

$(BUILD_DIR)/top_synth.json : $(VERILOG_FILES) $(TANGNANO_FILES)
	mkdir -p $(BUILD_DIR)
	$(YOSYS) -p "read_verilog -sv $^ ; synth_gowin -json $@"

$(BUILD_DIR)/top_pnr.json : $(BUILD_DIR)/top_synth.json $(CST)
	mkdir -p $(BUILD_DIR)
	$(NEXTPNR) --json $< --write $@ --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=$(CST)

$(BUILD_DIR)/top.fs: $(BUILD_DIR)/top_pnr.json
	$(GOWIN_PACK) -d GW2A-18C -o $@ $<

run: $(BUILD_DIR)/top_vvp MEM.TXT
	vvp $(BUILD_DIR)/top_vvp

.PHONY: program-sram-top
program-sram-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -m $<

.PHONY: program-flash-top
program-flash-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -f $<

.PHONY: program-text
program-text:
	openFPGALoader -btangnano20k --external-flash -o 0x600000 sdram_test.bin

MEM.TXT: sdram_test.bin
	hexdump -v -e '4/1 "%02x " "\n"' $< > $@

YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack

BUILD_DIR=out

SRC_TOP=../src/top

PROCESSOR_FILES = \
	$(SRC_TOP)/processor/processor.v \
	$(SRC_TOP)/processor/alu/alu.v \
	$(SRC_TOP)/processor/alu/lshifter.v \
	$(SRC_TOP)/processor/alu/rshifter.v \
	$(SRC_TOP)/processor/branchlogic/branchlogic.v \
	$(SRC_TOP)/processor/ctrl/ctrl.v \
	$(SRC_TOP)/processor/fwunit/fwunit.v \
	$(SRC_TOP)/processor/instr_or_nop/instr_or_nop.v \
	$(SRC_TOP)/processor/mux2/mux2.v \
	$(SRC_TOP)/processor/mux4/mux4.v \
	$(SRC_TOP)/processor/pipereg/pipereg.v \
	$(SRC_TOP)/processor/signext/signext.v


#PROCESSOR_FILES += $(SRC_TOP)/processor/regbank/regbank.v
PROCESSOR_FILES += $(SRC_TOP)/processor/regbank/regbank_sram.v

all: $(BUILD_DIR)/top.fs

.PHONY: synth
synth: $(BUILD_DIR)/top_synth.json

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/top_synth.json : ${SRC_TOP}/uart_tx/uart_tx.v ${SRC_TOP}/flash_reader/flash_reader.v $(PROCESSOR_FILES) processor_ram.v top.v
	mkdir -p $(BUILD_DIR)
	$(YOSYS) -p "read_verilog -sv $^; synth_gowin -json $@"

$(BUILD_DIR)/top_pnr.json : $(BUILD_DIR)/top_synth.json top.cst
	mkdir -p $(BUILD_DIR)
	$(NEXTPNR) --json $< --write $@ --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=top.cst

$(BUILD_DIR)/top.fs: $(BUILD_DIR)/top_pnr.json
	$(GOWIN_PACK) -d GW2A-18C -o $@ $<

.PHONY: program-sram-top
program-sram-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -m $<

.PHONY: program-flash-top
program-flash-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -f $<

.PHONY: program-flash-test
program-flash-test: test.hex
	openFPGALoader -btangnano20k --external-flash -o 0x500000 $<

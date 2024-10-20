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

VERILOG_FILES = \
	$(PROCESSOR_FILES) \
	$(SRC_TOP)/memory_controller/memory_controller.v \
	$(SRC_TOP)/memory_controller/memory_arbiter.v \
	$(SRC_TOP)/icache/icache.v \
	$(SRC_TOP)/icache/icache_mem.v \
	$(SRC_TOP)/uart_tx/uart_tx.v \
	$(SRC_TOP)/flash_reader/flash_reader.v \
	$(SRC_TOP)/video/video.v \
	$(SRC_TOP)/video/video_dma.v \
	$(SRC_TOP)/video/line_mem.v \
	$(SRC_TOP)/video/dvi/dvi_generator.v \
	$(SRC_TOP)/video/dvi/tmds_channel.v \
	$(SRC_TOP)/top.v

TANGNANO20K_FILES = \
	tangnano20k_top.v \
	processor_ram.v \
	pll.v

CST=tangnano20k.cst

all: check $(BUILD_DIR)/top.fs

.PHONY: synth
synth: $(BUILD_DIR)/top_synth.json

.PHONY: pnr
pnr: $(BUILD_DIR)/top_pnr.json

.PHONY: fs-image
fs-image: $(BUILD_DIR)/top.fs

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/top_synth.json : $(VERILOG_FILES) $(TANGNANO20K_FILES)
	mkdir -p $(BUILD_DIR)
	$(YOSYS) -p "read_verilog -sv $^; synth_gowin -json $@"

$(BUILD_DIR)/top_pnr.json : $(BUILD_DIR)/top_synth.json $(CST)
	mkdir -p $(BUILD_DIR)
	$(NEXTPNR) --json $< --write $@ --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=$(CST)

$(BUILD_DIR)/top.fs: $(BUILD_DIR)/top_pnr.json
	$(GOWIN_PACK) -d GW2A-18C -o $@ $<

.PHONY: check
check: $(TANGNANO20K_FILES)
	iverilog -g2005-sv -DIVERLOG $^ -i && rm -rf a.out

.PHONY: program-sram-top
program-sram-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -m $<

.PHONY: program-flash-top
program-flash-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -f $<

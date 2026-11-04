YOSYS ?= yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack

BUILD_DIR=out

RTL=../rtl

PROCESSOR_FILES = \
	$(RTL)/processor/processor.v \
	$(RTL)/processor/alu/alu.v \
	$(RTL)/processor/alu/lshifter.v \
	$(RTL)/processor/alu/rshifter.v \
	$(RTL)/processor/branchlogic/branchlogic.v \
	$(RTL)/processor/ctrl/ctrl.v \
	$(RTL)/processor/fwunit/fwunit.v \
	$(RTL)/processor/instr_or_nop/instr_or_nop.v \
	$(RTL)/processor/mux2/mux2.v \
	$(RTL)/processor/mux4/mux4.v \
	$(RTL)/processor/pipereg/pipereg.v \
	$(RTL)/processor/signext/signext.v

#PROCESSOR_FILES += $(RTL)/processor/regbank/regbank.v
PROCESSOR_FILES += $(RTL)/processor/regbank/regbank_sram.v

VERILOG_FILES = \
	$(PROCESSOR_FILES) \
	$(RTL)/cdc/cdc.v \
	$(RTL)/sdram/sdram_ctrl.v \
	$(RTL)/memory_controller/memory_controller.v \
	$(RTL)/memory_controller/memory_arbiter.v \
	$(RTL)/icache/icache.v \
	$(RTL)/icache/icache_mem.v \
	$(RTL)/uart_tx/uart_tx.v \
	$(RTL)/flash_reader/flash_reader.v \
	$(RTL)/gamepad/gamepad.v \
	$(RTL)/video/video.v \
	$(RTL)/video/video_dma.v \
	$(RTL)/video/line_mem.v \
	$(RTL)/sound/sound.v \
	$(RTL)/sound/sound_seq.v \
	$(RTL)/video/dvi/hdmi_generator.v \
	$(RTL)/video/dvi/tmds_channel.v \
	$(RTL)/top.v

TANGNANO20K_FILES = \
	tangnano20k_top.v \
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
	$(YOSYS) -q -l $(BUILD_DIR)/yosys.log -p "read_verilog -sv $^; synth_gowin -top tangnano20k_top -json $@"

$(BUILD_DIR)/top_pnr.json : $(BUILD_DIR)/top_synth.json $(CST)
	mkdir -p $(BUILD_DIR)
	$(NEXTPNR) --json $< --write $@ --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=$(CST) -l $(BUILD_DIR)/nextpnr.log

$(BUILD_DIR)/top.fs: $(BUILD_DIR)/top_pnr.json
	$(GOWIN_PACK) -d GW2A-18C -o $@ $<

.PHONY: check
check: $(TANGNANO20K_FILES)
	iverilog -g2005-sv -DIVERLOG $^ -i && rm -rf a.out

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

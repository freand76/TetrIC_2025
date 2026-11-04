YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack

BUILD_DIR=out

SRC_TOP=../src/top
TESTCODE_FOLDER=../test_code
SPI_FLASH_MDOEL=/projects/W25Q64JVxxIM/W25Q64JVxxIM.v

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
	$(SPI_FLASH_MDOEL) \
	$(SRC_TOP)/cdc/cdc.v \
	$(SRC_TOP)/sdram/sdram_ctrl.v \
	$(SRC_TOP)/sdram/sdram_model_burst.v \
	$(SRC_TOP)/memory_controller/memory_controller.v \
	$(SRC_TOP)/memory_controller/memory_arbiter.v \
	$(SRC_TOP)/icache/icache.v \
	$(SRC_TOP)/icache/icache_mem.v \
	$(SRC_TOP)/flash_reader/flash_reader.v \
	$(SRC_TOP)/gamepad/gamepad.v \
	$(SRC_TOP)/gamepad/ps2pad_model.v \
	$(SRC_TOP)/video/video.v \
	$(SRC_TOP)/video/video_dma.v \
	$(SRC_TOP)/video/line_mem.v \
	$(SRC_TOP)/sound/sound.v \
	$(SRC_TOP)/sound/sound_seq.v \
	$(SRC_TOP)/video/dvi/hdmi_generator.v \
	$(SRC_TOP)/video/dvi/tmds_channel.v \
	$(SRC_TOP)/top.v \
	iverilog_top.v

all: $(BUILD_DIR)/top_vvp MEM.TXT

.PHONY: synth
synth: $(BUILD_DIR)/top_vvp

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/top_vvp: $(VERILOG_FILES)
	mkdir -p $(BUILD_DIR)
	iverilog -g2005-sv -DIVERLOG -o $@ $^

$(TESTCODE_FOLDER)/MEM.TXT:
	make -C $(TESTCODE_FOLDER) MEM.TXT

.PHONY: MEM.TXT
MEM.TXT: $(TESTCODE_FOLDER)/MEM.TXT
	cp $(TESTCODE_FOLDER)/MEM.TXT .

run: $(BUILD_DIR)/top_vvp MEM.TXT
	vvp $(BUILD_DIR)/top_vvp

# ---- sound test: test_code/sound_test.s through the whole system ----
# The audio log is checked bit exact against tools/sound_ref.py; the
# result is also written to out/sound/sound.wav.
SOUND_DIR = $(BUILD_DIR)/sound

.PHONY: sound
sound: $(BUILD_DIR)/top_vvp
	$(MAKE) -C $(TESTCODE_FOLDER) sound_test.bin
	mkdir -p $(SOUND_DIR)
	# zero padded: the simulation copies 1024 flash words (COPY_WORDS)
	{ hexdump -v -e '4/1 "%02x " "\n"' $(TESTCODE_FOLDER)/sound_test.bin; \
	  yes "00 00 00 00" | head -1024; } > $(SOUND_DIR)/MEM.TXT
	cp SECSI.TXT SFDP.TXT SREG.TXT $(SOUND_DIR)/
	cd $(SOUND_DIR) && vvp -n ../top_vvp +audio=audio.log +run_ns=16000000 | grep -v "^DBG \|^UART: \|PERIPHERAL_WRITE"
	python3 ../tools/sound_ref.py $(SOUND_DIR)/audio.log $(TESTCODE_FOLDER)/sound_test.bin --wav $(SOUND_DIR)/sound.wav

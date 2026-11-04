## Full-system simulation: rtl/top.v with the SPI flash, SDRAM and gamepad
## models (sim/models), iverilog. The test program is copied from the flash
## model (MEM.TXT) to SDRAM and run.
##
## make run     test_code/prg.s: UART output, SDRAM model and video frame checks
## make sound   test_code/sound_test.s: audio bit exact against tools/sound_ref.py
## make fwd     test_code/fwd_test.s: register forwarding, UART must print
##              00000005 00000005 0000000A
## make check   all three
##
## Each test runs in out/<test>/ (MEM.TXT, logs).

ROOT     = ../..
RTL      = $(ROOT)/rtl
MODELS   = $(ROOT)/sim/models
TESTCODE = $(ROOT)/test_code
TOOLS    = $(ROOT)/tools

BUILD_DIR = out
TB = $(BUILD_DIR)/tb_system

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
	$(RTL)/processor/signext/signext.v \
	$(RTL)/processor/regbank/regbank_sram.v

RTL_FILES = \
	$(PROCESSOR_FILES) \
	$(RTL)/cdc/cdc.v \
	$(RTL)/sdram/sdram_ctrl.v \
	$(RTL)/memory_controller/memory_controller.v \
	$(RTL)/memory_controller/memory_arbiter.v \
	$(RTL)/icache/icache.v \
	$(RTL)/icache/icache_mem.v \
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

SIM_FILES = \
	$(MODELS)/gowin_prims.v \
	$(MODELS)/spi_flash_model.v \
	$(MODELS)/sdram_model_burst.v \
	$(MODELS)/ps2pad_model.v \
	tb_system.v

# a program image for the flash model, zero padded: the simulation copies
# 1024 flash words to SDRAM (COPY_WORDS in rtl/top.v)
define memtxt
	mkdir -p $(2)
	{ hexdump -v -e '4/1 "%02x " "\n"' $(1); yes "00 00 00 00" | head -1024; } > $(2)/MEM.TXT
endef

FILTER = grep -v "^DBG \|^UART: \|PERIPHERAL_WRITE\|^REGDATA"

all: $(TB)

$(TB): $(RTL_FILES) $(SIM_FILES)
	mkdir -p $(BUILD_DIR)
	iverilog -g2005-sv -DIVERLOG -o $@ $^

.PHONY: run
run: $(TB)
	$(MAKE) -C $(TESTCODE) prg.bin
	$(call memtxt,$(TESTCODE)/prg.bin,$(BUILD_DIR)/run)
	cd $(BUILD_DIR)/run && vvp -n ../tb_system | tee sim.log | $(FILTER)
	grep -q "^SDRAM MODEL: .* 0 errors" $(BUILD_DIR)/run/sim.log
	grep -q "video frame: 0 pixel errors" $(BUILD_DIR)/run/sim.log

# ---- sound test: test_code/sound_test.s through the whole system ----
# The audio log is checked bit exact against tools/sound_ref.py; the
# result is also written to out/sound/sound.wav.
.PHONY: sound
sound: $(TB)
	$(MAKE) -C $(TESTCODE) sound_test.bin
	$(call memtxt,$(TESTCODE)/sound_test.bin,$(BUILD_DIR)/sound)
	cd $(BUILD_DIR)/sound && vvp -n ../tb_system +audio=audio.log +run_ns=16000000 | $(FILTER)
	python3 $(TOOLS)/sound_ref.py $(BUILD_DIR)/sound/audio.log $(TESTCODE)/sound_test.bin \
	  --wav $(BUILD_DIR)/sound/sound.wav

# ---- forwarding test: test_code/fwd_test.s ----
.PHONY: fwd
fwd: $(TB)
	$(MAKE) -C $(TESTCODE) fwd_test.bin
	$(call memtxt,$(TESTCODE)/fwd_test.bin,$(BUILD_DIR)/fwd)
	cd $(BUILD_DIR)/fwd && vvp -n ../tb_system | tee sim.log | $(FILTER)
	@if grep -A3 "^UART output" $(BUILD_DIR)/fwd/sim.log | tr '\n' ' ' | \
	    grep -q "00000005 00000005 0000000A"; then echo "PASS: forwarding"; \
	  else echo "FAIL: forwarding"; exit 1; fi

.PHONY: check
check: run sound fwd

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR)

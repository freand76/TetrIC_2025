BUILD_DIR=out

VERILOG_FILES = \
	sdram_test_top.v \
	sdram_model.v \
	../src/top/sdram/sdram.v \
	../src/top/sdram/sdram_wrap.v

all: $(BUILD_DIR)/top_vvp

.PHONY: synth
synth: $(BUILD_DIR)/top_vvp

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/top_vvp: $(VERILOG_FILES)
	mkdir -p $(BUILD_DIR)
	iverilog -g2005-sv -DIVERLOG -o $@ $^ -DSDRAM_DEBUG

run: $(BUILD_DIR)/top_vvp
	vvp $(BUILD_DIR)/top_vvp

YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack

BUILD_DIR=out

SRC_TOP=../src/top
SPI_FLASH_MDOEL=/projects/W25Q64JVxxIM/W25Q64JVxxIM.v

all: $(BUILD_DIR)/top_vvp

.PHONY: synth
synth: $(BUILD_DIR)/top_vvp

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/top_vvp: ${SRC_TOP}/flash_reader/flash_reader.v $(SPI_FLASH_MDOEL) ../tangnano20k/top.v iverilog_top.v
	mkdir -p $(BUILD_DIR)
	iverilog -g2005-sv -o $@ $^

run:
	vvp $(BUILD_DIR)/top_vvp

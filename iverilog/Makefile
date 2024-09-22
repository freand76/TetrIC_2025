YOSYS = yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack

BUILD_DIR=out

SRC_TOP=../src/top
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
	$(SRC_TOP)/processor/regbank/regbank.v \
	$(SRC_TOP)/processor/signext/signext.v

all: $(BUILD_DIR)/top_vvp

.PHONY: synth
synth: $(BUILD_DIR)/top_vvp

clean:
	rm -rf $(BUILD_DIR)

$(BUILD_DIR)/top_vvp: $(SRC_TOP)/flash_reader/flash_reader.v $(SPI_FLASH_MDOEL) $(PROCESSOR_FILES) ../tangnano20k/top.v iverilog_top.v
	mkdir -p $(BUILD_DIR)
	iverilog -g2005-sv -DIVERLOG -o $@ $^

prg.bin: prg.s
	abnasm.pl prg.s

MEM.TXT: prg.bin
	hexdump -v -e '4/1 "%02x " "\n"' $< > $@

run: MEM.TXT
	vvp $(BUILD_DIR)/top_vvp

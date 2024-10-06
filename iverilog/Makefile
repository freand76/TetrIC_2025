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
	$(SRC_TOP)/flash_reader/flash_reader.v \
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

YOSYS ?= yosys
NEXTPNR = nextpnr-himbaechel
GOWIN_PACK = gowin_pack
PYTHON ?= python3

CST=tangnano20k.cst

# SDRAM clock: "pll50" = separate 50.4 MHz PLL, 2 x pixel clock (default),
#              "pixel" = run SDRAM controller on the 25.2 MHz pixel clock
SDRAM_CLK ?= pll50

BUILD_DIR=out/$(SDRAM_CLK)
SIM_DIR ?= out/sim

ifeq ($(SDRAM_CLK),pixel)
DEFINES = -DSDRAM_CLK_PIXEL
endif

SPI_FLASH_MODEL ?= /projects/W25Q64JVxxIM
FLASH_START = 0x600000

CORE_FILES = \
	sdram_video_core.v \
	../src/top/sdram/sdram_ctrl.v \
	../src/top/flash_reader/flash_reader.v \
	../src/top/video/dvi/dvi_generator.v \
	../src/top/video/dvi/tmds_channel.v \
	../src/top/video/line_mem.v

VERILOG_FILES = \
	sdram_video_top.v \
	pll126.v \
	pll_sdram.v \
	$(CORE_FILES)

SIM_FILES = \
	sim/tb_sdram_video.v \
	../src/top/sdram/sdram_model_burst.v \
	sim/gowin_sim.v \
	$(SPI_FLASH_MODEL)/W25Q64JVxxIM.v \
	$(CORE_FILES)

# ---- simulation settings (override on the command line) ----
# Words copied from flash in simulation (full frame = 38400, 1MB = 262144).
# The rest of the frame buffer is back-door loaded into the SDRAM model.
SIM_COPY_WORDS ?= 4096
# SDRAM clock period in ns for simulation (19.841 = 50.4 MHz, 39.683 = 25.2 MHz)
SIM_SDRAM_PERIOD ?= 19.841
SIM_FREQ_KHZ ?= 50400
SIM_FRAMES ?= 1
# Extra read capture delay in the controller (only for negative testing)
SIM_RD_EXTRA ?= 0

all: $(BUILD_DIR)/top.fs

.PHONY: synth pnr sim sim-pixel image clean
synth: $(BUILD_DIR)/top_synth.json
pnr: $(BUILD_DIR)/top_pnr.json

clean:
	rm -rf out

$(BUILD_DIR)/top_synth.json : $(VERILOG_FILES)
	mkdir -p $(BUILD_DIR)
	$(YOSYS) -q -l $(BUILD_DIR)/yosys.log -p "read_verilog -sv $(DEFINES) $^ ; synth_gowin -top top -json $@"

$(BUILD_DIR)/top_pnr.json : $(BUILD_DIR)/top_synth.json $(CST)
	$(NEXTPNR) --json $< --write $@ --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=$(CST) -l $(BUILD_DIR)/nextpnr.log

$(BUILD_DIR)/top.fs: $(BUILD_DIR)/top_pnr.json
	$(GOWIN_PACK) -d GW2A-18C -o $@ $<

.PHONY: program-sram-top
program-sram-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -m $<

.PHONY: program-flash-top
program-flash-top: $(BUILD_DIR)/top.fs
	openFPGALoader -btangnano20k -f $<

# ---- flash image (1 MByte, starts with the 320x240 RGB565 frame) ----
# make image                  -> test pattern
# make image IMAGE_SRC=x.png  -> converted picture (needs Pillow)
image: out/image.bin
out/image.bin: tools/mkimage.py
	mkdir -p out
	$(PYTHON) tools/mkimage.py --pattern $(if $(IMAGE_SRC),--src $(IMAGE_SRC)) -o $@

.PHONY: program-image
program-image: out/image.bin
	openFPGALoader -btangnano20k --external-flash -o $(FLASH_START) $<

# ---- simulation ----
$(SIM_DIR)/tb_vvp: $(SIM_FILES)
	mkdir -p $(SIM_DIR)
	iverilog -g2005-sv -DIVERLOG -s tb_sdram_video \
		-Ptb_sdram_video.COPY_WORDS=$(SIM_COPY_WORDS) \
		-Ptb_sdram_video.SDRAM_PERIOD=$(SIM_SDRAM_PERIOD) \
		-Ptb_sdram_video.SDRAM_FREQ_KHZ=$(SIM_FREQ_KHZ) \
		-Ptb_sdram_video.FRAMES=$(SIM_FRAMES) \
		-Ptb_sdram_video.RD_EXTRA=$(SIM_RD_EXTRA) \
		-o $@ $(SIM_FILES)

$(SIM_DIR)/MEM.TXT: tools/mkimage.py
	mkdir -p $(SIM_DIR)
	$(PYTHON) tools/mkimage.py --random --seed 1 -o $(SIM_DIR)/image.bin \
		--memtxt $@ --flash-start $(FLASH_START) --hexwords $(SIM_DIR)/image_words.hex
	cp $(SPI_FLASH_MODEL)/SECSI.TXT $(SPI_FLASH_MODEL)/SFDP.TXT $(SPI_FLASH_MODEL)/SREG.TXT $(SIM_DIR)/

# Simulation always rebuilds (parameters are command line overridable)
sim: $(SIM_DIR)/MEM.TXT
	rm -f $(SIM_DIR)/tb_vvp
	$(MAKE) $(SIM_DIR)/tb_vvp
	cd $(SIM_DIR) && vvp -n tb_vvp

# Same as sim, but with the SDRAM controller on the 25.2 MHz pixel clock
sim-pixel:
	$(MAKE) sim SIM_SDRAM_PERIOD=39.683 SIM_FREQ_KHZ=25200

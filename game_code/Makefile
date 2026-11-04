## TetrIC game for the Tang Nano 20K system
##
## make                 assemble (out/TetrIC.bin)
## make program-flash   write it to the SPI flash at 0x500000 (copied to SDRAM at start)

ASM ?= uv run --script ../tools/abnasm.py
FLASH_START = 0x500000

OUT    = out
TARGET = TetrIC

MACRO   = TLib/Macro.s
STARTUP = Startup.s

SOURCES = \
	TLib/Math.s \
	TLib/Joy.s \
	TLib/Text.s \
	TLib/Gfx.s \
	TLib/Sound.s \
	Game.s \
	Intro.s \
	ViewHigh.s \
	Vector.s \
	FXMusic.s \
	ModeSwitch.s \
	EnterHigh.s \
	Stars.s \
	ScrollText.s \
	HighScoreList.s \
	Bars.s

DATA = $(wildcard Data/*) $(wildcard TLib/Data/*) TheText.txt

all: $(OUT)/$(TARGET).bin

# The sources are concatenated and assembled in one go (.file paths are
# relative to this directory)
$(OUT)/$(TARGET).s: $(MACRO) $(STARTUP) $(SOURCES)
	mkdir -p $(OUT)
	cat $^ > $@

$(OUT)/$(TARGET).bin: $(OUT)/$(TARGET).s $(DATA)
	$(ASM) $<

program-flash: $(OUT)/$(TARGET).bin
	openFPGALoader -btangnano20k --external-flash -o $(FLASH_START) $<

clean:
	rm -rf $(OUT)

.PHONY: all program-flash clean

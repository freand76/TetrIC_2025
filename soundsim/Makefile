## Stand-alone simulation of the sound unit (src/top/sound/sound.v)
##
## make beat     the game's beat loop (PlayBeat) from game_code/out/TetrIC.bin
## make mod      the game music (MOD player, channels 0..3), MOD_MS ms
## make fxmod    MOD effects test song (fxmod.py), 3.2 s
##
## Verilator by default; SIM=iverilog for Icarus (about 25 times slower).
##
## Each test writes out/<test>.log (checked bit exact with tools/sound_ref.py)
## and out/<test>.wav.

SRC = ../src/top
OUT = out
GAME_BIN = ../game_code/out/TetrIC.bin

GAME_LST = ../game_code/out/TetrIC.2
SIM ?= verilator
MOD_MS ?= 3000
# clocks per output sample (525 = 48 kHz at 25.2 MHz); smaller is faster
SAMPLE_DIV ?= 525

SOURCES = tb_sound.v models.v $(SRC)/sound/sound.v $(SRC)/sound/sound_seq.v $(SRC)/cdc/cdc.v

ifeq ($(SIM),iverilog)
TB = $(OUT)/tb_sound
RUN = vvp -n $(TB)
else
TB = $(OUT)/vl/tb_sound_vl
RUN = $(TB)
endif

$(OUT)/tb_sound: $(SOURCES)
	mkdir -p $(OUT)
	iverilog -g2012 -DSAMPLE_DIV=$(SAMPLE_DIV) -o $@ $(SOURCES)

$(OUT)/vl/tb_sound_vl: $(SOURCES)
	mkdir -p $(OUT)
	verilator --binary --timing -j 8 -O3 -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD \
	  -DSAMPLE_DIV=$(SAMPLE_DIV) --top-module tb_sound -Mdir $(OUT)/vl -o tb_sound_vl \
	  $(SOURCES) > $(OUT)/verilator.log 2>&1

$(OUT)/mod.txt: mod_script.py $(GAME_LST)
	mkdir -p $(OUT)
	python3 mod_script.py $(GAME_LST) $@

$(OUT)/game.hex: $(GAME_BIN)
	mkdir -p $(OUT)
	xxd -p -c4 $< > $@

.PHONY: beat
beat: $(TB) $(OUT)/game.hex
	$(RUN) +mem=$(OUT)/game.hex +script=beat.txt +samples=24000 +audio=$(OUT)/beat.log
	python3 ../tools/sound_ref.py $(OUT)/beat.log $(GAME_BIN) --wav $(OUT)/beat.wav

.PHONY: mod
mod: $(TB) $(OUT)/game.hex $(OUT)/mod.txt
	$(RUN) +mem=$(OUT)/game.hex +script=$(OUT)/mod.txt +samples=$$(($(MOD_MS) * 48)) +audio=$(OUT)/mod.log | grep -v '^- '
	python3 ../tools/sound_ref.py $(OUT)/mod.log $(GAME_BIN) --wav $(OUT)/mod.wav

$(OUT)/fxmod.hex: fxmod.py ../game_code/TLib/Data/Lut.raw
	mkdir -p $(OUT)
	python3 fxmod.py ../game_code/TLib/Data/Lut.raw $(OUT)/fxmod

.PHONY: fxmod
fxmod: $(TB) $(OUT)/fxmod.hex
	$(RUN) +mem=$(OUT)/fxmod.hex +script=$(OUT)/fxmod.txt +samples=153600 +audio=$(OUT)/fxmod.log | grep -v '^- '
	python3 ../tools/sound_ref.py $(OUT)/fxmod.log $(OUT)/fxmod.bin --wav $(OUT)/fxmod.wav

.PHONY: clean
clean:
	rm -rf $(OUT)

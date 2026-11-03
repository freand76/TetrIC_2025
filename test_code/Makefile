ASM ?= python3 ../tools/abnasm.py

# program to write to flash: make program-flash-code PRG=video_test
PRG ?= prg

all: MEM.TXT

clean:
	rm -f MEM.TXT *.bin *.1 *.2

prg.bin: prg.s HelloWorld.txt
	$(ASM) $<

%.bin: %.s
	$(ASM) $<

MEM.TXT: prg.bin
	hexdump -v -e '4/1 "%02x " "\n"' $< > $@

program-flash-code: $(PRG).bin
	openFPGALoader -btangnano20k --external-flash -o 0x500000 $<

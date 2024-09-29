all: MEM.TXT

clean:
	rm -f MEM.TXT prg.bin prg.1 prg.2

prg.bin: prg.s HelloWorld.txt
	abnasm.pl $<

MEM.TXT: prg.bin
	hexdump -v -e '4/1 "%02x " "\n"' $< > $@

program-flash-code: prg.bin
	openFPGALoader -btangnano20k --external-flash -o 0x500000 $<

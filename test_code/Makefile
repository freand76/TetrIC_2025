all: MEM.TXT

clean:
	rm MEM.TXT prg.bin prg.1 prg.2

prg.bin: prg.s
	abnasm.pl $<

MEM.TXT: prg.bin
	hexdump -v -e '4/1 "%02x " "\n"' $< > $@

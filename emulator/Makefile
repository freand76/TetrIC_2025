## TetrIC emulator (Rust). See README.md.
##
## make            build (target/release/tetric_emu, tetric_check)
## make run        play the game (game_code/out/TetrIC.bin)
## make windows    Windows x86_64 build with cargo-zigbuild
##                 (target/x86_64-pc-windows-gnu/release/tetric_emu.exe)
## make test       unit tests and the test programs (test_code)
## make rtl-check  cross check with the RTL simulation (Verilator, ~10 min)

GAME = ../game_code/out/TetrIC.bin

.PHONY: all run windows test rtl-check clean
all:
	cargo build --release

$(GAME):
	$(MAKE) -C ../game_code

run: all $(GAME)
	target/release/tetric_emu --flash $(GAME) --scale 2

windows:
	cargo zigbuild --release --target x86_64-pc-windows-gnu

test:
	$(MAKE) -C ../test_code prg.bin fwd_test.bin
	cargo test --release

rtl-check:
	./rtl_check.sh

clean:
	cargo clean
	rm -rf out

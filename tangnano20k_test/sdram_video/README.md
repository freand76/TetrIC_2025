# SDRAM video test (Tang Nano 20K)

1. After reset, 1 MByte is copied from SPI flash (`FLASH_START` = 0x600000) to SDRAM address 0.
2. A 320x240 RGB565 frame buffer at SDRAM address 0 is then shown over HDMI at 640x480. Each line is shown twice, and each pixel is two pixels wide.

## Frame buffer format

The frame buffer is packed at 640 bytes per line. Pixels are RGB565, stored big endian in flash (high byte first). The flash reader shifts MSB first, so each 32-bit SDRAM word holds two pixels, with the left pixel in bits 31:16.

## Architecture

| Block | Clock | Notes |
|-------|-------|-------|
| `flash_reader`, DVI timing, line memory read | `clk_pixel` 25.2 MHz | |
| `sdram_ctrl`, line memory write | `clk_sdram` 50.4 MHz | separate PLL (`pll_sdram.v`): 302.4 MHz / 6 on CLKOUTD. The SDRAM CLK pin uses the controller clock |

- Signals cross between the domains with toggle synchronisers in `sdram_video_core.v`. Any clock ratio works.
- `make SDRAM_CLK=pixel` runs the controller on the pixel clock instead. That is the same clocking as the earlier single-word SDRAM tests.
- `sdram_ctrl.v` uses full-page read bursts, terminated with PRECHARGE, and single-word writes (mode register A9=1). Refresh is internal (7.8 us), and the timings are derived from `FREQ_KHZ`.
- A 160-word line that crosses an SDRAM row (256 words) is split into two bursts.
- At the end of the visible part of HDMI line 2k, source line k+1 is fetched into the other line memory (even/odd lines). Line 0 is fetched on the last line of the frame.
- Both clock modes have been checked on hardware. A ~101 MHz version was dropped: some DQ bits read wrong, most likely because the I/O registers sit in the fabric with uneven routing delays.

## Make targets

| Target | Description |
|--------|-------------|
| `make` / `make SDRAM_CLK=pixel` | bitstream in `out/pll50/top.fs` or `out/pixel/top.fs` |
| `make program-sram-top` / `program-flash-top` | load the bitstream |
| `make image` | build the 1 MByte flash image `out/image.bin` with a test pattern (`IMAGE_SRC=pic.png` converts a picture; uv installs Pillow for the script) |
| `make program-image` | write the image to external flash at 0x600000 |
| `make sim` | iverilog simulation, SDRAM controller at 50.4 MHz (see below) |
| `make sim-pixel` | same, with the SDRAM controller at 25.2 MHz |

## Simulation

The simulation uses `sim/tb_sdram_video.v`, the SPI flash model `../../sim/models/spi_flash_model.v`, and the burst-capable SDRAM model `../../sim/models/sdram_model_burst.v`.

It checks:

- the SDRAM contents after the flash copy
- every pixel of a full 640x480 HDMI frame
- SDRAM timing and protocol, using the model's checks

The first frame is written to `out/sim/frame.ppm`.

To keep runtime short, only `SIM_COPY_WORDS` (default 4096) words are copied from flash, and the rest of the frame is loaded through the back door. Use `make sim SIM_COPY_WORDS=38400` to copy the whole frame from flash. That run is slow.

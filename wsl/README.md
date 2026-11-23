# TetrIC on Windows with WSL

How to build, simulate, emulate and program TetrIC from a Windows PC with
WSL2 (Windows Subsystem for Linux). Everything runs in a WSL distro of its own,
used only for this project: the whole setup is removed with one command.

Tested on Windows 11 with Ubuntu 26.04 in WSL2 (WSLg for the emulator window and
sound).

## 1. Create the distro (PowerShell)

```
wsl --install                              # only if WSL is not installed yet; reboot afterwards
wsl --list --online                        # the Ubuntu versions available
wsl --install -d Ubuntu-26.04 --name tetric
```

* `--name` needs a recent WSL (`wsl --update`).
* Pick a Linux user name and password when asked. `sudo` asks for this password.
* Start the distro later with `wsl -d tetric`.

## 2. Install the tools (in the distro)

```
curl -LO https://raw.githubusercontent.com/freand76/TetrIC_2025/main/wsl/setup_tetric.sh
bash setup_tetric.sh
```

or, from a clone, `bash wsl/setup_tetric.sh`. It takes a while; building nextpnr
is most of it. The script:

| Step | What |
|---|---|
| apt | Yosys, Icarus Verilog, Verilator, GTKWave, CMake, compilers and the libraries for nextpnr, openFPGALoader and the emulator |
| audio | `~/.asoundrc` routes ALSA to the PulseAudio server of WSLg (WSL has no ALSA sound card) |
| clone | this repository into `~/TetrIC_2025` |
| uv, Rust | installed in `~/.local/bin` and `~/.cargo` |
| Apicula 0.35 | `uv tool install apycula==0.35` (`gowin_pack`) |
| nextpnr-himbaechel | built in `~/src/nextpnr` for the GW2A-18C, installed in `~/.local` |
| openFPGALoader | built in `~/src/openFPGALoader`, installed in `~/.local`; udev rules, user added to `plugdev` |

Then close and reopen the terminal (or `exec $SHELL -l`). The script can be run
again; finished steps are skipped or redone.

nextpnr is configured with `-DPython3_EXECUTABLE` set to the Python of the
Apicula tool, so the chip database build can import Apicula.

* Keep the work in the Linux file system (`~`), not under `/mnt/c`: builds are
  much faster there.

## 3. Check the setup

```
cd ~/TetrIC_2025
make -C emulator run       # game in a window; press Enter for the menu (the intro is silent)
./uv_run_pytest.sh         # module testbenches
make -C tangnano20k        # bitstream: tangnano20k/out/top.fs (about 10 minutes)
```

If the emulator has no sound, check `pactl info`: it should show
`unix:/mnt/wslg/PulseServer`. If not, run `wsl --shutdown` in PowerShell and
start the distro again.

## 4. Connect the board (usbipd)

WSL doesn't see USB devices by itself. [usbipd-win](https://github.com/dorssel/usbipd-win)
passes the board through. In PowerShell:

```
winget install usbipd                      # once
usbipd list                                # find the board: 0403:6010 "20K's FRIEND"
usbipd bind --busid <busid>                # once, in an administrator PowerShell
usbipd attach --wsl --busid <busid>        # after every replug or WSL restart
```

In the distro the board shows up as `/dev/ttyUSB0` and `/dev/ttyUSB1`:

```
openFPGALoader -btangnano20k --detect      # should find the GW2A-18C
openFPGALoader -btangnano20k -f tangnano20k/bitstream/tetric.fs
make -C game_code program-flash
```

`usbipd detach --busid <busid>` gives the board back to Windows.

## Remove everything (PowerShell)

```
wsl --unregister tetric
```

This deletes the distro and all files in it.

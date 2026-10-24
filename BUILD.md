# Building Nekketsu

The core is built inside a [jtcores](https://github.com/jotego/jtcores) checkout with jotego's `jtcore` tool. No patches to jtcores are needed. ROMs are loaded at run time from the MRA, so the bitstream contains no game data.

## Requirements

- **jtcores** at the commit in [`JTCORES_COMMIT`](JTCORES_COMMIT), the version this core is built and tested with. Newer commits may work but are not tested.
- The tools `jtcore` uses (see jtcores' `modules/jtframe/doc/compilation.md`):
  - bash 4 or newer
  - Go 1.22 or newer (the `jtframe` tool is built on first use)
  - gawk
  - Python 3, available as `python`
  - git, and GNU coreutils (`ln -r`, `realpath --relative-to`)
- **Quartus Prime Lite 17** or newer for the MiSTer target. Built here with 17.0.2.

On a usual Linux system everything except Go and Quartus is normally already installed.

## Steps

This flow is untested on Linux. The maintainer builds on macOS, where `jtcore` only generates the Quartus project and Quartus runs separately in a Linux container.

1. Get jtcores at the tested commit:

   ```sh
   git clone --recurse-submodules https://github.com/jotego/jtcores.git
   cd jtcores
   git checkout "$(cat <this repo>/JTCORES_COMMIT)"
   git submodule update --init --recursive
   ```

   The submodule `modules/jt539` is private and fails to clone over https. This core doesn't use it.

2. Put the core into jtcores, as a copy or a symbolic link:

   ```sh
   cp -r <this repo>/cores/nkdodge cores/nkdodge
   # or: ln -s <this repo>/cores/nkdodge cores/nkdodge
   ```

   With a link, `jtcore` writes its output (`mister/`, `ver/`) inside this repository. `.gitignore` already excludes it.

3. Build:

   ```sh
   source setprj.sh
   jtcore nkdodge -mister --nodbg
   ```

   `--nodbg` defines `JTFRAME_RELEASE`, which turns off JTFRAME's debug controls (START or COIN with the joystick changes an on-screen debug value, F7-F12 turn off graphics layers and sound channels). Leave it out only for a debug build.

   `jtcore` generates the Quartus project in `cores/nkdodge/mister/` and compiles it. The project is named after `CORENAME` in `cfg/macros.def`, so the bitstream is `cores/nkdodge/mister/output_files/nekketsu.rbf`.

4. Install on the MiSTer:
   - Copy the bitstream to `_Arcade/cores/Nekketsu_YYYYMMDD.rbf`. The MRAs load it through `<rbf>Nekketsu</rbf>`.
   - Copy the contents of `mra/` into `_Arcade/`: `Super Dodge Ball (US).mra` goes to `_Arcade/`, the Japanese set to `_Arcade/_alternatives/_Super Dodge Ball/`.

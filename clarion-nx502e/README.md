# Clarion NX502E — Reverse Engineering / Binary Patch Project

Reverse-engineering and binary-patching the firmware of the **Clarion NX502E**
double-DIN head unit (Windows CE / ARM) to add features missing from the
stock UI and, long-term, to replace the Clarion app with a custom one.

This subproject lives alongside the unrelated "Delete all Sim Mods" solution
in this repository. It is self-contained under `clarion-nx502e/` and does not
touch the main solution.

---

## Device facts

| Field       | Value                                       |
|-------------|---------------------------------------------|
| Model       | Clarion NX502E                              |
| OS          | Windows CE (Windows Embedded Compact)       |
| CPU         | ARM (Cortex-A8 class, ~600–800 MHz, LE)     |
| OS build    | PA01-V2.02.0038.13-15R8                     |
| Application | 1.07.1.38 (2015-03-13)                      |
| MCU         | V2.39 (Nov 13 2013)                         |
| MPEG        | EUR0.52 (2012-06-27) — update EUR0.61 avail |
| Bluetooth   | HW05-SW01.63.30                             |

## Firmware package layout (observed)

| Channel          | Medium    | Contents                                                                 |
|------------------|-----------|--------------------------------------------------------------------------|
| OS update        | microSD   | `NK.bin`, `TINYNK.bin` (WinCE kernel images)                             |
| MPU + MCU + BT   | microSD   | `MCU.bin`, `BT.bin`, `bootloader.bin`, `flasher.bin`, `updater.bin`, `CE69/` |
| MPEG update      | USB       | `build.img`                                                              |
| Runtime config   | int. SD   | `sys.txt`, `data.zip` (plain text / zip — **editable, no flash**)        |

## Goals (priority order)

1. **Mute → auto-pause media.** Hook the mute event, dispatch a pause to the
   media-player window via `PostMessageW(hMediaWnd, WM_COMMAND, ID_PAUSE, 0)`.
2. **Startup optimisation.** Don't auto-launch navigation, cut boot delay.
3. **Further QoL patches** once analysis surfaces low-hanging fruit.

See [`docs/PROJECT.md`](docs/PROJECT.md) for the full plan, toolchain, and
Thumb-2 BL hook strategy.

---

## Repository layout

```
clarion-nx502e/
├── README.md                  ← you are here
├── docs/
│   ├── PROJECT.md             ← full project plan, toolchain, hook strategy
│   └── ANALYSIS.md            ← living notes on firmware structure / findings
├── scripts/
│   ├── fetch_firmware.sh      ← download + extract NX502E.zip
│   └── analyze_layout.sh      ← offline triage (inventory + strings)
└── firmware/                  ← git-ignored; populated locally
    ├── downloads/             ← raw zips / images
    ├── extracted/             ← unzipped binaries
    └── analysis/              ← inventory.tsv, strings/, interesting.txt
```

**Nothing inside `firmware/` is ever committed.** The root `.gitignore` has a
`clarion-nx502e/firmware/` entry.

## Quickstart

```bash
# 1. Fetch and extract (MPU+MCU+BT archive; ~85 MB).
cd clarion-nx502e
./scripts/fetch_firmware.sh

# 2. Grab NK.bin (OS) and build.img (MPEG) manually from the sub-pages
#    printed at the end of the fetch script, drop them into
#    firmware/downloads/, then re-run:
./scripts/fetch_firmware.sh --verify

# 3. Run first-pass triage (inventory + strings + keyword scan).
./scripts/analyze_layout.sh

# 4. Inspect the results.
less firmware/analysis/inventory.tsv
less firmware/analysis/interesting.txt
```

The scripts need: `bash`, `curl`, `unzip`, `sha256sum`, `file`, `strings`
(binutils). All standard on Linux and macOS with Homebrew binutils.

## Safety / backup

Before writing *anything* back to the device's internal SD card, clone it:

```bash
sudo dd if=/dev/sdX of=nx502e_backup.img bs=4M status=progress conv=fsync
```

The `sys.txt` / `data.zip` track is low-risk (text config on a FAT partition).
The `NK.bin` / `MCU.bin` track is high-risk (bricks possible). Always have the
original firmware images on hand to re-flash a recovery SD.

## Legal

This work targets firmware on a device we own for personal use. We do not
redistribute Clarion firmware — the fetch script pulls from Clarion's own
public archive (`archive.clarion.com`) at run time.

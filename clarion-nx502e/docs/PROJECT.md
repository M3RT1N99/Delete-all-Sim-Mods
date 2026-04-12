# Clarion NX502E — Project Plan

Full reference plan for the reverse-engineering and binary-patching work.
The short version is in [`../README.md`](../README.md).

---

## Device

| Field       | Value                                       |
|-------------|---------------------------------------------|
| Model       | Clarion NX502E                              |
| OS          | Windows CE / Windows Embedded Compact       |
| CPU         | ARM (Cortex-A8 class, ~600–800 MHz, LE)     |
| OS build    | PA01-V2.02.0038.13-15R8                     |
| Application | 1.07.1.38 (2015-03-13)                      |
| MCU         | V2.39 (Nov 13 2013)                         |
| MPEG        | EUR0.52 (2012-06-27) — update EUR0.61 avail |
| Bluetooth   | HW05-SW01.63.30 (current)                   |

## What we know

### Firmware structure

- **OS update** via microSD: `NK.bin` + `TINYNK.bin` (WinCE kernel images).
- **MPU/MCU/BT update** via microSD: `MCU.bin`, `BT.bin`, `bootloader.bin`,
  `flasher.bin`, `updater.bin`, `CE69/` directory.
- **MPEG update** via USB: `build.img`.
- **Runtime config** on the internal microSD: `sys.txt`, `data.zip` —
  plain-text / zip, editable without flash risk.

### Official archive (live)

| Artefact         | URL                                                                          |
|------------------|------------------------------------------------------------------------------|
| MPU + MCU + BT   | https://archive.clarion.com/xe/en/pdf/NX502E.zip (~84.7 MB)                  |
| MPEG             | https://archive.clarion.com/xe/en/user-support/software/NX502E/MPEG/         |
| OS (NK.bin)      | https://archive.clarion.com/xe/en/user-support/software/NX502E/OS/           |
| Landing page     | https://archive.clarion.com/xe/en/user-support/software/NX502E/              |

### Community

- **gpspower.net** has NX502E threads covering alternative navigation
  (iGO Primo), `sys.txt` / `data.zip` modding.
- WinCE apps run as user-space `.exe` — custom programs are possible without
  touching the kernel.

## Toolchain

| Tool                                          | Purpose                                            |
|-----------------------------------------------|----------------------------------------------------|
| **IDA Pro** + Hex-Rays ARM                    | Main RE: disassembly + decompiler (F5)             |
| FLIRT signatures (FLIRTDB, `arm/`)            | Auto-label WinCE API calls                         |
| **cedecomp**                                  | NK.bin → individual `.exe` / `.dll`                |
| `arm-linux-gnueabi-gcc` (cross)               | Compile hook / trampoline code                     |
| Python + `keystone-engine`                    | Generate and inject patch bytes                    |

### IDA Pro setup for WinCE ARM

```
Processor: ARM Little-endian
Compiler:  Visual C++           (WinCE uses MSVC calling convention, not GCC)
Thumb:     ON ("Analyze Thumb instructions" must be enabled)
COREDLL:   Load as external library so API calls resolve automatically
FLIRT:     https://github.com/Maktm/FLIRTDB  (arm/ subtree)
```

## Planned features (priority)

1. **Mute → auto-pause media** *(primary goal)*
   - Mute event → `PostMessageW(hMediaWnd, WM_COMMAND, ID_PAUSE, 0)`.
   - Locate the mute handler in `MediaPlayer.exe` (or sibling) via IDA.

2. **Startup optimisation** — disable navigation auto-start, reduce boot delay.

3. **Further QoL patches** after analysis.

## Patch strategy — ARM Thumb-2 hook

Same pattern as FA_Patcher (SCFA), different architecture:

```
1. Locate target fn in IDA (e.g. MuteHandler).
2. Replace the first bytes with a Thumb-2 BL → our hook.
3. Hook re-implements the original prologue + adds the new logic.
4. Hook body lives in a free cave or a new PE section.
5. Repack NK.bin / MCU.bin.
6. Flash from microSD (keep a recovery image handy).
```

### Thumb-2 BL encoder

```python
import struct

def make_thumb2_bl(from_addr: int, to_addr: int) -> bytes:
    """Encode a Thumb-2 BL from from_addr to to_addr. Both must be halfword
    aligned. Returns 4 bytes (two halfwords, little-endian)."""
    offset = to_addr - from_addr - 4
    s  = (offset >> 24) & 1
    i1 = (offset >> 23) & 1
    i2 = (offset >> 22) & 1
    j1 = (~(i1 ^ s)) & 1
    j2 = (~(i2 ^ s)) & 1
    imm10 = (offset >> 12) & 0x3FF
    imm11 = (offset >> 1)  & 0x7FF
    hw1 = 0xF000 | (s << 10) | imm10
    hw2 = 0xF800 | (j1 << 13) | (j2 << 11) | imm11
    return struct.pack('<HH', hw1, hw2)
```

## Execution plan

- [ ] 1. Download `NX502E.zip` from the Clarion archive.
- [ ] 2. Build cedecomp → extract NK.bin → list EXEs.
- [ ] 3. IDA: load MediaPlayer EXE, wire up COREDLL + FLIRT sigs.
- [ ] 4. Find the mute handler via string search ("mute", "MUTE") and the
      `waveOut*` API.
- [ ] 5. Hex-Rays decompile → understand the logic.
- [ ] 6. Identify the PostMessage target (media-player HWND).
- [ ] 7. Write hook, inject Thumb-2 BL.
- [ ] 8. Repack and flash to a test microSD.

Progress lives in [`ANALYSIS.md`](ANALYSIS.md).

## Low-risk parallel track

Edit `sys.txt` directly on the navigation microSD — no flash risk, fully
reversible by restoring the backup image:

```ini
[interface]
show_exit=1

[startup]
autostart_navi=0
autostart_delay=2000

[audio]
mute_pauses_media=1   ; hypothetical; verify by scanning strings first
```

**Always clone the SD before touching it:**

```bash
sudo dd if=/dev/sdX of=nx502e_backup.img bs=4M status=progress conv=fsync
```

## References

- Clarion archive: https://archive.clarion.com/xe/en/user-support/software/NX502E/
- gpspower.net NX502E thread: https://www.gpspower.net/igo-primo-software-tools/342764-clarion-nx502e-nx702-primo-9-6-5-223767-a.html
- cedecomp: https://github.com/ncsdk/cedecomp
- FLIRT sigs: https://github.com/Maktm/FLIRTDB
- WinCE API docs: https://docs.microsoft.com/en-us/previous-versions/windows/embedded/

# NX502E — Firmware Analysis Notes

Living document. Fill in after running `scripts/fetch_firmware.sh` and
`scripts/analyze_layout.sh`. Every section has pinned questions we need
answered before writing any patch.

---

## 0. Download provenance

| File                 | Source URL                                           | Size | sha256 | Date fetched |
|----------------------|------------------------------------------------------|------|--------|--------------|
| `NX502E.zip`         | https://archive.clarion.com/xe/en/pdf/NX502E.zip     |      |        |              |
| `NK.bin`             | (OS sub-page)                                        |      |        |              |
| `TINYNK.bin`         | (OS sub-page)                                        |      |        |              |
| `build.img` (MPEG)   | (MPEG sub-page)                                      |      |        |              |

> Fill from `firmware/checksums.txt` after running the fetch script.

## 1. MPU + MCU + BT archive (`NX502E.zip`)

### 1.1 Top-level inventory

Paste the relevant rows from `firmware/analysis/inventory.tsv` here once the
analysis script has run:

```
size    sha256                                                              magic                                   path
----    ------                                                              -----                                   ----
```

### 1.2 Per-file first impressions

For each top-level binary, note:

- **`bootloader.bin`** — entry point, address, recognisable magic?
- **`flasher.bin`**    — is it a standalone stub or linked into updater?
- **`updater.bin`**    — how does it consume the other bins? Any manifest?
- **`MCU.bin`**        — vendor? (probably not ARM — MCU is separate µC)
- **`BT.bin`**         — Bluetooth chip firmware; which chip family?
- **`CE69/`**          — what does it hold?

### 1.3 Open questions

- [ ] Are the `.bin` files raw blobs, PE images, or a custom container?
- [ ] Is there a checksum / signature appended we need to preserve after patch?
- [ ] Which file actually drives the flash — is it `updater.bin` or
      `flasher.bin`?

## 2. OS image (`NK.bin`)

### 2.1 Extraction via cedecomp

```
# Expected output:
NK.bin -> <count> modules, <count> files
```

- [ ] Does cedecomp succeed on this NK.bin version or do we need to patch it?
- [ ] List of extracted `.exe` (only the ones with Clarion / NX502E / nav
      markers in the name or strings).

### 2.2 Candidate target EXEs for the mute patch

Rank from most to least likely. Fill in after a first pass of strings.

| EXE              | Hits for `mute` | Hits for `waveOut` | Hits for `MediaPlayer` | Rank |
|------------------|-----------------|--------------------|------------------------|------|
|                  |                 |                    |                        |      |

### 2.3 Primary target

Once identified:

- Name:
- Load address:
- Thumb or ARM mode:
- Mute handler RVA:
- PostMessage target HWND lookup path:

## 3. MPEG image (`build.img`)

- [ ] Container format?
- [ ] Does it matter for our patches, or is it purely A/V decoder firmware?
- [ ] EUR0.52 → EUR0.61 diff, anything we care about?

## 4. Runtime config (`sys.txt`, `data.zip`)

Paste a redacted dump of `sys.txt` here (from the device's internal SD).
Flag every section and key we might want to flip.

```ini
# paste here
```

Known-interesting keys we want to confirm / negate:

- [ ] `[startup] autostart_navi`
- [ ] `[startup] autostart_delay`
- [ ] `[audio]   mute_pauses_media`  (may not exist — verify!)
- [ ] `[interface] show_exit`

`data.zip` contents summary:

- [ ] Skin / theme assets?
- [ ] Language packs?
- [ ] Scripts (Lua / similar)?

## 5. Interesting strings

Top hits from `firmware/analysis/interesting.txt` — paste the 20–50 most
promising lines, grouped by binary:

```
# MediaPlayer.exe
...

# Nav.exe (or similar)
...
```

## 6. Patch roadmap (rolling)

| #  | Feature                       | Status    | Target binary | Notes |
|----|-------------------------------|-----------|---------------|-------|
| 1  | Mute → media pause            | planning  |               |       |
| 2  | Disable nav autostart         | planning  |               |       |
| 3  | Reduce boot delay             | planning  |               |       |

Update `Status` as: `planning → analysed → hook-drafted → tested → shipped`.

## 7. Dead ends / ruled out

Anything we tried that didn't pan out. Keeps us from going in circles.

- _(nothing yet)_

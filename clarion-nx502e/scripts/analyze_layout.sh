#!/usr/bin/env bash
#
# analyze_layout.sh - First-pass triage of extracted Clarion NX502E firmware.
#
# Runs strictly offline against firmware/extracted/. Produces:
#
#   firmware/analysis/inventory.tsv   size, sha256, file(1) magic, path
#   firmware/analysis/strings/        per-binary strings dumps (ASCII + UTF16LE)
#   firmware/analysis/interesting.txt strings that hint at mute/media/autostart
#
# The interesting-strings filter targets the features listed in PROJECT.md:
#   - Mute -> media pause
#   - Startup / auto-launch of navigation
#   - Audio / waveOut / media player window handles
#
# Usage:
#   ./analyze_layout.sh             # full pass
#   ./analyze_layout.sh --quick     # inventory only, skip strings dumps
#
# Requirements: file, sha256sum, strings (from binutils), iconv.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FW_DIR="${PROJECT_DIR}/firmware"
EX_DIR="${FW_DIR}/extracted"
OUT_DIR="${FW_DIR}/analysis"
STR_DIR="${OUT_DIR}/strings"
INVENTORY="${OUT_DIR}/inventory.tsv"
INTERESTING="${OUT_DIR}/interesting.txt"

# Keywords we care about for the planned patches. Case-insensitive.
# Tuned for WinCE / Clarion head-unit binaries.
KEYWORDS='mute|MUTE|pause|Pause|PAUSE|media|Media|MediaPlayer|wave[Oo]ut|waveOut|PostMessage|WM_COMMAND|autostart|auto_start|navi|Navigation|IGO|primo|Primo|boot[Dd]elay|splash|sys\.txt|data\.zip|startup|Startup'

log()  { printf '\033[1;34m[anlz]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[err ]\033[0m %s\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "Missing tool: $1"; }

build_inventory() {
    log "Building inventory -> ${INVENTORY}"
    printf 'size\tsha256\tmagic\tpath\n' > "${INVENTORY}"
    # Sorted, deterministic order. Relative paths only.
    (cd "${EX_DIR}" && find . -type f -print0 | sort -z) \
        | while IFS= read -r -d '' rel; do
              local abs="${EX_DIR}/${rel#./}"
              local size sha magic
              size="$(stat -c '%s' "${abs}" 2>/dev/null || stat -f '%z' "${abs}")"
              sha="$(sha256sum "${abs}" | awk '{print $1}')"
              magic="$(file -b "${abs}" | tr '\t' ' ')"
              printf '%s\t%s\t%s\t%s\n' "${size}" "${sha}" "${magic}" "${rel#./}" >> "${INVENTORY}"
          done
    log "$(($(wc -l < "${INVENTORY}") - 1)) files catalogued."
}

dump_strings_one() {
    local abs="$1" out="$2"
    mkdir -p "$(dirname "${out}")"
    {
        echo "=== ASCII (min length 6) ==="
        strings -a -n 6 "${abs}" || true
        echo
        echo "=== UTF-16LE (min length 6) ==="
        strings -a -n 6 -e l "${abs}" || true
    } > "${out}"
}

dump_all_strings() {
    log "Dumping strings -> ${STR_DIR}"
    mkdir -p "${STR_DIR}"
    (cd "${EX_DIR}" && find . -type f -print0) \
        | while IFS= read -r -d '' rel; do
              rel="${rel#./}"
              # Skip tiny files and obvious archives (we only want binaries).
              local abs="${EX_DIR}/${rel}"
              local size
              size="$(stat -c '%s' "${abs}" 2>/dev/null || stat -f '%z' "${abs}")"
              [[ "${size}" -ge 1024 ]] || continue
              dump_strings_one "${abs}" "${STR_DIR}/${rel}.strings.txt"
          done
}

grep_interesting() {
    log "Scanning strings for keywords -> ${INTERESTING}"
    : > "${INTERESTING}"
    if [[ ! -d "${STR_DIR}" ]]; then
        warn "No strings dumps yet; run without --quick first."
        return 0
    fi
    # -H prints filename, -n line number, -E extended regex.
    # Suppress grep's non-zero exit when there are no matches so the pipeline
    # stays clean under `set -e`.
    (cd "${STR_DIR}" && grep -rHnE "${KEYWORDS}" . 2>/dev/null || true) \
        >> "${INTERESTING}"
    local hits
    hits="$(wc -l < "${INTERESTING}")"
    log "Found ${hits} candidate lines."
}

main() {
    need file
    need sha256sum
    need strings
    need find
    need awk

    [[ -d "${EX_DIR}" ]] || die "No extracted firmware at ${EX_DIR}. Run fetch_firmware.sh first."

    mkdir -p "${OUT_DIR}"

    local quick=0
    if [[ "${1:-}" == "--quick" ]]; then quick=1; fi

    build_inventory
    if [[ ${quick} -eq 0 ]]; then
        dump_all_strings
        grep_interesting
    else
        log "Quick mode: skipping strings pass."
    fi

    log "Done. See ${OUT_DIR}/"
}

main "$@"

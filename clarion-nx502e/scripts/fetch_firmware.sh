#!/usr/bin/env bash
#
# fetch_firmware.sh - Download and extract Clarion NX502E firmware from
# the official Clarion archive (https://archive.clarion.com).
#
# Output layout (relative to this repo's clarion-nx502e/firmware/ directory,
# which is git-ignored):
#
#   firmware/
#     downloads/                  Raw zip / img as downloaded
#       NX502E.zip
#     extracted/
#       mpu_mcu_bt/               Contents of NX502E.zip
#         MCU.bin
#         BT.bin
#         bootloader.bin
#         flasher.bin
#         updater.bin
#         CE69/
#           ...
#     checksums.txt               sha256 of every downloaded/extracted file
#
# Usage:
#   ./fetch_firmware.sh            # full fetch + extract
#   ./fetch_firmware.sh --verify   # re-compute checksums only
#   ./fetch_firmware.sh --clean    # wipe firmware/ and start over
#
# Notes:
#   * The Clarion archive does NOT publish checksums. We generate sha256
#     locally so subsequent runs are reproducible and any future fetch can
#     be cross-checked.
#   * NK.bin (OS) and the MPEG build.img have dedicated sub-pages with
#     dynamic URLs that change per release. This script fetches the known
#     direct URL for MPU+MCU+BT (NX502E.zip, ~85 MB) and prints hints
#     for the other archives so you can grab them manually.
#   * No Clarion binary will ever be committed to the repo; the entire
#     firmware/ tree is in .gitignore.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
FW_DIR="${PROJECT_DIR}/firmware"
DL_DIR="${FW_DIR}/downloads"
EX_DIR="${FW_DIR}/extracted"
CHECKSUM_FILE="${FW_DIR}/checksums.txt"

# Known-good direct URL, from the project plan.
MPU_ZIP_URL="https://archive.clarion.com/xe/en/pdf/NX502E.zip"
MPU_ZIP_NAME="NX502E.zip"

# Informational: pages where NK.bin and build.img live. The file names
# change per release, so we only print these for the user.
OS_PAGE_URL="https://archive.clarion.com/xe/en/user-support/software/NX502E/OS/"
MPEG_PAGE_URL="https://archive.clarion.com/xe/en/user-support/software/NX502E/MPEG/"

log()  { printf '\033[1;34m[fetch]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn ]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

need() {
    command -v "$1" >/dev/null 2>&1 || die "Required tool '$1' not found in PATH."
}

cmd_clean() {
    if [[ -d "${FW_DIR}" ]]; then
        log "Removing ${FW_DIR}"
        rm -rf "${FW_DIR}"
    else
        log "Nothing to clean."
    fi
}

compute_checksums() {
    log "Computing sha256 checksums -> ${CHECKSUM_FILE}"
    : > "${CHECKSUM_FILE}"
    if [[ -d "${FW_DIR}" ]]; then
        (cd "${FW_DIR}" && find . -type f ! -name 'checksums.txt' -print0 \
            | sort -z \
            | xargs -0 sha256sum) >> "${CHECKSUM_FILE}"
    fi
    log "Wrote $(wc -l < "${CHECKSUM_FILE}") entries."
}

fetch_mpu_zip() {
    mkdir -p "${DL_DIR}"
    local out="${DL_DIR}/${MPU_ZIP_NAME}"
    if [[ -f "${out}" ]]; then
        log "Already downloaded: ${out}"
        return 0
    fi
    log "Downloading ${MPU_ZIP_URL}"
    # -L follows redirects, --fail exits non-zero on HTTP errors, -C - resumes.
    curl -L --fail --retry 3 --retry-delay 2 -C - -o "${out}" "${MPU_ZIP_URL}" \
        || die "Download failed. Check network / archive availability."
    log "Saved $(du -h "${out}" | cut -f1) -> ${out}"
}

extract_mpu_zip() {
    local zip="${DL_DIR}/${MPU_ZIP_NAME}"
    local dest="${EX_DIR}/mpu_mcu_bt"
    [[ -f "${zip}" ]] || die "Missing ${zip} (run without --verify first)."
    mkdir -p "${dest}"
    log "Extracting ${zip} -> ${dest}"
    # -o overwrite, -q quiet, -d dest
    unzip -oq "${zip}" -d "${dest}"
    log "Extracted $(find "${dest}" -type f | wc -l) files."
}

print_manual_hints() {
    cat <<EOF

----- Manual downloads still needed -----

The following artefacts are published on sub-pages with per-release URLs
that this script cannot reliably guess. Open them in a browser and drop
the downloaded files into:

    ${DL_DIR}/

  OS (NK.bin / TINYNK.bin):
      ${OS_PAGE_URL}

  MPEG (build.img, EUR0.61 or newer):
      ${MPEG_PAGE_URL}

Then re-run:   ./fetch_firmware.sh --verify
to regenerate checksums.txt.

------------------------------------------
EOF
}

main() {
    local mode="fetch"
    case "${1:-}" in
        --clean)  mode="clean"  ;;
        --verify) mode="verify" ;;
        "")       mode="fetch"  ;;
        *)        die "Unknown option: $1 (use --clean, --verify, or no arg)" ;;
    esac

    case "${mode}" in
        clean)
            cmd_clean
            ;;
        verify)
            compute_checksums
            ;;
        fetch)
            need curl
            need unzip
            need sha256sum
            mkdir -p "${DL_DIR}" "${EX_DIR}"
            fetch_mpu_zip
            extract_mpu_zip
            compute_checksums
            print_manual_hints
            ;;
    esac
}

main "$@"

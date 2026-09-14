#!/bin/bash
# Runs everything: unit + integration tests (native and, on Apple Silicon, Intel via Rosetta),
# the universal release build, and the packaging checks.
set -euo pipefail
cd "$(dirname "$0")/.."

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

summarize() {
    grep -E "error:|failed \(|skipped|round trip|Executed [0-9]+ tests.*seconds\)?$" "$LOG" | tail -3 || true
}

echo "==> Testler ($(uname -m), yerel)"
if ! swift test >"$LOG" 2>&1; then summarize; echo "✗ Testler başarısız (tam çıktı: swift test)"; exit 1; fi
summarize

if [[ "$(uname -m)" == "arm64" ]] && arch -x86_64 /usr/bin/true 2>/dev/null; then
    echo "==> Testler (x86_64, Rosetta — Intel Mac'ler için)"
    swift build --build-tests --triple x86_64-apple-macosx13.0 >"$LOG" 2>&1 || { tail -20 "$LOG"; exit 1; }
    if ! arch -x86_64 "$(xcrun --find xctest)" .build/x86_64-apple-macosx/debug/SnapPastePackageTests.xctest >"$LOG" 2>&1; then
        summarize; echo "✗ x86_64 testleri başarısız"; exit 1
    fi
    summarize
else
    echo "==> x86_64 testleri atlandı (Rosetta yok veya zaten Intel)"
fi

echo
./scripts/build.sh
echo
./scripts/verify.sh

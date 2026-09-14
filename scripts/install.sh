#!/bin/bash
# Installs SnapPaste.app into /Applications (or ~/Applications) and starts it.
# Usage: bash install.sh [path/to/SnapPaste.app]
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${1:-}"
if [[ -z "$SRC" ]]; then
    for candidate in "$HERE/SnapPaste.app" "$HERE/../dist/SnapPaste.app"; do
        [[ -d "$candidate" ]] && { SRC="$candidate"; break; }
    done
fi
[[ -d "${SRC:-}" ]] || { echo "✗ SnapPaste.app bulunamadı. Önce scripts/build.sh çalıştırın." >&2; exit 1; }

DEST_DIR="/Applications"
[[ -w "$DEST_DIR" ]] || { DEST_DIR="$HOME/Applications"; mkdir -p "$DEST_DIR"; }
DEST="$DEST_DIR/SnapPaste.app"

if [[ "$(cd "$SRC" && pwd -P)" != "$(cd "$DEST" 2>/dev/null && pwd -P)" ]]; then
    echo "==> Çalışan SnapPaste kapatılıyor"
    osascript -e 'if application id "com.yusufkorkmaz.SnapPaste" is running then tell application id "com.yusufkorkmaz.SnapPaste" to quit' >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do pgrep -xq SnapPaste || break; /bin/sleep 0.2; done
    pkill -x SnapPaste 2>/dev/null || true

    echo "==> $DEST konumuna kopyalanıyor"
    rm -rf "$DEST"
    ditto "$SRC" "$DEST"
fi

# The app is ad-hoc signed (not notarized): clear the download quarantine so Gatekeeper lets it open.
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "==> Başlatılıyor"
open "$DEST"

cat <<'EOF'

✓ SnapPaste kuruldu ve menü çubuğunda çalışıyor.

  ⇧⌥S  → ekran görüntüsü al (alan seç; Space: pencere, Esc: iptal)
  ⌘V   → son ekran görüntüsünü yapıştır

İlk çekimde macOS "Ekran ve Sistem Sesi Kaydı" izni isteyecek:
Sistem Ayarları › Gizlilik ve Güvenlik › Ekran ve Sistem Sesi Kaydı › SnapPaste'i açın.
EOF

#!/bin/bash
# Removes SnapPaste, its login item, cached screenshot and preferences.
set -uo pipefail

BUNDLE_ID="com.yusufkorkmaz.SnapPaste"

osascript -e "if application id \"$BUNDLE_ID\" is running then tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1
/bin/sleep 0.5
pkill -x SnapPaste 2>/dev/null

for app in "/Applications/SnapPaste.app" "$HOME/Applications/SnapPaste.app"; do
    [[ -d "$app" ]] && rm -rf "$app" && echo "Silindi: $app"
done
rm -rf "$HOME/Library/Caches/$BUNDLE_ID"
defaults delete "$BUNDLE_ID" >/dev/null 2>&1

echo "✓ SnapPaste kaldırıldı."
echo "  İsterseniz Sistem Ayarları › Gizlilik ve Güvenlik › Ekran ve Sistem Sesi Kaydı listesinden de silebilirsiniz."

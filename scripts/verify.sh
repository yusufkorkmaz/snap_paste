#!/bin/bash
# Checks the built artifacts in dist/ are complete and portable to other Macs.
set -uo pipefail
cd "$(dirname "$0")/.."

APP="dist/SnapPaste.app"
BIN="$APP/Contents/MacOS/SnapPaste"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
DMG="dist/SnapPaste-$VERSION.dmg"
ZIP="dist/SnapPaste-$VERSION.zip"
failures=0

check() {
    local name="$1"; shift
    if "$@" >/dev/null 2>&1; then echo "  ✓ $name"; else echo "  ✗ $name"; failures=$((failures + 1)); fi
}
plist() { /usr/libexec/PlistBuddy -c "Print $1" "$APP/Contents/Info.plist" 2>/dev/null; }

echo "Paket yapısı"
check "çalıştırılabilir dosya var" test -x "$BIN"
check "simge var" test -s "$APP/Contents/Resources/AppIcon.icns"
check "PkgInfo var" test -s "$APP/Contents/PkgInfo"
check "CFBundleIdentifier = com.yusufkorkmaz.SnapPaste" test "$(plist CFBundleIdentifier)" = "com.yusufkorkmaz.SnapPaste"
check "LSUIElement = true (Dock simgesi yok)" test "$(plist LSUIElement)" = "true"
check "CFBundleExecutable eşleşiyor" test "$(plist CFBundleExecutable)" = "SnapPaste"
check "plist geçerli" plutil -lint "$APP/Contents/Info.plist"

echo "Taşınabilirlik"
archs=$(lipo -archs "$BIN")
check "arm64 dilimi (Apple Silicon)" grep -qw arm64 <<<"$archs"
check "x86_64 dilimi (Intel)" grep -qw x86_64 <<<"$archs"
for arch in arm64 x86_64; do
    minos=$(vtool -arch "$arch" -show-build "$BIN" 2>/dev/null | awk '/minos/ {print $2; exit}')
    check "$arch minimum macOS = $(plist LSMinimumSystemVersion) (bulunan: ${minos:-?})" test "$minos" = "$(plist LSMinimumSystemVersion)"
done
check "yalnızca sistem kütüphanelerine bağlı (@rpath yok)" bash -c "! otool -L '$BIN' | grep -E '^\s' | grep -vE '^\s+/(System/Library|usr/lib)/'"
check "Swift çalışma zamanı sistemden (/usr/lib/swift)" bash -c "otool -L '$BIN' | grep -q '/usr/lib/swift/libswiftCore.dylib'"

echo "İmza"
check "codesign --verify --strict" codesign --verify --strict --verbose=2 "$APP"
check "hardened runtime etkin" bash -c "codesign -dv '$APP' 2>&1 | grep -q 'flags=.*runtime'"
check "sandbox yetkisi yok (screencapture çalıştırabilmek için)" bash -c "! codesign -d --entitlements - '$APP' 2>/dev/null | grep -q app-sandbox"

echo "DMG"
check "DMG bütünlüğü (hdiutil verify)" hdiutil verify -quiet "$DMG"
MOUNT=$(mktemp -d)
if hdiutil attach -quiet -readonly -nobrowse -mountpoint "$MOUNT" "$DMG"; then
    check "DMG içinde SnapPaste.app" test -x "$MOUNT/SnapPaste.app/Contents/MacOS/SnapPaste"
    check "DMG içindeki uygulamanın imzası geçerli" codesign --verify --strict "$MOUNT/SnapPaste.app"
    check "DMG içinde Kur.command çalıştırılabilir" test -x "$MOUNT/Kur.command"
    check "DMG içinde Applications kısayolu" test -L "$MOUNT/Applications"
    check "DMG içinde BENİOKU.md" test -s "$MOUNT/BENİOKU.md"
    hdiutil detach -quiet "$MOUNT"
else
    echo "  ✗ DMG bağlanamadı"; failures=$((failures + 1))
fi
rmdir "$MOUNT" 2>/dev/null

echo "ZIP"
UNZIP=$(mktemp -d)
check "ZIP açılıyor" unzip -q "$ZIP" -d "$UNZIP"
check "ZIP'ten çıkan uygulamanın imzası geçerli" codesign --verify --strict "$UNZIP/SnapPaste.app"
check "ZIP içinde install.sh" test -s "$UNZIP/install.sh"
check "ZIP içinde README.md" test -s "$UNZIP/README.md"
rm -rf "$UNZIP"

echo "Betikler"
for script in scripts/*.sh; do check "bash -n $script" bash -n "$script"; done

echo
if [[ $failures -eq 0 ]]; then echo "✓ Tüm paket kontrolleri geçti"; else echo "✗ $failures kontrol başarısız"; fi
exit "$failures"

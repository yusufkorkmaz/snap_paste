#!/bin/bash
# Builds a universal (Apple Silicon + Intel) SnapPaste.app and the distributable DMG/ZIP into dist/.
# Needs only Xcode or the Command Line Tools (xcode-select --install).
#   --package-only   re-create DMG/ZIP from the existing dist/SnapPaste.app without recompiling
#                    (keeps the exact tested binary, so granted permissions stay valid)
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="SnapPaste"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
MIN_MACOS=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" Resources/Info.plist)
DIST="dist"
APP="$DIST/$APP_NAME.app"

if [[ "${1:-}" == "--package-only" ]]; then
    codesign --verify --strict "$APP" || { echo "✗ $APP yok veya imzası bozuk; önce tam derleme yapın." >&2; exit 1; }
    rm -f "$DIST"/*.dmg "$DIST"/*.zip
else
echo "==> Derleniyor ($APP_NAME $VERSION, macOS $MIN_MACOS+)"
for arch in arm64 x86_64; do
    swift build -c release --product "$APP_NAME" --triple "$arch-apple-macosx$MIN_MACOS" 2>&1 | grep -vE '^\[[0-9]+/[0-9]+\]' || true
    test -x ".build/$arch-apple-macosx/release/$APP_NAME" || { echo "✗ $arch derlemesi başarısız" >&2; exit 1; }
done

echo "==> .app paketi oluşturuluyor"
rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create -output "$APP/Contents/MacOS/$APP_NAME" \
    ".build/arm64-apple-macosx/release/$APP_NAME" \
    ".build/x86_64-apple-macosx/release/$APP_NAME"
strip -x "$APP/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

echo "==> İmzalanıyor (ad-hoc, hardened runtime)"
codesign --force --options runtime --timestamp=none --sign - "$APP"
codesign --verify --strict "$APP"
fi

echo "==> Dağıtım dosyaları hazırlanıyor"
# Not notarized: copies arriving via AirDrop/download are blocked by Gatekeeper on first open,
# so the unblock steps ship as a plain text file anyone can read before opening the app.
HELP="AÇILMAZSA BENİ OKU.txt"
cp scripts/install.sh scripts/uninstall.sh README.md "$DIST/"
cp Resources/ACILMAZSA-BENI-OKU.txt "$DIST/$HELP"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/$APP_NAME.app"
cp Resources/ACILMAZSA-BENI-OKU.txt "$STAGE/$HELP"
cp README.md "$STAGE/BENİOKU.md"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" -fs HFS+ -format ULMO -ov "$DIST/$APP_NAME-$VERSION.dmg"
(cd "$DIST" && zip -qry "$APP_NAME-$VERSION.zip" "$APP_NAME.app" "$HELP" install.sh uninstall.sh README.md)

echo
echo "✓ Hazır:"
ls -lh "$DIST" | awk 'NR>1 {size=$5; for (i=1; i<=8; i++) $i=""; sub(/^ +/, ""); print "   " size "\t" $0}'
echo "   Çalıştırılabilir boyutu: $(du -h "$APP/Contents/MacOS/$APP_NAME" | cut -f1) ($(lipo -archs "$APP/Contents/MacOS/$APP_NAME"))"

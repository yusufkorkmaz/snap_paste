#!/bin/bash
# Builds a universal (Apple Silicon + Intel) SnapPaste.app and the distributable DMG/ZIP into dist/.
# Needs only Xcode or the Command Line Tools (xcode-select --install).
set -euo pipefail
cd "$(dirname "$0")/.."

APP_NAME="SnapPaste"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" Resources/Info.plist)
MIN_MACOS=$(/usr/libexec/PlistBuddy -c "Print LSMinimumSystemVersion" Resources/Info.plist)
DIST="dist"
APP="$DIST/$APP_NAME.app"

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

echo "==> Dağıtım dosyaları hazırlanıyor"
cp scripts/install.sh scripts/uninstall.sh README.md "$DIST/"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/$APP_NAME.app"
cp scripts/install.sh "$STAGE/Kur.command"
cp scripts/uninstall.sh "$STAGE/Kaldir.command"
cp README.md "$STAGE/BENİOKU.md"
chmod +x "$STAGE/Kur.command" "$STAGE/Kaldir.command"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "$APP_NAME $VERSION" -srcfolder "$STAGE" -fs HFS+ -format ULMO -ov "$DIST/$APP_NAME-$VERSION.dmg"
(cd "$DIST" && zip -qry "$APP_NAME-$VERSION.zip" "$APP_NAME.app" install.sh uninstall.sh README.md)

echo
echo "✓ Hazır:"
ls -lh "$DIST" | awk 'NR>1 {print "   " $5 "\t" $9}'
echo "   Çalıştırılabilir boyutu: $(du -h "$APP/Contents/MacOS/$APP_NAME" | cut -f1) ($(lipo -archs "$APP/Contents/MacOS/$APP_NAME"))"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="${APP_NAME:-MacThing}"
BUNDLE_ID="${BUNDLE_ID:-com.shibuki.MacThing}"
VERSION="${VERSION:-0.1.3}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
CONFIGURATION="${CONFIGURATION:-release}"

DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGING_DIR="$DIST_DIR/dmg-staging"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
ICONSET_DIR="$DIST_DIR/$APP_NAME.iconset"
ICON_DOC="${ICON_DOC:-$ROOT_DIR/Assets/$APP_NAME.icon}"
README_ICON_PATH="$ROOT_DIR/Assets/README/$APP_NAME-icon.png"
DOCS_ICON_PATH="$ROOT_DIR/docs/assets/$APP_NAME-icon.png"
EXECUTABLE_PATH="$ROOT_DIR/.build/$CONFIGURATION/$APP_NAME"

rm -rf "$APP_BUNDLE" "$STAGING_DIR" "$ICONSET_DIR" "$DMG_PATH"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$DIST_DIR"

swift build -c "$CONFIGURATION" --product "$APP_NAME"

if [[ ! -x "$EXECUTABLE_PATH" ]]; then
    echo "missing executable: $EXECUTABLE_PATH" >&2
    exit 1
fi

cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

find_ictool() {
    if [[ -n "${ICTOOL:-}" && -x "$ICTOOL" ]]; then
        printf '%s\n' "$ICTOOL"
        return 0
    fi

    local candidates=(
        "/Applications/Icon Composer.app/Contents/Executables/ictool"
        "$HOME/Applications/Icon Composer.app/Contents/Executables/ictool"
        "/Volumes/Icon Composer 1/Icon Composer.app/Contents/Executables/ictool"
    )

    local candidate
    for candidate in "${candidates[@]}"; do
        if [[ -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    find /Volumes -path '*/Icon Composer.app/Contents/Executables/ictool' -print -quit 2>/dev/null
}

ICTOOL_PATH="$(find_ictool)"
if [[ -z "$ICTOOL_PATH" || ! -x "$ICTOOL_PATH" ]]; then
    echo "missing Icon Composer ictool; install or mount Icon Composer, or set ICTOOL=/path/to/ictool" >&2
    exit 1
fi

if [[ ! -d "$ICON_DOC" ]]; then
    echo "missing Icon Composer document: $ICON_DOC" >&2
    exit 1
fi

mkdir -p "$ICONSET_DIR"

export_icon_image() {
    local output_file="$1"
    local points="$2"
    local scale="$3"

    "$ICTOOL_PATH" "$ICON_DOC" \
        --export-image \
        --output-file "$output_file" \
        --platform macOS \
        --rendition Default \
        --width "$points" \
        --height "$points" \
        --scale "$scale" >/dev/null
}

export_icon_image "$ICONSET_DIR/icon_16x16.png" 16 1
export_icon_image "$ICONSET_DIR/icon_16x16@2x.png" 16 2
export_icon_image "$ICONSET_DIR/icon_32x32.png" 32 1
export_icon_image "$ICONSET_DIR/icon_32x32@2x.png" 32 2
export_icon_image "$ICONSET_DIR/icon_128x128.png" 128 1
export_icon_image "$ICONSET_DIR/icon_128x128@2x.png" 128 2
export_icon_image "$ICONSET_DIR/icon_256x256.png" 256 1
export_icon_image "$ICONSET_DIR/icon_256x256@2x.png" 256 2
export_icon_image "$ICONSET_DIR/icon_512x512.png" 512 1
export_icon_image "$ICONSET_DIR/icon_512x512@2x.png" 512 2

mkdir -p "$(dirname "$README_ICON_PATH")" "$(dirname "$DOCS_ICON_PATH")"
cp "$ICONSET_DIR/icon_512x512.png" "$README_ICON_PATH"
cp "$ICONSET_DIR/icon_512x512.png" "$DOCS_ICON_PATH"

iconutil --convert icns \
    --output "$APP_BUNDLE/Contents/Resources/$APP_NAME.icns" \
    "$ICONSET_DIR"

cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleSignature</key>
    <string>MCTH</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <true/>
    <key>NSSupportsSuddenTermination</key>
    <true/>
</dict>
</plist>
EOF

printf "APPLMCTH" > "$APP_BUNDLE/Contents/PkgInfo"
plutil -lint "$APP_BUNDLE/Contents/Info.plist"

if command -v codesign >/dev/null 2>&1; then
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

mkdir -p "$STAGING_DIR"
cp -R "$APP_BUNDLE" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR" "$ICONSET_DIR"

echo "App bundle: $APP_BUNDLE"
echo "DMG: $DMG_PATH"

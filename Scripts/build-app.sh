#!/bin/bash
# `.app` を組み立てる。`--build-system swiftbuild` は外さない: Bundle.module が
# `.app/Contents/Resources` を探すのはこのバックエンドの生成コードだけ。
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${CONFIG:-release}"
VERSION="${VERSION:-0.1.0}"
BUILD="${BUILD:-1}"
IDENTITY="${CODESIGN_IDENTITY:-Copipe Storage Dev}"
APP="$ROOT/build/Copipe Storage.app"

cd "$ROOT"
swift build -c "$CONFIG" --build-system swiftbuild --product CopipeStorage
BIN="$(swift build -c "$CONFIG" --build-system swiftbuild --product CopipeStorage --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/CopipeStorage" "$APP/Contents/MacOS/"
for bundle in "$BIN"/*.bundle; do
  cp -R "$bundle" "$APP/Contents/Resources/"
done
sed -e "s/@VERSION@/$VERSION/" -e "s/@BUILD@/$BUILD/" "$ROOT/Packaging/Info.plist" > "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp -R "$ROOT/Packaging/ja.lproj" "$ROOT/Packaging/en.lproj" "$APP/Contents/Resources/"
if [ "$CONFIG" = "debug" ]; then
  # 検証用の URL スキームは DEBUG ビルドにだけ付ける
  /usr/libexec/PlistBuddy \
    -c "Add :CFBundleURLTypes array" \
    -c "Add :CFBundleURLTypes:0 dict" \
    -c "Add :CFBundleURLTypes:0:CFBundleURLName string jp.ichitai.copipestorage.debug" \
    -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" \
    -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string copipestorage" \
    "$APP/Contents/Info.plist"
fi

if security find-identity -v -p codesigning | grep -q "\"$IDENTITY\""; then
  SIGN="$IDENTITY"
else
  SIGN="-"
  echo "warning: 署名 identity \"$IDENTITY\" が無いのでアドホック署名にする（ビルドごとに権限の付け直しが要る）" >&2
fi
codesign --force --options runtime --timestamp=none --sign "$SIGN" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "built: $APP (signed by: $SIGN)"

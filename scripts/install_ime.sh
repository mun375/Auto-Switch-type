#!/bin/bash
# Installs the freshly built Switchless (免切注音) input method into
# ~/Library/Input Methods and leaves exactly one copy registered with
# LaunchServices.
#
# Why the lsregister dance: the Xcode target has a RegisterWithLaunchServices
# build phase, so every build registers the DerivedData copy under the same
# bundle ID as the installed one. With more than one copy registered, macOS may
# launch the build-directory app as the input method, and the Text Input menu
# can silently drop the input method from the enabled-sources list.
#
# Note the two different names below: the Xcode project is still McBopomofo
# (so DerivedData is named McBopomofo-*), while the built product is
# Switchless.app.

set -euo pipefail

APP=Switchless.app
DST="$HOME/Library/Input Methods/$APP"
LEGACY="$HOME/Library/Input Methods/McBopomofo.app"
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

SRC="${1:-}"
if [ -z "$SRC" ]; then
    SRC=$(ls -dt "$HOME"/Library/Developer/Xcode/DerivedData/McBopomofo-*/Build/Products/Debug/"$APP" 2>/dev/null | head -1)
fi
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
    echo "error: no built $APP found; pass the path as \$1" >&2
    exit 1
fi
echo "source: $SRC"

# Stop any running copy so the bundle can be replaced cleanly.
pkill -f "Input Methods/$APP" 2>/dev/null || true
pkill -f "DerivedData/McBopomofo.*$APP" 2>/dev/null || true
sleep 1

rm -rf "$DST"
cp -R "$SRC" "$DST"

# Unregister every copy that is not the installed one, then re-register it.
"$LSR" -dump 2>/dev/null \
    | awk -v app="$APP" '/^path:/ && index($0, app) { sub(/^path:[ \t]*/, ""); sub(/ \(0x[0-9a-f]+\)$/, ""); print }' \
    | sort -u \
    | while IFS= read -r path; do
        [ "$path" = "$DST" ] && continue
        echo "unregistering: $path"
        "$LSR" -u "$path" 2>/dev/null || true
    done
"$LSR" -f "$DST"
sleep 2

echo "=== registered copies ==="
"$LSR" -dump 2>/dev/null | grep -i "$APP" | sort -u

echo
echo "Installed build $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DST/Contents/Info.plist")."

# The pre-rebrand fork has a different bundle ID, so it survives this install
# and keeps showing up in the input menu. Removing it is a deliberate choice,
# not something this script should do behind your back.
if [ -d "$LEGACY" ]; then
    echo
    echo "NOTE: the pre-rebrand fork is still installed at:"
    echo "  $LEGACY"
    echo "It has a different bundle ID, so both appear in the input menu."
    echo "To remove it once Switchless is verified working:"
    echo "  \"$LSR\" -u \"$LEGACY\" && rm -rf \"$LEGACY\""
fi

echo
echo "First install: 系統設定 → 鍵盤 → 輸入來源「編輯…」→ 左下角 + → 繁體中文"
echo "→ 加入「免切注音」與「免切注音（傳統）」，然後從選單列選用。"

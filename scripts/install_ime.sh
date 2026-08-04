#!/bin/bash
# Installs the freshly built McBopomofo fork into ~/Library/Input Methods and
# leaves exactly one copy registered with LaunchServices.
#
# Why the lsregister dance: the Xcode target has a RegisterWithLaunchServices
# build phase, so every build registers the DerivedData copy under the same
# bundle ID as the installed one. With more than one copy registered, macOS may
# launch the build-directory app as the input method, and the Text Input menu
# can silently drop McBopomofo from the enabled-sources list.

set -euo pipefail

DST="$HOME/Library/Input Methods/McBopomofo.app"
LSR=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

SRC="${1:-}"
if [ -z "$SRC" ]; then
    SRC=$(ls -dt "$HOME"/Library/Developer/Xcode/DerivedData/McBopomofo-*/Build/Products/Debug/McBopomofo.app 2>/dev/null | head -1)
fi
if [ -z "$SRC" ] || [ ! -d "$SRC" ]; then
    echo "error: no built McBopomofo.app found; pass the path as \$1" >&2
    exit 1
fi
echo "source: $SRC"

# Stop any running copy so the bundle can be replaced cleanly.
pkill -f "Input Methods/McBopomofo.app" 2>/dev/null || true
pkill -f "DerivedData/McBopomofo.*McBopomofo.app" 2>/dev/null || true
sleep 1

rm -rf "$DST"
cp -R "$SRC" "$DST"

# Unregister every copy that is not the installed one, then re-register it.
"$LSR" -dump 2>/dev/null \
    | awk '/^path:/ && /McBopomofo\.app/ { sub(/^path:[ \t]*/, ""); sub(/ \(0x[0-9a-f]+\)$/, ""); print }' \
    | sort -u \
    | while IFS= read -r path; do
        [ "$path" = "$DST" ] && continue
        echo "unregistering: $path"
        "$LSR" -u "$path" 2>/dev/null || true
    done
"$LSR" -f "$DST"
sleep 2

echo "=== registered copies ==="
"$LSR" -dump 2>/dev/null | grep -i "McBopomofo.app" | sort -u

echo
echo "Installed build $(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$DST/Contents/Info.plist")."
echo "Pick 小麥注音 from the menu bar input menu to start the new copy."

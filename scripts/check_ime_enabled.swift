// Reports whether Switchless (免切注音) is in the system's enabled input
// sources, i.e. whether it can show up in the menu-bar input menu.
//
// Usage: swift scripts/check_ime_enabled.swift   (exit 0 = enabled, 1 = not)
//
// Runs in a fresh process on purpose: the TIS enabled list is cached per
// process, so a long-running caller can report stale state. Do not use
// `defaults read com.apple.HIToolbox AppleEnabledInputSources` instead — it
// lags behind the real state (2026-11-04: it lacked Switchless while System
// Settings and this query both showed it enabled).
//
// Why this exists: running `xcodebuild test` launches the build-directory
// copy of Switchless.app (same bundle ID) as the test host, and twice now
// (2026-08-04, 2026-11-04) the input method then vanished from the menu bar
// until it was re-added in System Settings. Called at the end of
// install_ime.sh; also worth running after vendor tests.

import Carbon
import Foundation

let bundleID = "tw.benjiang.inputmethod.Switchless"
// Keyed by the last component of the input source ID.
let wanted = [".Bopomofo": "免切注音", ".PlainBopomofo": "免切注音（傳統）"]

let enabled = (TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource]) ?? []
var found: Set<String> = []
for source in enabled {
    guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
        let bundlePtr = TISGetInputSourceProperty(source, kTISPropertyBundleID),
        Unmanaged<CFString>.fromOpaque(bundlePtr).takeUnretainedValue() as String == bundleID
    else { continue }
    let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    // The IDs TIS reports are not the Info.plist mode IDs verbatim (observed:
    // "…Switchless.Switchless.Bopomofo"), so match on the bundle ID plus the
    // mode's last component.
    for mode in wanted.keys where id.hasSuffix(mode) {
        found.insert(mode)
    }
}

for (mode, name) in wanted.sorted(by: { $0.key < $1.key }) {
    print("\(found.contains(mode) ? "enabled" : "MISSING") \(name)")
}

if found.isEmpty {
    print("""

        WARNING: 免切注音 is not in the enabled input sources, so it will not
        appear in the menu bar. Re-add it (no logout needed when the bundle ID
        is unchanged): 系統設定 → 鍵盤 → 輸入方式「編輯…」→ 左下角 + → 繁體中文
        → 免切注音、免切注音（傳統）→ 加入
        """)
    exit(1)
}

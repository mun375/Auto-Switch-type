import Carbon
import Foundation

let path = NSString(string: "~/Library/Input Methods/McBopomofo.app").expandingTildeInPath
let url = URL(fileURLWithPath: path) as CFURL

let regStatus = TISRegisterInputSource(url)
print("register status:", regStatus)

// Find McBopomofo input sources (including currently disabled ones)
let props = [kTISPropertyBundleID as String: "org.openvanilla.inputmethod.McBopomofo"] as CFDictionary
guard let list = TISCreateInputSourceList(props, true)?.takeRetainedValue() as? [TISInputSource] else {
    print("no input sources found for bundle id")
    exit(1)
}
print("found \(list.count) source(s)")
for src in list {
    let idPtr = TISGetInputSourceProperty(src, kTISPropertyInputSourceID)
    let id = idPtr.map { Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String } ?? "?"
    let enableStatus = TISEnableInputSource(src)
    print("enable \(id):", enableStatus)
}

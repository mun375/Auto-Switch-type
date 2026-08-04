import Carbon
import Foundation

let path = NSString(string: "~/Library/Input Methods/Switchless.app").expandingTildeInPath
let url = URL(fileURLWithPath: path) as CFURL

let regStatus = TISRegisterInputSource(url)
print("register status:", regStatus)

// Find Switchless input sources (including currently disabled ones)
let props = [kTISPropertyBundleID as String: "tw.benjiang.inputmethod.Switchless"] as CFDictionary
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

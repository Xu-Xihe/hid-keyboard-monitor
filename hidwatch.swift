import Foundation
import IOKit.hid

let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)

let matching: [String: Any] = [
    kIOHIDPrimaryUsagePageKey: kHIDPage_GenericDesktop,
    kIOHIDPrimaryUsageKey: kHIDUsage_GD_Keyboard
]

IOHIDManagerSetDeviceMatching(
    manager,
    matching as CFDictionary
)

let callback: IOHIDReportCallback = {
    _,
    _,
    _,
    type,
    reportID,
    report,
    reportLength
    in

    let bytes = UnsafeBufferPointer(
        start: report,
        count: reportLength
    )

    let hex = bytes
        .map { String(format: "%02X", $0) }
        .joined(separator: " ")

    print(
        "REPORT type=\(type.rawValue) " +
        "id=\(reportID) " +
        "len=\(reportLength)  " +
        hex
    )
}

IOHIDManagerRegisterInputReportCallback(
    manager,
    callback,
    nil
)

IOHIDManagerScheduleWithRunLoop(
    manager,
    CFRunLoopGetCurrent(),
    CFRunLoopMode.defaultMode.rawValue
)

let result = IOHIDManagerOpen(manager, 0)

if result != kIOReturnSuccess {
    print("Failed to open HID manager: \(result)")
    exit(1)
}

print("========================================")
print(" HID keyboard report monitor")
print("========================================")
print("Press F1 / Fn+F1")
print("Ctrl+C to exit")
print("")

CFRunLoopRun()
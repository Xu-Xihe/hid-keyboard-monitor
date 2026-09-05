import Foundation
import IOKit
import IOKit.hid

// MARK: - Helpers

func stringProperty(_ device: IOHIDDevice, _ key: String) -> String {
    guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
        return "-"
    }

    if let value = value as? String {
        return value
    }

    return String(describing: value)
}

func intProperty(_ device: IOHIDDevice, _ key: String) -> Int64? {
    guard let value = IOHIDDeviceGetProperty(device, key as CFString) else {
        return nil
    }

    if let number = value as? NSNumber {
        return number.int64Value
    }

    return nil
}

// MARK: - Device Filter

func isTargetKeyboard(_ device: IOHIDDevice) -> Bool {
    let vendorID = intProperty(device, kIOHIDVendorIDKey)
    let productID = intProperty(device, kIOHIDProductIDKey)
    let usagePage = intProperty(device, kIOHIDPrimaryUsagePageKey)
    let usage = intProperty(device, kIOHIDPrimaryUsageKey)

    return vendorID == 0x05AC
        && productID == 0x024F
        && usagePage == 0x01
        && usage == 0x06
}

// MARK: - fnState

func setFnState(_ state: Bool) {
    let value = state ? "true" : "false"

    print("Setting fnState =", value)

    // defaults write -g com.apple.keyboard.fnState -boolean xxx
    let defaults = Process()
    defaults.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
    defaults.arguments = [
        "write",
        "-g",
        "com.apple.keyboard.fnState",
        "-boolean",
        value
    ]

    do {
        try defaults.run()
        defaults.waitUntilExit()

        guard defaults.terminationStatus == 0 else {
            print("defaults failed:", defaults.terminationStatus)
            return
        }
    } catch {
        print("Failed to execute defaults:", error)
        return
    }


    // activateSettings -u
    let activateSettings = Process()
    activateSettings.executableURL = URL(
        fileURLWithPath:
            "/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings"
    )

    activateSettings.arguments = ["-u"]

    do {
        try activateSettings.run()
        activateSettings.waitUntilExit()

        guard activateSettings.terminationStatus == 0 else {
            print(
                "activateSettings failed:",
                activateSettings.terminationStatus
            )
            return
        }
    } catch {
        print("Failed to execute activateSettings:", error)
        return
    }

    print("fnState applied successfully.")
}


// MARK: - Callbacks

let matchingCallback: IOHIDDeviceCallback = {
    context,
    result,
    sender,
    device in

    guard isTargetKeyboard(device) else {
        return
    }

    print("")
    print("========================================")
    print("TARGET KEYBOARD CONNECTED")
    print("========================================")

    print("Product   :", stringProperty(device, kIOHIDProductKey))
    print("Manufacturer:", stringProperty(device, kIOHIDManufacturerKey))
    print("Transport :", stringProperty(device, kIOHIDTransportKey))

    if let vid = intProperty(device, kIOHIDVendorIDKey) {
        print(String(format: "Vendor ID : 0x%X", vid))
    }

    if let pid = intProperty(device, kIOHIDProductIDKey) {
        print(String(format: "Product ID: 0x%X", pid))
    }

    if let usagePage = intProperty(device, kIOHIDPrimaryUsagePageKey) {
        print(String(format: "Usage Page: 0x%X", usagePage))
    }

    if let usage = intProperty(device, kIOHIDPrimaryUsageKey) {
        print(String(format: "Usage     : 0x%X", usage))
    }

    setFnState(true)

    print("========================================")
    print("")
}

let removalCallback: IOHIDDeviceCallback = {
    context,
    result,
    sender,
    device in

    guard isTargetKeyboard(device) else {
        return
    }

    print("")
    print("========================================")
    print("TARGET KEYBOARD DISCONNECTED")
    print("========================================")

    print("Product   :", stringProperty(device, kIOHIDProductKey))
    print("Transport :", stringProperty(device, kIOHIDTransportKey))

    setFnState(false)

    print("========================================")
    print("")
}

// MARK: - HID Manager

let manager = IOHIDManagerCreate(
    kCFAllocatorDefault,
    0
)

// 严格匹配
let matching: [String: Any] = [
    kIOHIDVendorIDKey as String: 0x05AC,
    kIOHIDProductIDKey as String: 0x024F,
    kIOHIDPrimaryUsagePageKey as String: 0x01,
    kIOHIDPrimaryUsageKey as String: 0x06
]

IOHIDManagerSetDeviceMatching(
    manager,
    matching as CFDictionary
)

// 连接
IOHIDManagerRegisterDeviceMatchingCallback(
    manager,
    matchingCallback,
    nil
)

// 断开
IOHIDManagerRegisterDeviceRemovalCallback(
    manager,
    removalCallback,
    nil
)

// RunLoop
IOHIDManagerScheduleWithRunLoop(
    manager,
    CFRunLoopGetCurrent(),
    CFRunLoopMode.defaultMode.rawValue
)

// Open
let result = IOHIDManagerOpen(
    manager,
    IOOptionBits(kIOHIDOptionsTypeNone)
)

guard result == kIOReturnSuccess else {
    print(
        String(
            format: "Failed to open IOHIDManager: 0x%08X",
            result
        )
    )

    exit(1)
}

print("HID monitor started.")
print("Waiting for target keyboard...")
print("Press Ctrl+C to exit.")
print("")

CFRunLoopRun()
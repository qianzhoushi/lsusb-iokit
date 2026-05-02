import Foundation
import IOKit

struct USBDevice: Codable {
    let bus: Int
    let device: Int
    let vendorID: Int
    let productID: Int
    let vendorName: String
    let productName: String
    let serialNumber: String?
    let locationID: UInt32?
    let usbSpeed: Int?
    let linkSpeedBps: Int?
    let deviceClass: Int?
    let deviceSubClass: Int?
    let deviceProtocol: Int?
    let usbVersionBCD: Int?
    let deviceVersionBCD: Int?

    func summaryLine() -> String {
        String(
            format: "Bus %03d Device %03d: ID %04x:%04x %@ %@",
            bus,
            device,
            vendorID,
            productID,
            vendorName,
            productName
        )
    }
}

struct Options {
    var verbose = false
    var json = false
}

enum CLIError: Error, CustomStringConvertible {
    case message(String)

    var description: String {
        switch self {
        case .message(let text):
            return text
        }
    }
}

func usage() {
    print(
        """
        Usage: lsusb_macos [-v|--verbose] [--json]

          -v, --verbose   show extra device details
              --json      output as JSON
          -h, --help      show this help message
        """
    )
}

func parseOptions() throws -> Options {
    var options = Options()

    for arg in CommandLine.arguments.dropFirst() {
        switch arg {
        case "-v", "--verbose":
            options.verbose = true
        case "--json":
            options.json = true
        case "-h", "--help":
            usage()
            exit(0)
        default:
            throw CLIError.message("unknown option: \(arg)")
        }
    }

    return options
}

func readProperties(from service: io_registry_entry_t) -> [String: Any] {
    var propertiesRef: Unmanaged<CFMutableDictionary>?
    let kr = IORegistryEntryCreateCFProperties(service, &propertiesRef, kCFAllocatorDefault, 0)
    guard kr == KERN_SUCCESS, let retained = propertiesRef?.takeRetainedValue() else {
        return [:]
    }
    return retained as NSDictionary as? [String: Any] ?? [:]
}

func intValue(_ value: Any?) -> Int? {
    switch value {
    case let number as NSNumber:
        return number.intValue
    case let string as String:
        return Int(string)
    default:
        return nil
    }
}

func uint32Value(_ value: Any?) -> UInt32? {
    switch value {
    case let number as NSNumber:
        return number.uint32Value
    case let string as String:
        return UInt32(string)
    default:
        return nil
    }
}

func stringValue(_ value: Any?) -> String? {
    switch value {
    case let text as String where !text.isEmpty:
        return text
    default:
        return nil
    }
}

func bcdString(_ value: Int?) -> String? {
    guard let value else { return nil }
    return String(format: "%x.%02x", value >> 8, value & 0xff)
}

func controllerRegistryID(for service: io_registry_entry_t) -> UInt64? {
    var current = service

    while true {
        if IOObjectConformsTo(current, "IOUSBHostController") != 0 {
            var entryID: UInt64 = 0
            if IORegistryEntryGetRegistryEntryID(current, &entryID) == KERN_SUCCESS {
                return entryID
            }
            return nil
        }

        var parent: io_registry_entry_t = 0
        let kr = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
        if kr != KERN_SUCCESS {
            return nil
        }
        current = parent
    }
}

func collectDevices() throws -> [USBDevice] {
    var iterator: io_iterator_t = 0
    let kr = IORegistryCreateIterator(
        kIOMainPortDefault,
        "IOUSB",
        IOOptionBits(kIORegistryIterateRecursively),
        &iterator
    )
    guard kr == KERN_SUCCESS else {
        throw CLIError.message("failed to enumerate IOUSB registry: \(kr)")
    }

    defer { IOObjectRelease(iterator) }

    var devices: [USBDevice] = []
    var busByControllerID: [UInt64: Int] = [:]
    var nextBusNumber = 1

    while case let service = IOIteratorNext(iterator), service != 0 {
        defer { IOObjectRelease(service) }

        guard IOObjectConformsTo(service, "IOUSBHostDevice") != 0 else {
            continue
        }

        let properties = readProperties(from: service)
        guard
            let vendorID = intValue(properties["idVendor"]),
            let productID = intValue(properties["idProduct"])
        else {
            continue
        }

        let controllerID = controllerRegistryID(for: service) ?? 0
        let busNumber: Int
        if let existing = busByControllerID[controllerID] {
            busNumber = existing
        } else {
            busNumber = nextBusNumber
            busByControllerID[controllerID] = busNumber
            nextBusNumber += 1
        }

        let deviceNumber = intValue(properties["USB Address"] ?? properties["kUSBAddress"]) ?? 0
        let vendorName = stringValue(properties["USB Vendor Name"] ?? properties["kUSBVendorString"]) ?? "Unknown Vendor"
        let productName = stringValue(properties["USB Product Name"] ?? properties["kUSBProductString"]) ?? "Unknown Product"

        devices.append(
            USBDevice(
                bus: busNumber,
                device: deviceNumber,
                vendorID: vendorID,
                productID: productID,
                vendorName: vendorName,
                productName: productName,
                serialNumber: stringValue(properties["USB Serial Number"] ?? properties["kUSBSerialNumberString"]),
                locationID: uint32Value(properties["locationID"]),
                usbSpeed: intValue(properties["USBSpeed"]),
                linkSpeedBps: intValue(properties["UsbLinkSpeed"]),
                deviceClass: intValue(properties["bDeviceClass"]),
                deviceSubClass: intValue(properties["bDeviceSubClass"]),
                deviceProtocol: intValue(properties["bDeviceProtocol"]),
                usbVersionBCD: intValue(properties["bcdUSB"]),
                deviceVersionBCD: intValue(properties["bcdDevice"])
            )
        )
    }

    return devices.sorted {
        ($0.bus, $0.device, $0.vendorID, $0.productID) < ($1.bus, $1.device, $1.vendorID, $1.productID)
    }
}

func verboseOutput(for device: USBDevice) -> String {
    var lines = [device.summaryLine()]
    lines.append(String(format: "  Vendor:       %@ (%04x)", device.vendorName, device.vendorID))
    lines.append(String(format: "  Product:      %@ (%04x)", device.productName, device.productID))
    if let serial = device.serialNumber {
        lines.append("  Serial:       \(serial)")
    }
    if let locationID = device.locationID {
        lines.append(String(format: "  Location ID:  0x%08x", locationID))
    }
    if let usbSpeed = device.usbSpeed {
        lines.append("  USB Speed:    \(usbSpeed)")
    }
    if let linkSpeedBps = device.linkSpeedBps {
        lines.append("  Link Speed:   \(linkSpeedBps) bps")
    }
    if let usbVersion = bcdString(device.usbVersionBCD) {
        lines.append("  USB Version:  \(usbVersion)")
    }
    if let deviceVersion = bcdString(device.deviceVersionBCD) {
        lines.append("  Device Ver:   \(deviceVersion)")
    }
    if let deviceClass = device.deviceClass {
        lines.append(String(format: "  Class:        0x%02x", deviceClass))
    }
    if let deviceSubClass = device.deviceSubClass {
        lines.append(String(format: "  SubClass:     0x%02x", deviceSubClass))
    }
    if let deviceProtocol = device.deviceProtocol {
        lines.append(String(format: "  Protocol:     0x%02x", deviceProtocol))
    }
    return lines.joined(separator: "\n")
}

do {
    let options = try parseOptions()
    let devices = try collectDevices()

    if options.json {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(devices)
        if let text = String(data: data, encoding: .utf8) {
            print(text)
        }
        exit(0)
    }

    if options.verbose {
        print(devices.map(verboseOutput).joined(separator: "\n\n"))
        exit(0)
    }

    for device in devices {
        print(device.summaryLine())
    }
} catch {
    fputs("lsusb_macos: \(error)\n", stderr)
    exit(1)
}

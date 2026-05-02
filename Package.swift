// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "lsusb_macos",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(
            name: "lsusb",
            targets: ["lsusb"]
        )
    ],
    targets: [
        .executableTarget(
            name: "lsusb"
        ),
    ],
    swiftLanguageModes: [.v6]
)

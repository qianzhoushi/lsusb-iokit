# lsusb-iokit

`lsusb-iokit` is a macOS-native `lsusb` implementation built with `Swift + IOKit`.

It is designed for the case where existing Homebrew `lsusb` options do not work well on macOS, or when you want a native implementation that reads directly from the macOS USB registry instead of relying on `ioreg` output parsing.

The installed command name is:

```bash
lsusb
```

## Features

- Native macOS implementation using `IOKit`
- `lsusb`-style output for quick terminal inspection
- Verbose mode with extra device details
- JSON output for scripting and automation
- Distributed as a standard Swift Package

## Install

### Homebrew tap

```bash
brew tap qianzhoushi/tap
brew install lsusb-iokit
```

### Build from source

```bash
git clone https://github.com/qianzhoushi/lsusb-iokit.git
cd lsusb-iokit
mkdir -p .swift-cache .build
CLANG_MODULE_CACHE_PATH=$PWD/.swift-cache swift build --disable-sandbox --build-path $PWD/.build -c release
```

The compiled binary will be:

```bash
.build/release/lsusb
```

## Usage

```bash
lsusb
lsusb -v
lsusb --json
```

If you are running directly from the build output:

```bash
./.build/release/lsusb
./.build/release/lsusb -v
./.build/release/lsusb --json
```

## Example output

Default output:

```text
Bus 001 Device 001: ID 05ac:12a8 Apple Inc. iPhone
```

Verbose output:

```text
Bus 001 Device 001: ID 05ac:12a8 Apple Inc. iPhone
  Vendor:       Apple Inc. (05ac)
  Product:      iPhone (12a8)
  Serial:       1A2B3C4D5E6F7G8H9J0K1L2M
  Location ID:  0x00100000
```

JSON output:

```json
[
  {
    "bus": 1,
    "device": 1,
    "vendorID": 1452,
    "productID": 4776,
    "vendorName": "Apple Inc.",
    "productName": "iPhone"
  }
]
```

## How It Works

- Enumerates the `IOUSB` registry plane directly through `IOKit`
- Filters `IOUSBHostDevice` entries
- Maps each device to a synthetic `Bus` number based on its USB host controller
- Uses the system-reported USB address as the `Device` number when available

This keeps the tool close to the familiar Linux `lsusb` experience while remaining native to macOS.

## Project layout

- `Package.swift`: Swift Package definition
- `Sources/lsusb/main.swift`: command-line entry point
- `lsusb_macos`: standalone Swift script version kept for convenience

## Notes

- This project is macOS-only
- It depends on Apple `IOKit`, not `libusb`
- If Swift's default module cache is not writable in your environment, keeping `CLANG_MODULE_CACHE_PATH` inside the project directory is the safest option

## License

[MIT](./LICENSE)

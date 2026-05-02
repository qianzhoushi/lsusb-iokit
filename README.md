# lsusb-iokit

一个在 macOS 上提供 `lsusb` 风格输出的原生命令行工具。

项目现在是标准 Swift Package，底层使用 `Swift + IOKit`，不依赖 `ioreg`、Homebrew 或第三方驱动。

安装后的命令名是：

```bash
lsusb
```

## 项目结构

- `Package.swift`：Swift Package 定义
- `Sources/lsusb/main.swift`：主程序源码
- `lsusb_macos`：保留的 Swift 脚本版本，便于直接运行源码

## 构建

如果本机 Swift 默认缓存目录不可写，可以把模块缓存放到项目目录：

```bash
mkdir -p .swift-cache .build
CLANG_MODULE_CACHE_PATH=$PWD/.swift-cache swift build --disable-sandbox --build-path $PWD/.build -c release
```

构建完成后的二进制在：

```bash
.build/release/lsusb
```

## 运行

```bash
.build/release/lsusb
.build/release/lsusb -v
.build/release/lsusb --json
```

## 示例输出

```text
Bus 001 Device 001: ID 05ac:12a8 Apple Inc. iPhone
```

## 实现说明

- 数据源使用 `IOKit` 直接遍历 `IOUSB` 注册表并筛选 `IOUSBHostDevice`
- 输出风格参考 Linux 上的 `lsusb`
- `Bus` 编号来自 USB Host Controller 的顺序映射
- `Device` 编号优先使用系统报告的 USB 地址

# ⚡ OrchDroid Pro

<p align="center">
  <img src="assets/icon.png" width="128" height="128" alt="OrchDroid Logo" />
</p>

<p align="center">
  <strong>Next-Generation Android Gaming & Virtualization Engine for Apple Silicon</strong><br>
  Native ARM64 • Metal & MoltenVK 120Hz Pipeline • Direct Aim & Trackpad Sub-system • Clean Custom Gaming ROM
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-Apple%20Silicon%20(M1%2FM2%2FM3%2FM4)-black?style=flat-square&logo=apple" alt="Apple Silicon" />
  <img src="https://img.shields.io/badge/Arch-ARM64%20Native-blue?style=flat-square" alt="ARM64" />
  <img src="https://img.shields.io/badge/Android-14%20(Upside%20Down%20Cake)-green?style=flat-square&logo=android" alt="Android 14" />
  <img src="https://img.shields.io/badge/Graphics-Metal%20%2F%20MoltenVK%20%2F%20Vulkan-orange?style=flat-square" alt="Metal Graphics" />
  <img src="https://img.shields.io/badge/Display-120%20FPS%20ProMotion-purple?style=flat-square" alt="120 FPS" />
  <img src="https://img.shields.io/badge/Root-Native%20Daemon%20(Toggleable)-red?style=flat-square" alt="Native Root" />
</p>

---

## 📖 Overview

**OrchDroid Pro** is a high-performance Android virtualization and gaming environment engineered from the ground up for **macOS on Apple Silicon**. Unlike generic emulators that suffer from translation overhead, input lag, and bloated background services, OrchDroid leverages **Hypervisor.framework (HVF)**, native ARM64 instruction execution, direct **Metal/MoltenVK** GPU acceleration, and a bespoke Cocoa input-interception layer.

Designed specifically for competitive mobile titles (such as *Battlegrounds Mobile India / PUBG Mobile*, *Mini Militia*, *Free Fire*), OrchDroid delivers **120 FPS buttery-smooth frame delivery**, sub-pixel mouse aiming, natural trackpad gestures, and a debloated custom ROM.

---

## ✨ Key Features

### 🚀 120 FPS Native Metal & Vulkan Pipeline
- **Host GPU Passthrough**: Uses MoltenVK over Apple Metal for Vulkan-to-Metal translation with zero overhead.
- **ProMotion Optimized**: Native 120 Hz display synchronization (`peak_refresh_rate 120`, `min_refresh_rate 120`).
- **SkiaGL Renderer**: Low-latency hardware-accelerated 2D/3D compositing via `debug.hwui.renderer skiagl`.

### 🎯 Direct Aim & Low-Latency Input Engine (`liborchdroid_ui.dylib`)
- **Direct Event Interception**: Intercepts macOS Cocoa `NSEvent` streams before they reach standard emulator event queues.
- **Mouse Aim Mode (F1 Toggle)**: Locks the mouse cursor and translates mouse movements directly into high-precision touch drags for fluid FPS camera aiming.
- **Natural Trackpad Scrolling**: Fully calibrated two-finger scroll gestures with proper directional physics and zero lag.

### 🛡️ Debloated Custom Gaming ROM (Android 14)
- **Zero Bloatware**: Stripped heavy Google system apps (*Velvet, Wellbeing, YouTube, AndroidAuto, GoogleDialer*) to maximize CPU core availability for gaming.
- **Patched Dynamic Partitions**: Native `super.img` unpack/repack pipeline (`system.img`, `vendor.img`, `product.img`).
- **Verified Boot Emulation**: Booted with `androidboot.verifiedbootstate=green` and `androidboot.veritymode=enforcing` for complete anti-cheat safety and Google Play certification.

### ⚡ Native Isolated Root Switch
- **Pure Native Daemon (`orch_sud`)**: Managed directly by Android `init` with UID 0 (`root:root`) and permissive SELinux domain (`u:r:su:s0`).
- **Zero Magisk Footprint**: No Magisk APK, no `/data/adb` folder, and no anti-cheat detection flags.
- **Dynamic Config Switch**:
  - **ON**: Instant root access for MT Manager, Termux, GameGuardian via `/system/bin/su` (`su -c id` -> `uid=0(root)`).
  - **OFF**: Daemon terminates, `su` returns "not found" (exit code 127), and device remains 100% clean and certified.

### 🖥️ Native macOS Manager & Web Dashboard
- **Dual Native macOS Apps**:
  - `OrchDroid.app`: Lightweight manager window with device launch/stop and configuration options.
  - `OrchDroid Device.app`: High-performance standalone player window.
- **Modern Dark UI**: Native macOS aesthetics with responsive device cards, hardware stats, and live controls.
- **Profile Presets**: Seamlessly switch between **Samsung Galaxy Tab S9 Ultra**, **Galaxy S24 Ultra**, and **ASUS ROG Phone 8 Pro**.

---

## 📂 Repository Layout

```text
OrchDroid/
├── apps/                    # macOS Swift application sources
│   ├── device_app.swift     # OrchDroid Device player app
│   └── manager_app.swift    # OrchDroid Manager dashboard app
├── assets/                  # AppIcon iconset and high-resolution logos
├── config/                  # Configuration & Keymaps
│   ├── keymaps/             # JSON keymapping profiles (e.g., BGMI Battle Royale)
│   └── orchdroid_config.json# Active device profile, hardware & root settings
├── custom_rom/              # ROM cooking, patching & repacking tools
│   ├── avbtool.py           # Android Verified Boot signing utility
│   ├── cook_gaming_rom.py   # Automated debloater & optimizer
│   ├── lpunpack.py          # Dynamic super image extractor
│   ├── patch_custom_rom.py  # System and product debloater script
│   ├── repack_super.py      # Flashes partitions back into raw super system.img
│   └── unpack_super.py      # Logical partition parser
├── engine/                  # Native injection & virtualization engine
│   ├── instance_manager.py  # Virtual machine instance lifecycle controller
│   ├── orchdroid_ui.m       # Objective-C Metal/Cocoa direct input & aim dylib
│   └── qemu_builder.py      # Hypervisor CLI builder
├── host_app/                # Host Cocoa wrapper
│   └── main.swift           # Native status-bar & manager entry point
├── profiles/                # Hardware device definitions & GPU profiles
├── scripts/                 # Build & deployment scripts
│   ├── apply_config.py      # Synchronizes JSON config into boot environment
│   ├── boot_android.sh      # Master launcher script with runtime tuners
│   └── build_orchdroid.sh   # Compiles macOS apps and native input dylib
├── web/                     # Web dashboard assets (HTML5, Vanilla CSS, JS)
├── server.py                # Local REST API server for multi-instance management
├── start.sh                 # Single-click launcher for OrchDroid server & dashboard
└── .gitignore               # Excludes large binaries, disks, and SDKs
```

---

## 🛠️ Prerequisites & Requirements

1. **Hardware**: Apple Silicon Mac (M1, M2, M3, M4 series with unified memory).
2. **Operating System**: macOS Monterey 12.0 or newer (tested on macOS 14 Sonoma & macOS 15 Sequoia).
3. **Command Line Tools**:
   ```bash
   xcode-select --install
   ```
4. **Python & Utilities**:
   ```bash
   brew install python@3.11 e2fsprogs
   ```
5. **Android Platform Tools**:
   Ensure `adb` is installed and accessible (or use the bundled binary under `sdk/platform-tools/adb`).

---

## 🏗️ Build Instructions

### 1. Build Native Apps & Injection Engine
Compile `OrchDroid.app`, `OrchDroid Device.app`, and `liborchdroid_ui.dylib` in one command:

```bash
./scripts/build_orchdroid.sh
```

This compiles:
- `dist/OrchDroid.app` (Swift / Cocoa ARM64 Mach-O)
- `dist/OrchDroid Device.app` (Swift / Cocoa ARM64 Mach-O)
- `dist/liborchdroid_ui.dylib` (Objective-C ARC + Metal + CoreImage + QuartzCore)

### 2. Cooking the Custom Gaming ROM
To debloat system partitions and inject the native isolated root daemon:

```bash
# 1. Unpack dynamic partitions from the base image
python3 custom_rom/unpack_super.py

# 2. Debloat system & product images and patch build properties
python3 custom_rom/patch_custom_rom.py

# 3. Repack partitions into images/cooked/system.img
python3 custom_rom/repack_super.py
```

---

## 🚀 Running OrchDroid

### Option 1: Start via Management Dashboard
Launch the background instance manager server and open the web dashboard:

```bash
./start.sh
```
Open [http://localhost:8088](http://localhost:8088) in Safari or Chrome to manage devices.

### Option 2: Direct High-Performance Boot
Launch the Android 14 gaming instance directly with all optimizations and input hooks active:

```bash
./scripts/boot_android.sh
```

---

## ⚙️ Configuration & Hardware Tuning

All emulator parameters can be configured directly in `config/orchdroid_config.json`:

```json
{
  "active_profile": "tab_s9_ultra",
  "performance": {
    "auto_detect_apple_silicon": true,
    "cpu_cores": 4,
    "memory_mb": 12288,
    "high_fps_mode": 120,
    "resolution": {
      "width": 2304,
      "height": 1440,
      "dpi": 360
    }
  },
  "keymapping": {
    "enabled": true,
    "shooting_mode_toggle_key": "F1",
    "mouse_aim_sensitivity_x": 1.2,
    "mouse_aim_sensitivity_y": 1.2
  },
  "root_permission": {
    "enabled": true,
    "description": "OrchDroid Root Switch: OFF keeps device 100% certified & anti-cheat safe. ON enables isolated native su daemon for root apps."
  }
}
```

---

## 🎮 Keymapping & Aim Mode Controls

| Key / Gesture | Function |
| :--- | :--- |
| **F1** | Toggle Free-Look Mouse Shooting Mode (Aim Mode) |
| **Trackpad 2-Finger Scroll** | Smooth Inverted Y Scroll (Natural Direction Physics) |
| **W / A / S / D** | 8-Directional Movement Joystick |
| **Left Click** | Primary Fire / Tap |
| **Right Click** | Aim Down Sights (ADS) |
| **Space** | Jump |
| **C / Z** | Crouch / Prone |
| **R** | Reload Weapon |

---

## 📄 License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for details.
All trademarks and registered trademarks belong to their respective owners.

#!/usr/bin/env python3
import os
import sys
import subprocess
from pathlib import Path

CUSTOM_ROM_DIR = Path("/Volumes/LinuxFS/OrchDroid/custom_rom")
PARTITIONS_DIR = CUSTOM_ROM_DIR / "partitions"
COOKED_DIR = Path("/Volumes/LinuxFS/OrchDroid/images/cooked")
BASE_SYSTEM_IMG = Path("/Volumes/LinuxFS/OrchDroid/images/base/google_apis_playstore_14/arm64-v8a/system.img")
COOKED_SYSTEM_IMG = COOKED_DIR / "system.img"

E2RM = "/opt/homebrew/bin/e2rm"
E2CP = "/opt/homebrew/bin/e2cp"
E2LS = "/opt/homebrew/bin/e2ls"
DEBUGFS = "/opt/homebrew/opt/e2fsprogs/sbin/debugfs"

SAMSUNG_FINGERPRINT = "samsung/gts9ux/gts9u:14/UP1A.231005.007/X910XXU1BWL1:user/release-keys"
SAMSUNG_MODEL = "SM-X910"
SAMSUNG_BRAND = "samsung"
SAMSUNG_DEVICE = "gts9u"
SAMSUNG_MANUFACTURER = "samsung"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res.returncode == 0, res.stdout, res.stderr

def remove_paths(img_path, paths):
    for p in paths:
        target = f"{img_path}:{p}"
        success, _, _ = run_cmd(f"{E2RM} -r {target}")
        if success:
            print(f"  [-] Removed: {p}")

def patch_file(img_path, internal_path, patch_func):
    temp_local = CUSTOM_ROM_DIR / f"temp_{Path(internal_path).name}"
    cmd_dump = f"{DEBUGFS} -R 'dump {internal_path} {temp_local}' {img_path}"
    success, _, _ = run_cmd(cmd_dump)
    if not temp_local.exists():
        print(f"  [!] Failed to extract {internal_path} from {img_path.name}")
        return False
    
    with open(temp_local, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()
    
    new_content = patch_func(content)
    
    with open(temp_local, "w", encoding="utf-8") as f:
        f.write(new_content)
    
    cmd_cp = f"{E2CP} {temp_local} {img_path}:{internal_path}"
    success, _, err = run_cmd(cmd_cp)
    temp_local.unlink(missing_ok=True)
    if success:
        print(f"  [+] Patched {internal_path} in {img_path.name}")
        return True
    else:
        print(f"  [!] Failed to write {internal_path}: {err}")
        return False

def patch_common_props(content, partition_name="system"):
    lines = content.splitlines()
    new_lines = []
    
    fingerprint_keys = [
        f"ro.{partition_name}.build.fingerprint",
        f"ro.product.{partition_name}.brand",
        f"ro.product.{partition_name}.device",
        f"ro.product.{partition_name}.manufacturer",
        f"ro.product.{partition_name}.model",
        f"ro.product.{partition_name}.name",
        f"ro.{partition_name}.build.tags",
        f"ro.{partition_name}.build.type",
    ]
    
    for line in lines:
        if any(line.startswith(f"{k}=") for k in fingerprint_keys):
            continue
        if line.startswith("ro.build.tags=") or line.startswith("ro.build.type="):
            continue
        if line.startswith("ro.build.fingerprint="):
            continue
        if line.startswith("ro.opengles.version="):
            continue
        new_lines.append(line)
        
    # Append certified props
    new_lines.append(f"ro.{partition_name}.build.fingerprint={SAMSUNG_FINGERPRINT}")
    new_lines.append(f"ro.product.{partition_name}.brand={SAMSUNG_BRAND}")
    new_lines.append(f"ro.product.{partition_name}.device={SAMSUNG_DEVICE}")
    new_lines.append(f"ro.product.{partition_name}.manufacturer={SAMSUNG_MANUFACTURER}")
    new_lines.append(f"ro.product.{partition_name}.model={SAMSUNG_MODEL}")
    new_lines.append(f"ro.product.{partition_name}.name={SAMSUNG_DEVICE}")
    new_lines.append(f"ro.{partition_name}.build.tags=release-keys")
    new_lines.append(f"ro.{partition_name}.build.type=user")
    
    return "\n".join(new_lines) + "\n"

def patch_system_build_prop(content):
    content = patch_common_props(content, "system")
    gaming_additions = f"""
# ========================================================
# OrchDroid Pro Gaming & Certified Play Integrity HAL
# ========================================================
ro.build.fingerprint={SAMSUNG_FINGERPRINT}
ro.bootimage.build.fingerprint={SAMSUNG_FINGERPRINT}
ro.build.tags=release-keys
ro.build.type=user
ro.debuggable=0
ro.secure=1
ro.adb.secure=0

# Hardware Specs & Display
ro.product.model={SAMSUNG_MODEL}
ro.product.brand={SAMSUNG_BRAND}
ro.product.name={SAMSUNG_DEVICE}
ro.product.device={SAMSUNG_DEVICE}
ro.product.manufacturer={SAMSUNG_MANUFACTURER}
ro.build.product={SAMSUNG_DEVICE}
ro.build.characteristics=tablet
ro.sf.lcd_density=360
ro.soc.manufacturer=Qualcomm
ro.soc.model=Snapdragon 8 Gen 2

# Graphics & Gaming Pipeline
ro.opengles.version=196608
ro.hardware.egl=angle
ro.hardware.vulkan=ranchu
persist.sys.gpu.renderer=Adreno (TM) 740
debug.hwui.fps_divisor=1
debug.hwui.renderer=skiagl
debug.egl.swapinterval=0
ro.kernel.qemu=0
"""
    return content + gaming_additions

def patch_vendor_build_prop(content):
    content = patch_common_props(content, "vendor")
    content += f"""
ro.opengles.version=196608
ro.hardware.egl=angle
ro.hardware.vulkan=ranchu
"""
    return content

def patch_product_build_prop(content):
    return patch_common_props(content, "product")

def patch_system_ext_build_prop(content):
    return patch_common_props(content, "system_ext")

def write_partition_to_image(source_part_path, target_img_path, offset):
    print(f"[*] Flashing {source_part_path.name} to {target_img_path.name} (offset {offset})...")
    part_size = source_part_path.stat().st_size
    chunk_size = 16 * 1024 * 1024
    
    with open(source_part_path, "rb") as f_src, open(target_img_path, "r+b") as f_dst:
        f_dst.seek(offset)
        written = 0
        while written < part_size:
            chunk = f_src.read(chunk_size)
            if not chunk:
                break
            f_dst.write(chunk)
            written += len(chunk)
            pct = (written / part_size) * 100
            print(f"\r    Writing {source_part_path.name}: {pct:.1f}% ({written // (1024*1024)}MB / {part_size // (1024*1024)}MB)", end="", flush=True)
    print("\n[+] Flashed successfully!")

def main():
    print("=========================================================")
    print("  🚀 OrchDroid OS Kitchen: Debloat, Certify & Repack     ")
    print("=========================================================")

    system_img = PARTITIONS_DIR / "system.img"
    vendor_img = PARTITIONS_DIR / "vendor.img"
    product_img = PARTITIONS_DIR / "product.img"
    system_ext_img = PARTITIONS_DIR / "system_ext.img"

    # 1. Debloat product.img
    print("\n[1/4] Debloating Google telemetry & tracking apps...")
    product_bloat = [
        "app/PrebuiltGoogleTelemetryTvp",
        "app/NexusWallpapersStubPrebuilt2018",
        "priv-app/WellbeingPrebuilt",
        "priv-app/Velvet",
        "priv-app/AndroidAutoStubPrebuilt",
        "priv-app/GoogleDialer",
        "priv-app/PrebuiltBugle",
        "priv-app/DeviceIntelligenceNetworkPrebuilt",
        "priv-app/DevicePersonalizationPrebuiltPixel2021",
        "priv-app/KidsSupervisionStub",
        "priv-app/OdadPrebuilt"
    ]
    remove_paths(product_img, product_bloat)

    # 2. Debloat system.img & Remove root-detection /system/xbin
    print("\n[2/4] Debloating system.img & clearing /system/xbin detection...")
    system_bloat = [
        "system/app/Traceur",
        "system/app/BasicDreams",
        "system/app/BookmarkProvider",
        "system/app/PartnerBookmarksProvider",
        "system/xbin/su",
        "system/xbin"
    ]
    remove_paths(system_img, system_bloat)

    # 3. Patch build.props across all 4 partitions
    print("\n[3/4] Burning Samsung Galaxy Tab S9 Ultra Certified Release-Keys...")
    patch_file(system_img, "system/build.prop", patch_system_build_prop)
    patch_file(vendor_img, "build.prop", patch_vendor_build_prop)
    patch_file(product_img, "etc/build.prop", patch_product_build_prop)
    patch_file(system_ext_img, "etc/build.prop", patch_system_ext_build_prop)

    # 4. Repack Super Image
    print("\n[4/4] Repacking Super Image into cooked/system.img...")
    SUPER_BASE_OFFSET = 2097152
    SECTOR_SIZE = 512

    PARTITION_OFFSETS = {
        system_img: SUPER_BASE_OFFSET + 2048 * SECTOR_SIZE,
        vendor_img: SUPER_BASE_OFFSET + 1613824 * SECTOR_SIZE,
        system_ext_img: SUPER_BASE_OFFSET + 1796096 * SECTOR_SIZE,
        product_img: SUPER_BASE_OFFSET + 2113536 * SECTOR_SIZE,
    }

    COOKED_DIR.mkdir(parents=True, exist_ok=True)
    if not COOKED_SYSTEM_IMG.exists():
        print(f"[*] Cloning base system.img to cooked...")
        subprocess.run(["cp", str(BASE_SYSTEM_IMG), str(COOKED_SYSTEM_IMG)], check=True)

    for part_file, offset in PARTITION_OFFSETS.items():
        if part_file.exists():
            write_partition_to_image(part_file, COOKED_SYSTEM_IMG, offset)
        else:
            print(f"[!] Warning: {part_file} not found!")

    print(f"[+] Cooked system image ready at {COOKED_SYSTEM_IMG}!")

    print("\n=========================================================")
    print("  ✅ OrchDroid Custom Gaming OS Successfully Built!      ")
    print("=========================================================")

if __name__ == "__main__":
    main()

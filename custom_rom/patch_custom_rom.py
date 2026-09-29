#!/usr/bin/env python3
import os
import subprocess
from pathlib import Path

CUSTOM_ROM_DIR = Path("/Volumes/LinuxFS/OrchDroid/custom_rom")
PARTITIONS_DIR = CUSTOM_ROM_DIR / "partitions"
SYSTEM_IMG = PARTITIONS_DIR / "system.img"
PRODUCT_IMG = PARTITIONS_DIR / "product.img"

E2RM = "/opt/homebrew/bin/e2rm"
E2CP = "/opt/homebrew/bin/e2cp"
DEBUGFS = "/opt/homebrew/opt/e2fsprogs/sbin/debugfs"

def remove_ext4_paths(img_path, paths):
    for p in paths:
        target = f"{img_path}:{p}"
        res = subprocess.run([E2RM, "-r", target], capture_output=True, text=True)
        if res.returncode == 0:
            print(f"[+] Debloated: {p}")
        else:
            pass

def patch_build_props():
    print("[*] Patching system/build.prop...")
    tmp_build_prop = CUSTOM_ROM_DIR / "system_build.prop.modified"
    subprocess.run([DEBUGFS, "-R", f"dump system/build.prop {tmp_build_prop}", str(SYSTEM_IMG)], capture_output=True)
    
    if not tmp_build_prop.exists():
        print("[-] Failed to dump system/build.prop")
        return

    with open(tmp_build_prop, "r") as f:
        content = f.read()

    replacements = {
        "ro.product.system.brand=google": "ro.product.system.brand=samsung",
        "ro.product.system.device=generic": "ro.product.system.device=gts9u",
        "ro.product.system.manufacturer=Google": "ro.product.system.manufacturer=samsung",
        "ro.product.system.model=mainline": "ro.product.system.model=SM-X910",
        "ro.product.system.name=mainline": "ro.product.system.name=gts9u",
        "ro.system.build.fingerprint=google/sdk_gphone64_arm64/emu64a:14/UE1A.230829.036.A4/12096271:user/release-keys": 
        "ro.system.build.fingerprint=samsung/gts9ux/gts9u:14/UP1A.231005.007/X910XXU1BWL1:user/release-keys",
    }
    
    for old, new in replacements.items():
        content = content.replace(old, new)

    # Append gaming and anti-detection props
    gaming_props = """
# OrchDroid Gaming & Anti-Detection Pipeline
ro.product.model=SM-X910
ro.product.brand=samsung
ro.product.name=gts9u
ro.product.device=gts9u
ro.product.manufacturer=samsung
ro.build.product=gts9u
ro.build.characteristics=tablet
ro.sf.lcd_density=360
debug.hwui.fps_divisor=1
debug.egl.swapinterval=0
persist.sys.gpu.renderer=Adreno (TM) 740
ro.soc.manufacturer=Qualcomm
ro.soc.model=Snapdragon 8 Gen 2
ro.kernel.qemu=0
"""
    content += gaming_props

    with open(tmp_build_prop, "w") as f:
        f.write(content)

    subprocess.run([E2CP, str(tmp_build_prop), f"{SYSTEM_IMG}:system/build.prop"], check=True)
    print("[+] Successfully injected modified system/build.prop!")

def main():
    print("=== OrchDroid Custom ROM Debloater ===")
    
    # Safely removable bloat apps (keeps TVP / sdksandbox required by Android 14 System Server)
    product_bloat = [
        "app/YouTube",
        "app/YouTubeMusicPrebuilt",
        "app/Maps",
        "app/Drive",
        "app/Photos",
        "app/PrebuiltGmail",
        "app/CalendarGooglePrebuilt",
        "app/NexusWallpapersStubPrebuilt2018",
        "priv-app/WellbeingPrebuilt",
        "priv-app/Velvet",
        "priv-app/AndroidAutoStubPrebuilt",
        "priv-app/GoogleDialer",
        "priv-app/PrebuiltBugle"
    ]
    
    print("[*] Debloating product.img...")
    remove_ext4_paths(PRODUCT_IMG, product_bloat)
    
    system_bloat = [
        "system/app/Traceur",
        "system/app/BasicDreams",
        "system/app/BookmarkProvider",
        "system/app/PartnerBookmarksProvider"
    ]
    print("[*] Debloating system.img...")
    remove_ext4_paths(SYSTEM_IMG, system_bloat)

    patch_build_props()
    print("\n[✓] Safe custom ROM debloat completed!")

if __name__ == "__main__":
    main()

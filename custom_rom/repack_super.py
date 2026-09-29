#!/usr/bin/env python3
import os
import subprocess
from pathlib import Path

BASE_SYSTEM_IMG = Path("/Volumes/LinuxFS/OrchDroid/images/base/google_apis_playstore_14/arm64-v8a/system.img")
COOKED_DIR = Path("/Volumes/LinuxFS/OrchDroid/images/cooked")
COOKED_SYSTEM_IMG = COOKED_DIR / "system.img"
PARTITIONS_DIR = Path("/Volumes/LinuxFS/OrchDroid/custom_rom/partitions")

# Super base offset in system.img: LBA 4096 * 512 = 2097152
SUPER_BASE_OFFSET = 2097152
SECTOR_SIZE = 512

PARTITION_OFFSETS = {
    "system.img": SUPER_BASE_OFFSET + 2048 * SECTOR_SIZE,
    "vendor.img": SUPER_BASE_OFFSET + 1613824 * SECTOR_SIZE,
    "product.img": SUPER_BASE_OFFSET + 2113536 * SECTOR_SIZE,
}

def write_partition_to_image(source_part_path, target_img_path, offset):
    print(f"[*] Flashing {source_part_path.name} to {target_img_path.name} at byte offset {offset}...")
    part_size = source_part_path.stat().st_size
    chunk_size = 16 * 1024 * 1024 # 16 MB chunk
    
    with open(source_part_path, "rb") as f_src, open(target_img_path, "r+b") as f_dst:
        f_dst.seek(offset)
        written = 0
        while written < part_size:
            chunk = f_src.read(chunk_size)
            if not chunk:
                break
            f_dst.write(chunk)
            written += len(chunk)
            progress = (written / part_size) * 100
            print(f"\r    Progress: {progress:.1f}% ({written // (1024*1024)} MB / {part_size // (1024*1024)} MB)", end="", flush=True)
    print("\n[+] Flashed successfully!")

def main():
    print("=== OrchDroid Super Image Repacker ===")
    COOKED_DIR.mkdir(parents=True, exist_ok=True)
    
    if not COOKED_SYSTEM_IMG.exists():
        print(f"[*] Creating APFS CoW clone of base system image...")
        subprocess.run(["cp", "-c", str(BASE_SYSTEM_IMG), str(COOKED_SYSTEM_IMG)], check=True)
    
    # Flash modified system and product
    for part_name, offset in PARTITION_OFFSETS.items():
        part_path = PARTITIONS_DIR / part_name
        if part_path.exists():
            write_partition_to_image(part_path, COOKED_SYSTEM_IMG, offset)
        else:
            print(f"[-] Warning: {part_name} not found in {PARTITIONS_DIR}")
            
    print("\n[✓] Cooked Custom ROM system.img is ready at:")
    print(f"    {COOKED_SYSTEM_IMG}")

if __name__ == "__main__":
    main()

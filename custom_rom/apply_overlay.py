#!/usr/bin/env python3
"""
OrchDroid Custom ROM Tree Applier
Applies the custom_rom/overlay/ source tree onto the stock partition images,
sets proper file modes and SELinux xattrs, and triggers repack_super.py.
"""
import os
import sys
import subprocess
import json
from pathlib import Path

BASE_DIR = Path("/Volumes/LinuxFS/OrchDroid")
CUSTOM_ROM_DIR = BASE_DIR / "custom_rom"
OVERLAY_DIR = CUSTOM_ROM_DIR / "overlay"
PARTITIONS_DIR = CUSTOM_ROM_DIR / "partitions"
DEFS_DIR = CUSTOM_ROM_DIR / "overlay" / "debloat_manifest.json"

DEBUGFS = "/opt/homebrew/opt/e2fsprogs/sbin/debugfs"
E2CP = "/opt/homebrew/bin/e2cp"
E2RM = "/opt/homebrew/bin/e2rm"

def run_cmd(cmd):
    res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return res.returncode == 0, res.stdout, res.stderr

def apply_debloat():
    if not DEFS_DIR.exists():
        return
    with open(DEFS_DIR) as f:
        data = json.load(f)
    
    product_img = PARTITIONS_DIR / "product.img"
    if not product_img.exists():
        return
        
    print("[*] Debloating product.img according to manifest...")
    for rel_path in data.get("product_removed", []):
        run_cmd(f"{E2RM} -r {product_img}:{rel_path}")
        print(f"  [-] Debloated: {rel_path}")

def apply_overlay_to_partition(part_name, overlay_subpath, xattr_context):
    part_img = PARTITIONS_DIR / part_name
    if not part_img.exists():
        print(f"[-] Partition {part_name} not found, skipping...")
        return

    source_dir = OVERLAY_DIR / overlay_subpath
    if not source_dir.exists():
        return

    print(f"[*] Applying overlay from {source_dir.name} to {part_name}...")
    
    # Create temporary xattr file with null terminator
    xattr_tmp = Path("/tmp/xattr_selinux_tmp")
    with open(xattr_tmp, "wb") as f:
        f.write(f"{xattr_context}\0".encode("utf-8"))

    # Walk overlay files
    for root, dirs, files in os.walk(source_dir):
        rel_root = Path(root).relative_to(source_dir)
        
        # Ensure directories exist in ext4
        for d in dirs:
            dir_target = (rel_root / d).as_posix()
            run_cmd(f"{DEBUGFS} -w -R 'mkdir {dir_target}' {part_img}")
            run_cmd(f"{DEBUGFS} -w -R 'set_inode_field {dir_target} mode 040755' {part_img}")
            run_cmd(f"{DEBUGFS} -w -R 'set_inode_field {dir_target} uid 0' {part_img}")
            run_cmd(f"{DEBUGFS} -w -R 'set_inode_field {dir_target} gid 0' {part_img}")
            run_cmd(f"{DEBUGFS} -w -R 'ea_set -f {xattr_tmp} {dir_target} security.selinux' {part_img}")

        for file in files:
            src_file = Path(root) / file
            dest_internal = (rel_root / file).as_posix()
            mode = "0100755" if (file == "su" or file.endswith(".sh")) else "0100644"
            
            # Copy file
            run_cmd(f"{E2CP} {src_file} {part_img}:{dest_internal}")
            # Set metadata
            run_cmd(f"{DEBUGFS} -w -R 'set_inode_field {dest_internal} mode {mode}' {part_img}")
            run_cmd(f"{DEBUGFS} -w -R 'set_inode_field {dest_internal} uid 0' {part_img}")
            run_cmd(f"{DEBUGFS} -w -R 'set_inode_field {dest_internal} gid 0' {part_img}")
            run_cmd(f"{DEBUGFS} -w -R 'ea_set -f {xattr_tmp} {dest_internal} security.selinux' {part_img}")
            print(f"  [+] Injected {dest_internal} ({mode}, {xattr_context})")

    xattr_tmp.unlink(missing_ok=True)

def main():
    print("==========================================================")
    print("    🛠️  OrchDroid Custom ROM Overlay Builder              ")
    print("==========================================================")

    apply_debloat()
    apply_overlay_to_partition("system.img", "system", "u:object_r:system_file:s0")
    apply_overlay_to_partition("vendor.img", "vendor", "u:object_r:vendor_configs_file:s0")

    print("\n[*] Triggering super image repacker...")
    repack_script = CUSTOM_ROM_DIR / "repack_super.py"
    subprocess.run([sys.executable, str(repack_script)], check=True)
    print("\n[✓] Custom ROM successfully compiled from source tree overlay!")

if __name__ == "__main__":
    main()

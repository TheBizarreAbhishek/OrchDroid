#!/usr/bin/env python3
import os
import sys
import struct
from pathlib import Path

# Subclass lpunpack with base offset support
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from lpunpack import LpUnpack, FormatType, LpUnpackError

class SuperUnpacker(LpUnpack):
    def __init__(self, offset=2097152, **kwargs):
        super().__init__(**kwargs)
        self._offset = offset
        orig_seek = self._fd.seek
        def offset_seek(pos, whence=0):
            if whence == 0:
                return orig_seek(self._offset + pos, whence)
            elif whence == 1:
                return orig_seek(pos, whence)
            elif whence == 2:
                return orig_seek(pos, whence)
        self._fd.seek = offset_seek

def main():
    super_img_path = "/Volumes/LinuxFS/OrchDroid/images/base/google_apis_playstore_14/arm64-v8a/system.img"
    out_dir = Path("/Volumes/LinuxFS/OrchDroid/custom_rom/partitions")
    out_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"[*] Reading partitions from: {super_img_path}")
    print(f"[*] Output directory: {out_dir}")
    
    unpacker = SuperUnpacker(
        offset=2097152, # GPT partition 1 super LBA 4096 * 512
        SUPER_IMAGE=super_img_path,
        OUTPUT_DIR=out_dir,
        SHOW_INFO=False
    )
    unpacker.unpack()
    print("[+] Partition extraction complete!")

if __name__ == "__main__":
    main()

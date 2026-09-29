import os

class QemuCmdBuilder:
    @staticmethod
    def build_command(config, base_dir="/Volumes/LinuxFS/OrchDroid"):
        inst_dir = config.get("deviceStorageDir", os.path.join(base_dir, "instances", config.get("instanceId", "default")))
        cores = config.get("vmCpuCount", 4)
        mem_mb = config.get("vmMemoryOfMB", 12288)
        adb_port = config.get("adbPort", 5555)
        
        # Build clean cmdline without emulator traces
        kernel_cmdline = "rdinit=init buildvariant=user console=ttyAMA1 androidboot.hardware=qcom"
        
        cmd = [
            "qemu-system-aarch64",
            "-M", "virt,highmem=on",
            "-accel", "hvf",
            "-cpu", "host",
            "-smp", str(cores),
            "-m", f"{mem_mb}M",
            "-append", f'"{kernel_cmdline}"',
            "-device", "virtio-gpu-pci",
            "-device", "virtio-mouse-pci",
            "-device", "virtio-keyboard-pci",
            "-netdev", f"user,id=orch-net0,hostfwd=tcp::{adb_port}-:5555",
            "-device", "virtio-net-pci,netdev=orch-net0"
        ]
        return cmd

#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

CONFIG_PATH = Path("/Volumes/LinuxFS/OrchDroid/config/orchdroid_config.json")

def get_sysctl(name):
    try:
        res = subprocess.run(["sysctl", "-n", name], capture_output=True, text=True, check=True)
        return res.stdout.strip()
    except Exception:
        return None

def main():
    if not CONFIG_PATH.exists():
        print("CONFIG_PATH not found", file=sys.stderr)
        sys.exit(1)
        
    with open(CONFIG_PATH, "r") as f:
        cfg = json.load(f)
        
    active_key = cfg.get("active_profile", "tab_s9_ultra")
    profile = cfg.get("profiles", {}).get(active_key, {})
    perf = cfg.get("performance", {})
    
    # 1. CPU cores & RAM auto-tuning for Apple Silicon
    cpu_cores = perf.get("cpu_cores", 4)
    memory_mb = perf.get("memory_mb", 8192)
    
    if perf.get("auto_detect_apple_silicon", True):
        p_cores = get_sysctl("hw.perflevel0.logicalcpu")
        if p_cores and p_cores.isdigit():
            cpu_cores = int(p_cores)
            
        mem_bytes = get_sysctl("hw.memsize")
        if mem_bytes and mem_bytes.isdigit():
            total_gb = int(mem_bytes) // (1024 * 1024 * 1024)
            # Allocate up to 50% of Mac Unified RAM to Android (capped at 16GB)
            memory_mb = min(16384, max(4096, (total_gb // 2) * 1024))

    # 2. Extract profile attributes
    brand = profile.get("brand", "samsung")
    model = profile.get("model", "SM-X910")
    product = profile.get("product", "gts9u")
    manufacturer = profile.get("manufacturer", "samsung")
    fingerprint = profile.get("fingerprint", "")
    gpu_renderer = profile.get("gpu", {}).get("renderer", "Adreno (TM) 740")
    gpu_vendor = profile.get("gpu", {}).get("vendor", "Qualcomm")
    
    res_w = perf.get("resolution", {}).get("width", 2304)
    res_h = perf.get("resolution", {}).get("height", 1440)
    res_dpi = perf.get("resolution", {}).get("dpi", 360)

    # Check instance config for carrier / SIM settings
    inst_cfg_path = Path("/Volumes/LinuxFS/OrchDroid/instances/default/vm.json")
    carrier = "none"
    phone_number = "+919876543210"
    if inst_cfg_path.exists():
        try:
            with open(inst_cfg_path) as ifile:
                idata = json.load(ifile)
                carrier = idata.get("carrierPreset", "none")
                phone_number = idata.get("phoneNumber", phone_number).replace(" ", "")
        except Exception:
            pass

    if carrier in ("none", "wifi_only"):
        sim_flag = "-no-sim"
        carrier_name = "Wi-Fi Only (No SIM)"
    elif carrier == "jio":
        sim_flag = f"-phone-number {phone_number}"
        carrier_name = "Jio True 5G"
    elif carrier == "airtel":
        sim_flag = f"-phone-number {phone_number}"
        carrier_name = "Airtel 5G"
    else:
        sim_flag = f"-phone-number {phone_number}"
        carrier_name = "Vi India"
    
    vm_root = False
    if inst_cfg_path.exists():
        try:
            with open(inst_cfg_path) as ifile:
                idata = json.load(ifile)
                vm_root = idata.get("vmRootEnable", False)
        except Exception:
            pass

    root_enabled = 1 if (vm_root or cfg.get("root_permission", {}).get("enabled", False)) else 0

    if len(sys.argv) > 1 and sys.argv[1] == "--env":
        # Output shell export variables
        print(f"export ORCH_CPU_CORES={cpu_cores}")
        print(f"export ORCH_MEMORY_MB={memory_mb}")
        print(f"export ORCH_BRAND='{brand}'")
        print(f"export ORCH_MODEL='{model}'")
        print(f"export ORCH_PRODUCT='{product}'")
        print(f"export ORCH_MANUFACTURER='{manufacturer}'")
        print(f"export ORCH_FINGERPRINT='{fingerprint}'")
        print(f"export ORCH_GPU_RENDERER='{gpu_renderer}'")
        print(f"export ORCH_GPU_VENDOR='{gpu_vendor}'")
        print(f"export ORCH_WIDTH={res_w}")
        print(f"export ORCH_HEIGHT={res_h}")
        print(f"export ORCH_DPI={res_dpi}")
        print(f"export ORCH_SIM_FLAG='{sim_flag}'")
        print(f"export ORCH_CARRIER_NAME='{carrier_name}'")
        print(f"export ORCH_ROOT_ENABLED={root_enabled}")
        print(f"export ORCH_PROFILE_NAME='{profile.get('name', model)}'")
    else:
        print(f"Profile: {profile.get('name', model)}")
        print(f"P-Cores: {cpu_cores}, RAM: {memory_mb}MB, GPU: {gpu_renderer}, SIM: {carrier_name}, Root: {root_enabled}")

if __name__ == "__main__":
    main()

import os
import json
import random
import shutil
import subprocess

BASE_DIR = "/Volumes/LinuxFS/OrchDroid"
INSTANCES_DIR = os.path.join(BASE_DIR, "instances")
PROFILES_DIR = os.path.join(BASE_DIR, "profiles")

def generate_luhn_imei(tac="868425"):
    """Generate a realistic 15-digit IMEI with valid Luhn checksum."""
    body = [int(x) for x in tac]
    while len(body) < 14:
        body.append(random.randint(0, 9))
    
    # Calculate Luhn checksum
    total = 0
    for i, num in enumerate(body):
        if (i % 2) != 0:
            doubled = num * 2
            total += (doubled // 10) + (doubled % 10)
        else:
            total += num
    checksum = (10 - (total % 10)) % 10
    body.append(checksum)
    return "".join(map(str, body))

class InstanceManager:
    def __init__(self):
        os.makedirs(INSTANCES_DIR, exist_ok=True)
        if not os.path.exists(os.path.join(INSTANCES_DIR, "default")):
            self.create_instance("default", "Android Device 1", device_type="tablet")

    def list_instances(self):
        instances = []
        for item in os.listdir(INSTANCES_DIR):
            p = os.path.join(INSTANCES_DIR, item, "vm.json")
            if os.path.isfile(p):
                try:
                    with open(p, "r") as f:
                        data = json.load(f)
                        instances.append(data)
                except Exception as e:
                    print(f"Error reading {p}: {e}")
        instances.sort(key=lambda x: x.get("instanceId", ""))
        return instances

    def get_instance(self, instance_id):
        p = os.path.join(INSTANCES_DIR, instance_id, "vm.json")
        if os.path.isfile(p):
            with open(p, "r") as f:
                return json.load(f)
        return None

    def save_instance(self, instance_id, data):
        inst_dir = os.path.join(INSTANCES_DIR, instance_id)
        os.makedirs(inst_dir, exist_ok=True)
        p = os.path.join(inst_dir, "vm.json")
        data["instanceId"] = instance_id
        with open(p, "w") as f:
            json.dump(data, f, indent=2)
        return data

    def create_instance(self, instance_id=None, name="New Android Device", device_type="tablet"):
        if not instance_id:
            num = len(os.listdir(INSTANCES_DIR)) + 1
            instance_id = f"device_{num}"
        
        is_phone = (device_type == "phone")
        width = 1080 if is_phone else 2304
        height = 2400 if is_phone else 1440
        dpi = 440 if is_phone else 360

        inst_dir = os.path.join(INSTANCES_DIR, instance_id)
        os.makedirs(inst_dir, exist_ok=True)

        config = {
            "instanceId": instance_id,
            "vmName": name,
            "vmDeviceType": 2 if is_phone else 1,
            "status": "stopped",
            "vmCpuCount": 4,
            "vmMemoryOfMB": 12288,
            "framebufferWidth": width,
            "framebufferHeight": height,
            "framebufferDPI": dpi,
            "resolutionType": device_type,
            "notchDisplay": "none",
            "fpsShowEnable": True,
            "windowAutoRotationEnable": True,
            "renderQualityEnable": True,
            "gpuFastMathEnable": False,
            "maxFpsLimit": 120,
            "dynamicFpsEnable": False,
            "dynamicFpsLimitToLow": 15,
            "systemDiskMode": "readonly",
            "diskOccupiedGB": "2.10",
            "deviceStorageDir": inst_dir,
            "phonePropBrand": "Samsung",
            "phonePropModel": "Galaxy S24 Ultra",
            "phonePropMiit": "SM-S928B",
            "phonePropIMEI": generate_luhn_imei(),
            "phoneNumber": "",
            "vmRootEnable": True,
            "gpuPropType": "custom",
            "gpuPropModel": "Adreno (TM) 750",
            "gpuVendor": "Qualcomm",
            "glVersion": "OpenGL ES 3.2 V@0615.0",
            "adbPort": 5555 + len(os.listdir(INSTANCES_DIR)),
            "tryDefaultAdbPort": (instance_id == "default"),
            "bossKey": "^⌥P",
            "bossKeyEnable": False,
            "mouseCursorStyle": "gaming",
            "quitOption": "popup",
            "security": {
                "playIntegrityFix": True,
                "trickyStoreEnabled": True,
                "keyboxXmlPath": "/Volumes/LinuxFS/OrchDroid/security/keybox.xml",
                "keyboxStatus": "Active (Hardware TEE)",
                "sensorMicroJitter": True,
                "batteryThermalCurve": True,
                "hideQemuPipes": True,
                "hideProcCmdline": True
            }
        }
        return self.save_instance(instance_id, config)

    def clone_instance(self, source_id):
        src = self.get_instance(source_id)
        if not src:
            return None
        new_id = f"{source_id}_clone_{random.randint(100, 999)}"
        clone_data = dict(src)
        clone_data["instanceId"] = new_id
        clone_data["vmName"] = f"{src.get('vmName', 'Android')} (Clone)"
        clone_data["phonePropIMEI"] = generate_luhn_imei()
        clone_data["status"] = "stopped"
        clone_data["adbPort"] = random.randint(28000, 32000)
        return self.save_instance(new_id, clone_data)

    def remove_instance(self, instance_id):
        inst_dir = os.path.join(INSTANCES_DIR, instance_id)
        if os.path.exists(inst_dir):
            shutil.rmtree(inst_dir)
            return True
        return False

// ============================================================================
// OrchDroid Settings Page Controller (OrchDroid Native Pro)
// ============================================================================

const urlParams = new URLSearchParams(window.location.search);
const instanceId = urlParams.get("id") || "default";
let currentInstanceData = null;
let currentTabName = "Device";
let saveTimeout = null;

const saveStatus = document.getElementById("saveStatus");

// 1. Fetch & Populate Instance Data
async function loadInstanceSettings() {
  try {
    const res = await fetch(`/api/instances/${instanceId}`);
    const data = await res.json();
    if (data.status === "success" && data.instance) {
      currentInstanceData = data.instance;
      populateForm(data.instance);
      updateWindowTitle();
    }
  } catch (err) {
    console.error("Failed to load instance settings:", err);
  }
}

function populateForm(cfg) {
  // Device
  document.getElementById("cfgDeviceName").value = cfg.vmName || "Android Device";
  document.getElementById("cfgBrand").value = cfg.phonePropBrand || "Samsung";
  document.getElementById("cfgModelName").value = cfg.phonePropModel || "Galaxy S23 Ultra";
  document.getElementById("cfgMiit").value = cfg.phonePropMiit || "SM-X910";
  document.getElementById("cfgPhoneNumber").value = cfg.phoneNumber || "";
  document.getElementById("cfgIMEI").value = cfg.phonePropIMEI || "868425047112024";
  document.getElementById("cfgGpuCustomName").value = cfg.gpuPropModel || "Adreno (TM) 720";
  document.getElementById("cfgRootAccess").checked = !!cfg.vmRootEnable;

  // Display
  document.getElementById("cfgWidth").value = cfg.framebufferWidth || 2304;
  document.getElementById("cfgHeight").value = cfg.framebufferHeight || 1440;
  document.getElementById("cfgDPI").value = cfg.framebufferDPI || 360;
  document.getElementById("cfgFpsCounter").checked = cfg.fpsShowEnable !== false;
  document.getElementById("cfgGfxEnhance").checked = cfg.renderQualityEnable !== false;

  // Performance
  if (cfg.vmCpuCount) document.getElementById("cfgCpuCores").value = String(cfg.vmCpuCount);
  if (cfg.vmMemoryOfMB) document.getElementById("cfgRamMB").value = String(cfg.vmMemoryOfMB);
  if (cfg.maxFpsLimit) document.getElementById("cfgMaxFps").value = String(cfg.maxFpsLimit);

  // Data
  document.getElementById("diskOccupiedLabel").textContent = `${cfg.diskOccupiedGB || '9.21'} GB`;
  document.getElementById("deviceStoragePath").textContent = cfg.deviceStorageDir || `/Volumes/LinuxFS/OrchDroid/instances/${instanceId}`;

  // Global
  document.getElementById("cfgDefaultAdb").checked = !!cfg.tryDefaultAdbPort;
  if (cfg.security) {
    document.getElementById("cfgPlayIntegrity").checked = !!cfg.security.playIntegrityFix;
    document.getElementById("cfgTrickyStore").checked = !!cfg.security.trickyStoreEnabled;
  }
}

// 2. Tab Switching & Title Sync
document.querySelectorAll(".tabs-list .tab-item").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".tabs-list .tab-item").forEach(b => b.classList.remove("active"));
    document.querySelectorAll(".tabs-content .tab-pane").forEach(p => p.classList.remove("active"));

    btn.classList.add("active");
    const targetTab = btn.getAttribute("data-tab");
    currentTabName = btn.getAttribute("data-title") || "Device";

    const pane = document.getElementById(`pane-${targetTab}`);
    if (pane) pane.classList.add("active");

    updateWindowTitle();
  });
});

function updateWindowTitle() {
  const devName = (currentInstanceData && currentInstanceData.vmName) || document.getElementById("cfgDeviceName").value || "Android Device";
  const titleText = `"${devName}" - ${currentTabName}`;
  document.title = titleText;

  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hostApp) {
    window.webkit.messageHandlers.hostApp.postMessage({
      action: "updateSettingsTitle",
      title: titleText
    });
  }
}

// 3. Auto-save on Input with Debounce
function triggerAutoSave() {
  clearTimeout(saveTimeout);
  saveTimeout = setTimeout(saveSettings, 350);
}

async function saveSettings() {
  if (!currentInstanceData) return;

  currentInstanceData.vmName = document.getElementById("cfgDeviceName").value;
  currentInstanceData.phonePropBrand = document.getElementById("cfgBrand").value;
  currentInstanceData.phonePropModel = document.getElementById("cfgModelName").value;
  currentInstanceData.phonePropMiit = document.getElementById("cfgMiit").value;
  currentInstanceData.phoneNumber = document.getElementById("cfgPhoneNumber").value;
  currentInstanceData.phonePropIMEI = document.getElementById("cfgIMEI").value;
  currentInstanceData.gpuPropModel = document.getElementById("cfgGpuCustomName").value;
  currentInstanceData.vmRootEnable = document.getElementById("cfgRootAccess").checked;

  currentInstanceData.framebufferWidth = parseInt(document.getElementById("cfgWidth").value, 10);
  currentInstanceData.framebufferHeight = parseInt(document.getElementById("cfgHeight").value, 10);
  currentInstanceData.framebufferDPI = parseInt(document.getElementById("cfgDPI").value, 10);
  currentInstanceData.fpsShowEnable = document.getElementById("cfgFpsCounter").checked;
  currentInstanceData.renderQualityEnable = document.getElementById("cfgGfxEnhance").checked;

  currentInstanceData.vmCpuCount = parseInt(document.getElementById("cfgCpuCores").value, 10);
  currentInstanceData.vmMemoryOfMB = parseInt(document.getElementById("cfgRamMB").value, 10);
  currentInstanceData.maxFpsLimit = parseInt(document.getElementById("cfgMaxFps").value, 10);
  currentInstanceData.tryDefaultAdbPort = document.getElementById("cfgDefaultAdb").checked;

  currentInstanceData.security = {
    playIntegrityFix: document.getElementById("cfgPlayIntegrity").checked,
    trickyStoreEnabled: document.getElementById("cfgTrickyStore").checked,
    hideQemuPipes: true,
    hideProcCmdline: true
  };

  try {
    const res = await fetch(`/api/instances/${instanceId}`, {
      method: "PUT",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(currentInstanceData)
    });
    const data = await res.json();
    if (data.status === "success") {
      saveStatus.classList.add("show");
      setTimeout(() => saveStatus.classList.remove("show"), 1200);
      updateWindowTitle();
    }
  } catch (err) {
    console.error("Failed to auto-save settings:", err);
  }
}

// Bind Auto-Save to All Form Inputs
document.querySelectorAll(".settings-container input, .settings-container select").forEach((el) => {
  el.addEventListener("input", triggerAutoSave);
  el.addEventListener("change", triggerAutoSave);
});

// 4. Random IMEI Generator Button
document.getElementById("btnRandomIMEI").addEventListener("click", async () => {
  try {
    const res = await fetch("/api/random_imei");
    const data = await res.json();
    if (data.status === "success" && data.imei) {
      document.getElementById("cfgIMEI").value = data.imei;
      triggerAutoSave();
    }
  } catch (err) {
    console.error("Error generating IMEI:", err);
  }
});

// 5. GPU Preset Change Handler
document.getElementById("cfgGpuPreset").addEventListener("change", (e) => {
  const customInput = document.getElementById("cfgGpuCustomName");
  if (e.target.value === "custom") {
    customInput.value = "";
    customInput.focus();
  } else {
    customInput.value = e.target.options[e.target.selectedIndex].text;
  }
  triggerAutoSave();
});

// 6. Clean Disk Space Button
document.getElementById("btnCleanDisk").addEventListener("click", async () => {
  try {
    const res = await fetch(`/api/instances/${instanceId}/clean_disk`, { method: "POST" });
    const data = await res.json();
    if (data.status === "success") {
      document.getElementById("diskOccupiedLabel").textContent = `${data.diskOccupiedGB} GB`;
      saveStatus.classList.add("show");
      setTimeout(() => saveStatus.classList.remove("show"), 1200);
    }
  } catch (err) {
    console.error("Error cleaning disk:", err);
  }
});

// Initial Load
loadInstanceSettings();

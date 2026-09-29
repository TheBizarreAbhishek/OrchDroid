// ============================================================================
// OrchDroid Manager - OrchDroid Native Engine
// ============================================================================

const API_BASE = "";
let currentInstances = [];

// DOM References
const instancesList = document.getElementById("instancesList");
const newInstanceMenu = document.getElementById("newInstanceMenu");
const toastMessage = document.getElementById("toastMessage");

// Toast Notification
function showToast(msg) {
  toastMessage.textContent = msg;
  toastMessage.classList.add("show");
  setTimeout(() => toastMessage.classList.remove("show"), 2200);
}

// Window Resizing through Cocoa Native Host
function resizeWindow(width, height) {
  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hostApp) {
    window.webkit.messageHandlers.hostApp.postMessage({
      action: "resize",
      width: width,
      height: height
    });
  }
}

let lastRenderedStateKey = "";
let lastInstanceCount = -1;
let userManuallyResized = false;

window.addEventListener("resize", () => {
  // If user dragged to resize or expand, preserve their chosen window size
  userManuallyResized = true;
});

// ============================================================================
// Instance Management & Polling
// ============================================================================
async function loadInstances() {
  try {
    const res = await fetch(`${API_BASE}/api/instances`);
    const data = await res.json();
    if (data.status === "success") {
      currentInstances = data.instances;

      // Only auto-resize on initial load or when instance count changes AND user has not manually resized
      const n = data.instances.length;
      if (lastInstanceCount === -1 || (!userManuallyResized && lastInstanceCount !== n)) {
        lastInstanceCount = n;
        const calculatedHeight = 44 + 32 + (n * 134) + (Math.max(0, n - 1) * 14) + 6;
        resizeWindow(640, Math.max(220, calculatedHeight));
      }

      // 1. DO NOT re-render if user currently has the dropdown menu open (prevents disappearing after 3-4s!)
      if (document.querySelector(".dropdown-menu.show")) {
        return;
      }

      // 2. Only re-render if instances state actually changed
      const stateKey = JSON.stringify(data.instances.map(i => ({ id: i.instanceId, s: i.status, n: i.vmName, cpu: i.vmCpuCount, ram: i.vmMemoryOfMB })));
      if (stateKey === lastRenderedStateKey) {
        return;
      }
      lastRenderedStateKey = stateKey;

      renderInstances(data.instances);
    }
  } catch (err) {
    console.error("Failed to load instances:", err);
  }
}

function renderInstances(instances) {
  instancesList.innerHTML = "";
  if (!instances || instances.length === 0) {
    instancesList.innerHTML = `
      <div style="display:flex; flex-direction:column; align-items:center; justify-content:center; padding:32px 16px; color:#8e8e93; text-align:center;">
        <svg width="36" height="36" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" style="margin-bottom:10px; opacity:0.6;">
          <rect x="4" y="2" width="16" height="20" rx="2" ry="2"></rect>
          <line x1="12" y1="18" x2="12.01" y2="18"></line>
        </svg>
        <div style="font-size:14px; font-weight:600; color:#e5e5ea; margin-bottom:4px;">No Devices Available</div>
        <div style="font-size:12px; color:#71717a;">Click "+" in the header to create a new device</div>
      </div>
    `;
    return;
  }
  instances.forEach((inst) => {
    const isRunning = inst.status === "running";
    const card = document.createElement("div");
    card.className = "instance-card";

    const actionBtnIcon = isRunning
      ? `<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round">
           <path d="M18.36 6.64a9 9 0 1 1-12.73 0"></path>
           <line x1="12" y1="2" x2="12" y2="12"></line>
         </svg>`
      : `<svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
           <polygon points="6 3 20 12 6 21 6 3"></polygon>
         </svg>`;

    card.innerHTML = `
      <div class="instance-left">
        <div class="tablet-frame ${isRunning ? 'running' : 'off'}">
          <img src="${isRunning ? 'thumb_default.png?t=' + Date.now() : 'thumb_off.png'}" class="tablet-screen" alt="Preview">
        </div>
        <div class="instance-meta">
          <div class="instance-title">${inst.vmName || 'Android Device'}</div>
          <div class="instance-specs-row">
            <span class="spec-tag">${inst.vmCpuCount || 4} vCPU</span>
            <span class="spec-tag">${Math.round((inst.vmMemoryOfMB || 12288) / 1024)} GB Unified RAM</span>
          </div>
          <div class="instance-sub-specs">
            ${inst.framebufferWidth || 2304} × ${inst.framebufferHeight || 1440} <span class="divider">|</span> ${inst.framebufferDPI || 360} DPI
          </div>
        </div>
      </div>
      <div class="instance-actions">
        <button class="orch-power-btn ${isRunning ? 'running' : 'stopped'}" data-id="${inst.instanceId}" title="${isRunning ? 'Shutdown Device' : 'Start Device'}">
          ${actionBtnIcon}
        </button>
        <div class="dropdown-wrapper">
          <button class="orch-more-btn" data-more="${inst.instanceId}" title="Options">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">
              <circle cx="12" cy="5" r="2"></circle>
              <circle cx="12" cy="12" r="2"></circle>
              <circle cx="12" cy="19" r="2"></circle>
            </svg>
          </button>
          <div class="dropdown-menu" id="menu-${inst.instanceId}">
            <div class="menu-item action-settings" data-id="${inst.instanceId}">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="3"></circle><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path></svg>
              Settings
            </div>
            <div class="menu-item action-clone" data-id="${inst.instanceId}">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
              Clone
            </div>
            <div class="menu-item action-remove" data-id="${inst.instanceId}" style="color: #ef4444;">
              <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></svg>
              Delete
            </div>
          </div>
        </div>
      </div>
    `;

    instancesList.appendChild(card);
  });
}

// Global click handler for instance menus & buttons
document.addEventListener("click", (e) => {
  // Toggle New Instance menu
  if (e.target.closest("#btnNewInstance")) {
    newInstanceMenu.classList.toggle("show");
    return;
  } else {
    newInstanceMenu.classList.remove("show");
  }

  // Toggle More Menu for instance
  const moreBtn = e.target.closest(".orch-more-btn");
  if (moreBtn) {
    const instId = moreBtn.getAttribute("data-more");
    document.querySelectorAll(".dropdown-menu").forEach(m => m.classList.remove("show"));
    const m = document.getElementById(`menu-${instId}`);
    if (m) {
      m.classList.toggle("show");
    }
    e.stopPropagation();
    return;
  } else {
    document.querySelectorAll(".dropdown-menu").forEach(m => m.classList.remove("show"));
  }

  // Power / Play / Stop button
  const powerBtn = e.target.closest(".orch-power-btn");
  if (powerBtn) {
    const instId = powerBtn.getAttribute("data-id");
    if (powerBtn.classList.contains("running")) {
      stopInstance(instId);
    } else {
      startInstance(instId);
    }
    return;
  }

  // Settings action -> OPENS DEDICATED SEPARATE SETTINGS WINDOW
  const settingsItem = e.target.closest(".action-settings");
  if (settingsItem) {
    const instId = settingsItem.getAttribute("data-id");
    openSettings(instId);
    return;
  }

  // Clone action
  const cloneItem = e.target.closest(".action-clone");
  if (cloneItem) {
    const instId = cloneItem.getAttribute("data-id");
    cloneInstance(instId);
    return;
  }

  // Remove action
  const removeItem = e.target.closest(".action-remove");
  if (removeItem) {
    const instId = removeItem.getAttribute("data-id");
    removeInstance(instId);
    return;
  }
});

// Dropdown item click for creating new instances
newInstanceMenu.addEventListener("click", async (e) => {
  const item = e.target.closest(".menu-item");
  if (!item) return;
  const devType = item.getAttribute("data-type");
  try {
    const res = await fetch(`${API_BASE}/api/instances`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        name: devType === "phone" ? "Android Phone" : "Android Device",
        device_type: devType
      })
    });
    const data = await res.json();
    if (data.status === "success") {
      showToast(`Created new ${devType} instance!`);
      loadInstances();
    }
  } catch (err) {
    showToast("Failed to create instance");
  }
});

// ============================================================================
// Start / Stop / Clone / Remove Instance
// ============================================================================
async function startInstance(instanceId) {
  showToast("Starting Android VM...");
  try {
    const res = await fetch(`${API_BASE}/api/instances/${instanceId}/start`, { method: "POST" });
    const data = await res.json();
    if (data.status === "success") {
      showToast("Android device launched!");
      loadInstances();
    }
  } catch (err) {
    showToast("Error starting instance");
  }
}

async function stopInstance(instanceId) {
  showToast("Shutting down VM...");
  try {
    const res = await fetch(`${API_BASE}/api/instances/${instanceId}/stop`, { method: "POST" });
    const data = await res.json();
    if (data.status === "success") {
      showToast("Device powered off");
      loadInstances();
    }
  } catch (err) {
    showToast("Error stopping instance");
  }
}

async function cloneInstance(instanceId) {
  showToast("Cloning instance...");
  try {
    const res = await fetch(`${API_BASE}/api/instances/${instanceId}/clone`, { method: "POST" });
    const data = await res.json();
    if (data.status === "success") {
      showToast("Instance cloned successfully!");
      loadInstances();
    }
  } catch (err) {
    showToast("Error cloning instance");
  }
}

// ============================================================================
// Custom Modal Delete Confirmation (No WKWebView confirm() block!)
// ============================================================================
let pendingDeleteId = null;
const deleteConfirmDialog = document.getElementById("deleteConfirmDialog");
const deleteConfirmText = document.getElementById("deleteConfirmText");
const btnCancelDelete = document.getElementById("btnCancelDelete");
const btnConfirmDelete = document.getElementById("btnConfirmDelete");

function removeInstance(instanceId) {
  document.querySelectorAll(".dropdown-menu").forEach(m => m.classList.remove("show"));
  pendingDeleteId = instanceId;
  const inst = currentInstances.find(i => i.instanceId === instanceId);
  const name = (inst && inst.vmName) || "Android Device";
  if (deleteConfirmText) {
    deleteConfirmText.textContent = `Are you sure you want to delete "${name}"? This will remove all associated VM files and configurations.`;
  }
  if (deleteConfirmDialog) {
    deleteConfirmDialog.classList.add("show");
  }
}

function closeDeleteDialog() {
  pendingDeleteId = null;
  if (deleteConfirmDialog) {
    deleteConfirmDialog.classList.remove("show");
  }
}

async function executeDelete() {
  if (!pendingDeleteId) return;
  const targetId = pendingDeleteId;
  closeDeleteDialog();
  showToast("Deleting device...");

  try {
    const res = await fetch(`${API_BASE}/api/instances/${targetId}`, { method: "DELETE" });
    const data = await res.json();
    if (data.status === "success") {
      showToast("Device deleted successfully");
      lastRenderedStateKey = ""; // force re-render
      loadInstances();
    } else {
      showToast("Failed to delete device");
    }
  } catch (err) {
    console.error("Delete error:", err);
    showToast("Error deleting device");
  }
}

if (btnCancelDelete) {
  btnCancelDelete.addEventListener("click", closeDeleteDialog);
}
if (btnConfirmDelete) {
  btnConfirmDelete.addEventListener("click", executeDelete);
}
if (deleteConfirmDialog) {
  deleteConfirmDialog.addEventListener("click", (e) => {
    if (e.target === deleteConfirmDialog) {
      closeDeleteDialog();
    }
  });
}

// ============================================================================
// Open Dedicated Settings Window (Separate Window Native OrchDroid)
// ============================================================================
function openSettings(instanceId) {
  document.querySelectorAll(".dropdown-menu").forEach(m => m.classList.remove("show"));
  const inst = currentInstances.find(i => i.instanceId === instanceId);
  const instName = (inst && inst.vmName) || "Android Device";

  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.hostApp) {
    window.webkit.messageHandlers.hostApp.postMessage({
      action: "openSettings",
      instanceId: instanceId,
      instanceName: instName
    });
  } else {
    // Regular Browser popup window fallback
    window.open(`/settings.html?id=${instanceId}`, "_blank", "width=620,height=550");
  }
}

window.openSettings = openSettings;
window.cloneInstance = cloneInstance;
window.removeInstance = removeInstance;

// Initial Load & Auto Poll Sync
loadInstances();
setInterval(loadInstances, 3000);

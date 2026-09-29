#!/usr/bin/env bash
set -e

BASE_DIR="/Volumes/LinuxFS/OrchDroid"
EMULATOR_BIN="$BASE_DIR/bin/emulator/emulator"
CONFIG_APPLY="$BASE_DIR/scripts/apply_config.py"

export ANDROID_SDK_ROOT="$BASE_DIR/sdk"
export ANDROID_HOME="$BASE_DIR/sdk"
export DYLD_INSERT_LIBRARIES="$BASE_DIR/dist/liborchdroid_ui.dylib"
export ANDROID_SERIAL="emulator-5554"

# OrchDroid Native Metal / Vulkan Engine Performance & Stability Flags
export MVK_ALLOW_METAL_EVENTS=1
export MVK_CONFIG_RESUME_LOST_DEVICE=1

# Clear any stale emulator locks automatically
rm -f "$HOME/.android/avd/OrchDroid_14.avd/"*.lock 2>/dev/null || true

# Load dynamic profile configuration
if [ -f "$CONFIG_APPLY" ]; then
    eval "$(python3 "$CONFIG_APPLY" --env)"
else
    export ORCH_CPU_CORES=4
    export ORCH_MEMORY_MB=8192
    export ORCH_BRAND="samsung"
    export ORCH_MODEL="SM-X910"
    export ORCH_PRODUCT="gts9u"
    export ORCH_MANUFACTURER="samsung"
    export ORCH_GPU_RENDERER="Adreno (TM) 740"
    export ORCH_PROFILE_NAME="Samsung Galaxy Tab S9 Ultra (120 FPS Gaming)"
fi

# OrchDroid Root: Uses 100% clean stock ramdisk (no Magisk bloat/files)
cp "$BASE_DIR/images/cooked/ramdisk_clean.img" "$BASE_DIR/images/cooked/ramdisk.img"
export ORCH_RAMDISK="$BASE_DIR/images/cooked/ramdisk_clean.img"

echo "========================================================="
echo "   ⚡ OrchDroid Pro: High-Performance Gaming Engine ⚡    "
echo "========================================================="
echo "• Profile:      $ORCH_PROFILE_NAME"
echo "• Device Model: $ORCH_MODEL ($ORCH_BRAND)"
echo "• GPU Renderer: $ORCH_GPU_RENDERER"
echo "• P-Cores:      $ORCH_CPU_CORES | RAM: ${ORCH_MEMORY_MB}MB"
echo "• Display:      ${ORCH_WIDTH:-2304}x${ORCH_HEIGHT:-1440} @ ${ORCH_DPI:-360} DPI"
echo "• UI Engine:    liborchdroid_ui.dylib (Direct Trackpad & Aim)"
echo "• Root Mode:    $( [ "${ORCH_ROOT_ENABLED:-0}" = "1" ] && echo "ENABLED (OrchDroid Native su)" || echo "DISABLED (Pure Certified)" )"
echo "========================================================="

# Apply runtime system optimizations upon boot completion
(
  "$BASE_DIR/sdk/platform-tools/adb" -s "$ANDROID_SERIAL" wait-for-device
  while [ "$("$BASE_DIR/sdk/platform-tools/adb" -s "$ANDROID_SERIAL" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
    sleep 1
  done

  "$BASE_DIR/sdk/platform-tools/adb" -s "$ANDROID_SERIAL" shell "
    # OrchDroid Instant Response (0ms animation delay)
    settings put global window_animation_scale 0
    settings put global transition_animation_scale 0
    settings put global animator_duration_scale 0
    settings put global disable_window_blurs 1
    settings put system peak_refresh_rate 120
    settings put system min_refresh_rate 120
    settings put secure refresh_rate_mode 2
    settings put system pointer_speed 3
    settings put global device_name '$ORCH_MODEL'
    settings put system bluetooth_name '$ORCH_MODEL'
    settings put secure show_ime_with_hard_keyboard 0
    settings put global policy_control immersive.navigation=*
    settings delete global angle_gl_driver_selection_pkgs 2>/dev/null || true
    settings delete global angle_gl_driver_selection_values 2>/dev/null || true

    # OrchDroid Low Latency Direct Touch & Smooth Input
    settings put system pointer_speed 0
    settings put secure show_touches 0
    device_config put input_native_boot touch_slop 1 2>/dev/null || true
    setprop debug.sf.early.app.duration "" 2>/dev/null || true
    setprop debug.sf.early.sf.duration "" 2>/dev/null || true
    setprop debug.sf.earlyGl.app.duration "" 2>/dev/null || true
    setprop debug.sf.earlyGl.sf.duration "" 2>/dev/null || true

    # OrchDroid Dynamic Host Storage Auto-Expansion
    /system/bin/resize2fs /dev/block/mapper/userdata 2>/dev/null || /system/bin/resize2fs /dev/block/by-name/userdata 2>/dev/null || true
  "

  # Inject dynamic model and GPU props into runtime
  "$BASE_DIR/sdk/platform-tools/adb" -s "$ANDROID_SERIAL" shell "
    setprop debug.hwui.renderer skiagl
    setprop ro.product.model '$ORCH_MODEL'
    setprop ro.product.brand '$ORCH_BRAND'
    setprop ro.product.manufacturer '$ORCH_MANUFACTURER'
    setprop ro.product.device '$ORCH_PRODUCT'
    setprop ro.build.product '$ORCH_PRODUCT'
    setprop persist.sys.gpu.renderer '$ORCH_GPU_RENDERER'
  " 2>/dev/null || true

  # OrchDroid Root Switch Toggle
  if [ "${ORCH_ROOT_ENABLED:-0}" = "1" ]; then
    echo "⚡ [OrchDroid Root] Switch: ENABLED (Native SU Active)"
    "$BASE_DIR/sdk/platform-tools/adb" -s "$ANDROID_SERIAL" shell "
      setprop debug.orch_root 1
    " 2>/dev/null || true
  else
    echo "🛡️ [OrchDroid Root] Switch: DISABLED (Pure Certified Anti-Cheat Safe)"
    "$BASE_DIR/sdk/platform-tools/adb" -s "$ANDROID_SERIAL" shell "
      setprop debug.orch_root 0
    " 2>/dev/null || true
  fi

  # Dismiss keyguard / lockscreen to show home screen
  "$BASE_DIR/sdk/platform-tools/adb" -s "$ANDROID_SERIAL" shell "input keyevent 82; input keyevent 3" 2>/dev/null || true

  echo "🚀 OrchDroid Pro: 120Hz Zero-Lag Pipeline & $ORCH_MODEL Profile Active!"
) &

exec "$EMULATOR_BIN" \
  -avd OrchDroid_14 \
  -ramdisk "$ORCH_RAMDISK" \
  -gpu host \
  -cores "$ORCH_CPU_CORES" \
  -memory "$ORCH_MEMORY_MB" \
  -no-skin \
  -no-snapshot-load \
  -ports 5554,5555 \
  -android-serialno R52W30E09LA \
  -shell-serial tcp::4444,server,nowait \
  -prop qemu.hw.mainkeys=1 \
  -no-metrics \
  -feature Vulkan,-VulkanNativeSwapchain \
  -append-userspace-opt androidboot.verifiedbootstate=green \
  -append-userspace-opt androidboot.flash.locked=1 \
  -append-userspace-opt androidboot.vbmeta.device_state=locked \
  -append-userspace-opt androidboot.veritymode=enforcing \
  $ORCH_SIM_FLAG






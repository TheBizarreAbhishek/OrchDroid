#!/usr/bin/env bash
set -e

cd "$(dirname "$0")"

PORT=8088
echo "=========================================================="
echo "    🚀 Starting OrchDroid Pro (Apple Silicon Native)      "
echo "=========================================================="
echo "• Virtualization: QEMU HVF (ARM64 Native)"
echo "• Graphics: MoltenVK Metal Bridge (Adreno 750)"
echo "• Storage: Copy-On-Write (userdata.qcow2)"
echo "• Anti-Detection: TEE Attestation & Keybox Support"
echo "----------------------------------------------------------"
echo "Dashboard running at: http://localhost:$PORT"
echo "=========================================================="

python3 server.py

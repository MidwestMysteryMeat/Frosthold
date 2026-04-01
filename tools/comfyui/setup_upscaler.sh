#!/bin/bash
# Setup script for ComfyUI upscaler models and custom nodes
# Run from anywhere — paths are absolute

COMFYUI_DIR="F:/ComfyUI"
MODELS_DIR="$COMFYUI_DIR/models/upscale_models"
CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"

echo "=== ComfyUI Upscaler Setup ==="

# --- Download upscaler models ---
echo ""
echo "[1/3] Downloading upscaler models to $MODELS_DIR ..."

# 4x-UltraSharp (67MB) — best general-purpose upscaler, sharp detail
if [ ! -f "$MODELS_DIR/4x-UltraSharp.pth" ]; then
    echo "  Downloading 4x-UltraSharp.pth ..."
    curl -L -o "$MODELS_DIR/4x-UltraSharp.pth" \
        "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-UltraSharp.pth"
else
    echo "  4x-UltraSharp.pth already exists, skipping."
fi

# RealESRGAN_x4plus (64MB) — robust general-purpose, handles noisy inputs well
if [ ! -f "$MODELS_DIR/RealESRGAN_x4plus.pth" ]; then
    echo "  Downloading RealESRGAN_x4plus.pth ..."
    curl -L -o "$MODELS_DIR/RealESRGAN_x4plus.pth" \
        "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/RealESRGAN_x4plus.pth"
else
    echo "  RealESRGAN_x4plus.pth already exists, skipping."
fi

# 4x-AnimeSharp (64MB) — optimized for anime/illustration/pixel art
if [ ! -f "$MODELS_DIR/4x-AnimeSharp.pth" ]; then
    echo "  Downloading 4x-AnimeSharp.pth ..."
    curl -L -o "$MODELS_DIR/4x-AnimeSharp.pth" \
        "https://huggingface.co/uwg/upscaler/resolve/main/ESRGAN/4x-AnimeSharp.pth"
else
    echo "  4x-AnimeSharp.pth already exists, skipping."
fi

# --- Install Ultimate SD Upscale custom node ---
echo ""
echo "[2/3] Installing Ultimate SD Upscale custom node ..."

if [ ! -d "$CUSTOM_NODES_DIR/ComfyUI_UltimateSDUpscale" ]; then
    cd "$CUSTOM_NODES_DIR"
    git clone https://github.com/ssitu/ComfyUI_UltimateSDUpscale --recursive
    echo "  Installed."
else
    echo "  Already installed, skipping."
fi

# --- Verify ---
echo ""
echo "[3/3] Verifying installation ..."
echo ""
echo "Upscale models:"
ls -lh "$MODELS_DIR"/*.pth 2>/dev/null || echo "  (none found)"
echo ""
echo "Custom nodes:"
ls -d "$CUSTOM_NODES_DIR"/ComfyUI_UltimateSDUpscale 2>/dev/null && echo "  UltimateSDUpscale: OK" || echo "  UltimateSDUpscale: MISSING"

echo ""
echo "=== Setup complete. Restart ComfyUI to load new nodes. ==="

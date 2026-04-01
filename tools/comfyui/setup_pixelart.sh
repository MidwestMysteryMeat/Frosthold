#!/bin/bash
# setup_pixelart.sh — Download pixel art models for Frosthold sprite generation
# Run once to set up ComfyUI for pixel art batch generation.

COMFYUI_DIR="F:/ComfyUI"
MODELS_DIR="$COMFYUI_DIR/models"
CUSTOM_NODES="$COMFYUI_DIR/custom_nodes"

echo "=== Frosthold Pixel Art Pipeline Setup ==="
echo ""

# --- Checkpoint ---
# We already have dreamshaper_8 which works well with pixel art LoRAs.
# Optionally grab a dedicated pixel art checkpoint:
echo "[1/4] Checking checkpoints..."
if [ ! -f "$MODELS_DIR/checkpoints/pixelArtRDKL_v10.safetensors" ]; then
    echo "  Downloading PixelArt RDKL v1.0 (SD1.5 pixel art checkpoint)..."
    echo "  >>> Manual download needed from CivitAI:"
    echo "      https://civitai.com/models/120096/pixel-art-rdkl"
    echo "      Save to: $MODELS_DIR/checkpoints/pixelArtRDKL_v10.safetensors"
    echo ""
    echo "  Alternative: Use dreamshaper_8 (already installed) + LoRA below."
else
    echo "  pixelArtRDKL_v10 already present."
fi

# --- LoRA ---
echo "[2/4] Checking LoRAs..."
if [ ! -f "$MODELS_DIR/loras/pixel-art-style.safetensors" ]; then
    echo "  Downloading Pixel Art Style LoRA..."
    echo "  >>> Manual download from CivitAI:"
    echo "      https://civitai.com/models/120096  (LoRA version)"
    echo "      OR search 'pixel art xl lora' on civitai"
    echo "      Save to: $MODELS_DIR/loras/pixel-art-style.safetensors"
    echo ""
    echo "  Alternative free LoRA (HuggingFace):"
    echo "      https://huggingface.co/nerijs/pixel-art-xl"
    echo "      Save to: $MODELS_DIR/loras/pixel-art-style.safetensors"
else
    echo "  pixel-art-style LoRA already present."
fi

# --- ControlNet (for variant generation from existing sprites) ---
echo "[3/4] Checking ControlNet models..."
if [ ! -f "$MODELS_DIR/controlnet/control_v11p_sd15_canny.pth" ]; then
    echo "  Downloading SD1.5 Canny ControlNet..."
    echo "  >>> Download from HuggingFace:"
    echo "      https://huggingface.co/lllyasviel/ControlNet-v1-1/resolve/main/control_v11p_sd15_canny.pth"
    echo "      Save to: $MODELS_DIR/controlnet/control_v11p_sd15_canny.pth"
else
    echo "  Canny ControlNet already present."
fi

# --- Custom nodes ---
echo "[4/4] Checking custom nodes..."
if [ ! -d "$CUSTOM_NODES/ComfyUI-Manager" ]; then
    echo "  Installing ComfyUI-Manager (makes installing other nodes easy)..."
    cd "$CUSTOM_NODES"
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git 2>/dev/null || echo "  (git clone failed — install manually)"
else
    echo "  ComfyUI-Manager already present."
fi

echo ""
echo "=== Setup Summary ==="
echo "Required for batch generation:"
echo "  [$(test -f "$MODELS_DIR/checkpoints/dreamshaper_8.safetensors" && echo 'X' || echo ' ')] dreamshaper_8.safetensors (checkpoint)"
echo "  [ ] pixel-art-style.safetensors (LoRA — STRONGLY recommended)"
echo ""
echo "Optional (for variant generation from existing sprites):"
echo "  [$(test -f "$MODELS_DIR/controlnet/control_v11p_sd15_canny.pth" && echo 'X' || echo ' ')] control_v11p_sd15_canny.pth (ControlNet)"
echo ""
echo "The batch generator works WITHOUT the LoRA (uses prompt engineering only)"
echo "but results are much better WITH a pixel art LoRA."
echo ""
echo "Once models are in place, run:"
echo "  python tools/comfyui/batch_generate.py --list all --output ./gen_sprites"

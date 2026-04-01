"""
Batch upscale/refine images through ComfyUI API.

Usage:
    python batch_upscale.py --input ./sprites --output ./upscaled
    python batch_upscale.py --input ./sprites --output ./refined --workflow refine
    python batch_upscale.py --input ./sprites --output ./upscaled --model 4x-AnimeSharp.pth
    python batch_upscale.py --input ./sprites --output ./upscaled --denoise 0.4

Requires ComfyUI running at localhost:8188 (default).
"""

import argparse
import json
import os
import shutil
import sys
import time
import urllib.request
import urllib.error
import uuid
import websocket  # pip install websocket-client

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
COMFYUI_INPUT_DIR = "F:/ComfyUI/input"
COMFYUI_OUTPUT_DIR = "F:/ComfyUI/output"
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".webp", ".tiff"}


def load_workflow(name: str) -> dict:
    """Load a workflow JSON from this script's directory."""
    path = os.path.join(SCRIPT_DIR, f"workflow_upscale_{name}.json")
    if not os.path.exists(path):
        print(f"Error: workflow not found at {path}")
        sys.exit(1)
    with open(path, "r") as f:
        return json.load(f)


def queue_prompt(workflow: dict, server: str = "127.0.0.1:8188", client_id: str = "") -> str:
    """Send a workflow to ComfyUI and return the prompt_id."""
    payload = json.dumps({"prompt": workflow, "client_id": client_id}).encode("utf-8")
    req = urllib.request.Request(
        f"http://{server}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    return result["prompt_id"]


def wait_for_completion(ws, prompt_id: str) -> dict:
    """Listen on WebSocket until the prompt finishes. Returns output info."""
    while True:
        msg = ws.recv()
        if isinstance(msg, str):
            data = json.loads(msg)
            if data.get("type") == "executing":
                exec_data = data.get("data", {})
                if exec_data.get("prompt_id") == prompt_id and exec_data.get("node") is None:
                    # Execution finished
                    break
            elif data.get("type") == "execution_error":
                exec_data = data.get("data", {})
                if exec_data.get("prompt_id") == prompt_id:
                    print(f"  ERROR: {exec_data.get('exception_message', 'unknown error')}")
                    return {}
    # Fetch history to get output filenames
    resp = urllib.request.urlopen(f"http://127.0.0.1:8188/history/{prompt_id}")
    history = json.loads(resp.read())
    return history.get(prompt_id, {}).get("outputs", {})


def get_output_images(outputs: dict) -> list:
    """Extract output image filenames from ComfyUI history output."""
    images = []
    for node_id, node_output in outputs.items():
        if "images" in node_output:
            for img in node_output["images"]:
                images.append(img["filename"])
    return images


def copy_to_comfyui_input(src_path: str) -> str:
    """Copy a source image into ComfyUI's input directory, return the filename."""
    filename = os.path.basename(src_path)
    dest = os.path.join(COMFYUI_INPUT_DIR, filename)
    shutil.copy2(src_path, dest)
    return filename


def collect_output(filenames: list, dest_dir: str, original_name: str):
    """Move generated images from ComfyUI output to our destination."""
    os.makedirs(dest_dir, exist_ok=True)
    stem = os.path.splitext(original_name)[0]
    for i, fname in enumerate(filenames):
        src = os.path.join(COMFYUI_OUTPUT_DIR, fname)
        if os.path.exists(src):
            ext = os.path.splitext(fname)[1]
            suffix = f"_{i}" if len(filenames) > 1 else ""
            dest = os.path.join(dest_dir, f"{stem}{suffix}{ext}")
            shutil.move(src, dest)


def main():
    parser = argparse.ArgumentParser(description="Batch upscale images via ComfyUI")
    parser.add_argument("--input", required=True, help="Input directory of images")
    parser.add_argument("--output", required=True, help="Output directory for results")
    parser.add_argument(
        "--workflow", default="fast", choices=["fast", "refine"],
        help="'fast' = ESRGAN only, 'refine' = ESRGAN + img2img refinement pass (default: fast)"
    )
    parser.add_argument(
        "--model", default="4x-UltraSharp.pth",
        help="Upscaler model filename (default: 4x-UltraSharp.pth)"
    )
    parser.add_argument(
        "--checkpoint", default="dreamshaper_8.safetensors",
        help="SD checkpoint for refine workflow (default: dreamshaper_8.safetensors)"
    )
    parser.add_argument(
        "--denoise", type=float, default=0.30,
        help="Denoise strength for refine workflow, 0.0-1.0 (default: 0.30)"
    )
    parser.add_argument(
        "--positive", default="masterpiece, best quality, highly detailed, sharp focus, clean lines",
        help="Positive prompt for refine workflow"
    )
    parser.add_argument(
        "--negative",
        default="blurry, low quality, artifacts, noise, jpeg compression, watermark",
        help="Negative prompt for refine workflow"
    )
    parser.add_argument("--server", default="127.0.0.1:8188", help="ComfyUI server address")
    args = parser.parse_args()

    # Validate input dir
    if not os.path.isdir(args.input):
        print(f"Error: input directory not found: {args.input}")
        sys.exit(1)

    # Gather images
    images = sorted([
        f for f in os.listdir(args.input)
        if os.path.splitext(f)[1].lower() in IMAGE_EXTENSIONS
    ])
    if not images:
        print(f"No images found in {args.input}")
        sys.exit(0)

    print(f"Found {len(images)} images in {args.input}")
    print(f"Workflow: {args.workflow} | Model: {args.model} | Server: {args.server}")
    if args.workflow == "refine":
        print(f"Checkpoint: {args.checkpoint} | Denoise: {args.denoise}")
    print()

    # Load and configure workflow template
    workflow = load_workflow(args.workflow)

    # Set upscaler model
    workflow["2"]["inputs"]["model_name"] = args.model

    # Configure refine-specific settings
    if args.workflow == "refine":
        workflow["4"]["inputs"]["ckpt_name"] = args.checkpoint
        workflow["6"]["inputs"]["text"] = args.positive
        workflow["7"]["inputs"]["text"] = args.negative
        workflow["8"]["inputs"]["denoise"] = args.denoise

    # Check ComfyUI is reachable
    try:
        urllib.request.urlopen(f"http://{args.server}/system_stats", timeout=5)
    except (urllib.error.URLError, OSError):
        print(f"Error: cannot reach ComfyUI at {args.server}")
        print("Make sure ComfyUI is running (python main.py --listen)")
        sys.exit(1)

    # Connect WebSocket
    client_id = str(uuid.uuid4())
    ws = websocket.WebSocket()
    ws.connect(f"ws://{args.server}/ws?clientId={client_id}")

    os.makedirs(args.output, exist_ok=True)
    success = 0
    failed = 0

    for i, img_name in enumerate(images, 1):
        src_path = os.path.join(args.input, img_name)
        print(f"[{i}/{len(images)}] {img_name} ...", end=" ", flush=True)

        # Copy image to ComfyUI input
        comfy_filename = copy_to_comfyui_input(src_path)

        # Patch workflow with this image
        workflow["1"]["inputs"]["image"] = comfy_filename

        # Unique prefix per image to avoid collisions
        save_node = "4" if args.workflow == "fast" else "10"
        workflow[save_node]["inputs"]["filename_prefix"] = f"batch_{uuid.uuid4().hex[:8]}"

        try:
            prompt_id = queue_prompt(workflow, args.server, client_id)
            outputs = wait_for_completion(ws, prompt_id)
            if outputs:
                out_files = get_output_images(outputs)
                collect_output(out_files, args.output, img_name)
                print(f"OK ({len(out_files)} output(s))")
                success += 1
            else:
                print("FAILED")
                failed += 1
        except Exception as e:
            print(f"ERROR: {e}")
            failed += 1

    ws.close()
    print(f"\nDone. {success} succeeded, {failed} failed.")
    print(f"Output: {os.path.abspath(args.output)}")


if __name__ == "__main__":
    main()

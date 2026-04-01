"""
batch_generate.py — Overnight batch sprite generation via ComfyUI.

Reads the art asset list, generates prompts, feeds them to ComfyUI,
saves full-res + downscaled versions. Designed to run unattended overnight.

Usage:
    # Generate ALL missing sprites
    python batch_generate.py --output ./gen_sprites

    # Generate only creatures
    python batch_generate.py --category creatures --output ./gen_sprites

    # Generate specific asset
    python batch_generate.py --id frost_titan --output ./gen_sprites

    # Generate 3 variants per asset (artist picks best)
    python batch_generate.py --variants 3 --output ./gen_sprites

    # Dry run — see what would be generated
    python batch_generate.py --dry-run

    # Resume after interruption (skips already-generated)
    python batch_generate.py --output ./gen_sprites --resume

Requires:
    - ComfyUI running at localhost:8188
    - pip install websocket-client Pillow
"""

import argparse
import json
import os
import random
import shutil
import sys
import time
import traceback
import urllib.error
import urllib.request
import uuid

try:
    import websocket
except ImportError:
    print("Error: pip install websocket-client")
    sys.exit(1)

try:
    from PIL import Image
except ImportError:
    print("Error: pip install Pillow")
    sys.exit(1)

# Add parent to path for sprite_prompts import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprite_prompts import build_asset_list

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
COMFYUI_OUTPUT_DIR = "F:/ComfyUI/output"

# ---------------------------------------------------------------------------
# ComfyUI API helpers
# ---------------------------------------------------------------------------

def check_comfyui(server):
    """Verify ComfyUI is reachable."""
    try:
        urllib.request.urlopen(f"http://{server}/system_stats", timeout=5)
        return True
    except (urllib.error.URLError, OSError):
        return False


def check_model_exists(server, model_name):
    """Check if a checkpoint model is available in ComfyUI."""
    try:
        resp = urllib.request.urlopen(f"http://{server}/object_info/CheckpointLoaderSimple", timeout=5)
        info = json.loads(resp.read())
        models = info.get("CheckpointLoaderSimple", {}).get("input", {}).get("required", {}).get("ckpt_name", [[]])[0]
        return model_name in models
    except Exception:
        return True  # assume it exists if we can't check


def load_workflow():
    """Load the pixel art generation workflow."""
    path = os.path.join(SCRIPT_DIR, "workflow_pixelart.json")
    with open(path, "r") as f:
        return json.load(f)


def check_lora_exists(server):
    """Check if pixel art LoRA is available."""
    # Preferred LoRA in priority order
    preferred = [
        "PixelArtRedmond15V-PixelArt-PIXARFK.safetensors",
    ]
    try:
        resp = urllib.request.urlopen(f"http://{server}/object_info/LoraLoader", timeout=5)
        info = json.loads(resp.read())
        loras = info.get("LoraLoader", {}).get("input", {}).get("required", {}).get("lora_name", [[]])[0]
        # Check preferred list first
        for pref in preferred:
            if pref in loras:
                return pref
        # Fallback: any lora with "pixel" in the name
        for lora in loras:
            if "pixel" in lora.lower():
                return lora
    except Exception:
        pass
    # Offline check — if we can't reach ComfyUI API, check the file directly
    lora_path = "F:/ComfyUI/models/loras/PixelArtRedmond15V-PixelArt-PIXARFK.safetensors"
    if os.path.isfile(lora_path):
        return "PixelArtRedmond15V-PixelArt-PIXARFK.safetensors"
    return None


def build_workflow(asset, base_workflow, checkpoint, lora_name=None, seed=None):
    """Configure workflow for a specific asset."""
    wf = json.loads(json.dumps(base_workflow))  # deep copy

    # Set checkpoint
    wf["1"]["inputs"]["ckpt_name"] = checkpoint

    # Set prompts
    wf["2"]["inputs"]["text"] = asset["positive"]
    wf["3"]["inputs"]["text"] = asset["negative"]

    # Set dimensions
    wf["4"]["inputs"]["width"] = asset["gen_width"]
    wf["4"]["inputs"]["height"] = asset["gen_height"]

    # Set seed
    wf["5"]["inputs"]["seed"] = seed if seed is not None else random.randint(0, 2**32 - 1)

    # Set output prefix
    prefix = f"frosthold_{asset['subdir']}_{asset['id']}"
    wf["7"]["inputs"]["filename_prefix"] = prefix

    # If LoRA available, inject LoRA loader between checkpoint and sampler
    if lora_name:
        # Insert LoRA loader node
        wf["10"] = {
            "class_type": "LoraLoader",
            "inputs": {
                "lora_name": lora_name,
                "strength_model": 0.75,
                "strength_clip": 0.75,
                "model": ["1", 0],
                "clip": ["1", 1]
            }
        }
        # Rewire: sampler uses LoRA model, CLIP encoders use LoRA clip
        wf["5"]["inputs"]["model"] = ["10", 0]
        wf["2"]["inputs"]["clip"] = ["10", 1]
        wf["3"]["inputs"]["clip"] = ["10", 1]

    return wf, prefix


def queue_prompt(workflow, server, client_id):
    """Send workflow to ComfyUI, return prompt_id."""
    payload = json.dumps({"prompt": workflow, "client_id": client_id}).encode("utf-8")
    req = urllib.request.Request(
        f"http://{server}/prompt",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    return result["prompt_id"]


def wait_for_completion(ws, prompt_id, timeout=120):
    """Wait for ComfyUI to finish a prompt. Returns output info or None."""
    start = time.time()
    ws.settimeout(timeout)
    try:
        while True:
            if time.time() - start > timeout:
                print("TIMEOUT", end="")
                return None
            msg = ws.recv()
            if isinstance(msg, str):
                data = json.loads(msg)
                if data.get("type") == "executing":
                    exec_data = data.get("data", {})
                    if exec_data.get("prompt_id") == prompt_id and exec_data.get("node") is None:
                        break
                elif data.get("type") == "execution_error":
                    exec_data = data.get("data", {})
                    if exec_data.get("prompt_id") == prompt_id:
                        print(f"GEN_ERROR({exec_data.get('exception_message', '?')[:40]})", end="")
                        return None
    except websocket.WebSocketTimeoutException:
        print("WS_TIMEOUT", end="")
        return None

    # Fetch output filenames from history
    try:
        resp = urllib.request.urlopen(f"http://{ws._url.split('//')[1].split('/')[0]}/history/{prompt_id}")
        history = json.loads(resp.read())
        return history.get(prompt_id, {}).get("outputs", {})
    except Exception:
        return None


def get_output_images(outputs):
    """Extract filenames from ComfyUI output."""
    images = []
    if not outputs:
        return images
    for node_id, node_output in outputs.items():
        if "images" in node_output:
            for img in node_output["images"]:
                images.append(img["filename"])
    return images


# ---------------------------------------------------------------------------
# Image post-processing
# ---------------------------------------------------------------------------

def downscale_nearest(src_path, dst_path, target_w, target_h):
    """Downscale image using nearest-neighbor (preserves pixel art look)."""
    img = Image.open(src_path)

    # Calculate scale to fit within target while maintaining aspect ratio
    scale_x = target_w / img.width
    scale_y = target_h / img.height
    scale = min(scale_x, scale_y)

    new_w = max(1, int(img.width * scale))
    new_h = max(1, int(img.height * scale))

    resized = img.resize((new_w, new_h), Image.NEAREST)
    resized.save(dst_path, "PNG")
    return new_w, new_h


def remove_background_simple(src_path, dst_path):
    """Simple background removal: flood-fill corners with transparency.

    This is a basic approach — the artist will refine. Works well enough
    for sprites generated with 'transparent background' in the prompt.
    """
    img = Image.open(src_path).convert("RGBA")
    pixels = img.load()
    w, h = img.size

    # Sample corner colors (likely background)
    corners = [
        pixels[0, 0], pixels[w-1, 0],
        pixels[0, h-1], pixels[w-1, h-1]
    ]

    # Find most common corner color
    from collections import Counter
    bg_color = Counter(corners).most_common(1)[0][0]

    # If background is very close to white or very uniform, do flood fill
    r, g, b, a = bg_color
    brightness = (r + g + b) / 3

    # Only auto-remove if background looks solid (all corners similar)
    if all(sum(abs(c[i] - bg_color[i]) for i in range(3)) < 30 for c in corners):
        tolerance = 35
        # Simple flood fill from all 4 corners
        from collections import deque
        visited = set()
        queue = deque([(0, 0), (w-1, 0), (0, h-1), (w-1, h-1)])

        while queue:
            x, y = queue.popleft()
            if (x, y) in visited:
                continue
            if x < 0 or x >= w or y < 0 or y >= h:
                continue
            px = pixels[x, y]
            diff = sum(abs(px[i] - bg_color[i]) for i in range(3))
            if diff > tolerance:
                continue
            visited.add((x, y))
            pixels[x, y] = (0, 0, 0, 0)  # transparent
            queue.extend([(x+1, y), (x-1, y), (x, y+1), (x, y-1)])

    img.save(dst_path, "PNG")


# ---------------------------------------------------------------------------
# Main batch loop
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Batch generate Frosthold sprites via ComfyUI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python batch_generate.py --output ./gen_sprites
  python batch_generate.py -c creatures --variants 3 --output ./gen_sprites
  python batch_generate.py --id frost_titan --output ./gen_sprites
  python batch_generate.py --dry-run
  python batch_generate.py --output ./gen_sprites --resume
        """
    )
    parser.add_argument("--output", "-o", default="./gen_sprites",
                        help="Output directory (default: ./gen_sprites)")
    parser.add_argument("--category", "-c",
                        help="Generate only this category (tiles, creatures, buildings, items, defense, weapons, crops, ui, colonists, raiders, clothing)")
    parser.add_argument("--id",
                        help="Generate only this specific asset ID")
    parser.add_argument("--variants", "-v", type=int, default=1,
                        help="Number of variants per asset (default: 1, recommend 2-3 for artist selection)")
    parser.add_argument("--checkpoint", default="dreamshaper_8.safetensors",
                        help="SD checkpoint to use (default: dreamshaper_8.safetensors)")
    parser.add_argument("--no-lora", action="store_true",
                        help="Don't use LoRA even if available")
    parser.add_argument("--no-downscale", action="store_true",
                        help="Skip downscaling step, keep full generation size")
    parser.add_argument("--no-bg-remove", action="store_true",
                        help="Skip background removal step")
    parser.add_argument("--include-existing", action="store_true",
                        help="Regenerate even if sprite already exists in assets/sprites/")
    parser.add_argument("--resume", action="store_true",
                        help="Skip assets that already have output in the output directory")
    parser.add_argument("--server", default="127.0.0.1:8188",
                        help="ComfyUI server address")
    parser.add_argument("--timeout", type=int, default=120,
                        help="Per-image generation timeout in seconds (default: 120)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Show what would be generated without actually generating")
    parser.add_argument("--seed", type=int, default=None,
                        help="Fixed seed for reproducibility (default: random)")
    args = parser.parse_args()

    # Build asset list
    cats = [args.category] if args.category else None
    skip_existing = not args.include_existing
    assets = build_asset_list(categories=cats, skip_existing=skip_existing)

    # Filter to specific ID if requested
    if args.id:
        assets = [a for a in assets if a["id"] == args.id]
        if not assets:
            # Try without skip_existing
            assets = build_asset_list(categories=cats, skip_existing=False)
            assets = [a for a in assets if a["id"] == args.id]
            if not assets:
                print(f"Asset '{args.id}' not found in art list.")
                sys.exit(1)

    if not assets:
        print("No assets to generate (all sprites already exist).")
        sys.exit(0)

    # Count totals
    total_images = len(assets) * args.variants
    print(f"=== Frosthold Sprite Generator ===")
    print(f"Assets: {len(assets)} | Variants: {args.variants} | Total images: {total_images}")
    print(f"Checkpoint: {args.checkpoint}")
    print(f"Output: {os.path.abspath(args.output)}")

    # Category breakdown
    cat_counts = {}
    for a in assets:
        cat_counts[a["category"]] = cat_counts.get(a["category"], 0) + 1
    for cat, n in sorted(cat_counts.items()):
        print(f"  {cat}: {n}")
    print()

    if args.dry_run:
        print("--- DRY RUN (no generation) ---\n")
        for a in assets:
            print(f"[{a['category']:<12}] {a['id']}")
            print(f"  -> {a['subdir']}/{a['id']}.png  ({a['gen_width']}x{a['gen_height']} -> {a['target_width']}x{a['target_height']})")
            print(f"  + {a['positive'][:100]}...")
            print(f"  - {a['negative'][:80]}...")
            print()
        print(f"Total: {len(assets)} assets × {args.variants} variants = {total_images} images")

        # Estimate time: ~8-15 sec per 512x512 on RTX 3070 Ti
        est_low = total_images * 8
        est_high = total_images * 15
        print(f"Estimated time: {est_low // 60}–{est_high // 60} minutes ({est_low // 3600}–{est_high // 3600} hours)")
        return

    # Check ComfyUI
    if not check_comfyui(args.server):
        print(f"Error: Cannot reach ComfyUI at {args.server}")
        print("Start ComfyUI first: cd F:/ComfyUI && python main.py --listen")
        sys.exit(1)

    # Check checkpoint
    if not check_model_exists(args.server, args.checkpoint):
        print(f"Warning: Checkpoint '{args.checkpoint}' might not be available")

    # Check for LoRA
    lora_name = None
    if not args.no_lora:
        lora_name = check_lora_exists(args.server)
        if lora_name:
            print(f"Using pixel art LoRA: {lora_name}")
        else:
            print("No pixel art LoRA found (proceeding with prompt-only approach)")

    # Load base workflow
    base_workflow = load_workflow()

    # Create output directories
    os.makedirs(args.output, exist_ok=True)
    fullres_dir = os.path.join(args.output, "fullres")
    scaled_dir = os.path.join(args.output, "scaled")
    os.makedirs(fullres_dir, exist_ok=True)
    os.makedirs(scaled_dir, exist_ok=True)

    # Create per-category subdirs
    for a in assets:
        os.makedirs(os.path.join(fullres_dir, a["subdir"]), exist_ok=True)
        os.makedirs(os.path.join(scaled_dir, a["subdir"]), exist_ok=True)

    # Connect WebSocket
    client_id = str(uuid.uuid4())
    ws = websocket.WebSocket()
    ws.connect(f"ws://{args.server}/ws?clientId={client_id}")
    # Store server for later use
    ws._url = f"ws://{args.server}/ws?clientId={client_id}"

    success = 0
    failed = 0
    skipped = 0
    start_time = time.time()

    # Write generation log
    log_path = os.path.join(args.output, "generation_log.txt")
    log_file = open(log_path, "a", encoding="utf-8")
    log_file.write(f"\n=== Generation run: {time.strftime('%Y-%m-%d %H:%M:%S')} ===\n")
    log_file.write(f"Assets: {len(assets)} | Variants: {args.variants} | Checkpoint: {args.checkpoint}\n")
    if lora_name:
        log_file.write(f"LoRA: {lora_name}\n")
    log_file.write("\n")

    try:
        for i, asset in enumerate(assets, 1):
            for v in range(args.variants):
                variant_suffix = f"_v{v+1}" if args.variants > 1 else ""
                out_name = f"{asset['id']}{variant_suffix}"

                # Resume check
                if args.resume:
                    fullres_path = os.path.join(fullres_dir, asset["subdir"], f"{out_name}.png")
                    if os.path.exists(fullres_path):
                        skipped += 1
                        continue

                # Progress
                elapsed = time.time() - start_time
                done_count = success + failed + skipped
                total = total_images
                if done_count > 0:
                    eta_sec = (elapsed / done_count) * (total - done_count)
                    eta_str = f"ETA {int(eta_sec // 3600)}h{int((eta_sec % 3600) // 60)}m"
                else:
                    eta_str = "calculating..."

                print(f"[{done_count + 1}/{total}] {asset['category']}/{out_name} ({eta_str}) ...", end=" ", flush=True)

                # Build and send workflow
                seed = args.seed + v if args.seed is not None else None
                wf, prefix = build_workflow(asset, base_workflow, args.checkpoint, lora_name, seed)

                try:
                    prompt_id = queue_prompt(wf, args.server, client_id)
                    outputs = wait_for_completion(ws, prompt_id, timeout=args.timeout)

                    if outputs:
                        out_files = get_output_images(outputs)
                        if out_files:
                            # Get the generated image from ComfyUI output
                            src = os.path.join(COMFYUI_OUTPUT_DIR, out_files[0])
                            if os.path.exists(src):
                                # Save full-res
                                fullres_path = os.path.join(fullres_dir, asset["subdir"], f"{out_name}.png")
                                shutil.copy2(src, fullres_path)

                                # Background removal (for non-tile sprites)
                                if asset["category"] != "tiles" and not args.no_bg_remove:
                                    remove_background_simple(fullres_path, fullres_path)

                                # Downscale
                                if not args.no_downscale:
                                    scaled_path = os.path.join(scaled_dir, asset["subdir"], f"{out_name}.png")
                                    w, h = downscale_nearest(
                                        fullres_path, scaled_path,
                                        asset["target_width"], asset["target_height"]
                                    )
                                    print(f"OK ({w}x{h})")
                                else:
                                    print("OK (full-res only)")

                                # Clean up ComfyUI output
                                os.remove(src)

                                success += 1
                                log_file.write(f"OK  {asset['subdir']}/{out_name}.png\n")
                            else:
                                print(f"MISSING_OUTPUT")
                                failed += 1
                                log_file.write(f"ERR {asset['subdir']}/{out_name}.png — output file missing\n")
                        else:
                            print("NO_OUTPUT")
                            failed += 1
                            log_file.write(f"ERR {asset['subdir']}/{out_name}.png — no output files\n")
                    else:
                        print("FAILED")
                        failed += 1
                        log_file.write(f"ERR {asset['subdir']}/{out_name}.png — generation failed\n")

                except Exception as e:
                    print(f"ERROR: {e}")
                    failed += 1
                    log_file.write(f"ERR {asset['subdir']}/{out_name}.png — {e}\n")
                    traceback.print_exc()

                    # Try to reconnect WebSocket if it died
                    try:
                        ws.close()
                    except Exception:
                        pass
                    try:
                        ws = websocket.WebSocket()
                        ws.connect(f"ws://{args.server}/ws?clientId={client_id}")
                        ws._url = f"ws://{args.server}/ws?clientId={client_id}"
                        print("  (WebSocket reconnected)")
                    except Exception:
                        print("  FATAL: Cannot reconnect to ComfyUI. Exiting.")
                        break

                log_file.flush()

    except KeyboardInterrupt:
        print("\n\nInterrupted! Use --resume to continue later.")

    finally:
        try:
            ws.close()
        except Exception:
            pass
        log_file.close()

    # Final report
    elapsed = time.time() - start_time
    print(f"\n=== Generation Complete ===")
    print(f"Success: {success} | Failed: {failed} | Skipped: {skipped}")
    print(f"Time: {int(elapsed // 3600)}h {int((elapsed % 3600) // 60)}m {int(elapsed % 60)}s")
    print(f"Full-res output: {os.path.abspath(fullres_dir)}")
    print(f"Scaled output:   {os.path.abspath(scaled_dir)}")
    print(f"Log: {os.path.abspath(log_path)}")

    if success > 0:
        print(f"\nNext steps:")
        print(f"  1. Review {scaled_dir}/ — these are game-ready sizes")
        print(f"  2. Artist cleans up in Aseprite/Photoshop")
        print(f"  3. Copy final sprites to assets/sprites/")
        if args.variants > 1:
            print(f"  4. Pick best variant per asset (_v1, _v2, _v3)")


if __name__ == "__main__":
    main()

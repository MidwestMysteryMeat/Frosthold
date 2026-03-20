"""
Frosthold v3 Generator — Live Viewer
Opens a browser at localhost:8090 showing generated content in real-time.
Usage: python gen_viewer.py [--delay 3] [--batch 1] [--port 8090]
"""
import http.server
import threading
import json
import time
import random
import argparse
import webbrowser
from pathlib import Path
from urllib.parse import urlparse, parse_qs

# Import generator
from gen_v3 import generate_piece, Context, WorldState, GENERATORS

# ============================================================
# VIEWER STATE
# ============================================================

class ViewerState:
    """Thread-safe store for generated pieces."""

    def __init__(self):
        self.pieces = []
        self.lock = threading.Lock()
        self.seq = 0
        self.start_time = time.time()
        self.type_counts = {}
        self.errors = 0

    def add_piece(self, content, label, gen_type):
        with self.lock:
            self.seq += 1
            self.type_counts[label] = self.type_counts.get(label, 0) + 1
            self.pieces.append({
                "seq": self.seq,
                "content": content,
                "label": label,
                "type": gen_type,
                "time": time.strftime("%H:%M:%S"),
            })

    def add_error(self, message):
        with self.lock:
            self.seq += 1
            self.errors += 1
            self.pieces.append({
                "seq": self.seq,
                "content": f"GENERATOR ERROR: {message}",
                "label": "Error",
                "type": "error",
                "time": time.strftime("%H:%M:%S"),
            })

    def get_since(self, since_seq):
        with self.lock:
            return [p for p in self.pieces if p["seq"] > since_seq]

    def get_stats(self):
        with self.lock:
            elapsed = time.time() - self.start_time
            rate = (self.seq / (elapsed / 60.0)) if elapsed > 60 else 0
            return {
                "total": self.seq,
                "errors": self.errors,
                "rate_per_min": round(rate, 1),
                "elapsed_s": round(elapsed),
                "type_counts": dict(self.type_counts),
            }


# ============================================================
# GENERATOR THREAD
# ============================================================

def generator_thread(state, delay, batch_size):
    """Background thread that continuously generates lore pieces."""
    ws = WorldState()
    ctx = Context(world_state=ws)
    gen_count = 0

    while True:
        try:
            for _ in range(batch_size):
                content, label, gen_type = generate_piece(ctx=ctx)

                if content is None:
                    state.add_error("Generator returned None — no generators registered")
                    continue

                state.add_piece(content, label, gen_type)
                ws.log_generation(gen_type, label)
                gen_count += 1

                # Periodic world state save & context refresh
                if gen_count % 50 == 0:
                    ws.save()
                    ctx = Context(world_state=ws)

        except Exception as e:
            state.add_error(str(e))

        time.sleep(delay)


# ============================================================
# HTML PAGE
# ============================================================

HTML_PAGE = r"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FROSTHOLD — Live Generator</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: #0a0a0a; color: #c0c0c0;
            font-family: 'Courier New', monospace;
            font-size: 14px; line-height: 1.6;
        }

        #header {
            position: fixed; top: 0; width: 100%; z-index: 100;
            background: #111; border-bottom: 1px solid #333;
            padding: 12px 20px;
            display: flex; justify-content: space-between; align-items: center;
            flex-wrap: wrap; gap: 8px;
        }
        #header h1 { color: #d4a017; font-size: 18px; letter-spacing: 2px; }
        #stats { color: #666; font-size: 12px; }
        #stats span { margin-left: 15px; }
        .stat-value { color: #888; }

        #controls {
            display: flex; gap: 10px; align-items: center;
        }
        #controls button {
            background: #222; color: #888; border: 1px solid #444;
            padding: 4px 12px; cursor: pointer; font-family: inherit;
            font-size: 12px;
        }
        #controls button:hover { border-color: #d4a017; color: #d4a017; }
        #controls button.active { border-color: #27ae60; color: #27ae60; }

        #filter-bar {
            position: fixed; top: 50px; width: 100%; z-index: 99;
            background: #0d0d0d; border-bottom: 1px solid #222;
            padding: 6px 20px;
            display: flex; gap: 8px; flex-wrap: wrap; align-items: center;
        }
        .filter-btn {
            background: #1a1a1a; color: #555; border: 1px solid #333;
            padding: 2px 10px; cursor: pointer; font-family: inherit;
            font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px;
        }
        .filter-btn:hover { color: #999; border-color: #555; }
        .filter-btn.active { color: #ccc; border-color: #666; }
        .filter-btn.npc.active { color: #d4a017; border-color: #d4a017; }
        .filter-btn.quest.active { color: #c0392b; border-color: #c0392b; }
        .filter-btn.datapad.active { color: #00bcd4; border-color: #00bcd4; }
        .filter-btn.robot.active { color: #27ae60; border-color: #27ae60; }
        .filter-btn.location.active { color: #2980b9; border-color: #2980b9; }
        .filter-btn.history.active { color: #7f8c8d; border-color: #7f8c8d; }
        .filter-btn.weapon.active { color: #e67e22; border-color: #e67e22; }
        .filter-btn.artifact.active { color: #9b59b6; border-color: #9b59b6; }
        .filter-btn.entity.active { color: #e74c3c; border-color: #e74c3c; }
        .filter-btn.vehicle.active { color: #1abc9c; border-color: #1abc9c; }
        .filter-btn.company.active { color: #f39c12; border-color: #f39c12; }
        .filter-btn.faction.active { color: #3498db; border-color: #3498db; }

        #content {
            margin-top: 90px; padding: 20px;
            max-width: 900px; margin-left: auto; margin-right: auto;
        }

        .piece {
            background: #111; border: 1px solid #222; border-left: 3px solid #444;
            margin-bottom: 16px; padding: 16px 20px;
            border-radius: 2px;
            animation: fadeIn 0.5s ease-in;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-10px); }
            to { opacity: 1; transform: translateY(0); }
        }

        .piece.npc { border-left-color: #d4a017; }
        .piece.quest { border-left-color: #c0392b; }
        .piece.datapad { border-left-color: #00bcd4; }
        .piece.robot { border-left-color: #27ae60; }
        .piece.location { border-left-color: #2980b9; }
        .piece.history { border-left-color: #7f8c8d; }
        .piece.weapon { border-left-color: #e67e22; }
        .piece.artifact { border-left-color: #9b59b6; }
        .piece.entity { border-left-color: #e74c3c; }
        .piece.vehicle { border-left-color: #1abc9c; }
        .piece.company { border-left-color: #f39c12; }
        .piece.faction { border-left-color: #3498db; }
        .piece.error { border-left-color: #ff0000; background: #1a0000; }

        .piece-header {
            display: flex; justify-content: space-between; align-items: center;
            margin-bottom: 10px; padding-bottom: 8px; border-bottom: 1px solid #222;
        }
        .piece-type {
            font-weight: bold; text-transform: uppercase;
            font-size: 11px; letter-spacing: 1px;
        }
        .piece.npc .piece-type { color: #d4a017; }
        .piece.quest .piece-type { color: #c0392b; }
        .piece.datapad .piece-type { color: #00bcd4; }
        .piece.robot .piece-type { color: #27ae60; }
        .piece.location .piece-type { color: #2980b9; }
        .piece.history .piece-type { color: #7f8c8d; }
        .piece.weapon .piece-type { color: #e67e22; }
        .piece.artifact .piece-type { color: #9b59b6; }
        .piece.entity .piece-type { color: #e74c3c; }
        .piece.vehicle .piece-type { color: #1abc9c; }
        .piece.company .piece-type { color: #f39c12; }
        .piece.faction .piece-type { color: #3498db; }
        .piece.error .piece-type { color: #ff4444; }

        .piece-meta { display: flex; gap: 12px; }
        .piece-time { color: #444; font-size: 11px; }
        .piece-seq { color: #333; font-size: 11px; }

        .piece-content { white-space: pre-wrap; word-wrap: break-word; }

        /* Markdown-like formatting */
        .md-h2 { color: #ddd; font-size: 15px; font-weight: bold; margin: 10px 0 6px 0; }
        .md-bold { color: #999; }
        .md-italic { color: #777; font-style: italic; }
        .md-hr { border: none; border-top: 1px solid #222; margin: 12px 0; }
        .md-quote { display: block; border-left: 2px solid #333; padding-left: 10px; color: #888; margin: 4px 0; }
        .md-li { display: block; padding-left: 14px; color: #aaa; }
        .md-li::before { content: "- "; color: #555; }

        #empty-state {
            text-align: center; color: #333; margin-top: 100px;
            font-size: 16px;
        }
        #empty-state .spinner {
            display: inline-block; width: 12px; height: 12px;
            border: 2px solid #333; border-top-color: #d4a017;
            border-radius: 50%; animation: spin 1s linear infinite;
            margin-right: 8px; vertical-align: middle;
        }
        @keyframes spin { to { transform: rotate(360deg); } }

        /* Scrollbar styling */
        ::-webkit-scrollbar { width: 8px; }
        ::-webkit-scrollbar-track { background: #0a0a0a; }
        ::-webkit-scrollbar-thumb { background: #333; border-radius: 4px; }
        ::-webkit-scrollbar-thumb:hover { background: #555; }

        /* Collapsed piece */
        .piece.collapsed .piece-content { display: none; }
        .piece-toggle {
            cursor: pointer; color: #444; font-size: 10px;
            margin-left: 8px; user-select: none;
        }
        .piece-toggle:hover { color: #888; }
    </style>
</head>
<body>
    <div id="header">
        <h1>FROSTHOLD &mdash; LIVE GENERATOR</h1>
        <div id="stats">
            <span>Total: <span class="stat-value" id="stat-total">0</span></span>
            <span>Rate: <span class="stat-value" id="stat-rate">0</span>/min</span>
            <span>Elapsed: <span class="stat-value" id="stat-elapsed">0:00</span></span>
        </div>
        <div id="controls">
            <button id="btn-scroll" class="active" onclick="toggleScroll()">AUTO-SCROLL</button>
            <button id="btn-pause" onclick="togglePause()">PAUSE</button>
            <button onclick="clearDisplay()">CLEAR</button>
        </div>
    </div>
    <div id="filter-bar">
        <span style="color:#444;font-size:11px;margin-right:4px;">FILTER:</span>
        <button class="filter-btn npc active" data-type="npc" onclick="toggleFilter(this)">NPC</button>
        <button class="filter-btn quest active" data-type="quest" onclick="toggleFilter(this)">QUEST</button>
        <button class="filter-btn datapad active" data-type="datapad" onclick="toggleFilter(this)">DATA PAD</button>
        <button class="filter-btn robot active" data-type="robot" onclick="toggleFilter(this)">ROBOT</button>
        <button class="filter-btn location active" data-type="location" onclick="toggleFilter(this)">LOCATION</button>
        <button class="filter-btn history active" data-type="history" onclick="toggleFilter(this)">HISTORY</button>
        <button class="filter-btn weapon active" data-type="weapon" onclick="toggleFilter(this)">WEAPON</button>
        <button class="filter-btn artifact active" data-type="artifact" onclick="toggleFilter(this)">ARTIFACT</button>
        <button class="filter-btn entity active" data-type="entity" onclick="toggleFilter(this)">ENTITY</button>
        <button class="filter-btn vehicle active" data-type="vehicle" onclick="toggleFilter(this)">VEHICLE</button>
        <button class="filter-btn company active" data-type="company" onclick="toggleFilter(this)">COMPANY</button>
        <button class="filter-btn faction active" data-type="faction" onclick="toggleFilter(this)">FACTION</button>
    </div>
    <div id="content">
        <div id="empty-state"><span class="spinner"></span> Initializing generator...</div>
    </div>

    <script>
        let autoScroll = true;
        let paused = false;
        let lastSeq = 0;
        let pieceCount = 0;
        let startTime = Date.now();
        let typeCounts = {};
        let activeFilters = new Set([
            'npc','quest','datapad','robot','location','history',
            'weapon','artifact','entity','vehicle','company','faction','error'
        ]);

        function toggleScroll() {
            autoScroll = !autoScroll;
            document.getElementById('btn-scroll').classList.toggle('active');
        }

        function togglePause() {
            paused = !paused;
            const btn = document.getElementById('btn-pause');
            btn.classList.toggle('active');
            btn.textContent = paused ? 'RESUME' : 'PAUSE';
        }

        function clearDisplay() {
            document.getElementById('content').innerHTML = '';
        }

        function toggleFilter(btn) {
            const t = btn.dataset.type;
            btn.classList.toggle('active');
            if (activeFilters.has(t)) {
                activeFilters.delete(t);
            } else {
                activeFilters.add(t);
            }
            // Show/hide existing pieces
            document.querySelectorAll('.piece').forEach(el => {
                const cls = el.dataset.gentype;
                el.style.display = activeFilters.has(cls) ? '' : 'none';
            });
        }

        function typeClass(label) {
            const map = {
                'NPC': 'npc', 'Quest': 'quest', 'Data Pad': 'datapad',
                'Robot/AI': 'robot', 'Location': 'location', 'History Event': 'history',
                'Weapon': 'weapon', 'Artifact': 'artifact', 'Entity': 'entity',
                'Vehicle': 'vehicle', 'Company': 'company', 'Faction': 'faction',
                'Error': 'error',
            };
            return map[label] || 'history';
        }

        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }

        function formatContent(text) {
            let escaped = escapeHtml(text);
            return escaped
                .replace(/^## (.+)$/gm, '<div class="md-h2">$1</div>')
                .replace(/\*\*(.+?)\*\*/g, '<span class="md-bold">$1</span>')
                .replace(/\*(.+?)\*/g, '<span class="md-italic">$1</span>')
                .replace(/^---$/gm, '<hr class="md-hr">')
                .replace(/^&gt; (.+)$/gm, '<span class="md-quote">$1</span>')
                .replace(/^- (.+)$/gm, '<span class="md-li">$1</span>')
                .replace(/\n/g, '<br>');
        }

        function toggleCollapse(el) {
            el.closest('.piece').classList.toggle('collapsed');
            el.textContent = el.closest('.piece').classList.contains('collapsed') ? '[+]' : '[-]';
        }

        function formatElapsed(ms) {
            const s = Math.floor(ms / 1000);
            const m = Math.floor(s / 60);
            const h = Math.floor(m / 60);
            if (h > 0) return h + ':' + String(m % 60).padStart(2, '0') + ':' + String(s % 60).padStart(2, '0');
            return m + ':' + String(s % 60).padStart(2, '0');
        }

        function addPiece(piece) {
            const container = document.getElementById('content');
            const empty = document.getElementById('empty-state');
            if (empty) empty.remove();

            const cls = typeClass(piece.label);
            typeCounts[piece.label] = (typeCounts[piece.label] || 0) + 1;
            pieceCount++;

            const div = document.createElement('div');
            div.className = 'piece ' + cls;
            div.dataset.gentype = cls;
            if (!activeFilters.has(cls)) {
                div.style.display = 'none';
            }
            div.innerHTML =
                '<div class="piece-header">' +
                    '<span class="piece-type">' + escapeHtml(piece.label) + '</span>' +
                    '<div class="piece-meta">' +
                        '<span class="piece-time">' + escapeHtml(piece.time) + '</span>' +
                        '<span class="piece-seq">#' + piece.seq + '</span>' +
                        '<span class="piece-toggle" onclick="toggleCollapse(this)">[-]</span>' +
                    '</div>' +
                '</div>' +
                '<div class="piece-content">' + formatContent(piece.content) + '</div>';
            container.insertBefore(div, container.firstChild);

            // Update stats
            document.getElementById('stat-total').textContent = pieceCount;
            const elapsed = Date.now() - startTime;
            const rate = elapsed > 60000 ? (pieceCount / (elapsed / 60000)).toFixed(1) : '--';
            document.getElementById('stat-rate').textContent = rate;
            document.getElementById('stat-elapsed').textContent = formatElapsed(elapsed);

            if (autoScroll) window.scrollTo(0, 0);
        }

        async function poll() {
            if (paused) {
                setTimeout(poll, 2000);
                return;
            }
            try {
                const resp = await fetch('/api/pieces?since=' + lastSeq);
                if (resp.ok) {
                    const data = await resp.json();
                    for (const piece of data.pieces) {
                        addPiece(piece);
                        lastSeq = piece.seq;
                    }
                }
            } catch (e) {
                // Server unreachable, will retry
            }
            setTimeout(poll, 2000);
        }

        // Update elapsed timer independently
        setInterval(function() {
            document.getElementById('stat-elapsed').textContent = formatElapsed(Date.now() - startTime);
        }, 1000);

        poll();
    </script>
</body>
</html>"""


# ============================================================
# HTTP HANDLER
# ============================================================

viewer_state = None  # set in main()


class ViewerHandler(http.server.BaseHTTPRequestHandler):
    """Serves the viewer page and piece data API."""

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path

        if path == "/" or path == "":
            self._serve_html()
        elif path == "/api/pieces":
            self._serve_pieces(parsed.query)
        elif path == "/api/stats":
            self._serve_stats()
        else:
            self.send_response(404)
            self.end_headers()

    def _serve_html(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(HTML_PAGE.encode("utf-8"))

    def _serve_pieces(self, query_string):
        params = parse_qs(query_string)
        since = int(params.get("since", [0])[0])
        pieces = viewer_state.get_since(since)
        body = json.dumps({"pieces": pieces}, ensure_ascii=False)
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def _serve_stats(self):
        stats = viewer_state.get_stats()
        body = json.dumps(stats, ensure_ascii=False)
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def log_message(self, format, *args):
        pass  # suppress request logging noise


# ============================================================
# MAIN
# ============================================================

def main():
    parser = argparse.ArgumentParser(
        description="Frosthold v3 Generator — Live Viewer"
    )
    parser.add_argument(
        "--delay", type=float, default=3.0,
        help="Seconds between generation batches (default: 3)"
    )
    parser.add_argument(
        "--batch", type=int, default=1,
        help="Pieces per batch (default: 1)"
    )
    parser.add_argument(
        "--port", type=int, default=8090,
        help="Web server port (default: 8090)"
    )
    parser.add_argument(
        "--no-browser", action="store_true",
        help="Don't auto-open browser"
    )
    args = parser.parse_args()

    global viewer_state
    viewer_state = ViewerState()

    # Start generator thread
    gen_thread = threading.Thread(
        target=generator_thread,
        args=(viewer_state, args.delay, args.batch),
        daemon=True,
    )
    gen_thread.start()

    # Start web server
    server = http.server.HTTPServer(("0.0.0.0", args.port), ViewerHandler)

    url = f"http://localhost:{args.port}"
    print(f"Frosthold Live Viewer running at {url}")
    print(f"Generating {args.batch} piece(s) every {args.delay}s")
    print("Ctrl+C to stop\n")

    if not args.no_browser:
        webbrowser.open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.shutdown()
        print(f"\nStopped. Generated {viewer_state.seq} pieces total.")


if __name__ == "__main__":
    main()

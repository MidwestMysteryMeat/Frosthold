#!/usr/bin/env python3
"""
generate_feature_checklist_pdf.py — Converts FROSTHOLD_Feature_Checklist.md
to a styled PDF using fpdf2.

Run from repo root:  python tools/generate_feature_checklist_pdf.py
Output:              FROSTHOLD_Feature_Checklist.pdf
"""

import os
import re
import sys

try:
    from fpdf import FPDF, XPos, YPos
except ImportError:
    print("ERROR: fpdf2 not installed. Run: pip install fpdf2")
    sys.exit(1)

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MD_FILE = os.path.join(REPO_ROOT, 'FROSTHOLD_Feature_Checklist.md')
PDF_FILE = os.path.join(REPO_ROOT, 'FROSTHOLD_Feature_Checklist.pdf')

# ── Colors ──────────────────────────────────────────────────────────────────
C_DARK    = (13, 27, 42)
C_HEADER  = (27, 58, 92)
C_SUBHEAD = (44, 95, 130)
C_TH_BG   = (27, 58, 92)
C_TH_FG   = (255, 255, 255)
C_ROW_ALT = (242, 245, 249)
C_ROW_WHT = (255, 255, 255)
C_BORDER  = (180, 195, 210)
C_RED     = (196, 30, 58)
C_ORANGE  = (212, 131, 10)
C_QUOTE   = (232, 240, 248)
C_GAP_TH  = (139, 37, 0)
C_CHECK   = (100, 100, 100)

FONT = 'FH'  # alias for whatever Unicode font we load

# ── PDF subclass ────────────────────────────────────────────────────────────

class ChecklistPDF(FPDF):
    def header(self):
        if self.page_no() == 1:
            return
        self.set_font(FONT, 'I', 7)
        self.set_text_color(130, 130, 130)
        self.cell(0, 6, 'FROSTHOLD  |  Feature & Mechanics Testing Checklist', align='L')
        self.ln(6)

    def footer(self):
        self.set_y(-12)
        self.set_font(FONT, 'I', 7)
        self.set_text_color(130, 130, 130)
        self.cell(0, 8, f'Page {self.page_no()} / {{nb}}', align='C')


# ── Markdown parser ─────────────────────────────────────────────────────────

def parse_markdown(md_text):
    blocks = []
    lines = md_text.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]

        if re.match(r'^---+\s*$', line):
            blocks.append(('hr', None))
            i += 1; continue

        if line.startswith('# ') and not line.startswith('## '):
            blocks.append(('h1', line[2:].strip()))
            i += 1; continue

        if line.startswith('## '):
            blocks.append(('h2', line[3:].strip()))
            i += 1; continue

        if line.startswith('### '):
            blocks.append(('h3', line[4:].strip()))
            i += 1; continue

        if line.startswith('>'):
            text = line.lstrip('> ').strip()
            i += 1
            while i < len(lines) and lines[i].startswith('>'):
                text += ' ' + lines[i].lstrip('> ').strip()
                i += 1
            blocks.append(('blockquote', text))
            continue

        if '|' in line and i + 1 < len(lines) and re.match(r'^[\s|:-]+$', lines[i + 1]):
            headers = [c.strip() for c in line.strip('| \t').split('|')]
            i += 2
            rows = []
            while i < len(lines) and '|' in lines[i] and not lines[i].startswith('#'):
                cells = [c.strip() for c in lines[i].strip('| \t').split('|')]
                rows.append(cells)
                i += 1
            blocks.append(('table', {'headers': headers, 'rows': rows}))
            continue

        if line.strip():
            text = line.strip()
            i += 1
            while i < len(lines) and lines[i].strip() and not lines[i].startswith('#') \
                    and not lines[i].startswith('|') and not lines[i].startswith('>') \
                    and not lines[i].startswith('---') and not lines[i].startswith('- '):
                text += ' ' + lines[i].strip()
                i += 1
            blocks.append(('paragraph', text))
            continue

        i += 1
    return blocks


# ── Column width calculation ────────────────────────────────────────────────

DONE_COL_W = 10        # mm — fixed width for "Done" checkbox column
HASH_COL_W = 8         # mm — fixed for "#" column
MIN_COL_W  = 18        # mm — minimum for any text column
MAX_FIXED_W = 55       # mm — cap for non-last columns (so last col gets room)


def compute_col_widths(pdf, headers, rows, total_width):
    n = len(headers)
    if n == 0:
        return []

    # Step 1: Measure natural content widths
    natural = []
    for j in range(n):
        pdf.set_font(FONT, 'B', 7.5)
        best = pdf.get_string_width(headers[j]) + 4
        pdf.set_font(FONT, '', 7.5)
        for row in rows:
            if j < len(row):
                w = pdf.get_string_width(row[j]) + 4
                best = max(best, w)
        natural.append(best)

    # Step 2: Assign fixed-width columns
    widths = [0.0] * n
    flexible_indices = []
    consumed = 0.0

    for j in range(n):
        h = headers[j].lower().strip()
        if h == 'done':
            widths[j] = DONE_COL_W
            consumed += DONE_COL_W
        elif h == '#':
            widths[j] = HASH_COL_W
            consumed += HASH_COL_W
        else:
            flexible_indices.append(j)

    if not flexible_indices:
        return widths

    remaining = total_width - consumed

    # Step 3: For tables with a "Test" or last text column, give it remaining space
    # after assigning reasonable widths to the middle columns
    if len(flexible_indices) == 1:
        widths[flexible_indices[0]] = remaining
    elif len(flexible_indices) >= 2:
        # Give non-last flexible columns their natural width, capped
        last_flex = flexible_indices[-1]
        middle_consumed = 0.0
        for j in flexible_indices[:-1]:
            w = min(natural[j], MAX_FIXED_W)
            w = max(w, MIN_COL_W)
            widths[j] = w
            middle_consumed += w
        # Last flexible column gets the rest
        last_w = remaining - middle_consumed
        widths[last_flex] = max(last_w, MIN_COL_W)

        # If last column got squeezed, scale everything down
        if last_w < MIN_COL_W:
            scale = remaining / (middle_consumed + MIN_COL_W)
            for j in flexible_indices[:-1]:
                widths[j] *= scale
            widths[last_flex] = MIN_COL_W

    return widths


# ── Draw a checkbox ─────────────────────────────────────────────────────────

def draw_checkbox(pdf, x, y, size=3.2):
    """Draw an empty checkbox square at (x, y)."""
    pdf.set_draw_color(*C_CHECK)
    pdf.set_line_width(0.35)
    pdf.rect(x, y, size, size)


# ── Compute row height for wrapping ────────────────────────────────────────

def cell_lines(pdf, text, col_w, font_size=7.5):
    """Count how many lines `text` needs at the given column width."""
    if not text:
        return 1
    pdf.set_font(FONT, '', font_size)
    # Approximate: fpdf multi_cell wraps on word boundaries
    words = text.split()
    line_w = 0
    lines = 1
    space_w = pdf.get_string_width(' ')
    for word in words:
        ww = pdf.get_string_width(word)
        if line_w + ww > col_w - 2:  # 2mm padding
            lines += 1
            line_w = ww + space_w
        else:
            line_w += ww + space_w
    return lines


# ── Table renderer ──────────────────────────────────────────────────────────

LINE_H = 4.2       # mm per line of text inside a row
ROW_PAD = 1.5      # mm extra vertical padding per row
MIN_ROW_H = 7.0    # mm minimum row height


def render_table_header(pdf, headers, col_widths, th_bg):
    n = len(headers)
    pdf.set_fill_color(*th_bg)
    pdf.set_text_color(*C_TH_FG)
    pdf.set_font(FONT, 'B', 7)
    for j in range(n):
        w = col_widths[j]
        pdf.cell(w, 7, '  ' + headers[j].upper() if headers[j].lower() != 'done' else '',
                 border=0, fill=True, align='L')
    pdf.ln(7)


def render_table(pdf, data, is_gap_table=False):
    headers = data['headers']
    rows = data['rows']
    n = len(headers)
    if n == 0:
        return

    page_width = pdf.w - pdf.l_margin - pdf.r_margin
    col_widths = compute_col_widths(pdf, headers, rows, page_width)

    # Ensure room for header + 2 rows
    if pdf.get_y() + 25 > pdf.h - 20:
        pdf.add_page()

    th_bg = C_GAP_TH if is_gap_table else C_TH_BG
    has_done = headers[0].lower() == 'done'

    render_table_header(pdf, headers, col_widths, th_bg)

    # Data rows
    for r_idx, row in enumerate(rows):
        # Compute row height: find tallest cell
        max_lines = 1
        for j in range(n):
            if j == 0 and has_done:
                continue
            txt = row[j] if j < len(row) else ''
            txt = txt.replace('**', '')
            nl = cell_lines(pdf, txt, col_widths[j])
            max_lines = max(max_lines, nl)
        row_h = max(MIN_ROW_H, max_lines * LINE_H + ROW_PAD)

        # Page break check
        if pdf.get_y() + row_h > pdf.h - 20:
            pdf.add_page()
            render_table_header(pdf, headers, col_widths, th_bg)

        # Row background
        row_y = pdf.get_y()
        bg = C_ROW_ALT if r_idx % 2 else C_ROW_WHT
        pdf.set_fill_color(*bg)
        pdf.rect(pdf.l_margin, row_y, page_width, row_h, 'F')

        # Bottom border
        pdf.set_draw_color(*C_BORDER)
        pdf.set_line_width(0.15)
        pdf.line(pdf.l_margin, row_y + row_h, pdf.l_margin + page_width, row_y + row_h)

        # Render cells
        cell_x = pdf.l_margin
        for j in range(n):
            w = col_widths[j]
            txt = row[j] if j < len(row) else ''
            txt = txt.replace('**', '')

            if j == 0 and has_done:
                # Draw checkbox
                cb_x = cell_x + (w - 3.2) / 2
                cb_y = row_y + (row_h - 3.2) / 2
                draw_checkbox(pdf, cb_x, cb_y)
            else:
                # Render text with wrapping
                pdf.set_xy(cell_x + 1.5, row_y + ROW_PAD / 2)

                # Color overrides
                if 'MISSING' in txt:
                    pdf.set_font(FONT, 'B', 7.5)
                    pdf.set_text_color(*C_RED)
                elif 'VERIFY' in txt:
                    pdf.set_font(FONT, 'B', 7.5)
                    pdf.set_text_color(*C_ORANGE)
                else:
                    pdf.set_font(FONT, '', 7.5)
                    pdf.set_text_color(26, 26, 26)

                pdf.multi_cell(w - 3, LINE_H, txt, border=0, align='L')
                pdf.set_text_color(0, 0, 0)

            cell_x += w

        pdf.set_y(row_y + row_h)

    pdf.ln(3)


# ── Main ────────────────────────────────────────────────────────────────────

def load_font(pdf):
    """Load a Unicode TTF font. Try bundled DejaVu, then Windows fonts."""
    # fpdf2 bundles DejaVu in its fonts/ directory
    import fpdf
    bundled = os.path.join(os.path.dirname(fpdf.__file__), 'fonts')

    search_dirs = [bundled]

    for d in search_dirs:
        regular = os.path.join(d, 'DejaVuSans.ttf')
        if os.path.exists(regular):
            pdf.add_font(FONT, '', regular)
            bold = os.path.join(d, 'DejaVuSans-Bold.ttf')
            pdf.add_font(FONT, 'B', bold if os.path.exists(bold) else regular)
            italic = os.path.join(d, 'DejaVuSans-Oblique.ttf')
            pdf.add_font(FONT, 'I', italic if os.path.exists(italic) else regular)
            print(f"  Font: DejaVuSans from {d}")
            return True

    # Fallback: Windows system fonts
    win_dir = os.path.join(os.environ.get('WINDIR', r'C:\Windows'), 'Fonts')
    arial = os.path.join(win_dir, 'arial.ttf')
    if os.path.exists(arial):
        pdf.add_font(FONT, '', arial)
        arialbd = os.path.join(win_dir, 'arialbd.ttf')
        pdf.add_font(FONT, 'B', arialbd if os.path.exists(arialbd) else arial)
        ariali = os.path.join(win_dir, 'ariali.ttf')
        pdf.add_font(FONT, 'I', ariali if os.path.exists(ariali) else arial)
        print(f"  Font: Arial from {win_dir}")
        return True

    print("  WARNING: No Unicode font found")
    return False


def main():
    if not os.path.exists(MD_FILE):
        print(f"ERROR: {MD_FILE} not found")
        sys.exit(1)

    print(f"Reading {MD_FILE}...")
    with open(MD_FILE, 'r', encoding='utf-8') as f:
        md_text = f.read()

    blocks = parse_markdown(md_text)

    pdf = ChecklistPDF('P', 'mm', 'A4')
    pdf.alias_nb_pages()
    pdf.set_auto_page_break(auto=False)  # we handle breaks manually

    load_font(pdf)
    pdf.add_page()

    in_gaps = False

    for btype, bdata in blocks:
        # Auto page-break safety for non-table blocks
        if btype != 'table' and pdf.get_y() > pdf.h - 25:
            pdf.add_page()

        if btype == 'h1':
            pdf.set_font(FONT, 'B', 18)
            pdf.set_text_color(*C_DARK)
            clean = bdata.replace('**', '')
            pdf.cell(0, 12, clean, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            pdf.set_draw_color(*C_HEADER)
            pdf.set_line_width(0.8)
            pdf.line(pdf.l_margin, pdf.get_y(), pdf.w - pdf.r_margin, pdf.get_y())
            pdf.ln(4)

        elif btype == 'h2':
            if pdf.get_y() > pdf.h - 40:
                pdf.add_page()
            in_gaps = 'KNOWN GAPS' in bdata.upper() or 'TOTALS' in bdata.upper()
            pdf.ln(4)
            pdf.set_font(FONT, 'B', 12)
            pdf.set_text_color(*C_HEADER)
            clean = bdata.replace('**', '')
            pdf.cell(0, 8, clean, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            pdf.set_draw_color(*C_SUBHEAD)
            pdf.set_line_width(0.5)
            pdf.line(pdf.l_margin, pdf.get_y(), pdf.w - pdf.r_margin, pdf.get_y())
            pdf.ln(3)

        elif btype == 'h3':
            if pdf.get_y() > pdf.h - 30:
                pdf.add_page()
            pdf.set_font(FONT, 'B', 9.5)
            pdf.set_text_color(*C_SUBHEAD)
            clean = bdata.replace('**', '')
            pdf.cell(0, 7, clean, new_x=XPos.LMARGIN, new_y=YPos.NEXT)
            pdf.ln(1)

        elif btype == 'blockquote':
            pdf.set_fill_color(*C_QUOTE)
            x = pdf.l_margin
            y = pdf.get_y()
            pdf.set_font(FONT, 'I', 7.5)
            pdf.set_text_color(80, 80, 80)
            text_w = pdf.w - pdf.l_margin - pdf.r_margin
            pdf.set_x(x + 5)
            pdf.multi_cell(text_w - 6, 4.5, bdata, fill=True)
            end_y = pdf.get_y()
            pdf.set_draw_color(58, 124, 165)
            pdf.set_line_width(0.8)
            pdf.line(x, y, x, end_y)
            pdf.ln(2)

        elif btype == 'paragraph':
            pdf.set_font(FONT, '', 8)
            pdf.set_text_color(50, 50, 50)
            clean = bdata.replace('**', '')
            pdf.multi_cell(0, 4.5, clean)
            pdf.ln(1)

        elif btype == 'table':
            render_table(pdf, bdata, is_gap_table=in_gaps)

        elif btype == 'hr':
            pdf.set_draw_color(210, 210, 210)
            pdf.set_line_width(0.2)
            pdf.line(pdf.l_margin, pdf.get_y(), pdf.w - pdf.r_margin, pdf.get_y())
            pdf.ln(2)

    print(f"Writing {PDF_FILE}...")
    pdf.output(PDF_FILE)
    size = os.path.getsize(PDF_FILE)
    print(f"Done! {PDF_FILE} ({size:,} bytes)")


if __name__ == '__main__':
    main()

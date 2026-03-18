"""Generate Frosthold Art Asset Checklist PDF with sprite grouping notes."""
from fpdf import FPDF


class AssetPDF(FPDF):
    def header(self):
        if self.page_no() == 1:
            return
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(120, 120, 120)
        self.cell(0, 6, "FROSTHOLD - Art Asset Checklist", align="C", new_x="LMARGIN", new_y="NEXT")
        self.line(10, self.get_y(), 200, self.get_y())
        self.ln(4)

    def footer(self):
        self.set_y(-15)
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(120, 120, 120)
        self.cell(0, 10, f"Page {self.page_no()}/{{nb}}", align="C")

    def section_title(self, title):
        self.check_page_break(16)
        self.set_font("Helvetica", "B", 14)
        self.set_text_color(30, 60, 90)
        self.cell(0, 10, title, new_x="LMARGIN", new_y="NEXT")
        y = self.get_y()
        self.set_draw_color(30, 60, 90)
        self.set_line_width(0.6)
        self.line(10, y, 200, y)
        self.ln(4)

    def sub_title(self, title, count=None):
        self.check_page_break(12)
        self.set_font("Helvetica", "B", 11)
        self.set_text_color(60, 60, 60)
        label = title if count is None else f"{title} ({count})"
        self.cell(0, 8, label, new_x="LMARGIN", new_y="NEXT")
        self.ln(1)

    def sprite_group_box(self, text):
        """Draw a highlighted sprite-sharing note box."""
        self.check_page_break(12)
        self.set_fill_color(255, 245, 220)
        self.set_draw_color(200, 170, 80)
        self.set_line_width(0.4)
        self.set_font("Helvetica", "BI", 8)
        self.set_text_color(120, 80, 10)
        x = self.get_x()
        y = self.get_y()
        self.rect(x + 2, y, 186, 9, style="DF")
        self.set_xy(x + 5, y + 1)
        self.cell(180, 7, "SPRITE TIP: " + text)
        self.set_xy(x, y + 11)

    def checkbox(self, x, y, size=4):
        self.set_draw_color(80, 80, 80)
        self.set_line_width(0.3)
        self.rect(x, y + 1.5, size, size)

    def table(self, headers, rows, col_widths=None, checklist=True):
        cb_w = 8 if checklist else 0
        if col_widths is None:
            total = 190 - cb_w
            col_widths = [total / len(headers)] * len(headers)
        else:
            if checklist:
                ratio = (190 - cb_w) / sum(col_widths)
                col_widths = [w * ratio for w in col_widths]
        self.set_font("Helvetica", "B", 8)
        self.set_fill_color(40, 70, 100)
        self.set_text_color(255, 255, 255)
        if checklist:
            self.cell(cb_w, 7, "Done", border=1, fill=True, align="C")
        for i, h in enumerate(headers):
            self.cell(col_widths[i], 7, h, border=1, fill=True, align="C")
        self.ln()
        self.set_font("Helvetica", "", 8)
        fill = False
        for row in rows:
            self.check_page_break(7)
            if fill:
                self.set_fill_color(235, 240, 248)
            else:
                self.set_fill_color(255, 255, 255)
            self.set_text_color(30, 30, 30)
            if checklist:
                cx = self.get_x()
                cy = self.get_y()
                self.cell(cb_w, 7, "", border=1, fill=True)
                self.checkbox(cx + 2, cy)
            for i, val in enumerate(row):
                align = "L" if i == 1 else "C"
                self.cell(col_widths[i], 7, str(val), border=1, fill=True, align=align)
            self.ln()
            fill = not fill

    def bullet_list(self, items):
        self.set_font("Helvetica", "", 9)
        self.set_text_color(40, 40, 40)
        for item in items:
            self.check_page_break(7)
            cx = self.get_x()
            cy = self.get_y()
            self.checkbox(cx + 2, cy, size=4)
            self.cell(10, 7, "")
            self.cell(0, 7, item, new_x="LMARGIN", new_y="NEXT")

    def note(self, text):
        self.set_font("Helvetica", "I", 8)
        self.set_text_color(100, 100, 100)
        self.multi_cell(0, 5, text)
        self.ln(2)

    def check_page_break(self, h):
        if self.get_y() + h > self.h - 20:
            self.add_page()

    def color_swatch_row(self, label, swatches, swatch_size=14, show_arrow=True):
        """Draw a row of colored squares with labels to show recolor concept.
        swatches = list of (r, g, b, label) tuples.
        First swatch shown as 'BASE', rest as variations with arrow."""
        self.check_page_break(swatch_size + 16)
        self.set_font("Helvetica", "B", 8)
        self.set_text_color(60, 60, 60)
        self.cell(0, 6, label, new_x="LMARGIN", new_y="NEXT")
        start_x = self.get_x() + 8
        start_y = self.get_y()
        gap = 6
        for idx, (r, g, b, name) in enumerate(swatches):
            sx = start_x + idx * (swatch_size + gap + 16)
            if show_arrow and idx > 0:
                # Draw arrow from prev swatch
                ax = sx - gap - 6
                ay = start_y + swatch_size / 2
                self.set_draw_color(150, 150, 150)
                self.set_line_width(0.5)
                self.line(ax, ay, ax + gap + 2, ay)
                # arrowhead
                self.line(ax + gap, ay - 2, ax + gap + 2, ay)
                self.line(ax + gap, ay + 2, ax + gap + 2, ay)
            # Draw swatch square
            self.set_fill_color(r, g, b)
            self.set_draw_color(40, 40, 40)
            self.set_line_width(0.4)
            self.rect(sx, start_y, swatch_size, swatch_size, style="DF")
            # Label below
            self.set_font("Helvetica", "B" if idx == 0 else "", 6)
            self.set_text_color(50, 50, 50)
            label_w = swatch_size + 12
            self.set_xy(sx - 3, start_y + swatch_size + 1)
            self.cell(label_w, 5, name, align="C")
            # "BASE" tag on first
            if idx == 0:
                self.set_font("Helvetica", "B", 5)
                self.set_text_color(255, 255, 255)
                self.set_fill_color(30, 60, 90)
                self.set_xy(sx, start_y)
                self.cell(swatch_size, 5, "BASE", fill=True, align="C")
        self.set_xy(10, start_y + swatch_size + 8)

    def sprite_reuse_diagram(self, title, base_color, variants, shape="rect"):
        """Draw a base sprite shape + arrow + recolored variants to show reuse.
        base_color = (r, g, b)
        variants = list of (r, g, b, label)
        shape = 'rect' | 'circle' | 'triangle'"""
        self.check_page_break(34)
        self.set_font("Helvetica", "B", 8)
        self.set_text_color(60, 60, 60)
        self.cell(0, 6, title, new_x="LMARGIN", new_y="NEXT")

        box_h = 22
        box_w = 180
        self.set_fill_color(245, 245, 250)
        self.set_draw_color(180, 180, 190)
        self.set_line_width(0.3)
        bx = self.get_x() + 5
        by = self.get_y()
        self.rect(bx, by, box_w, box_h, style="DF")

        sz = 14  # shape size
        # Draw base shape
        cx_base = bx + 16
        cy_base = by + (box_h - sz) / 2
        r, g, b = base_color
        self._draw_shape(cx_base, cy_base, sz, r, g, b, shape)
        # "BASE" label
        self.set_font("Helvetica", "B", 5)
        self.set_text_color(30, 60, 90)
        self.set_xy(cx_base - 1, cy_base + sz + 0.5)
        self.cell(sz + 2, 4, "DRAW THIS", align="C")

        # Big arrow
        arrow_x1 = cx_base + sz + 6
        arrow_x2 = arrow_x1 + 14
        arrow_y = by + box_h / 2
        self.set_draw_color(100, 100, 100)
        self.set_line_width(0.8)
        self.line(arrow_x1, arrow_y, arrow_x2, arrow_y)
        self.line(arrow_x2 - 3, arrow_y - 2.5, arrow_x2, arrow_y)
        self.line(arrow_x2 - 3, arrow_y + 2.5, arrow_x2, arrow_y)
        # "recolor" text
        self.set_font("Helvetica", "I", 5)
        self.set_text_color(100, 100, 100)
        self.set_xy(arrow_x1 - 1, arrow_y - 6)
        self.cell(18, 4, "recolor", align="C")

        # Draw variant shapes
        vx_start = arrow_x2 + 6
        gap = 4
        for idx, (vr, vg, vb, vlabel) in enumerate(variants):
            vx = vx_start + idx * (sz + gap + 2)
            vy = by + (box_h - sz) / 2
            self._draw_shape(vx, vy, sz - 2, vr, vg, vb, shape)
            self.set_font("Helvetica", "", 5)
            self.set_text_color(80, 80, 80)
            self.set_xy(vx - 3, vy + sz - 1)
            self.cell(sz + 4, 4, vlabel, align="C")

        self.set_xy(10, by + box_h + 3)

    def _draw_shape(self, x, y, size, r, g, b, shape):
        self.set_fill_color(r, g, b)
        self.set_draw_color(max(0, r - 40), max(0, g - 40), max(0, b - 40))
        self.set_line_width(0.5)
        if shape == "rect":
            self.rect(x, y, size, size, style="DF")
        elif shape == "circle":
            cx = x + size / 2
            cy = y + size / 2
            self.circle(cx, cy, size / 2, style="DF")
        elif shape == "triangle":
            # top-down triangle
            p1 = (x + size / 2, y)
            p2 = (x, y + size)
            p3 = (x + size, y + size)
            self.polygon([p1, p2, p3], style="DF")


def px(size):
    """Convert game size multiplier to pixel dimensions (32px base tile).
    Snaps to nearest multiple of 8 for clean sprite sheets."""
    raw = float(size) * 32
    p = max(8, round(raw / 8) * 8)
    return f"{p}x{p}"


def build():
    pdf = AssetPDF(orientation="P", unit="mm", format="A4")
    pdf.alias_nb_pages()
    pdf.set_auto_page_break(auto=True, margin=20)

    # =========================================================================
    # COVER PAGE
    # =========================================================================
    pdf.add_page()
    pdf.ln(50)
    pdf.set_font("Helvetica", "B", 32)
    pdf.set_text_color(30, 60, 90)
    pdf.cell(0, 15, "FROSTHOLD", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.set_font("Helvetica", "", 16)
    pdf.set_text_color(80, 80, 80)
    pdf.cell(0, 10, "Art Asset Checklist", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(4)
    pdf.set_draw_color(30, 60, 90)
    pdf.set_line_width(0.8)
    pdf.line(60, pdf.get_y(), 150, pdf.get_y())
    pdf.ln(8)
    pdf.set_font("Helvetica", "", 11)
    pdf.set_text_color(100, 100, 100)
    pdf.cell(0, 8, "Frostpunk x RimWorld Colony Survival Sim", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 8, "Love2D 11.4  |  32px tiles  |  1280x720", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(16)

    # Summary table
    pdf.set_font("Helvetica", "B", 11)
    pdf.set_text_color(60, 60, 60)
    pdf.cell(0, 8, "Asset Summary", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.ln(2)
    summary = [
        ("Category", "Items", "Base Sprites", "Notes"),
        ("Tiles & Terrain", "35", "~22", "Wall/floor tiers = material swaps"),
        ("Zone Overlays", "3", "1", "Same pattern, color swap"),
        ("Colonist", "~20", "~8", "Base model + overlay layers"),
        ("Creatures", "35 species", "~22", "Wolf/brute tiers share bases"),
        ("Eldritch Growth", "45", "~18", "5 stages but 2-3 share silhouette"),
        ("Named Bosses", "8", "~6", "2 share base creature form"),
        ("Megabeast Proc.", "10+10", "10", "10 forms, materials are palettes"),
        ("Lairs", "8", "~3", "Cave/den/nest base types"),
        ("Raiders", "15", "~6", "4 factions, colonist base model"),
        ("NPCs/Merchants", "3", "1", "Same humanoid, faction colors"),
        ("Buildings", "187", "~65", "Heavy reuse across tiers"),
        ("Items", "160+", "~55", "Many share silhouette + recolor"),
        ("Crops", "70 stages", "~31", "14 crops, shared early stages"),
        ("Effects/Particles", "18+", "~12", "Some share base anim"),
        ("Weather", "7", "~4", "Snow intensity scales"),
        ("UI Icons", "80+", "~50", "Many small unique icons"),
        ("Disease/Status", "8", "~5", "Overlay tints share base"),
        ("", "", "", ""),
        ("TOTAL ITEMS", "~700+", "", ""),
        ("UNIQUE BASE SPRITES", "", "~320", "After shared-base grouping"),
    ]
    pdf.set_font("Helvetica", "", 9)
    for row in summary:
        cat, items, bases, notes = row
        if cat in ("TOTAL ITEMS", "UNIQUE BASE SPRITES"):
            pdf.set_font("Helvetica", "B", 10)
            pdf.set_text_color(30, 60, 90)
        elif cat == "Category":
            pdf.set_font("Helvetica", "B", 9)
            pdf.set_text_color(40, 70, 100)
        elif cat == "":
            pdf.ln(1)
            continue
        else:
            pdf.set_font("Helvetica", "", 9)
            pdf.set_text_color(50, 50, 50)
        pdf.cell(48, 7, cat, align="R")
        pdf.cell(4, 7, "")
        pdf.cell(20, 7, items, align="C")
        pdf.cell(24, 7, bases, align="C")
        pdf.cell(4, 7, "")
        pdf.set_font("Helvetica", "I", 8)
        pdf.set_text_color(120, 100, 60)
        pdf.cell(0, 7, notes, new_x="LMARGIN", new_y="NEXT")

    pdf.ln(8)
    pdf.set_font("Helvetica", "I", 9)
    pdf.set_text_color(100, 100, 100)
    pdf.multi_cell(0, 5, 'Legend: "Base Sprites" = unique drawings needed. Remaining items are\ncolor swaps, material tints, or size variations of the base sprite.\nRimWorld-style: one turret base, swap the barrel; one wall, swap the texture.')

    # =========================================================================
    # 1. TILES & TERRAIN
    # =========================================================================
    pdf.add_page()
    pdf.section_title("1. TILES & TERRAIN")
    pdf.sprite_group_box("Walls share 1 base shape - swap material texture (wood grain / stone / metal / tech).")
    pdf.sprite_group_box("Floors share 1 base shape - swap material texture. Same for doors.")
    pdf.note("All tiles 32x32px. Consider damaged/cracked variant overlay (1 shared crumble texture).")
    pdf.ln(1)

    pdf.sub_title("Natural Terrain (unique sprites)", 7)
    tiles_natural = [
        ("0", "Void", "Empty space outside map bounds, pure black", "Unique"),
        ("1", "Snow", "Flat white tundra ground, default outdoor surface", "Unique"),
        ("2", "Ice", "Frozen translucent surface, slightly reflective", "Unique"),
        ("3", "Rock", "Solid unmined gray stone, rough hewn texture", "Unique"),
        ("4", "Permafrost", "Frozen soil, cracked gray-blue surface", "Unique"),
        ("5", "Dirt", "Exposed brown earth, muddy patches", "Unique"),
        ("15", "Debris", "Broken rubble, collapsed wall/rock fragments", "Unique"),
    ]
    pdf.table(["ID", "Tile", "Description", "Sprite"], tiles_natural, [10, 28, 95, 18])
    pdf.ln(2)

    pdf.sub_title("Natural Resources (unique sprites)", 2)
    tiles_res = [
        ("16", "Tree", "Frost-covered conifer tree, choppable for wood", "Unique"),
        ("17", "Ore Vein", "Rock wall with visible metal ore seams/flecks", "Unique"),
    ]
    pdf.table(["ID", "Tile", "Description", "Sprite"], tiles_res, [10, 28, 95, 18])
    pdf.ln(2)

    pdf.sub_title("Walls - 1 base shape, 4 material textures", 4)
    pdf.sprite_group_box("Draw 1 wall silhouette. Apply 4 material fills: wood grain, stone, metal, blue-tech.")
    pdf.sprite_reuse_diagram(
        "Example: Wall material swaps",
        (102, 77, 38),  # wood brown base
        [
            (89, 86, 77, "Stone"),
            (115, 122, 128, "Metal"),
            (128, 133, 148, "Insulated"),
        ],
        shape="rect"
    )
    walls = [
        ("9", "Wood Wall", "Rough-hewn log or plank wall segment", "Base"),
        ("10", "Stone Wall", "Stacked stone block wall segment", "Recolor"),
        ("11", "Metal Wall", "Riveted steel panel wall segment", "Recolor"),
        ("18", "Insulated Wall", "Tech panel wall, thermal-sealed seams", "Recolor"),
    ]
    pdf.table(["ID", "Name", "Description", "Work"], walls, [10, 32, 92, 18])
    pdf.ln(2)

    pdf.sub_title("Floors - 1 base shape, 4 material textures", 4)
    pdf.sprite_group_box("Same approach as walls. 1 floor tile pattern, swap fill texture.")
    floors = [
        ("6", "Wood Floor", "Plank flooring, parallel boards", "Base"),
        ("7", "Stone Floor", "Cut flagstone tile pattern", "Recolor"),
        ("8", "Metal Floor", "Industrial steel grate/diamond plate", "Recolor"),
        ("19", "Insulated Floor", "Sealed tech-panel flooring", "Recolor"),
    ]
    pdf.table(["ID", "Name", "Description", "Work"], floors, [10, 32, 92, 18])
    pdf.ln(2)

    pdf.sub_title("Doors - 1 base shape, 2 variants", 2)
    doors = [
        ("12", "Door", "Hinged wooden door in wall frame, open/closed states", "Base"),
        ("20", "Sealed Door", "Pneumatic airlock door, sliding panels, airtight", "Variant"),
    ]
    pdf.table(["ID", "Name", "Description", "Work"], doors, [10, 28, 104, 18])
    pdf.ln(2)

    pdf.sub_title("Special Tiles", 2)
    special = [
        ("13", "Water", "Standing water pool, gentle ripple animation", "Animated"),
        ("14", "Lava Vent", "Volcanic fissure in ground, glowing orange magma, pulsing", "Animated"),
    ]
    pdf.table(["ID", "Name", "Description", "Work"], special, [10, 28, 104, 18])
    pdf.ln(2)

    pdf.sub_title("Underground Tiles - 4 unique + 3 column variants", 7)
    pdf.sprite_group_box("Columns share 1 pillar silhouette - swap material texture (wood / stone / reinforced).")
    pdf.note("Used in the multi-layer depth system for underground mining and construction.")
    underground = [
        ("21", "Deep Rock", "Extremely hard unmined stone below surface layer", "Unique"),
        ("22", "Underground Rock", "Standard subsurface stone, dark tones", "Unique"),
        ("23", "Underground Floor", "Cleared underground floor, smooth stone", "Unique"),
        ("24", "Shaft Entrance", "Vertical shaft access point, ladder/winch visible", "Unique"),
        ("25", "Wood Column", "Rough timber support pillar", "Base column"),
        ("26", "Support Column", "Cut stone support pillar", "Column recolor"),
        ("27", "Reinforced Column", "Steel-reinforced concrete pillar", "Column recolor"),
    ]
    pdf.table(["ID", "Tile", "Description", "Sprite"], underground, [10, 32, 100, 18])
    pdf.ln(2)

    pdf.sub_title("Biocave Tiles - 7 unique organic tiles", 7)
    pdf.sprite_group_box("Fungal pair: floor + wall = 1 organic texture, 2 configs. Same for membrane and organ.")
    pdf.note("Eldritch underground biome. Organic, living surfaces. Pulsing/animated where possible.")
    biocave = [
        ("28", "Fungal Floor", "Spongy bioluminescent fungal mat, faint glow", "Base fungal"),
        ("29", "Fungal Wall", "Dense fungal growth forming wall barrier", "Fungal var."),
        ("30", "Membrane Floor", "Translucent biological membrane, veins visible", "Base membrane"),
        ("31", "Membrane Wall", "Thick organic membrane wall, pulsing faintly", "Membrane var."),
        ("32", "Organ Floor", "Fleshy tissue surface, wet, disturbing", "Base organ"),
        ("33", "Organ Wall", "Thick fleshy wall with embedded structures", "Organ var."),
        ("34", "Growth Creep", "Spreading organic growth, tendrils reaching outward", "Unique"),
    ]
    pdf.table(["ID", "Tile", "Description", "Sprite"], biocave, [10, 32, 100, 18])
    pdf.ln(2)

    pdf.sub_title("Zone Overlays - 1 pattern, 3 color tints", 3)
    pdf.sprite_group_box("1 crosshatch/stipple pattern. Tint green, orange, red. Semi-transparent.")
    zones = [
        ("stockpile", "Stockpile", "Area where items are stored, green overlay"),
        ("dumping", "Dumping", "Trash/waste disposal zone, orange overlay"),
        ("restricted", "Restricted", "No-go zone for colonists, red overlay"),
    ]
    pdf.table(["ID", "Zone", "Description"], zones, [30, 30, 90])

    pdf.note("\nTiles total: 35 items, ~22 unique base sprites needed.")

    # =========================================================================
    # 2. COLONISTS
    # =========================================================================
    pdf.add_page()
    pdf.section_title("2. COLONISTS")
    pdf.sprite_group_box("1 base colonist model (body + head). Equipment = overlay layers, not separate sprites.")
    pdf.sprite_group_box("Hypothermia stages = blue tint ramp on base sprite, not 5 separate drawings.")
    pdf.note("Directional frames (4 or 8 dir). RimWorld-style: base body is generic, clothing/gear layers on top.")

    pdf.sub_title("Base Colonist (1 model, multiple anim states)")
    pdf.bullet_list([
        "Idle (standing) - base sprite",
        "Walking (4-dir animation) - 3-4 frames per direction",
        "Working (task animation) - reuse walk frames or 2-3 unique",
        "Sleeping (lying down) - rotated/flattened base",
        "Injured / Downed - recolor + prone",
        "Dead / Corpse - darkened prone",
    ])
    pdf.ln(1)

    pdf.sub_title("Hypothermia Stages - tint ramp, NOT separate sprites", 5)
    pdf.sprite_group_box("Apply progressive blue tint + frost particle overlay. 1 frost overlay reused.")
    hypo = [
        ("normal", ">= 60", "No tint", "Base sprite as-is"),
        ("chilled", ">= 40", "5% blue", "Color multiply"),
        ("cold", ">= 20", "15% blue", "Color multiply"),
        ("hypothermic", ">= 10", "30% blue + frost", "Multiply + overlay"),
        ("severe", "< 10", "50% blue + heavy frost", "Multiply + overlay"),
    ]
    pdf.table(["Stage", "Warmth", "Tint", "Implementation"], hypo, [28, 22, 38, 60])
    pdf.ln(2)

    pdf.sub_title("Equipment Overlay Layers")
    pdf.sprite_group_box("Clothing/armor are small overlay sprites drawn on top of colonist. Not full redraws.")

    pdf.set_font("Helvetica", "B", 9)
    pdf.set_text_color(60, 60, 60)
    pdf.cell(0, 7, "Clothing (2 overlays):", new_x="LMARGIN", new_y="NEXT")
    pdf.bullet_list(["parka - torso overlay", "boots - feet overlay"])

    pdf.set_font("Helvetica", "B", 9)
    pdf.set_text_color(60, 60, 60)
    pdf.cell(0, 7, "Suits (2 overlays - full body, replaces clothing layer):", new_x="LMARGIN", new_y="NEXT")
    pdf.bullet_list(["thermal_suit - blue-white full body", "exosuit - metallic full body"])

    pdf.set_font("Helvetica", "B", 9)
    pdf.set_text_color(60, 60, 60)
    pdf.cell(0, 7, "Armor (3 overlays - torso layer, progressive bulk):", new_x="LMARGIN", new_y="NEXT")
    pdf.sprite_group_box("1 vest/chestplate base shape. Swap material fill: hide brown, leather tan, metal gray.")
    pdf.color_swatch_row("Armor material progression:", [
        (140, 100, 60, "Hide (base)"),
        (180, 150, 100, "Leather"),
        (160, 165, 170, "Metal"),
    ])
    pdf.bullet_list(["hide_coat - light, brown", "leather_armor - medium, tan", "metal_plate - heavy, gray"])

    pdf.set_font("Helvetica", "B", 9)
    pdf.set_text_color(60, 60, 60)
    pdf.cell(0, 7, "Accessories (4 small overlays):", new_x="LMARGIN", new_y="NEXT")
    pdf.bullet_list(["warm_scarf - neck area", "lucky_charm - belt area",
                      "medkit_pouch - hip area", "scope - weapon attachment"])

    pdf.note("\nColonist total: ~20 visual items, ~8 unique base sprites (1 body + overlays).")

    # =========================================================================
    # 3. CREATURES
    # =========================================================================
    pdf.add_page()
    pdf.section_title("3. CREATURES")
    pdf.note("Each creature needs: idle, walk, attack, death frames (minimum). Larger = more detail.")

    pdf.sub_title("Small Fauna - 3 unique sprites", 3)
    pdf.note("Small, simple silhouettes. No reuse between these - hare/fox/bird are distinct shapes.")
    small = [
        ("frost_hare", "Frost Hare", px(0.4), "White arctic rabbit, long ears, round body"),
        ("ice_fox", "Ice Fox", px(0.5), "Sleek arctic fox, bushy tail, pointed snout"),
        ("snow_grouse", "Snow Grouse", px(0.3), "Small plump bird, feathered feet, short beak"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description"], small, [28, 28, 14, 78])
    pdf.ln(2)

    pdf.sub_title("Thermovores - 10 species, ~8 base sprites (Akrid-inspired)", 10)
    pdf.note("Arthropod predator lineage. Feed on thermal energy. Warm orange/red palette contrasts the blue/white fauna.\nRange from cat-sized parasites to colony-ending apex predators. All have visible exoskeletons and glowing thermal vents.")
    pdf.sprite_group_box("Char hound + bore beetle share a chunky arthropod body plan, different proportions.")
    pdf.sprite_group_box("Iron carapace = scaled bore beetle shell + unique leg/head details.")
    thermo_small = [
        ("cinder_mite", "Cinder Mite", px(0.3), "Cat-sized six-legged scuttler, orange chitin, glowing vents on back", "Unique"),
        ("heat_skipper", "Heat Skipper", px(0.2), "Tiny gliding arthropod, translucent amber wings, spindly legs", "Unique"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], thermo_small, [24, 24, 14, 86, 18])
    pdf.ln(1)
    thermo_med = [
        ("char_hound", "Char Hound", px(0.7), "Wolf-sized arthropod, mandibles, six legs, hunched pack hunter", "Base hound"),
        ("bore_beetle", "Bore Beetle", px(0.9), "Armored pill bug, rolls to charge, thick orange-brown shell", "Base beetle"),
        ("razorjaw", "Razorjaw", px(0.9), "Mantis predator, scythe forelegs, low ambush stance", "Unique"),
        ("spine_lurker", "Spine Lurker", px(0.8), "Scorpion body, segmented tail with barb, wide stance", "Unique"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], thermo_med, [24, 24, 14, 86, 18])
    pdf.ln(1)
    thermo_mega = [
        ("hive_matron", "Hive Matron", px(2.0), "Enormous queen, bloated thorax, crown of antennae, dark red", "Unique"),
        ("gorge_worm", "Gorge Worm", px(2.2), "Massive burrowing worm, segmented, glowing hot between plates", "Unique"),
        ("iron_carapace", "Iron Carapace", px(2.8), "Walking fortress beetle, layered shell plates, tiny red eyes", "Scaled beetle"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], thermo_mega, [24, 24, 14, 86, 18])
    pdf.ln(1)
    thermo_eld = [
        ("the_thermophage", "The Thermophage", px(4.5), "Apex arthropod, massive mandibles, glowing thermal core visible through cracked exoskeleton", "Unique"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], thermo_eld, [24, 24, 14, 86, 18])
    pdf.ln(3)

    pdf.sub_title("Medium Fauna - 10 species, ~6 base sprites", 10)
    pdf.sprite_group_box("Wolf family: tundra_wolf + dire_wolf = 1 base wolf, size/color swap.")
    pdf.sprite_group_box("Primate pair: snow_ape + ice_brute = 1 base ape, scale up + color.")
    pdf.sprite_group_box("Stalker + shade share similar hunched predator silhouette, different tint.")
    pdf.sprite_reuse_diagram(
        "Example: Wolf family - 1 base, 2 variants",
        (128, 128, 140),  # tundra wolf gray
        [
            (89, 89, 102, "Dire Wolf"),
        ],
        shape="circle"
    )
    pdf.sprite_reuse_diagram(
        "Example: Primate family - 1 base, 1 scaled variant",
        (191, 199, 209),  # snow ape light gray
        [
            (115, 128, 166, "Ice Brute"),
        ],
        shape="circle"
    )
    med = [
        ("tundra_wolf", "Tundra Wolf", px(0.7), "Gray wolf, lean build, pack hunter", "Base wolf"),
        ("dire_wolf", "Dire Wolf", px(0.85), "Larger darker wolf, heavier jaw", "Wolf recolor"),
        ("glacier_bear", "Glacier Bear", px(0.9), "Massive polar bear, thick fur, hunched", "Unique"),
        ("ice_stalker", "Ice Stalker", px(0.8), "Lean reptilian predator, low to ground", "Unique"),
        ("snow_ape", "Snow Ape", px(1.3), "Gorilla-like primate, white shaggy fur", "Base ape"),
        ("ice_brute", "Ice Brute", px(1.5), "Hulking ape, icy blue, smashes walls", "Ape recolor"),
        ("stalker", "Stalker", px(1.1), "Hunched shadowy predator, long limbs, night hunter", "Base stalker"),
        ("shade", "Shade", px(0.9), "Ghostly pale stalker, semi-transparent", "Stalker tint"),
        ("mammoth", "Woolly Mammoth", px(1.6), "Huge tusked mammoth, shaggy brown coat", "Unique"),
        ("sabertooth", "Sabertooth", px(0.9), "Big cat with long fangs, muscular build", "Unique"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], med, [24, 26, 14, 76, 22])
    pdf.ln(2)

    pdf.sub_title("Megafauna - 8 species, ~5 base sprites", 8)
    pdf.sprite_group_box("Titan family: frost_titan + mountain_titan + ice_colossus = 1 base titan, 3 palettes.")
    pdf.sprite_group_box("ancient_brute = scaled ice_brute from medium. storm_titan = titan + lightning tint.")
    mega = [
        ("frost_titan", "Frost Titan", px(2.0), "Towering ice humanoid, crystal armor, slow", "Base titan"),
        ("mountain_titan", "Mountain Titan", px(3.0), "Enormous rocky giant, boulder fists", "Titan recolor"),
        ("ice_colossus", "Ice Colossus", px(2.8), "Massive frozen statue brought to life", "Titan recolor"),
        ("storm_titan", "Storm Titan", px(2.3), "Lightning-wreathed giant, crackling aura", "Titan + FX"),
        ("ancient_brute", "Ancient Brute", px(2.2), "Scarred elder ice_brute, massive arms", "Scaled brute"),
        ("thermal_wurm", "Thermal Wurm", px(1.8), "Giant burrowing worm, glowing hot segments", "Unique"),
        ("glacial_leviathan", "Glacial Leviathan", px(2.5), "Whale-sized ice creature, many legs", "Unique"),
        ("alpha_stalker", "Alpha Stalker", px(1.6), "Larger stalker, glowing eyes, fear aura", "Scaled stalker"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], mega, [28, 30, 14, 78, 22])

    pdf.add_page()
    pdf.sub_title("Eldritch Horrors - 5 unique sprites", 5)
    pdf.note("End-game creatures. These should all be unique and terrifying. No reuse.")
    eld = [
        ("the_hungering", "The Hungering", px(4.0), "Writhing mass of mouths and tendrils, ever-consuming", "Unique"),
        ("the_pale_thing", "The Pale Thing", px(3.5), "Gaunt bone-white entity, crown of antlers, hard to look at", "Unique"),
        ("the_thermophage", "The Thermophage", px(4.5), "Apex arthropod, cracked exoskeleton reveals molten core", "Unique"),
        ("that_which_sleeps", "That Which Sleeps", px(5.0), "Colossal frozen entity, oldest thing on Erebus, dormant power", "Unique"),
        ("fleshwalker", "Fleshwalker", px(2.5), "Fast void-black humanoid, elongated limbs, no face", "Unique"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], eld, [28, 28, 14, 88, 14])
    pdf.ln(3)

    pdf.sub_title("Swarm Creatures - 6 species, ~4 base sprites", 6)
    pdf.sprite_group_box("Insect pair: frost_beetle + skitterer = 1 base bug, recolor. ice_locust = winged variant.")
    pdf.sprite_group_box("giant_rat = tiny recolor of a simple rodent shape.")
    swarm = [
        ("frost_beetle", "Frost Beetle", px(0.3), "Armored insect, pincers, swarms in dozens", "Base bug"),
        ("skitterer", "Skitterer", px(0.35), "Fast many-legged bug, pale and frantic", "Bug recolor"),
        ("ice_locust", "Ice Locust", px(0.25), "Winged frost insect, buzzing swarms", "Bug+wings"),
        ("frost_wurm", "Frost Wurm", px(1.2), "Large burrowing worm, armored segments, breaches walls", "Unique"),
        ("spawnling", "Spawnling", px(0.6), "Small fleshy horror, skitters in packs at night", "Unique"),
        ("giant_rat", "Permafrost Rat", px(0.25), "Oversized rat, matted fur, swarms from tunnels", "Unique"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], swarm, [24, 26, 14, 90, 18])
    pdf.ln(3)

    pdf.sub_title("Eldritch Livestock: Egg-based - 5 species, 5 unique", 5)
    pdf.note("These are all distinct creature types (mammal, cephalopod, insectoid, void, serpent). Unique shapes.")
    eld_egg = [
        ("gore_shoat", "Gore Shoat", px(0.4), "Fleshy piglet-like creature, exposed muscle, red", "Unique"),
        ("weeping_calf", "Weeping Calf", px(0.5), "Ichor-dripping calf, translucent purple skin", "Unique"),
        ("husk_pup", "Husk Pup", px(0.35), "Chitinous insectoid puppy, armored plates, tan", "Unique"),
        ("void_minnow", "Void Minnow", px(0.15), "Tiny floating dark fish-like void creature", "Unique"),
        ("pit_wyrm", "Pit Wyrm", px(0.2), "Small serpent, dark red, venomous fangs", "Unique"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], eld_egg, [24, 28, 14, 92, 14])
    pdf.ln(2)

    pdf.sub_title("Eldritch Livestock: Spore-based - 4 species, ~2 base sprites", 4)
    pdf.sprite_group_box("Organic blobs: bile_mold + rot_bloom = 1 base blob, recolor. thorn_polyp + nerve_cluster = 1 base polyp.")
    eld_spore = [
        ("bile_mold", "Bile Mold", px(0.25), "Pulsing yellow-green fungal blob, oozes acid", "Base blob"),
        ("rot_bloom", "Rot Bloom", px(0.3), "Dark brown decaying flower-like growth", "Blob recolor"),
        ("thorn_polyp", "Thorn Polyp", px(0.3), "Spiny coral-like sessile creature, brown", "Base polyp"),
        ("nerve_cluster", "Nerve Cluster", px(0.2), "Purple pulsing brain-like mass, tendrils", "Polyp recolor"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], eld_spore, [24, 26, 14, 100, 10])
    pdf.ln(2)

    pdf.sub_title("Eldritch Growth Stages - 45 total, ~18 base sprites")
    pdf.sprite_group_box("5 growth stages per species, but larva/whelp can share 1 'small blob' per species.")
    pdf.sprite_group_box("Juvenile/mature/ancient are scaled versions - draw juvenile, scale up 1.8x and 3x.")
    pdf.note("9 species x 5 stages = 45. With scaling reuse: ~2 unique per species = ~18 base sprites.")
    stages = [
        ("Larva", px(0.3), "Tiny", "1 per species (simple)"),
        ("Whelp", px(0.5), "Small", "Scaled larva or unique"),
        ("Juvenile", px(1.0), "Medium", "Base drawing (key frame)"),
        ("Mature", px(1.8), "Large", "Scaled juvenile + detail"),
        ("Ancient", px(3.0), "Huge", "Scaled juvenile + more detail"),
    ]
    pdf.table(["Stage", "Sprite", "Size Class", "Sprite Approach"], stages, [25, 18, 22, 80])

    # =========================================================================
    # 4. BOSSES
    # =========================================================================
    pdf.add_page()
    pdf.section_title("4. BOSSES")
    pdf.sprite_group_box("Bosses that share a base creature can reuse that sprite at larger scale + unique details.")
    pdf.sprite_group_box("frost_titan boss = megafauna frost_titan + crown/glow. the_stalker = alpha_stalker + FX.")
    pdf.note("Named encounters with multi-phase combat. Each phase may add visual tells (glowing eyes, cracks, etc).\n10 bosses, ~7 need unique sprites. 3 can reuse base creature + boss overlay.")
    bosses = [
        ("frost_titan", "Frost Titan", px(2.0), "Crowned ice giant, multi-phase ice attacks", "Mega+FX"),
        ("thermal_wurm", "Thermal Wurm", px(1.8), "Giant burrowing worm, glowing hot, bursts from ground", "Mega+FX"),
        ("glacial_leviathan", "Glacial Leviathan", px(2.5), "Enormous ice beast, ancient and slow, devastating", "Mega+FX"),
        ("the_bull", "Ice Brute King", px(2.2), "Scarred brute king, bone crown, charges", "Brute+crown"),
        ("the_stalker", "Alpha Stalker", px(1.6), "Master predator, glowing red eyes, stealth", "Stalker+FX"),
        ("mountain_titan_boss", "Mountain Titan", px(3.0), "Building-sized rocky giant, seismic attacks", "Mega+FX"),
        ("iron_carapace_boss", "Iron Empress", px(2.8), "Thermovore queen, reinforced shell plating, summons bore beetles", "Beetle+FX"),
        ("the_hungering_boss", "The Hungering", px(4.0), "4-phase abomination, grows mouths each phase", "Unique"),
        ("the_thermophage_boss", "The Thermophage", px(4.5), "Apex thermovore, cracked exoskeleton, glowing core, 4-phase", "Unique"),
        ("that_which_sleeps", "That Which Sleeps", px(5.0), "FINAL BOSS: frozen god awakens, 4 phases", "Unique"),
    ]
    pdf.table(["ID", "Name", "Sprite", "Description", "Work"], bosses, [32, 28, 14, 88, 18])
    pdf.ln(1)
    pdf.note("Boss drop items (10) need inventory icons - small colored gems/trophies, easy to batch.")

    # =========================================================================
    # 5. MEGABEASTS
    # =========================================================================
    pdf.ln(2)
    pdf.section_title("5. PROCEDURAL MEGABEASTS")
    pdf.sprite_group_box("10 base body form silhouettes. Materials = palette swap / texture overlay. NOT 100 sprites.")
    pdf.note("RimWorld approach: draw 10 distinct creature silhouettes (forms), then apply 10 color palettes.\n10 drawings + 10 palettes = 100 visual combinations.")

    pdf.sub_title("Body Forms - 10 unique silhouettes")
    pdf.bullet_list(["Serpent - long sinuous body", "Arachnid - 8-legged",
                      "Titan - large humanoid", "Swarm Host - bloated spawner",
                      "Crawler - low centipede", "Leviathan - massive whale-like",
                      "Giant - tall humanoid", "Stalker - hunched predator",
                      "Colossus - thick armored", "Wraith - ghostly floating"])
    pdf.ln(1)

    pdf.sub_title("Body Materials - 10 palette/texture swaps")
    pdf.sprite_group_box("These are NOT separate drawings. Just color palettes applied to the forms above.")
    pdf.bullet_list(["Living Ice - translucent blue-white", "Obsidian - glossy black",
                      "Frozen Gas - misty blue-green", "Crystal - faceted, prismatic",
                      "Iron Flesh - dark metallic red", "Volcanic Stone - dark gray + orange cracks",
                      "Bone Chitin - off-white/cream", "Void Matter - deep purple-black",
                      "Permafrost - gray-blue", "Rotting Flesh - mottled green-brown"])
    pdf.ln(1)

    pdf.sub_title("Attack VFX - 10 effect animations")
    pdf.note("These are particle/overlay effects, not creature sprites. Some can share bases.")
    pdf.sprite_group_box("Frost Breath + Ice Shards + Blizzard Form all use ice particle base with different spread.")
    pdf.bullet_list(["Frost Breath - cone of ice", "Toxic Spores - green cloud",
                      "Seismic Stomp - ground crack ring", "Acid Spray - green arc",
                      "Void Howl - purple shockwave", "Ice Shards - projectile burst",
                      "Soul Rend - dark slash", "Fear Scream - distortion wave",
                      "Ground Devour - hole/crack", "Blizzard Form - swirling ice aura"])

    # =========================================================================
    # 6. LAIRS
    # =========================================================================
    pdf.add_page()
    pdf.section_title("6. CREATURE LAIRS")
    pdf.sprite_group_box("3 base lair types: cave mouth, animal den, nest. 8 lairs = recolor/resize of these 3.")
    pdf.note("Each needs: intact, damaged, destroyed states = 3 base x 3 states = 9 sprites total.")
    lairs = [
        ("Tundra Wolf Lair", "Den", "Shallow dirt den, paw prints, gray-brown earth mound"),
        ("Dire Wolf Lair", "Den", "Larger darker den, scattered bones around entrance"),
        ("Glacier Bear Lair", "Cave", "Rocky cave mouth, large opening, claw marks on stone"),
        ("Ice Stalker Lair", "Cave", "Icy cave, blue frost around entrance, frozen ground"),
        ("Ice Brute Lair", "Cave", "Massive frost-covered cave, broken trees nearby"),
        ("Snow Ape Lair", "Nest", "Pile of branches/debris, organic nest mound"),
        ("Stalker Lair", "Den", "Dark shadowy hollow, hard to see, ominous"),
        ("Sabertooth Lair", "Den", "Den with scattered prey bones, fang-scored rocks"),
    ]
    pdf.table(["Lair", "Base", "Description"], lairs, [32, 14, 106])

    # =========================================================================
    # 7. RAIDERS
    # =========================================================================
    pdf.add_page()
    pdf.section_title("7. HUMANOID RAIDERS")
    pdf.sprite_group_box("1 base humanoid raider model (colonist variant). Faction = outfit color/gear overlay.")
    pdf.sprite_group_box("Within each faction, troops share 1 base + weapon/armor detail swap.")
    pdf.note("15 raider types across 4 factions. All humanoid - share colonist base model.\nDifferentiation via outfit color, gear overlay, and weapon attachment.")

    pdf.sub_title("Outlaw Faction - 4 types, 1 base + gear overlays", 4)
    pdf.color_swatch_row("Outlaw outfit palette:", [
        (120, 90, 60, "Thug (base)"),
        (100, 80, 50, "Brawler"),
        (80, 80, 90, "Gunner"),
        (60, 70, 80, "Marksman"),
    ])
    outlaws = [
        ("outlaw_thug", "Outlaw Thug", "50 HP", "Ragged melee fighter, improvised weapon", "Base outlaw"),
        ("outlaw_brawler", "Outlaw Brawler", "80 HP", "Heavier melee, leather armor, chain weapon", "Outlaw+armor"),
        ("outlaw_gunner", "Outlaw Gunner", "45 HP", "Light ranged, pistol, scavenged vest", "Outlaw+gun"),
        ("outlaw_marksman", "Outlaw Marksman", "40 HP", "Sniper with scope, hooded cloak", "Outlaw+scope"),
    ]
    pdf.table(["ID", "Name", "Stats", "Description", "Work"], outlaws, [28, 26, 14, 94, 22])
    pdf.ln(2)

    pdf.sub_title("Scavenger Crews - 3 types", 3)
    scavs = [
        ("scav_militia", "Scav Militia", "60 HP", "Patched gear, mixed melee, brown coats", "Base scav"),
        ("scav_scrapper", "Scav Scrapper", "90 HP", "Armored scrapyard fighter, heavy melee", "Scav+armor"),
        ("scav_sharpshooter", "Scav Sharpshooter", "50 HP", "Ranged with hunting rifle, camouflage", "Scav+rifle"),
    ]
    pdf.table(["ID", "Name", "Stats", "Description", "Work"], scavs, [30, 30, 14, 90, 20])
    pdf.ln(2)

    pdf.sub_title("Mammona Logistics - 2 types", 2)
    mammona = [
        ("mammona_enforcer", "Mammona Enforcer", "70 HP", "Corporate soldier, dark gray/red uniform, sidearm", "Base corp"),
        ("mammona_heavy", "Mammona Heavy", "100 HP", "Heavy armor, assault weapon, red visor", "Corp+heavy"),
    ]
    pdf.table(["ID", "Name", "Stats", "Description", "Work"], mammona, [30, 30, 14, 90, 20])
    pdf.ln(2)

    pdf.sub_title("Mastema Incorporated - 3 types", 3)
    mastema = [
        ("mastema_operative", "Mastema Operative", "80 HP", "Elite soldier, black tactical gear, precise", "Base tac"),
        ("mastema_sniper", "Mastema Sniper", "50 HP", "Long-range specialist, ghillie/camo, scoped", "Tac+scope"),
        ("mastema_breacher", "Mastema Breacher", "120 HP", "Heavy armor, breaching charges, shield", "Tac+heavy"),
    ]
    pdf.table(["ID", "Name", "Stats", "Description", "Work"], mastema, [30, 30, 14, 90, 20])
    pdf.ln(2)

    pdf.sub_title("Precursor Survivors - 3 types, unique look", 3)
    pdf.note("End-game raiders. Should look distinctly different from other factions - alien/ancient tech aesthetic.")
    precursor = [
        ("precursor_scout", "Precursor Scout", "90 HP", "Ancient-tech armor, glowing visor, fast", "Unique base"),
        ("precursor_warrior", "Precursor Warrior", "150 HP", "Heavy ancient plate, energy melee weapon", "Precursor+heavy"),
        ("precursor_sage", "Precursor Sage", "70 HP", "Robed, energy staff, ranged abilities", "Precursor+robes"),
    ]
    pdf.table(["ID", "Name", "Stats", "Description", "Work"], precursor, [30, 30, 14, 90, 20])
    pdf.note("\nRaiders total: 15 types, ~6 unique bases (1 per faction + 2 precursor). Rest are gear overlays.")

    # =========================================================================
    # 8. NPCs
    # =========================================================================
    pdf.ln(3)
    pdf.section_title("8. NPCs & MERCHANTS")
    pdf.sprite_group_box("1 base humanoid merchant model. 3 faction outfits = clothing overlay color swaps.")
    pdf.note("Same colonist-style base. Faction identity through outfit color + emblem.")
    npcs = [
        ("scavenger", "Scavenger Caravan", "Scavenger Crews", "Rugged traders in patched brown coats, pack animals"),
        ("equipment", "Equipment Trader", "Mastema Ops", "Corporate soldiers in dark gray/red uniforms, armed"),
        ("exotic", "Rim Runner Trader", "Rim Runners", "Explorers in blue/white parkas, exotic wares on sled"),
    ]
    pdf.table(["ID", "Name", "Faction", "Description"], npcs, [24, 30, 30, 88])

    # =========================================================================
    # 9. BUILDINGS
    # =========================================================================
    pdf.add_page()
    pdf.section_title("9. BUILDINGS")
    pdf.note("RimWorld approach: many buildings share a base housing/frame sprite with different\ninterior detail or color accent. Idle + active/operating states where applicable.")

    pdf.sub_title("Heating & Thermal - 2 unique + 1 reuse", 3)
    pdf.sprite_group_box("steam_hub = heater base + pipe detail.")
    heat = [
        ("campfire", "Campfire", "Stone ring with burning logs, animated flames", "Unique"),
        ("heater", "Thermal Heater", "Metal box radiator with glowing coils, vents steam", "Unique"),
        ("steam_hub", "Steam Hub", "Cylindrical pipe hub, radiates heat outward, steaming", "Heater var."),
    ]
    pdf.table(["ID", "Name", "Description", "Work"], heat, [24, 28, 108, 20])
    pdf.ln(2)

    pdf.sub_title("Ventilation - 1 base + 2 variants", 3)
    pdf.sprite_group_box("1 vent grille base. intake = arrows in, exhaust = arrows out, purifier = + machine detail.")
    vent = [
        ("air_intake", "Air Intake", "Wall-mounted grille, pulls air in from outside", "Base vent"),
        ("air_exhaust", "Air Exhaust", "Wall-mounted grille, pushes stale air out", "Vent recolor"),
        ("air_purifier", "Air Purifier", "Vent + attached filter machine box, fans visible, 15W", "Vent+box"),
    ]
    pdf.table(["ID", "Name", "Description", "Work"], vent, [24, 24, 114, 20])
    pdf.ln(2)

    pdf.sub_title("Furniture - 4 unique", 4)
    furn = [
        ("bed", "Bed", "Simple cot with blanket+pillow, empty/occupied/owned states", "Unique"),
        ("memorial", "Memorial", "Stone grave marker/tombstone, small wreath at base", "Unique"),
        ("farm_plot", "Farm Plot", "Tilled dark soil rectangle, planting rows visible", "Unique"),
        ("greenhouse", "Greenhouse", "Glass-walled growing structure with heating element, 15W", "Unique"),
    ]
    pdf.table(["ID", "Name", "Description", "Work"], furn, [24, 24, 120, 14])
    pdf.ln(2)

    pdf.sub_title("Decorations - 4 unique", 4)
    pdf.note("Small props. Simple sprites.")
    deco = [
        ("shelf", "Shelf", "+2", "Wooden wall shelf with a few items/books on it"),
        ("rug", "Rug", "+3", "Woven floor rug, patterned textile, warm colors"),
        ("painting", "Painting", "+5", "Framed painting on wall, landscape or abstract"),
        ("trophy_mount", "Trophy Mount", "+8", "Mounted creature head/horns on wall plaque"),
    ]
    pdf.table(["ID", "Name", "Beauty", "Description"], deco, [26, 28, 14, 84])
    pdf.ln(2)

    pdf.sub_title("Colony Growth - 2 unique", 2)
    pdf.bullet_list(["cloning_vat - 30W, needs active/growing glow states",
                      "radio_beacon - 15W, needs active antenna pulse"])

    pdf.add_page()
    pdf.sub_title("Production Machines - 14 total, ~8 unique bases", 14)
    pdf.sprite_group_box("Workstation family: workbench + loom + tannery = 1 base table, swap top detail/color.")
    pdf.sprite_group_box("Furnace family: smelter + forge + refinery = 1 base furnace, swap glow color/size.")
    pdf.sprite_group_box("Food family: kitchen + smokehouse + butcher_table = 1 base counter, swap props.")
    machines = [
        ("sawmill", "Sawmill", "Circular saw blade on wood frame, log pile beside it", "Unique"),
        ("smelter", "Smelter", "Brick furnace with chimney, orange glow inside, 25W", "Base furnace"),
        ("forge", "Forge", "Anvil + bellows + hot coals, bright orange, 30W", "Furnace var."),
        ("refinery", "Refinery", "Industrial furnace with pipes/tanks, 35W", "Furnace var."),
        ("kitchen", "Kitchen", "Counter with pots/pans, cutting board, hanging utensils", "Base counter"),
        ("smokehouse", "Smokehouse", "Enclosed counter with smoke rising, meat hanging", "Counter var."),
        ("butcher_table", "Butcher Table", "Blood-stained counter, cleaver, meat hooks", "Counter var."),
        ("workbench", "Workbench", "Sturdy table with tools, vise, scattered parts", "Base table"),
        ("loom", "Loom", "Wooden frame loom with stretched threads, shuttle", "Table var."),
        ("tannery", "Tannery", "Table with stretched hides, scraping tools, rack", "Table var."),
        ("drug_lab", "Drug Lab", "Table with beakers, tubes, burner, bubbling, 15W", "Unique"),
        ("surgery_table", "Surgery Table", "Medical bed, overhead light, sterile, 10W", "Unique"),
        ("deep_drill", "Deep Drill", "Large drill rig, spinning bit into ground, 50W", "Unique"),
        ("research_bench", "Research Bench", "Desk with books, microscope, notes, lamp, 10W", "Unique"),
    ]
    pdf.table(["ID", "Name", "Description", "Work"], machines, [24, 28, 112, 18])
    pdf.ln(3)

    pdf.sub_title("Power Generation - 20 total, ~10 unique bases", 20)
    pdf.sprite_group_box("Fire family: fire_pit + deep_fire_pit + coal_burner + gas_burner = 1 base pit, scale/color.")
    pdf.sprite_group_box("Manned family: hand_crank + treadmill + chain_gang_wheel = 1 base wheel, scale.")
    pdf.sprite_group_box("Reactor family: bio_reactor + mini_reactor + nuclear_reactor = 1 base reactor, scale + glow.")
    pdf.sprite_group_box("Burner family: chemical_burner + ichor_burner + waste_incinerator = 1 industrial burner, recolor.")
    gens = [
        ("fire_pit", "Fire Pit", "15W", "Stone-ringed fire pit, burning wood/coal", "Base pit"),
        ("deep_fire_pit", "Deep Fire Pit", "20W", "Larger sunken fire pit, more flames", "Pit+scale"),
        ("coal_burner", "Coal Burner", "30W", "Enclosed fire pit with chimney stack", "Pit+chimney"),
        ("gas_burner", "Gas Burner", "45W", "Fire pit with gas pipe feed, blue flame", "Pit+pipes"),
        ("hand_crank", "Hand Crank", "12W", "Small hand-operated wheel generator", "Base wheel"),
        ("treadmill", "Treadmill Gen", "25W", "Larger hamster-wheel style, colonist-powered", "Wheel+size"),
        ("chain_gang_wheel", "Chain Gang Wheel", "50W", "Massive 3-person wheel, industrial", "Wheel+big"),
        ("solar_panel", "Solar Panel", "40W", "Flat angled panel on frame, reflective surface", "Unique"),
        ("wind_turbine", "Wind Turbine", "55W", "Tall pole with spinning blades on top", "Unique"),
        ("thermopile", "Thermopile", "25W", "Flat metal plate array, harvests temp difference", "Unique"),
        ("bio_reactor", "Bio Reactor", "35W", "Glass tank with green organic matter, bubbles", "Base reactor"),
        ("mini_reactor", "Mini Reactor", "90W", "Small shielded reactor, blue core glow", "Reactor+glow"),
        ("nuclear_reactor", "Nuclear Reactor", "250W", "Large reactor vessel, yellow warning, cooling", "Reactor+big"),
        ("chemical_burner", "Chemical Burner", "60W", "Industrial burner, barrel fuel, dark smoke", "Base burner"),
        ("ichor_burner", "Ichor Burner", "55W", "Alien-fed burner, purple glow, dripping", "Burner+purple"),
        ("waste_incinerator", "Waste Incinerator", "40W", "Trash burner, gray smoke, conveyor feed", "Burner+gray"),
        ("geothermal", "Geothermal Vent", "120W", "Capped natural vent, steam escaping, pipes", "Unique"),
        ("steam_turbine", "Steam Turbine", "65W", "Enclosed turbine housing, spinning, steam pipes", "Unique"),
        ("hydrogen_cell", "Hydrogen Cell", "70W", "Sleek fuel cell unit, LED indicators", "Unique"),
        ("lightning_rod", "Lightning Rod", "200W", "Tall metal rod with capacitor banks at base", "Unique"),
    ]
    pdf.table(["ID", "Name", "Out", "Description", "Work"], gens, [30, 28, 14, 94, 18])

    pdf.add_page()
    pdf.sub_title("Central Reactor (Frostpunk-style)", 1)
    pdf.note("Unique centerpiece building. 4 power levels with visual escalation + overdrive glow.")
    pdf.bullet_list([
        "reactor_gen - Base reactor structure (unique, prominent sprite)",
        "Power level 1 (low) - dim glow",
        "Power level 2 (med) - orange glow",
        "Power level 3 (high) - bright orange",
        "Power level 4 (max) - white-hot glow",
        "Overdrive state - pulsing red warning + steam FX",
    ])
    pdf.note("Power level visuals can be glow overlays on 1 base structure, not separate sprites.")
    pdf.ln(2)

    pdf.sub_title("Logistics: Conveyors - 2 types, directional", 2)
    pdf.sprite_group_box("1 belt sprite x 4 rotations + 1 splitter sprite x 4 rotations. Animated belt movement.")
    pdf.bullet_list(["belt - straight + corner + junction variants, 4 directions",
                      "splitter - belt + split arrow indicator, 4 directions"])
    pdf.ln(1)

    pdf.sub_title("Logistics: Inserters - 1 base + 2 recolors", 3)
    pdf.sprite_group_box("1 base arm/crane sprite. basic = gray, fast = blue, filter = green/orange.")
    pdf.color_swatch_row("Inserter colors:", [
        (140, 140, 145, "Basic (base)"),
        (60, 120, 200, "Fast"),
        (80, 180, 80, "Filter"),
    ])
    ins = [
        ("basic_inserter", "Basic Inserter", "5W", "2.0s", "Base arm (gray)"),
        ("fast_inserter", "Fast Inserter", "5W", "0.5s", "Recolor (blue)"),
        ("filter_inserter", "Filter Inserter", "5W", "1.0s", "Recolor (green)"),
    ]
    pdf.table(["ID", "Name", "Power", "Speed", "Sprite Work"], ins, [30, 30, 14, 14, 56])
    pdf.ln(2)

    pdf.sub_title("Logistics: Pipes & Ducts - 6 types, 2 bases", 6)
    pdf.sprite_group_box("1 base pipe sprite (round cross-section) + 1 base duct sprite (square).")
    pdf.sprite_group_box("Size = line width change. Insulated/sealed = add wrapping detail. Connection shapes shared.")
    pipes = [
        ("small_pipe", "Small Pipe", "Fluid", "Base pipe (thin)"),
        ("large_pipe", "Large Pipe", "Fluid", "Pipe (thicker)"),
        ("insulated_pipe", "Insulated Pipe", "Fluid", "Pipe + wrap detail"),
        ("small_duct", "Small Duct", "Gas", "Base duct (thin)"),
        ("large_duct", "Large Duct", "Gas", "Duct (thicker)"),
        ("sealed_duct", "Sealed Duct", "Gas", "Duct + seal detail"),
    ]
    pdf.table(["ID", "Name", "Medium", "Sprite Work"], pipes, [28, 32, 18, 66])
    pdf.note("All pipes/ducts need: straight, corner, T-junction, cross connector sprites.\nFrozen overlay + burst/leak FX overlay (shared across all types).")
    pdf.ln(2)

    pdf.sub_title("Logistics: Tanks - 4 types, 2 bases", 4)
    pdf.sprite_group_box("1 fluid tank base (cylinder) small/large = scale. 1 gas tank base, canister/pressurized = scale.")
    tanks = [
        ("fluid_tank_small", "Small Fluid Tank", "200", "Base tank (small)"),
        ("fluid_tank_large", "Large Fluid Tank", "800", "Tank scaled up"),
        ("gas_canister", "Gas Canister", "150", "Base canister"),
        ("pressurized_tank", "Pressurized Tank", "500", "Canister + gauge"),
    ]
    pdf.table(["ID", "Name", "Capacity", "Sprite Work"], tanks, [32, 38, 24, 50])
    pdf.ln(2)

    pdf.sub_title("Logistics: Processors - 7 total, ~4 unique", 7)
    pdf.sprite_group_box("Industrial box family: oil_refinery + coolant_refiner + waste_processor = 1 base + pipe color.")
    procs = [
        ("water_pump", "Water Pump", "15W", "Unique (well/pump)"),
        ("oil_refinery", "Oil Refinery", "35W", "Base ind. box (dark)"),
        ("coolant_refiner", "Coolant Refiner", "20W", "Ind. box (cyan)"),
        ("waste_processor", "Waste Processor", "12W", "Ind. box (brown)"),
        ("ichor_converter", "Ichor Converter", "10W", "Unique (alien tech)"),
        ("gas_separator", "Gas Separator", "25W", "Unique (tall column)"),
        ("steam_boiler", "Steam Boiler", "0", "Unique (boiler + steam)"),
    ]
    pdf.table(["ID", "Name", "Power", "Sprite Work"], procs, [30, 34, 16, 64])

    # =========================================================================
    # 10. DEFENSES
    # =========================================================================
    pdf.add_page()
    pdf.section_title("10. DEFENSES")

    pdf.sub_title("Turrets - 17 total, ~8 unique bases", 17)
    pdf.sprite_group_box("RimWorld style: 1 turret base pedestal shared by all. Swap the weapon/barrel on top.")
    pdf.sprite_group_box("Ballistic family: gun + minigun + shotgun + autocannon + heavy_mg = 1 base, 5 barrels.")
    pdf.sprite_group_box("Primitive pair: ballista + crossbow = 1 wooden frame, different bowstring/bolt.")
    pdf.sprite_group_box("Area family: mortar + rocket + grenade_launcher = 1 base platform, different tube.")
    pdf.sprite_group_box("Energy family: laser + tesla + cryo = 1 tech base, different emitter tip + FX color.")

    # Turret visual example
    pdf.check_page_break(30)
    pdf.set_font("Helvetica", "B", 8)
    pdf.set_text_color(60, 60, 60)
    pdf.cell(0, 6, "Example: Turret base + barrel swap (RimWorld style)", new_x="LMARGIN", new_y="NEXT")
    bx = pdf.get_x() + 5
    by = pdf.get_y()
    pdf.set_fill_color(245, 245, 250)
    pdf.set_draw_color(180, 180, 190)
    pdf.set_line_width(0.3)
    pdf.rect(bx, by, 180, 28, style="DF")
    # Base pedestal (shared)
    pdf.set_fill_color(100, 100, 110)
    pdf.set_draw_color(60, 60, 70)
    pdf.set_line_width(0.5)
    pdf.rect(bx + 8, by + 14, 16, 10, style="DF")
    pdf.set_font("Helvetica", "B", 5)
    pdf.set_text_color(255, 255, 255)
    pdf.set_xy(bx + 8, by + 17)
    pdf.cell(16, 5, "BASE", align="C")
    pdf.set_font("Helvetica", "", 5)
    pdf.set_text_color(80, 80, 80)
    pdf.set_xy(bx + 4, by + 25)
    pdf.cell(24, 4, "Shared pedestal", align="C")
    # Plus sign
    pdf.set_font("Helvetica", "B", 12)
    pdf.set_text_color(100, 100, 100)
    pdf.set_xy(bx + 28, by + 12)
    pdf.cell(10, 10, "+", align="C")
    # Barrel variants
    barrels = [
        (42, "Gun", (80, 80, 90)),
        (66, "Minigun", (70, 75, 85)),
        (90, "Laser", (40, 120, 200)),
        (114, "Tesla", (160, 120, 40)),
        (138, "Cryo", (80, 180, 200)),
    ]
    for boff, bname, (br, bg, bb) in barrels:
        pdf.set_fill_color(br, bg, bb)
        pdf.set_draw_color(max(0, br-30), max(0, bg-30), max(0, bb-30))
        pdf.rect(bx + boff, by + 6, 4, 12, style="DF")  # barrel
        pdf.set_fill_color(100, 100, 110)
        pdf.rect(bx + boff - 4, by + 14, 12, 10, style="DF")  # base copy
        pdf.set_font("Helvetica", "", 5)
        pdf.set_text_color(80, 80, 80)
        pdf.set_xy(bx + boff - 6, by + 25)
        pdf.cell(16, 4, bname, align="C")
    # Equals
    pdf.set_font("Helvetica", "B", 10)
    pdf.set_text_color(100, 100, 100)
    pdf.set_xy(bx + 158, by + 12)
    pdf.cell(20, 8, "= 17", align="C")
    pdf.set_font("Helvetica", "", 5)
    pdf.set_xy(bx + 156, by + 20)
    pdf.cell(24, 4, "turrets total", align="C")
    pdf.set_xy(10, by + 30)

    pdf.note("Each turret = shared base + unique barrel/emitter sprite. Barrel rotates to target.\nBase sprites needed: 1 pedestal + ~8 distinct weapon tops + muzzle FX per type.")
    turrets = [
        ("turret_ballista", "Ballista", "T1", "Wooden frame siege bow, large bolt loaded", "Wood base"),
        ("turret_crossbow", "Auto-Crossbow", "T1", "Smaller auto-loading crossbow on tripod", "Wood var."),
        ("turret_gun", "Gun Turret", "T2", "Metal pedestal + single rotating gun barrel", "Metal base"),
        ("turret_minigun", "Minigun Turret", "T2", "Pedestal + spinning multi-barrel gatling", "Same+barrel"),
        ("turret_shotgun", "Shotgun Turret", "T2", "Pedestal + short wide-bore barrel", "Same+barrel"),
        ("turret_autocannon", "Autocannon", "T2", "Pedestal + long heavy barrel, ammo box", "Same+barrel"),
        ("turret_heavy_mg", "Heavy MG Nest", "T2", "Sandbag nest + belt-fed machine gun", "Same+barrel"),
        ("turret_sniper", "Sniper Nest", "T2", "Elevated platform + long scoped rifle", "Same+barrel"),
        ("mortar", "Mortar", "T2", "Ground platform + angled tube, shell stack", "Platform"),
        ("turret_rocket", "Rocket Turret", "T2", "Platform + multi-tube rocket launcher", "Platform var."),
        ("turret_grenade_launcher", "Grenade Lnchr", "T2", "Platform + rotating drum launcher", "Platform var."),
        ("turret_laser", "Laser Turret", "T3", "Sleek tech pedestal + lens/crystal emitter", "Tech base"),
        ("turret_tesla", "Tesla Coil", "T3", "Tech pedestal + tall copper coil, arcing", "Tech var."),
        ("turret_flamethrower", "Flamethrower", "T3", "Tech pedestal + fuel tank + nozzle", "Tech var."),
        ("turret_cryo", "Cryo Turret", "T3", "Tech pedestal + frost emitter, icy mist", "Tech var."),
        ("turret_railgun", "Railgun", "T4", "Heavy reinforced base + long magnetic rail", "Heavy base"),
        ("turret_emp", "EMP Cannon", "T4", "Heavy base + satellite dish emitter", "Heavy var."),
    ]
    pdf.table(["ID", "Name", "Tier", "Description", "Work"], turrets, [34, 26, 8, 96, 18])

    pdf.add_page()
    pdf.sub_title("Traps - 19 total, ~8 unique bases", 19)
    pdf.sprite_group_box("Damage traps: spike + deadfall + spring_blade + punji_pit = 1 ground hole/plate, swap innards.")
    pdf.sprite_group_box("Hold traps: snare + bear_trap = 1 jaw mechanism, size swap.")
    pdf.sprite_group_box("Explosive family: tripwire_ied + claymore + frag_mine + napalm_mine = 1 mine base, color swap.")
    pdf.sprite_group_box("Elemental mines: emp_mine + cryo_mine + acid_trap = mine base, different glow color.")
    pdf.note("Each trap: hidden (flush with ground), armed (subtle detail), triggered (open/sprung).\n3 states per base = ~24 state sprites from ~8 bases.")
    traps = [
        ("spike_trap", "Spike Trap", "T1", "Hidden floor plate, spikes pop up when triggered", "Base plate"),
        ("deadfall_trap", "Deadfall Trap", "T1", "Weighted stone/log drops on victim from above", "Plate var."),
        ("spring_blade", "Spring Blade", "T2", "Hidden blade swings out from ground slot", "Plate var."),
        ("punji_pit_trap", "Punji Pit", "T2", "Covered pit with sharpened stakes at bottom", "Plate+pit"),
        ("pit_trap", "Pit Trap", "T1", "Covered hole in ground, victim falls in", "Unique"),
        ("snare_trap", "Snare Trap", "T1", "Rope/wire loop on ground, catches legs", "Base snare"),
        ("bear_trap", "Bear Trap", "T2", "Metal jaw trap, spring-loaded, teeth visible", "Snare metal"),
        ("caltrops_trap", "Caltrops", "T1", "Scattered small metal spikes on ground", "Unique"),
        ("tripwire_alarm", "Tripwire Alarm", "T1", "Thin wire across path connected to bell/alarm", "Unique"),
        ("razor_wire", "Razor Wire", "T2", "Coiled barbed wire barrier, sharp edges", "Unique"),
        ("tripwire_ied", "Tripwire IED", "T2", "Small explosive + thin trip wire across path", "Base mine"),
        ("claymore_trap", "Claymore", "T2", "Directional mine, flat box facing outward", "Mine recolor"),
        ("frag_mine", "Frag Mine", "T3", "Buried disc mine, pressure-activated, shrapnel", "Mine recolor"),
        ("napalm_mine", "Napalm Mine", "T3", "Mine with incendiary payload, orange markings", "Mine orange"),
        ("fire_trap", "Fire Pit Trap", "T2", "Hidden fuel reservoir ignites when triggered", "Base fire"),
        ("incendiary_trap", "Incendiary Trap", "T3", "Tech fire trap, chemical igniter, hotter", "Fire+tech"),
        ("emp_mine", "EMP Mine", "T3", "Electronic mine, blue indicator light, disables", "Mine+blue"),
        ("cryo_mine", "Cryo Mine", "T3", "Freezing mine, cyan frost around it, slows", "Mine+cyan"),
        ("acid_trap", "Acid Trap", "T3", "Corrosive liquid trap, green bubbling reservoir", "Mine+green"),
        ("gas_trap", "Gas Trap", "T3", "Pressurized canister releases poison cloud", "Unique"),
    ]
    pdf.table(["ID", "Name", "Tier", "Description", "Work"], traps, [28, 24, 8, 108, 18])
    pdf.ln(2)

    pdf.sub_title("Fortifications - 4 total, 1 base + 3 progression", 4)
    pdf.sprite_group_box("1 barrier shape that gets progressively beefier: bags -> metal sheets -> steel plates -> bunker walls.")
    pdf.color_swatch_row("Cover progression:", [
        (180, 160, 120, "Sandbag (base)"),
        (130, 135, 140, "Barricade"),
        (100, 105, 115, "Steel"),
        (80, 85, 90, "Bunker"),
    ])
    forts = [
        ("sandbag", "Sandbag", "40%", "Stacked cloth sandbags, waist-height, crouching cover"),
        ("barricade", "Barricade", "60%", "Welded metal sheet barrier, chest-height, riveted"),
        ("steel_barrier", "Steel Barrier", "75%", "Thick reinforced steel wall section, heavy bolts"),
        ("bunker", "Bunker", "85%", "Concrete bunker wall, embrasure slot, very thick"),
    ]
    pdf.table(["ID", "Name", "Cover", "Description"], forts, [24, 24, 14, 90])
    pdf.ln(2)

    pdf.sub_title("Special Defense - 2 unique", 2)
    pdf.bullet_list(["watchtower - Unique (elevated platform with lookout)",
                      "shield_generator - Unique (50W, needs active dome FX overlay)"])

    # =========================================================================
    # 11. AGRICULTURE
    # =========================================================================
    pdf.add_page()
    pdf.section_title("11. AGRICULTURE")
    pdf.sprite_group_box("Generic growth frames: 1 seed, 1 sprout, 1 mid-growth shared across most crops.")
    pdf.sprite_group_box("Only mature + harvest stages need unique per-crop leaf/fruit shape and color.")
    pdf.note("14 crops x 5 stages = 70 total. With shared early stages: ~3 shared + 14x2 unique = ~31 sprites.")

    pdf.sub_title("Food Crops", 4)
    food_crops = [
        ("ice_rice", "Ice Rice", "200s", "Short pale grain stalks, cold-hardy rice paddy, blue-green"),
        ("frost_potatoes", "Frost Potatoes", "360s", "Low leafy plant, tubers visible at base, hardy"),
        ("tundra_corn", "Tundra Corn", "600s", "Tall stalks with frost-dusted cobs, slow growing"),
        ("thermal_berries", "Thermal Berries", "280s", "Low berry bush, red clusters, warm-toned leaves"),
    ]
    pdf.table(["ID", "Name", "Grow", "Description (mature stage)"], food_crops, [30, 28, 16, 108])
    pdf.ln(1)

    pdf.sub_title("Special Food", 2)
    special_crops = [
        ("alien_fungus", "Alien Fungus", "420s", "Purple alien mushrooms, bioluminescent caps, no light needed"),
        ("haygrass", "Haygrass", "180s", "Tall golden grass, fast growing, animal feed"),
    ]
    pdf.table(["ID", "Name", "Grow", "Description (mature stage)"], special_crops, [30, 28, 16, 108])
    pdf.ln(1)

    pdf.sub_title("Industrial Crops", 3)
    ind_crops = [
        ("healroot", "Healroot", "500s", "Green herb with white flower clusters, medicinal"),
        ("fiber_vine", "Fiber Vine", "400s", "Climbing brown vine, thick fibrous stems, strong"),
        ("frostweed", "Frostweed", "900s", "Pale blue-white fibrous plant, cold-loving, slow"),
    ]
    pdf.table(["ID", "Name", "Grow", "Description (mature stage)"], ind_crops, [30, 28, 16, 108])
    pdf.ln(1)

    pdf.sub_title("Drug Crops", 3)
    drug_crops = [
        ("psychoid_plant", "Psychoid Plant", "400s", "Dark green leafy plant, serrated leaves, drug crop"),
        ("smokeleaf_plant", "Smokeleaf Plant", "300s", "Light green broad-leaf plant, aromatic, drug crop"),
        ("hops_plant", "Hops", "320s", "Climbing vine with yellow-green cone-shaped flowers"),
    ]
    pdf.table(["ID", "Name", "Grow", "Description (mature stage)"], drug_crops, [30, 28, 16, 108])
    pdf.ln(1)
    pdf.note("Growth stages: (1) Seed/bare soil, (2) Sprout, (3) Growing, (4) Mature, (5) Harvest-ready.\nStages 1-2 can be generic across crops. Stage 3 semi-generic. Stages 4-5 crop-specific.")

    # =========================================================================
    # 12. ITEMS
    # =========================================================================
    pdf.add_page()
    pdf.section_title("12. ITEMS")
    pdf.note("Each item needs: ground sprite (dropped on map) + inventory icon (UI).\nMany items can share base silhouettes with color/detail swaps.")

    pdf.sub_title("Raw Resources - 12 items, ~8 unique sprites", 12)
    pdf.sprite_group_box("Rock family: raw_stone + raw_ore + coal = 1 rock pile shape, 3 colors.")
    pdf.sprite_group_box("Plant family: plant_fiber + berries + mushrooms + medicinal_herb = 1 gather bundle, 4 colors.")
    pdf.sprite_reuse_diagram(
        "Example: Rock pile - 1 base, 3 fills",
        (128, 128, 128),  # raw stone gray
        [
            (170, 145, 110, "Ore"),
            (40, 40, 40, "Coal"),
        ],
        shape="triangle"
    )
    raws = [
        ("raw_wood", "Raw Wood", "50", "Stack of rough-cut logs, bark visible", "Unique"),
        ("raw_stone", "Raw Stone", "50", "Pile of gray rough-hewn rock chunks", "Base rocks"),
        ("raw_ore", "Raw Ore", "50", "Rock chunks with metallic ore seams", "Rocks+tint"),
        ("coal", "Coal", "50", "Pile of black glossy coal lumps", "Rocks+black"),
        ("raw_ice", "Raw Ice", "50", "Stack of translucent blue ice blocks", "Unique"),
        ("raw_meat", "Raw Meat", "20", "Red meat cuts on a slab, raw and bloody", "Unique"),
        ("raw_hide", "Raw Hide", "20", "Folded animal skin/pelt, fur side up", "Unique"),
        ("thermal_core", "Thermal Core", "10", "Glowing orange crystalline orb, warm halo", "Unique"),
        ("plant_fiber", "Plant Fiber", "50", "Bundle of dried green plant stalks", "Base bundle"),
        ("berries", "Berries", "30", "Cluster of small red/blue berries on stems", "Bundle+red"),
        ("mushrooms", "Mushrooms", "30", "Cluster of brown/white mushroom caps", "Bundle+brown"),
        ("medicinal_herb", "Medicinal Herb", "20", "Tied bundle of white-flowering herbs", "Bundle+white"),
    ]
    pdf.table(["ID", "Name", "Stk", "Description", "Work"], raws, [28, 28, 10, 96, 20])
    pdf.ln(2)

    pdf.sub_title("Processed Materials - 7 items, ~4 unique", 7)
    pdf.sprite_group_box("Ingot/plank family: lumber + cut_stone + metal_ingot + charcoal = 1 block stack, 4 colors.")
    proc_mat = [
        ("lumber", "Lumber", "50", "Neat stack of sawn planks, smooth edges", "Base blocks"),
        ("cut_stone", "Cut Stone", "50", "Stack of squared stone bricks", "Blocks+gray"),
        ("metal_ingot", "Metal Ingot", "50", "Stack of shiny silver metal bars", "Blocks+silver"),
        ("charcoal", "Charcoal", "50", "Stack of black charcoal briquettes", "Blocks+black"),
        ("leather", "Leather", "20", "Folded tanned leather, smooth brown", "Unique"),
        ("cloth", "Cloth", "30", "Bolt of folded woven fabric, colored", "Unique"),
        ("water", "Water", "50", "Sealed water container/barrel, blue label", "Unique"),
    ]
    pdf.table(["ID", "Name", "Stk", "Description", "Work"], proc_mat, [28, 28, 10, 96, 20])
    pdf.ln(2)

    pdf.sub_title("Advanced Materials - 6 items, ~3 unique", 6)
    pdf.sprite_group_box("Tech component family: steel + components + circuit + pipe = 1 parts pile, 4 tints.")
    adv = [
        ("steel", "Steel", "30", "Refined dark steel plates/bars stacked", "Base parts"),
        ("components", "Components", "20", "Mixed mechanical parts: gears, springs, bolts", "Parts+mixed"),
        ("circuit", "Circuit", "20", "Green circuit boards with soldered chips", "Parts+green"),
        ("pipe", "Pipe", "30", "Copper/steel pipe sections bundled", "Parts+copper"),
        ("insulation", "Insulation", "30", "Fluffy white fiberglass roll, wrapped", "Unique"),
        ("glass", "Glass", "30", "Stacked transparent glass panes", "Unique"),
    ]
    pdf.table(["ID", "Name", "Stk", "Description", "Work"], adv, [28, 28, 10, 96, 20])
    pdf.ln(2)

    pdf.sub_title("Food - 6 items, ~4 unique", 6)
    pdf.sprite_group_box("Prepared food: stew + feast = 1 bowl/plate base, different fullness/garnish.")
    food = [
        ("cooked_meat", "Cooked Meat", "20", "Browned meat on a plate, steaming", "Unique"),
        ("jerky", "Jerky", "30", "Strips of dried meat, dark reddish-brown", "Unique"),
        ("bread", "Bread", "20", "Round loaf of bread, golden crust", "Unique"),
        ("stew", "Stew", "10", "Bowl of brown stew, steam rising, spoon", "Base bowl"),
        ("feast", "Feast", "5", "Overflowing bowl with garnish, best food", "Bowl+full"),
        ("ration", "Ration Pack", "15", "Sealed foil MRE-style pack, stamped label", "Unique"),
    ]
    pdf.table(["ID", "Name", "Stk", "Description", "Work"], food, [28, 28, 10, 96, 20])

    pdf.add_page()
    pdf.sub_title("Medicine - 2 unique", 2)
    pdf.bullet_list(["bandage - white roll/wrap", "medicine - bottle/vial"])
    pdf.ln(1)

    pdf.sub_title("Drugs - 11 items, ~5 unique silhouettes", 11)
    pdf.sprite_group_box("Powder drugs: spike + stardust + shards = 1 small bag/pouch, 3 colors.")
    pdf.sprite_group_box("Liquid drugs: drift + smog + rotgut + surge = 1 bottle/vial, 4 colors.")
    pdf.sprite_group_box("Organic: voidbloom + fang + glimpse + thaw = 1 leaf/crystal, 4 colors.")
    pdf.color_swatch_row("Drug bottle family:", [
        (180, 140, 60, "Drift"),
        (140, 140, 140, "Smog"),
        (120, 80, 40, "Rotgut"),
        (200, 60, 60, "Surge"),
    ])
    pdf.color_swatch_row("Drug pouch family:", [
        (220, 220, 220, "Spike"),
        (200, 200, 240, "Stardust"),
        (100, 140, 220, "Shards"),
    ])
    drugs = [
        ("spike", "Spike", "White powder in small paper pouch, +40% work speed", "Base pouch"),
        ("stardust", "Stardust", "Sparkly iridescent powder in pouch, euphoric", "Pouch+sparkle"),
        ("shards", "Shards", "Blue crystal fragments in pouch, psychedelic", "Pouch+blue"),
        ("drift", "Drift", "Amber liquid in small bottle, synthetic opiate", "Base bottle"),
        ("smog", "Smog", "Gray-green liquid in bottle, sedative smoke", "Bottle+gray"),
        ("rotgut", "Rotgut", "Brown jug/bottle of homemade moonshine", "Bottle+brown"),
        ("surge", "Surge", "Red liquid in bottle, combat stimulant", "Bottle+red"),
        ("thaw", "Thaw", "Medical syringe with orange warmth serum", "Unique"),
        ("voidbloom", "Voidbloom", "Alien purple mushroom, glowing spores", "Unique"),
        ("fang", "Fang", "Small vial of dark serpent venom, tooth stopper", "Unique"),
        ("glimpse", "Glimpse", "Iridescent crystal eye-shaped pill, deep psych", "Unique"),
    ]
    pdf.table(["ID", "Name", "Description", "Work"], drugs, [22, 22, 126, 16])
    pdf.ln(2)

    pdf.sub_title("Corpses & Dark Products - 4 items, 2 unique", 4)
    pdf.sprite_group_box("corpse_creature + corpse_human = 2 prone body shapes. meat/leather = recolor of raw items.")
    pdf.bullet_list(["corpse_creature - prone creature shape",
                      "corpse_human - prone colonist shape",
                      "human_meat - raw_meat recolor (darker red)",
                      "human_leather - leather recolor (pale)"])
    pdf.ln(1)

    pdf.sub_title("Organs - 5 items, ~3 unique", 5)
    pdf.sprite_group_box("Similar icon approach: 1 organ jar base. heart/liver = red, lung = pink, kidney = brown, eye = white.")
    pdf.bullet_list(["organ_heart - jar (red)", "organ_lung - jar (pink)",
                      "organ_kidney - jar (brown)", "organ_liver - jar (dark red)",
                      "organ_eye - jar (white)"])
    pdf.ln(1)

    pdf.sub_title("Prosthetics & Bionics - 7 items, 3 base shapes", 7)
    pdf.sprite_group_box("3 tiers of same limb: wood -> metal -> bionic = 1 arm shape, 1 leg shape, 1 eye shape.")
    pdf.sprite_group_box("Each tier = same silhouette with material fill upgrade (wood grain -> metal -> glowing tech).")
    pdf.color_swatch_row("Limb material tiers:", [
        (140, 110, 70, "Wood (base)"),
        (150, 155, 160, "Metal"),
        (80, 180, 220, "Bionic"),
    ])
    pros = [
        ("peg_leg", "Peg Leg", "Wooden", "Base leg (wood)"),
        ("prosthetic_leg", "Prosthetic Leg", "Metal", "Leg (metal fill)"),
        ("bionic_leg", "Bionic Leg", "High-tech", "Leg (glow fill)"),
        ("wooden_arm", "Wooden Arm", "Wooden", "Base arm (wood)"),
        ("prosthetic_arm", "Prosthetic Arm", "Metal", "Arm (metal fill)"),
        ("bionic_arm", "Bionic Arm", "High-tech", "Arm (glow fill)"),
        ("bionic_eye", "Bionic Eye", "High-tech", "Unique"),
    ]
    pdf.table(["ID", "Name", "Tier", "Sprite Work"], pros, [30, 34, 22, 58])
    pdf.ln(2)

    pdf.sub_title("Melee Weapons - 10 items, ~7 unique", 10)
    pdf.sprite_group_box("Blade family: knife + machete + sword = 1 blade shape at 3 sizes. club + wrench = 1 blunt shape.")
    melee = [
        ("weapon_club", "Club", "6", "Rough wooden bludgeon, thick end, improvised", "Base blunt"),
        ("weapon_pipe_wrench", "Pipe Wrench", "10", "Heavy metal wrench, long handle", "Blunt+metal"),
        ("weapon_shiv", "Shiv", "5", "Small sharpened scrap metal blade, wrapped handle", "Unique"),
        ("weapon_torch", "Torch", "4", "Stick with burning cloth/pitch tip, casts light", "Unique"),
        ("weapon_knife", "Knife", "8", "Short single-edge blade, leather grip", "Base blade"),
        ("weapon_machete", "Machete", "12", "Wide medium-length chopping blade", "Blade+wider"),
        ("weapon_sword", "Sword", "16", "Long straight blade, crossguard, wrapped hilt", "Blade+long"),
        ("weapon_hatchet", "Hatchet", "10", "Small axe, single head, short wooden handle", "Unique"),
        ("weapon_axe", "Ice Axe", "18", "Large two-handed axe, wide curved blade", "Hatchet+big"),
        ("weapon_spear", "Spear", "14", "Long wooden shaft with metal point, two-handed", "Unique"),
    ]
    pdf.table(["ID", "Name", "Dmg", "Description", "Work"], melee, [28, 22, 10, 108, 18])

    pdf.add_page()
    pdf.sub_title("Ranged Weapons - 10 items, ~5 unique bases", 10)
    pdf.sprite_group_box("Bow family: shortbow + bow + crossbow = 1 curved shape at 3 detail levels.")
    pdf.sprite_group_box("Pistol family: revolver + pistol = 1 handgun shape, cylinder vs slide detail.")
    pdf.sprite_group_box("Rifle family: bolt_action + assault + battle = 1 long gun, 3 barrel/stock variants.")
    pdf.sprite_group_box("Shotgun pair: sawed_off + pump = 1 shotgun, short vs long.")
    ranged = [
        ("weapon_shortbow", "Short Bow", "10", "5", "Small curved wooden bow, simple string", "Base bow"),
        ("weapon_bow", "Hunting Bow", "15", "6", "Full-size recurve bow, leather grip", "Bow+big"),
        ("weapon_crossbow", "Crossbow", "22", "7", "Mechanical crossbow, shoulder stock, bolt", "Bow+mech"),
        ("weapon_revolver", "Revolver", "16", "6", "Six-shot revolver, visible cylinder", "Base pistol"),
        ("weapon_pistol", "Pistol", "14", "7", "Semi-auto pistol, slide and magazine", "Pistol var."),
        ("weapon_sawed_off", "Sawed-Off", "30", "3", "Short double-barrel shotgun, wide bores", "Base shotgun"),
        ("weapon_pump_shotgun", "Pump Shotgun", "28", "5", "Full-length pump shotgun, wooden stock", "Shotgun+long"),
        ("weapon_bolt_action", "Bolt-Action", "28", "10", "Long bolt-action rifle, scope mount, wooden stock", "Base rifle"),
        ("weapon_assault_rifle", "Assault Rifle", "18", "9", "Modern rifle, pistol grip, detachable mag", "Rifle var."),
        ("weapon_battle_rifle", "Battle Rifle", "24", "11", "Heavy rifle, longer barrel, bipod capable", "Rifle var."),
    ]
    pdf.table(["ID", "Name", "Dmg", "Rng", "Description", "Work"], ranged, [30, 24, 10, 10, 86, 14])
    pdf.ln(2)

    pdf.sub_title("Throwables - 4 items, ~3 unique", 4)
    pdf.sprite_group_box("grenade + pipe_bomb = 1 small round/cylinder shape, color swap. IED is unique. Molotov is unique.")
    throws = [
        ("grenade", "Grenade", "40", "AOE 3", "Base round (green)"),
        ("pipe_bomb", "Pipe Bomb", "35", "AOE 2", "Round (gray)"),
        ("ied", "IED", "50", "AOE 4", "Unique (wired box)"),
        ("molotov", "Molotov", "15", "AOE 2", "Unique (bottle + rag)"),
    ]
    pdf.table(["ID", "Name", "Dmg", "AOE", "Sprite Work"], throws, [24, 28, 14, 18, 60])
    pdf.ln(2)

    pdf.sub_title("Ammunition - 7 items, ~3 unique bases", 7)
    pdf.sprite_group_box("Arrow family: arrow + fire_arrow + bolt = 1 shaft shape, 3 tip colors.")
    pdf.sprite_group_box("Bullet family: bullet + shell = 1 cartridge, 2 sizes. rocket + mortar = 1 large round, 2 shapes.")
    ammo = [
        ("ammo_arrow", "Arrows", "50", "Base arrow (brown)"),
        ("ammo_fire_arrow", "Fire Arrows", "30", "Arrow (orange tip)"),
        ("ammo_bolt", "Crossbow Bolts", "50", "Arrow (metal tip)"),
        ("ammo_bullet", "Bullets", "50", "Base cartridge (small)"),
        ("ammo_shell", "Shells", "30", "Cartridge (wide)"),
        ("ammo_rocket", "Rockets", "10", "Base large round"),
        ("ammo_mortar_shell", "Mortar Shells", "10", "Large round (finned)"),
    ]
    pdf.table(["ID", "Name", "Stack", "Sprite Work"], ammo, [32, 34, 16, 62])
    pdf.ln(2)

    pdf.sub_title("Eldritch Eggs & Spores - 9 items, ~2 bases", 9)
    pdf.sprite_group_box("ALL eggs = 1 egg shape in 5 colors. ALL spores = 1 spore pod in 4 colors.")
    pdf.sprite_reuse_diagram(
        "Example: 1 egg shape, 5 color fills",
        (180, 50, 50),  # flesh red
        [
            (120, 40, 160, "Ichor"),
            (180, 160, 120, "Chitin"),
            (30, 20, 30, "Void"),
            (140, 40, 50, "Wyrm"),
        ],
        shape="circle"
    )
    eggs_spores = [
        ("flesh_egg", "Flesh Egg", "Red", "Base egg"),
        ("ichor_egg", "Ichor Egg", "Purple", "Egg recolor"),
        ("chitin_egg", "Chitin Egg", "Tan", "Egg recolor"),
        ("void_egg", "Void Egg", "Black", "Egg recolor"),
        ("wyrm_egg", "Wyrm Egg", "Dark red", "Egg recolor"),
        ("spore_bile", "Bile Spore", "Yellow-green", "Base spore pod"),
        ("spore_thorn", "Thorn Spore", "Brown", "Spore recolor"),
        ("spore_nerve", "Nerve Spore", "Purple", "Spore recolor"),
        ("spore_rot", "Rot Spore", "Dark brown", "Spore recolor"),
    ]
    pdf.table(["ID", "Name", "Color", "Sprite Work"], eggs_spores, [26, 30, 30, 56])

    pdf.add_page()
    pdf.sub_title("Eldritch Resources - 7 items, ~4 unique", 7)
    pdf.sprite_group_box("Liquid family: eldritch_ichor + caustic_liquid + serpent_venom = 1 vial, 3 fill colors.")
    eld_res = [
        ("eldritch_ichor", "Eldritch Ichor", "20", "Base vial (green)"),
        ("caustic_liquid", "Caustic Liquid", "15", "Vial (yellow)"),
        ("serpent_venom", "Serpent Venom", "10", "Vial (dark red)"),
        ("raw_fat", "Raw Fat", "20", "Unique (white glob)"),
        ("chitin_plate", "Chitin Plate", "15", "Unique (armored slab)"),
        ("void_crystal", "Void Crystal", "10", "Unique (dark gem)"),
        ("raw_fur", "Raw Fur", "20", "raw_hide recolor"),
    ]
    pdf.table(["ID", "Name", "Stack", "Sprite Work"], eld_res, [30, 34, 16, 64])
    pdf.ln(2)

    pdf.sub_title("Misc Items - 5", 5)
    pdf.bullet_list([
        "fuel_cell - Unique (battery/canister)",
        "rare_ore - raw_ore recolor (sparkle)",
        "ancient_artifact - Unique (alien relic)",
        "drug crops: psychoid_leaf, smokeleaf_leaf, hops - 1 leaf pile, 3 colors",
    ])
    pdf.ln(1)

    pdf.sub_title("Boss Drops - 8 items, ~4 unique", 8)
    pdf.sprite_group_box("Trophy family: titan_heart + leviathan_core + void_heart = 1 glowing orb, 3 colors.")
    pdf.sprite_group_box("Bone trophies: stalker_skull + titan_spine + giant_crown = 1 bone shape, 3 variants.")
    pdf.bullet_list([
        "titan_heart - Glowing orb (blue)",
        "leviathan_core - Glowing orb (deep blue)",
        "void_heart - Glowing orb (purple/black)",
        "wurm_scale - Unique (red-orange scale)",
        "godstone - Unique (massive gem)",
        "stalker_skull - Bone trophy (dark)",
        "titan_spine - Bone trophy (gray)",
        "giant_crown - Bone trophy (gold accent)",
    ])

    # =========================================================================
    # 13. FLUIDS & GASES
    # =========================================================================
    pdf.ln(2)
    pdf.section_title("13. FLUIDS & GASES")
    pdf.sprite_group_box("Pipe fill = 1 liquid animation inside pipe, 6 color tints. Spills = 1 puddle, 6 tints.")
    pdf.sprite_group_box("Gases = fog/haze overlay particle in 4 tints. Shared particle system.")

    pdf.sub_title("Fluids - 6 types, 1 base + 6 colors", 6)
    fluids = [
        ("water", "Water", "0 C", "Blue"),
        ("oil", "Crude Oil", "-10 C", "Dark brown"),
        ("ichor", "Eldritch Ichor", "-40 C", "Sickly green"),
        ("fuel", "Refined Fuel", "-25 C", "Amber"),
        ("coolant", "Coolant", "-60 C", "Cyan"),
        ("waste", "Waste Water", "-5 C", "Murky brown"),
    ]
    pdf.table(["ID", "Name", "Freeze", "Color Tint"], fluids, [22, 34, 22, 30])
    pdf.ln(2)

    pdf.sub_title("Gases - 4 types, 1 base + 4 colors", 4)
    gases = [
        ("oxygen", "Oxygen", "No", "Faint blue"),
        ("co2", "Carbon Dioxide", "No", "Gray"),
        ("steam", "Steam", "No", "White"),
        ("toxic_gas", "Toxic Gas", "Yes", "Yellow-green"),
    ]
    pdf.table(["ID", "Name", "Toxic", "Color Tint"], gases, [22, 38, 16, 32])

    # =========================================================================
    # 14. EFFECTS & PARTICLES
    # =========================================================================
    pdf.add_page()
    pdf.section_title("14. EFFECTS & PARTICLES")
    pdf.sprite_group_box("Ice FX family: frost breath + ice shards + cryo blast + blizzard = 1 ice particle, 4 spread patterns.")
    pdf.sprite_group_box("Fire FX family: fire + flamethrower + incendiary = 1 flame particle, 3 spread patterns.")
    pdf.sprite_group_box("Explosion FX: grenades + IED + mines = 1 burst animation, scale/color varies.")
    pdf.note("~18 effects total, ~12 unique base animations after sharing.")
    effects = [
        ("Fire", "Burning tiles, traps", "Anim loop", "Base flame"),
        ("Flamethrower", "Turret attack", "Cone", "Flame + spread"),
        ("Snow particles", "5 weather levels", "Particle sys", "Unique"),
        ("Wind streaks", "Blizzard/whiteout", "Streaks", "Unique"),
        ("Aurora", "Weather event", "Overlay", "Unique"),
        ("Projectile trail", "Bullets/arrows", "Line", "1 trail, speed varies"),
        ("Explosion", "Grenades/IEDs/mines", "Burst", "Base burst, scale"),
        ("Blood splatter", "Combat hits", "Decal", "Unique"),
        ("Hypothermia frost", "Cold colonist", "Overlay", "1 frost texture"),
        ("Pollution haze", "High pollution", "Fog", "1 haze, tint varies"),
        ("Thermal shimmer", "Heat sources", "Distortion", "Unique"),
        ("Muzzle flash", "Firearm discharge", "Flash", "1 flash"),
        ("Fluid spill", "Pipe burst", "Puddle", "1 puddle, 6 colors"),
        ("Frozen pipe", "Frozen pipes", "Overlay", "1 ice overlay"),
        ("Shield bubble", "Shield gen", "Dome", "Unique"),
        ("Tesla arc", "Tesla turret", "Lightning", "Unique"),
        ("Laser beam", "Laser turret", "Line", "1 beam, color varies"),
        ("Cryo blast", "Cryo turret", "Cone", "Ice particle cone"),
    ]
    pdf.table(["Effect", "Context", "Type", "Sprite Work"], effects, [34, 38, 22, 48])

    # =========================================================================
    # 15. WEATHER
    # =========================================================================
    pdf.ln(3)
    pdf.section_title("15. WEATHER")
    pdf.sprite_group_box("Snow intensity is 1 particle scaled by density/speed. NOT 5 separate systems.")
    pdf.note("7 weather types but most share the same particle system at different parameters.")
    weather = [
        ("clear", "0 C", "1.0", "None", "No particles"),
        ("overcast", "-5 C", "0.85", "Dim", "Screen tint only"),
        ("snowfall", "-10 C", "0.6", "Light snow", "Snow particle (slow)"),
        ("blizzard", "-25 C", "0.2", "Heavy snow", "Snow particle (fast+dense)"),
        ("whiteout", "-35 C", "0.05", "White fog", "Snow + fog overlay"),
        ("warm_front", "+15 C", "0.9", "Warm tint", "Screen tint (yellow)"),
        ("aurora", "-5 C", "0.95", "Color shift", "Unique sky overlay"),
    ]
    pdf.table(["Weather", "Temp", "Vis", "Particles", "Sprite Work"], weather, [24, 18, 14, 28, 54])

    # =========================================================================
    # 16. DISEASES & STATUS
    # =========================================================================
    pdf.add_page()
    pdf.section_title("16. DISEASES & STATUS EFFECTS")
    pdf.sprite_group_box("Disease icons: 1 biohazard/medical base icon shape, 5 color fills.")
    pdf.sprite_group_box("Status overlays on colonists: tint shifts on base sprite, not separate drawings.")

    pdf.sub_title("Diseases - 5 items, ~2 unique icon bases", 5)
    diseases = [
        ("frostlung", "Frostlung", "Lethal", "Lung icon (blue)"),
        ("blackrot", "Blackrot", "Lethal", "Skull icon (brown)"),
        ("ice_plague", "Ice Plague", "Lethal", "Lung icon (white)"),
        ("tissue_creep", "Tissue Creep", "Lethal", "Skull icon (red)"),
        ("spore_sickness", "Spore Sickness", "Non-lethal", "Unique (spore icon)"),
    ]
    pdf.table(["ID", "Name", "Severity", "Icon Approach"], diseases, [28, 32, 22, 60])
    pdf.ln(2)

    pdf.sub_title("Status Effects - 3 items, 3 icons + tint overlays", 3)
    status = [
        ("frostbite", "Frostbite", "-25% work", "Blue tint on limb"),
        ("infection", "Infection", "-20% work", "Green tint on limb"),
        ("exhaustion", "Exhaustion", "-40% work", "Gray tint overall"),
    ]
    pdf.table(["ID", "Name", "Debuff", "Visual Approach"], status, [26, 28, 28, 60])

    # =========================================================================
    # 17. UI
    # =========================================================================
    pdf.ln(3)
    pdf.section_title("17. UI ICONS & ELEMENTS")
    pdf.note("Small icons for panels, menus, and overlays. Most are simple symbolic shapes.")

    pdf.sub_title("Resource Bar - 6 icons")
    pdf.bullet_list(["Thermal Cores (orange gem)", "Wood (log)", "Stone (rock)",
                      "Metal (ingot)", "Food (leaf/apple)", "Fuel (flame/can)"])

    pdf.sub_title("Need Bars - 4 icons")
    pdf.sprite_group_box("4 simple symbolic icons. Warmth = thermometer, Food = fork, Rest = bed, Morale = smiley.")
    pdf.bullet_list(["Warmth (thermometer)", "Food (fork/apple)",
                      "Rest (bed/moon)", "Morale (face/star)"])

    pdf.sub_title("Game Controls - 4 icons")
    pdf.bullet_list(["Pause", "Speed 1x / 2x / 3x (or 1 arrow icon x3 with fill)"])

    pdf.sub_title("Build Menu - 13 category icons")
    pdf.note("Simple symbolic icons for each build category.")
    pdf.bullet_list([
        "Walls & Floors (brick)", "Heating (flame)", "Ventilation (fan)",
        "Furniture (chair)", "Decorations (frame)", "Production (gear)",
        "Power (lightning bolt)", "Logistics (conveyor arrow)",
        "Turrets (crosshair)", "Traps (warning triangle)", "Fortifications (shield)",
        "Colony (people)", "Agriculture (plant)",
    ])

    pdf.sub_title("Research Icons - 25+ nodes")
    pdf.note("Each research node needs a small icon. Many can share base shapes with different accents.\nPick/hammer for mining, beaker for chemistry, gear for mechanics, etc.")

    pdf.sub_title("Policy Icons - 6")
    pdf.bullet_list([
        "extended_shifts - clock with arrow",
        "rationing - half-empty plate",
        "martial_law - fist/shield",
        "emergency_protocol - alarm bell",
        "quota_compliance - checklist",
        "blackout_protocol - eye with slash",
    ])

    pdf.sub_title("Body Part Diagram - 1 figure + 6 highlight zones")
    pdf.sprite_group_box("1 simple human silhouette. Highlight head/torso/arms/legs with injury tint overlay.")
    pdf.bullet_list(["head", "torso", "left arm", "right arm", "left leg", "right leg"])

    pdf.sub_title("Misc UI")
    pdf.bullet_list([
        "Cursor icons: select, mine, build, cancel, designate (~5)",
        "Hope meter icon (rising arrow/sun)",
        "Discontent meter icon (storm cloud/fist)",
        "Minimap entity markers (colored dots - code-driven)",
        "Mental break icons (~6 unique small icons)",
        "Trait icons (~28, but many can be simple symbolic shapes)",
    ])

    # =========================================================================
    # GRAND TOTAL
    # =========================================================================
    pdf.add_page()
    pdf.section_title("FINAL SUMMARY - UNIQUE BASE SPRITES NEEDED")
    pdf.ln(2)
    pdf.note("This is the real work estimate. 'Base sprites' = actual drawings needed.\nAll other items are achieved through: color swap, palette tint, scale, overlay, or minor detail change.")
    pdf.ln(2)

    totals = [
        ("Category", "Total Items", "Base Sprites", "Savings Method"),
        ("Tiles & Terrain", "35", "~22", "Material texture swaps"),
        ("Zone Overlays", "3", "1", "Color tint"),
        ("Colonist Model", "~20 states", "~8", "Overlay layers + tints"),
        ("Small Fauna", "3", "3", "All unique shapes"),
        ("Medium Fauna", "10", "~6", "Wolf/ape/stalker families"),
        ("Megafauna", "8", "~5", "Titan family + scaled bases"),
        ("Eldritch Horrors", "4", "4", "All unique (end-game)"),
        ("Swarm Creatures", "6", "~4", "Bug pair shared"),
        ("Eldritch Livestock", "9", "~7", "Blob/polyp pairs"),
        ("Growth Stages", "45", "~18", "Scale juvenile up"),
        ("Named Bosses", "8", "~2 new", "Reuse base + boss FX overlay"),
        ("Megabeast Forms", "10", "10", "Unique silhouettes"),
        ("Megabeast Materials", "10", "0", "Palette swaps only"),
        ("Megabeast Attack FX", "10", "~6", "Ice/fire families"),
        ("Lairs", "8", "~3", "Cave/den/nest bases x states"),
        ("Raiders", "15", "~6", "4 factions, colonist base model"),
        ("NPCs/Merchants", "3", "1", "Colonist + faction colors"),
        ("Heating/Vent/Thermal", "7", "~4", "Vent family shared"),
        ("Furniture/Deco", "8", "8", "All small unique"),
        ("Colony Growth", "2", "2", "Both unique"),
        ("Production Machines", "14", "~8", "Table/furnace/counter families"),
        ("Power Generators", "20", "~10", "Fire/wheel/reactor/burner families"),
        ("Central Reactor", "1+states", "1", "Glow overlays for states"),
        ("Conveyors", "2 types", "2", "Rotate for directions"),
        ("Inserters", "3", "1", "Color swap"),
        ("Pipes & Ducts", "6", "2", "Pipe + duct bases"),
        ("Tanks", "4", "2", "Fluid + gas bases"),
        ("Processors", "7", "~4", "Industrial box family"),
        ("Turrets", "17", "~8", "Shared base + unique barrels"),
        ("Traps", "19", "~8", "Plate/snare/mine families"),
        ("Fortifications", "4", "1", "Progressive detail on 1 shape"),
        ("Special Defense", "2", "2", "Both unique"),
        ("Crops", "70 stages", "~31", "14 crops, shared early stages"),
        ("Raw Resources", "12", "~8", "Rock/plant families"),
        ("Processed Materials", "7", "~4", "Block stack family"),
        ("Advanced Materials", "6", "~3", "Parts pile family"),
        ("Food", "6", "~4", "Bowl family"),
        ("Medicine", "2", "2", "Both unique"),
        ("Drugs", "11", "~5", "Pouch/bottle/organic families"),
        ("Corpses/Dark", "4", "2", "Prone shapes + recolor"),
        ("Organs", "5", "~1", "Jar + 5 fills"),
        ("Prosthetics/Bionics", "7", "3", "Arm/leg/eye x material fill"),
        ("Melee Weapons", "10", "~7", "Blade/blunt families"),
        ("Ranged Weapons", "10", "~5", "Bow/pistol/rifle/shotgun"),
        ("Throwables", "4", "~3", "Grenade pair shared"),
        ("Ammunition", "7", "~3", "Arrow/cartridge/large families"),
        ("Eggs & Spores", "9", "2", "1 egg + 1 spore, recolor"),
        ("Eldritch Resources", "7", "~4", "Vial family"),
        ("Misc Items", "5", "~3", "Recolors of existing"),
        ("Boss Drops", "8", "~4", "Orb/bone trophy families"),
        ("Fluids in pipes", "6", "1", "1 flow anim, 6 tints"),
        ("Gases", "4", "1", "1 haze particle, 4 tints"),
        ("Effects/Particles", "18", "~12", "Ice/fire/explosion families"),
        ("Weather", "7", "~4", "Snow particle scales"),
        ("Disease Icons", "5", "~2", "Lung/skull bases + color"),
        ("Status Icons", "3", "3", "Tint overlays"),
        ("UI Resource Icons", "6", "6", "All unique symbols"),
        ("UI Need Icons", "4", "4", "All unique symbols"),
        ("UI Controls", "4", "4", "Simple shapes"),
        ("UI Build Categories", "13", "13", "Simple symbols"),
        ("UI Research Nodes", "25+", "~15", "Some share base + accent"),
        ("UI Policy Icons", "6", "6", "Simple symbols"),
        ("UI Body Diagram", "1+6", "1", "1 figure + highlight zones"),
        ("UI Misc", "~40", "~25", "Cursors, markers, traits"),
    ]

    pdf.set_font("Helvetica", "", 8)
    # Table header
    pdf.set_font("Helvetica", "B", 8)
    pdf.set_fill_color(40, 70, 100)
    pdf.set_text_color(255, 255, 255)
    ws = [52, 26, 26, 78]
    for i, h in enumerate(["Category", "Items", "Base Sprites", "Savings Method"]):
        pdf.cell(ws[i], 7, h, border=1, fill=True, align="C")
    pdf.ln()

    fill = False
    for row in totals:
        if row[0] == "Category":
            continue
        pdf.check_page_break(7)
        if fill:
            pdf.set_fill_color(235, 240, 248)
        else:
            pdf.set_fill_color(255, 255, 255)
        pdf.set_text_color(30, 30, 30)
        pdf.set_font("Helvetica", "", 7)
        for i, val in enumerate(row):
            align = "L" if i in (0, 3) else "C"
            pdf.cell(ws[i], 6, str(val), border=1, fill=True, align=align)
        pdf.ln()
        fill = not fill

    pdf.ln(6)
    pdf.set_draw_color(30, 60, 90)
    pdf.set_line_width(0.8)
    pdf.line(10, pdf.get_y(), 200, pdf.get_y())
    pdf.ln(4)

    pdf.set_font("Helvetica", "B", 14)
    pdf.set_text_color(30, 60, 90)
    pdf.cell(90, 10, "TOTAL ITEMS:", align="R")
    pdf.cell(10, 10, "")
    pdf.cell(0, 10, "~700+", new_x="LMARGIN", new_y="NEXT")

    pdf.cell(90, 10, "UNIQUE BASE SPRITES:", align="R")
    pdf.cell(10, 10, "")
    pdf.set_text_color(180, 60, 20)
    pdf.cell(0, 10, "~320", new_x="LMARGIN", new_y="NEXT")

    pdf.cell(90, 10, "SAVINGS:", align="R")
    pdf.cell(10, 10, "")
    pdf.set_text_color(40, 140, 40)
    pdf.cell(0, 10, "~54% reduction via reuse", new_x="LMARGIN", new_y="NEXT")

    pdf.ln(8)
    pdf.set_font("Helvetica", "I", 9)
    pdf.set_text_color(120, 120, 120)
    pdf.cell(0, 7, "FROSTHOLD - All assets currently placeholder shapes (colored rectangles/circles)", align="C", new_x="LMARGIN", new_y="NEXT")
    pdf.cell(0, 7, "Love2D 11.4  |  32px tiles  |  RimWorld-style sprite reuse strategy", align="C")

    # Save
    pdf.output("F:/IceRimworld/FROSTHOLD_Art_Assets.pdf")
    print("PDF saved: F:/IceRimworld/FROSTHOLD_Art_Assets.pdf")


if __name__ == "__main__":
    build()

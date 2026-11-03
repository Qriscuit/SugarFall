"""Edit the Sugarfall canvas by positioning existing, untouched image layers.

Phase one generates separate PNG pieces (see generation-prompts.json).
This phase never generates, recolors, resizes or flattens raster pixels. It
authors the same linked-image composition as SVG and Godot placement metadata.
"""
from pathlib import Path
import hashlib
import json
import math
import re
import xml.etree.ElementTree as ET

import numpy as np
from PIL import Image

HERE = Path(__file__).resolve().parent
WORKSPACE = HERE.parents[1]
PROJECT = WORKSPACE / "PLINKO"
WORLD = np.array([-2300.0, -6000.0, 11600.0, 7600.0])
CENTER = np.array([3400.0, 0.0])
MAX_ZOOM = 1.55
OLD_MANIFEST = json.loads((HERE.parent / "modular-arc-v1/sources.json").read_text())
SHADOWS = {
    "bakery_house": [.13, .82, .74, .12], "bakery_mill": [.22, .84, .66, .11],
    "greenhouse": [.16, .84, .71, .12], "gelato_house": [.18, .84, .66, .11],
    "gelato_pavilion": [.18, .84, .67, .11], "oak_tree": [.31, .86, .39, .09],
    "lilac_tree": [.35, .88, .33, .08], "flower_planter": [.17, .78, .70, .10],
    "garden_bench": [.15, .85, .71, .10],
}
ASSETS = {}
SIZES = {}
SOURCE_RECORDS = []


def register_asset(asset_id, path):
    with Image.open(path) as picture:
        assert picture.mode == "RGBA", (asset_id, picture.mode)
        assert picture.getchannel("A").getextrema()[0] == 0, asset_id
        SIZES[asset_id] = np.array(picture.size, dtype=float)
    resource = "res://" + path.relative_to(PROJECT).as_posix()
    ASSETS[asset_id] = {"texture": resource}
    if asset_id in SHADOWS:
        ASSETS[asset_id]["shadow_rect"] = SHADOWS[asset_id]
    template_path = PROJECT / "data/art/arc_props/bakery_house.png.import"
    template = template_path.read_text()
    template = re.sub(r"^uid=.*\n", "", template, flags=re.M)
    imported = path.name + "-" + hashlib.md5(resource.encode()).hexdigest() + ".ctex"
    template = re.sub(r"bakery_house\.png-[a-f0-9]+\.ctex", imported, template)
    template = template.replace("res://data/art/arc_props/bakery_house.png", resource)
    template = re.sub(r"process/size_limit=\d+", "process/size_limit=0", template)
    path.with_suffix(".png.import").write_text(template)
    SOURCE_RECORDS.append({
        "id": asset_id, "path": path.relative_to(WORKSPACE).as_posix(),
        "size": SIZES[asset_id].astype(int).tolist(),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "pixel_edits": False,
    })


for record in OLD_MANIFEST["assets"]:
    register_asset(record["id"], WORKSPACE / record["destination"])
for asset_id in ("garden_border", "herb_garden", "courtyard_steps"):
    register_asset(asset_id, PROJECT / "data/art/arc_sections" / (asset_id + ".png"))

layout = json.loads((PROJECT / "data/upgrade_layout.json").read_text())
NODES = np.array([node["position"] for node in layout["nodes"]])
distances = np.abs(NODES[:, None, :] - NODES[None, :, :]).max(axis=2)
np.fill_diagonal(distances, np.inf)
SPACING = distances.min(axis=1)
# This envelope covers every semantic node size, with additional clear air.
NODE_HALF = np.maximum(224, np.minimum(36 / .075, SPACING)) * .5 + 60
EDGES = np.array([edge["points"] for edge in layout["edges"]])
PLACEMENTS = []
SKIPPED = []


def intersects(a, b, padding=0):
    return bool(np.all(a[:2] - padding < b[:2] + b[2:]) and
                np.all(a[:2] + a[2:] + padding > b[:2]))


def cuts_edge(rect):
    lower, upper = rect[:2] - 32, rect[:2] + rect[2:] + 32
    for a, b in EDGES:
        delta = b - a
        low, high = 0., 1.
        for axis in range(2):
            if abs(delta[axis]) < 1e-9:
                if a[axis] < lower[axis] or a[axis] > upper[axis]:
                    break
            else:
                t0 = (lower[axis] - a[axis]) / delta[axis]
                t1 = (upper[axis] - a[axis]) / delta[axis]
                low, high = max(low, min(t0, t1)), min(high, max(t0, t1))
                if low > high:
                    break
        else:
            return True
    return False


def clear(rect):
    if np.any(rect[:2] < WORLD[:2]) or np.any(rect[:2] + rect[2:] > WORLD[:2] + WORLD[2:]):
        return False
    for point, half in zip(NODES, NODE_HALF):
        if intersects(rect, np.r_[point - half, [half * 2, half * 2]]):
            return False
    return not cuts_edge(rect)


def polar(angle, radius):
    a = math.radians(angle)
    return CENTER + np.array([math.cos(a), math.sin(a)]) * radius


def place(asset_id, center, width, area, section, label, z=10, flip=False, search=240):
    size = SIZES[asset_id]
    assert width * MAX_ZOOM <= size[0] + .01, (asset_id, width, size)
    extent = np.array([width, width * size[1] / size[0]])
    offsets = [np.zeros(2)]
    for radius in [60, 120, 180, 240, 330, 420]:
        if radius > search:
            continue
        for angle in range(0, 360, 30):
            a = math.radians(angle)
            offsets.append(np.array([math.cos(a), math.sin(a)]) * radius)
    for offset in offsets:
        candidate = np.array(center) + offset
        rect = np.r_[candidate - extent * .5, extent]
        if clear(rect):
            PLACEMENTS.append({
                "asset_id": asset_id, "rect": np.round(rect, 2).tolist(),
                "areas": [area], "section": section, "label": label,
                "z_index": z, "flip_h": flip,
            })
            return candidate
    SKIPPED.append([area, section, label])
    return None


for area in ("bakery", "gelato"):
    house = "bakery_house" if area == "bakery" else "gelato_house"
    special = "bakery_mill" if area == "bakery" else "gelato_pavilion"
    tree = "oak_tree" if area == "bakery" else "lilac_tree"

    # A small entrance district establishes scale at the player's starting corner.
    section = "01 entrance garden"
    entrance = place(house, (-800, 260), 760, area, section, "welcome house", search=180)
    if entrance is not None:
        place("courtyard_steps", entrance + [-30, 330], 690, area, section, "entry forecourt", z=0)
        place(tree, entrance + [-470, 20], 530, area, section, "entrance shade tree")
        place("garden_border", entrance + [-360, 340], 540, area, section, "entrance planted wall")
        place("flower_planter", entrance + [420, 390], 210, area, section, "door flowers")
        place("garden_bench", entrance + [-80, 580], 310, area, section, "entrance seating")

    # Seven individually arranged street sections follow the initial city-arc idea.
    # Their spacings, landmark sizes and garden layouts are deliberately irregular.
    landmarks = [
        (195, 5230, 720, house, -1),
        (220, 5260, 780, special, 1),
        (244, 5250, 690, house, 1),
        (270, 5290, 780, "greenhouse", -1),
        (296, 5250, 750, house, -1),
        (321, 5240, 730, special, 1),
        (343, 5130, 650, "greenhouse", -1),
    ]
    for index, (angle, radius, width, asset_id, side) in enumerate(landmarks):
        section = f"{index + 2:02d} outer district {angle}"
        anchor = place(asset_id, polar(angle, radius), width, area, section, "landmark", search=330)
        if anchor is None:
            continue
        place("courtyard_steps", anchor + [10, width * .43], min(660, width * .88), area, section, "stone forecourt", z=0)
        place(tree, anchor + [side * (width * .55), -width * .08], 450 + (index % 3) * 30,
              area, section, "canopy", search=180)
        place("garden_border", anchor + [-side * width * .43, width * .36], 520 + (index % 2) * 60,
              area, section, "planted garden wall", search=180, flip=index in [1, 4])
        place("flower_planter", anchor + [side * width * .32, width * .47], 190 + (index % 2) * 25,
              area, section, "front flowers", search=120)

    # Lush garden connectors visually join districts without closing their gaps.
    for index, (angle, radius, width) in enumerate([
        (207, 5040, 620), (231, 5130, 650), (256, 5140, 600),
        (284, 5100, 660), (308, 5110, 620), (334, 5050, 600),
    ]):
        section = f"{index + 9:02d} garden link {angle}"
        anchor = place("garden_border", polar(angle, radius), width, area, section,
                       "low curved flower wall", search=240, flip=index % 2 == 1)
        if anchor is not None:
            place(tree, anchor + [(-1 if index % 2 else 1) * 250, -210], 410 + (index % 3) * 30,
                  area, section, "garden tree", search=120)

    # The inner arc has a destination garden, with the same individually editable props.
    section = "15 inner conservatory garden"
    anchor = place("greenhouse", polar(250, 1090), 700, area, section, "conservatory", search=240)
    if anchor is not None:
        place("courtyard_steps", anchor + [0, 300], 610, area, section, "conservatory terrace", z=0)
        place("herb_garden", anchor + [500, 290], 500, area, section, "kitchen herb garden")
        place(tree, anchor + [-490, 100], 500, area, section, "conservatory tree")
        place("garden_bench", anchor + [280, 540], 330, area, section, "garden seat")
        place("flower_planter", anchor + [-260, 450], 220, area, section, "conservatory flowers")
    for index, (angle, radius) in enumerate([(211, 1450), (285, 1390), (324, 1370)]):
        section = f"{16 + index:02d} inner garden {angle}"
        anchor = place("herb_garden", polar(angle, radius), 500, area, section, "herbs and flowers")
        if anchor is not None:
            place(tree, anchor + [(-1 if index % 2 else 1) * 200, -230], 440,
                  area, section, "inner shade tree", search=120)

    # Only small accents enter quiet pockets between upgrade routes.
    for angle, radius in [(198, 3010), (226, 3930), (254, 2870), (282, 3910), (310, 2980), (337, 3730)]:
        place("flower_planter", polar(angle, radius), 180, area, "19 courtyard accents",
              f"flowers {angle}", search=120)

scene = {
    "schema": 2,
    "description": "Layered image composition guided by the original garden-city arc. Separate generated PNGs retain their exact pixels; placement and layer order are edited independently.",
    "world_rect": WORLD.tolist(),
    "ground": {"center": CENTER.tolist(), "inner_radius": 1750, "outer_radius": 5100,
               "start_angle_degrees": 176, "sweep_degrees": 170, "direction": 1},
    "landscaping": {
        "beds": [{"inner_radius": 5135, "outer_radius": 5550, "color_key": "garden_color"}],
        "walls": [{"radius": 5100, "width": 70, "height": 22},
                  {"radius": 1730, "width": 44, "height": 14}],
    },
    "areas": {
        "bakery": {"base_color": "aabd9b", "band_color": "d2dfbf", "border_color": "8fa684",
                   "garden_color": "8fa887", "terrace_color": "c5d5b7", "stone_color": "eee9dd", "stone_side_color": "b7b7a5"},
        "gelato": {"base_color": "afc4b2", "band_color": "d9d8e9", "border_color": "aaa8c2",
                   "garden_color": "91ad99", "terrace_color": "c6d7cc", "stone_color": "eeeaf2", "stone_side_color": "b7b5c2"},
    },
    "assets": ASSETS,
    "placements": PLACEMENTS,
}


SVG = "http://www.w3.org/2000/svg"
INKSCAPE = "http://www.inkscape.org/namespaces/inkscape"
XLINK = "http://www.w3.org/1999/xlink"
ET.register_namespace("", SVG)
ET.register_namespace("inkscape", INKSCAPE)
ET.register_namespace("xlink", XLINK)


def element(parent, tag, attributes=None, text=None):
    result = ET.SubElement(parent, "{" + SVG + "}" + tag, {k: str(v) for k, v in (attributes or {}).items()})
    if text is not None:
        result.text = text
    return result


def path_points(radius):
    return [polar(176 + 170 * i / 136, radius) for i in range(137)]


def points_text(points):
    return " ".join(f"{p[0]:.2f},{p[1]:.2f}" for p in points)


def write_svg(area):
    palette = scene["areas"][area]
    root = ET.Element("{" + SVG + "}svg", {
        "width": "1740", "height": "1140", "viewBox": " ".join(str(v) for v in WORLD),
        "version": "1.1",
    })
    element(root, "title", text=f"Sugarfall {area}: editable image composition")
    element(root, "desc", text="Every named image layer links to an original transparent PNG. Move or resize layers in an SVG editor. The original concept and upgrade keep-clear guides are hidden layers.")
    reference = element(root, "g", {"id": "original-concept", "style": "display:none",
        "{" + INKSCAPE + "}groupmode": "layer", "{" + INKSCAPE + "}label": "Reference — original arc concept (hidden)"})
    reference_path = "../../PLINKO/data/art/" + ("gelato/" if area == "gelato" else "") + "environment/upgrade_arc_v2.png"
    element(reference, "image", {"x": -2300, "y": -6000, "width": 11600, "height": 6628.6,
        "preserveAspectRatio": "xMidYMid meet", "opacity": .45, "{" + XLINK + "}href": reference_path})
    ground = element(root, "g", {"id": "ground", "{" + INKSCAPE + "}groupmode": "layer", "{" + INKSCAPE + "}label": "Ground and continuous curbs"})
    element(ground, "rect", {"x": WORLD[0], "y": WORLD[1], "width": WORLD[2], "height": WORLD[3], "fill": "#" + palette["base_color"]})
    element(ground, "polygon", {"points": points_text(path_points(5100) + list(reversed(path_points(1750)))), "fill": "#" + palette["band_color"]})
    for radius in [1750, 5100]:
        element(ground, "polyline", {"points": points_text(path_points(radius)), "fill": "none", "stroke": "#" + palette["border_color"], "stroke-opacity": .52, "stroke-width": 5})
        inset = radius + 9 if radius == 1750 else radius - 9
        light = "#" + "".join(f"{round(int(palette['band_color'][i:i+2], 16) * .84 + 255 * .16):02x}" for i in [0, 2, 4])
        element(ground, "polyline", {"points": points_text(path_points(inset)), "fill": "none", "stroke": light, "stroke-opacity": .68, "stroke-width": 2.5})
    for bed in scene["landscaping"]["beds"]:
        polygon = path_points(bed["outer_radius"]) + list(reversed(path_points(bed["inner_radius"])))
        element(ground, "polygon", {"points": points_text(polygon), "fill": "#" + palette[bed["color_key"]]})
    for wall in scene["landscaping"]["walls"]:
        inner, outer = wall["radius"] - wall["width"] / 2, wall["radius"] + wall["width"] / 2
        polygon = path_points(outer) + list(reversed(path_points(inner)))
        element(ground, "polygon", {"points": points_text([p + [0, wall["height"] + 10] for p in polygon]), "fill": "#263326", "fill-opacity": .13})
        element(ground, "polygon", {"points": points_text([p + [0, wall["height"]] for p in polygon]), "fill": "#" + palette["stone_side_color"]})
        element(ground, "polygon", {"points": points_text(polygon), "fill": "#" + palette["stone_color"]})
        element(ground, "polyline", {"points": points_text(path_points(outer)), "fill": "none", "stroke": "#" + palette["stone_side_color"], "stroke-opacity": .55, "stroke-width": 3})
        light = "#" + "".join(f"{round(int(palette['stone_color'][i:i+2], 16) * .68 + 255 * .32):02x}" for i in [0, 2, 4])
        element(ground, "polyline", {"points": points_text(path_points(inner + 8)), "fill": "none", "stroke": light, "stroke-opacity": .85, "stroke-width": 4})
    # Flat SVG order matches the production renderer's z-index/depth ordering.
    pieces = sorted([p for p in PLACEMENTS if area in p["areas"]], key=lambda p: (p["z_index"], p["rect"][1] + p["rect"][3]))
    for index, placement in enumerate(pieces):
        asset_id = placement["asset_id"]
        label = placement["section"] + " — " + placement["label"]
        group = element(root, "g", {"id": f"piece-{index:03d}-{asset_id}",
            "{" + INKSCAPE + "}groupmode": "layer", "{" + INKSCAPE + "}label": label})
        element(group, "title", text=label)
        x, y, width, height = placement["rect"]
        shadow = ASSETS[asset_id].get("shadow_rect")
        if shadow:
            sx, sy, sw, sh = shadow
            if placement["flip_h"]:
                sx = 1 - sx - sw
            cx, cy = x + (sx + sw / 2) * width, y + (sy + sh / 2) * height
            for scale, opacity in [(1, .09), (.72, .08)]:
                element(group, "ellipse", {"cx": cx, "cy": cy, "rx": width * sw / 2 * scale,
                    "ry": height * sh / 2 * scale, "fill": "#1f2921", "fill-opacity": opacity})
        attrs = {"x": x, "y": y, "width": width, "height": height, "preserveAspectRatio": "none",
            "{" + XLINK + "}href": "../../PLINKO/" + ASSETS[asset_id]["texture"].removeprefix("res://")}
        if placement["flip_h"]:
            attrs["transform"] = f"translate({2 * x + width} 0) scale(-1 1)"
        element(group, "image", attrs)
    guide = element(root, "g", {"id": "upgrade-clearance", "style": "display:none",
        "{" + INKSCAPE + "}groupmode": "layer", "{" + INKSCAPE + "}label": "Upgrade keep-clear guides (hidden)"})
    for a, b in EDGES:
        element(guide, "line", {"x1": a[0], "y1": a[1], "x2": b[0], "y2": b[1], "stroke": "#c34070", "stroke-width": 64, "stroke-opacity": .25})
    for point, half in zip(NODES, NODE_HALF):
        element(guide, "rect", {"x": point[0] - half, "y": point[1] - half, "width": half * 2, "height": half * 2, "fill": "#c34070", "fill-opacity": .18})
    ET.indent(root)
    ET.ElementTree(root).write(HERE / (area + "-editable-canvas.svg"), encoding="utf-8", xml_declaration=True)


(PROJECT / "data/upgrade_arc_art.json").write_text(json.dumps(scene, indent=2) + "\n")
for area in ["bakery", "gelato"]:
    write_svg(area)
(HERE / "composition-sources.json").write_text(json.dumps({
    "method": "Positioning, sizing and ordering existing linked image layers; no raster pixel edits",
    "composition_reference": "PLINKO/data/art/environment/upgrade_arc_v2.png",
    "assets": SOURCE_RECORDS,
    "placements": len(PLACEMENTS),
    "skipped_occupied_pockets": SKIPPED,
}, indent=2) + "\n")
print(f"Edited canvas: {len(ASSETS)} individual images, {len(PLACEMENTS)} layers, {len(PLACEMENTS) // 2} per area")
print("Skipped occupied pockets:", SKIPPED)

"""Compose a shorter Sugarfall arc from independently positioned image layers.

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
layout = json.loads((PROJECT / "data/upgrade_layout.json").read_text())
CENTER = np.array(layout["shape"]["center"], dtype=float)
LAYOUT_START = float(layout["shape"]["start_angle_degrees"])
LAYOUT_SWEEP = float(layout["shape"]["sweep_degrees"])
# Four degrees of quiet courtyard margin keep the first and last upgrade tiles
# fully grounded while the upgrade route itself remains exactly 120 degrees.
START, SWEEP = LAYOUT_START - 4, LAYOUT_SWEEP + 8
INNER_GROUND, OUTER_GROUND = 1820.0, 4980.0
assert LAYOUT_SWEEP == 120 and LAYOUT_START == 210, (LAYOUT_START, LAYOUT_SWEEP)
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
ALPHA_POINTS = {}
SOURCE_RECORDS = []


def register_asset(asset_id, path):
    with Image.open(path) as picture:
        assert picture.mode == "RGBA", (asset_id, picture.mode)
        assert picture.getchannel("A").getextrema()[0] == 0, asset_id
        SIZES[asset_id] = np.array(picture.size, dtype=float)
        if asset_id.startswith("planting_"):
            # Read alpha only to prove every opaque leaf stays outside the curb.
            # PNG pixels and proportions remain untouched.
            alpha = np.asarray(picture.getchannel("A"))
            ys, xs = np.where(alpha[::4, ::4] > 48)
            ALPHA_POINTS[asset_id] = np.column_stack((xs * 4, ys * 4)) / SIZES[asset_id]
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
for asset_id in ("herb_garden", "courtyard_steps"):
    register_asset(asset_id, PROJECT / "data/art/arc_sections" / (asset_id + ".png"))
for angle in (225, 255, 285, 315):
    asset_id = "planting_" + str(angle)
    register_asset(asset_id, PROJECT / "data/art/arc_sections/v3" / (asset_id + ".png"))

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


def place_polar(asset_id, angle, radius, width, area, section, label,
                anchor=(.5, .5), z=10, inward=False):
    """A section may move radially for clearance; its authored angle never drifts."""
    size = SIZES[asset_id]
    extent = np.array([width, width * size[1] / size[0]])
    assert np.all(extent * MAX_ZOOM <= size + .01), (asset_id, extent, size)
    for step in range(0, 481, 40):
        candidate_radius = radius + (-step if inward else step)
        contact = polar(angle, candidate_radius)
        rect = np.r_[contact - np.array(anchor) * extent, extent]
        if asset_id in ALPHA_POINTS:
            occupied = rect[:2] + ALPHA_POINTS[asset_id] * extent
            if np.linalg.norm(occupied - CENTER, axis=1).min() < OUTER_GROUND + 62:
                continue
        if clear(rect):
            PLACEMENTS.append({
                "asset_id": asset_id, "rect": np.round(rect, 2).tolist(),
                "areas": [area], "section": section, "label": label,
                "z_index": z, "ground_y": round(float(contact[1]), 2),
                "flip_h": False, "angle_degrees": angle,
                "anchor": list(anchor), "anchor_position": np.round(contact, 2).tolist(),
                "radius": candidate_radius,
            })
            return contact
    SKIPPED.append([area, section, label])
    return None


for area in ("bakery", "gelato"):
    house = "bakery_house" if area == "bakery" else "gelato_house"
    special = "bakery_mill" if area == "bakery" else "gelato_pavilion"
    tree = "oak_tree" if area == "bakery" else "lilac_tree"

    # An entrance cluster lies outside the start cut, never across its curb.
    section = "01 entrance garden"
    entrance = place(house, (-650, 360), 700, area, section, "welcome house", search=120)
    if entrance is not None:
        place("courtyard_steps", entrance + [-10, 290], 600, area, section, "entry forecourt", z=0, search=0)
        place(tree, entrance + [-390, -30], 460, area, section, "entrance shade tree", search=120)
        place("flower_planter", entrance + [330, 340], 180, area, section, "door flowers", search=60)

    # Upright architecture occupies gaps between the directional planting sections.
    # Foot contacts and forecourts are placed outside the perimeter, rather than
    # pasting horizontal curved planters across that perimeter.
    for index, (angle, width, asset_id) in enumerate([
        (213, 690, special), (241, 720, house), (270, 760, "greenhouse"),
        (299, 740, house), (327, 680, special),
    ]):
        section = f"{index + 2:02d} outer district {angle}"
        foot = place_polar(asset_id, angle, 5450, width, area, section,
                           "upright landmark", anchor=(.5, .90))
        if foot is None:
            continue
        # This horizontal forecourt belongs to its house, and is kept entirely
        # on the outer side of the curved town boundary.
        front = foot + [0, 42]
        step_width = min(620, width * .87)
        step_size = SIZES["courtyard_steps"]
        step_extent = np.array([step_width, step_width * step_size[1] / step_size[0]])
        step_center = front - np.array([0, step_extent[1] * .14])
        step_rect = np.r_[step_center - step_extent * .5, step_extent]
        corners = np.array([step_rect[:2], step_rect[:2] + step_rect[2:],
                            step_rect[:2] + [step_rect[2], 0], step_rect[:2] + [0, step_rect[3]]])
        # Entire slab outside the wall, including the foreground step.
        if np.linalg.norm(corners - CENTER, axis=1).min() > OUTER_GROUND + 70:
            place("courtyard_steps", step_center, step_width, area, section, "private forecourt", z=0, search=0)
        side = -1 if index in [0, 2, 4] else 1
        place(tree, foot + [side * width * .56, -width * .32], 430 + 20 * (index % 2),
              area, section, "courtyard shade tree", search=60)
        place("flower_planter", foot + [-side * width * .37, 36], 180,
              area, section, "door flowers", search=0)

    # These four images are generated for their exact position around the curve.
    # Each is used once per theme, at its matching tangent. They contain planting
    # only: the shared native geometry supplies the continuous stone boundary.
    for index, angle in enumerate((225, 255, 285, 315)):
        section = f"{index + 7:02d} directional planting {angle}"
        place_polar("planting_" + str(angle), angle, 5260, 760, area, section,
                    "planting follows local tangent", anchor=(.5, .5), z=8)

    # Interior scenery forms small garden islands rather than fragments of an
    # unrelated curved wall. Leave generous air between the scenery and the nodes.
    section = "11 inner conservatory garden"
    garden = place_polar("greenhouse", 270, 1050, 670, area, section,
                         "inner conservatory", anchor=(.5, .75), inward=True)
    if garden is not None:
        place("courtyard_steps", garden + [0, 155], 560, area, section, "garden terrace", z=0, search=0)
        place("herb_garden", garden + [-500, 210], 440, area, section, "kitchen herbs", search=120)
        place(tree, garden + [440, -40], 440, area, section, "garden shade", search=120)
        place("garden_bench", garden + [280, 340], 280, area, section, "garden seat", search=120)
    for index, angle in enumerate((229, 311)):
        section = f"{12 + index:02d} inner planted island"
        place_polar("herb_garden", angle, 1390, 430, area, section,
                    "independent round herb bed", inward=True)

# Fit the authored art and the shortened ground closely, instead of retaining
# the older near-semicircle's oversized canvas.
ground_points = np.array([polar(START + SWEEP * i / 120, radius)
                          for radius in [INNER_GROUND, 5550] for i in range(121)])
rect_points = np.array([point for p in PLACEMENTS for point in
                       (np.array(p["rect"][:2]), np.array(p["rect"][:2]) + np.array(p["rect"][2:]))])
all_points = np.concatenate((ground_points, rect_points, NODES), axis=0)
low = np.floor((all_points.min(axis=0) - 280) / 10) * 10
high = np.ceil((all_points.max(axis=0) + 280) / 10) * 10
WORLD = np.r_[low, high - low]
scene = {
    "schema": 2,
    "description": "Compact 120-degree upgrade arc with four degrees of quiet ground margin at each end. Directional planting follows its assigned angle; one continuous geometric curb defines the boundary. Separate PNGs remain independently editable.",
    "world_rect": WORLD.tolist(),
    "ground": {"center": CENTER.tolist(), "inner_radius": INNER_GROUND, "outer_radius": OUTER_GROUND,
               "start_angle_degrees": START, "sweep_degrees": SWEEP, "direction": 1},
    "landscaping": {
        "beds": [{"inner_radius": OUTER_GROUND + 30, "outer_radius": 5550, "color_key": "garden_color"}],
        "walls": [{"radius": OUTER_GROUND, "width": 60, "height": 22},
                  {"radius": 1800, "width": 44, "height": 14}],
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
    return [polar(START + SWEEP * i / 96, radius) for i in range(97)]


def points_text(points):
    return " ".join(f"{p[0]:.2f},{p[1]:.2f}" for p in points)


def write_svg(area):
    palette = scene["areas"][area]
    root = ET.Element("{" + SVG + "}svg", {
        "width": "1740", "height": str(round(1740 * WORLD[3] / WORLD[2])), "viewBox": " ".join(str(v) for v in WORLD),
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
    element(ground, "polygon", {"points": points_text(path_points(OUTER_GROUND) + list(reversed(path_points(INNER_GROUND)))), "fill": "#" + palette["band_color"]})
    for radius in [INNER_GROUND, OUTER_GROUND]:
        element(ground, "polyline", {"points": points_text(path_points(radius)), "fill": "none", "stroke": "#" + palette["border_color"], "stroke-opacity": .52, "stroke-width": 5})
        inset = radius + 9 if radius == INNER_GROUND else radius - 9
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
    pieces = sorted([p for p in PLACEMENTS if area in p["areas"]], key=lambda p: (p["z_index"], p.get("ground_y", p["rect"][1] + p["rect"][3])))
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

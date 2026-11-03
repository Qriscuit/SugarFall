"""Bake three irregular, independent upgrade routes into a compact 120-degree arc.

The canonical family sequences come from upgrade_graph.gd. No Python dependency
or placement randomness runs in game. Requires NumPy and Pillow for authoring.
Run from any directory; --preview-dir writes a geometry diagram for review.
"""
import argparse
import json
import math
from pathlib import Path
import random
import re

import numpy as np
from PIL import Image, ImageDraw

PROJECT = Path(__file__).resolve().parents[1]
SEED = 251027
TILE = 224.0
MIN_GAP = 40.0
CENTER = np.array([3400.0*math.cos(math.pi/6), 1700.0])
INNER, OUTER = 2200.0, 4600.0
START = math.radians(210)
SWEEP = math.radians(120)
MAX_LINK = 820.0


def cross(a, b):
    return a[..., 0]*b[..., 1]-a[..., 1]*b[..., 0]


def blocked_segments(a, b, centers, half=TILE/2+8):
    delta = b-a
    safe = np.where(np.abs(delta)<1e-9, 1e-9, delta)
    t0, t1 = (centers-half-a)/safe, (centers+half-a)/safe
    return np.maximum(np.minimum(t0, t1).max(axis=-1), 0) <= np.minimum(np.maximum(t0, t1).min(axis=-1), 1)


def graph():
    source = (PROJECT/'scripts/upgrade_graph.gd').read_text(encoding='utf-8-sig')
    families = json.loads(re.search(r'const ROUTE_FAMILIES = (\[[\s\S]*?\n\])', source).group(1))
    caps = json.loads(re.search(r'const CAPS = (\[[^\n]+\])', source).group(1))
    counts = [1, 0, 0, 0, 0, 0, 0, 0]
    root = (0, 1)
    routes = []
    parents = {}
    for sequence in families:
        route = []
        parent = root
        for family in sequence:
            counts[family] += 1
            node = (family, counts[family])
            route.append(node)
            parents[node] = parent
            parent = node
        routes.append(route)
    assert counts == caps, (counts, caps)
    ids = [root]
    for depth in range(max(map(len, routes))):
        ids.extend(route[depth] for route in routes if depth<len(route))
    return ids, routes, parents


def author():
    rng = random.Random(SEED)
    ids, routes, parents = graph()
    index = {node: i for i, node in enumerate(ids)}
    edges = np.array([[index[parent], index[node]] for node, parent in parents.items()])
    points = np.zeros((len(ids), 2))
    first = [(-270, -310), (0, -500), (270, -290)]
    target_radii = [4320.0, 3500.0, 2620.0]
    radial_bounds = [(3990, 4600), (3130, 3850), (2200, 2950)]
    lane_info = {}
    pinned = {0}
    for lane, route in enumerate(routes):
        head = np.array(first[lane], dtype=float)-CENTER
        first_angle = math.atan2(head[1], head[0])+math.tau
        first_radius = np.linalg.norm(head)
        # Equal angular spacing crowds square markers on diagonal parts of a
        # shorter arc. Seed by cumulative axis distance along each lane, then
        # jitter positions under the same exact clearance constraints.
        samples = np.linspace(0, 1, 2401)
        sample_blend = 1-(1-np.minimum(samples*(len(route)-1)/3, 1))**2
        sample_radii = first_radius+(target_radii[lane]-first_radius)*sample_blend
        sample_angles = first_angle+samples*(START+SWEEP-first_angle)
        sample_points = CENTER+np.column_stack([np.cos(sample_angles),np.sin(sample_angles)])*sample_radii[:,None]
        distance = np.r_[0,np.cumsum(np.abs(np.diff(sample_points,axis=0)).max(axis=1))]
        lane_parameters = np.interp(np.linspace(0,distance[-1],len(route)),distance,samples)
        for depth, node in enumerate(route):
            t = lane_parameters[depth]
            angle = first_angle+t*(START+SWEEP-first_angle)
            blend = 1-(1-min(t*(len(route)-1)/3, 1))**2
            radius = first_radius+(target_radii[lane]-first_radius)*blend
            points[index[node]] = CENTER+np.array([math.cos(angle), math.sin(angle)])*radius
            lane_info[index[node]] = (lane, depth, radius)
        points[index[route[0]]] = np.array(first[lane])
        pinned.add(index[route[0]])
        pinned.add(index[route[-1]])
    incident = [np.where((edges==i).any(axis=1))[0] for i in range(len(ids))]
    unrelated = [np.where(~np.isin(edges, edge).any(axis=1))[0] for edge in edges]
    others = [np.array([j for j in range(len(ids)) if j not in edge]) for edge in edges]

    def clear(i):
        gap = np.abs(points-points[i]).max(axis=1)
        gap[i] = math.inf
        if gap.min()<TILE+MIN_GAP: return False
        a, b = points[edges[:, 0]], points[edges[:, 1]]
        stationary = np.ones(len(edges), dtype=bool)
        stationary[incident[i]] = False
        if blocked_segments(a[stationary], b[stationary], points[i]).any(): return False
        for ei in incident[i]:
            if np.linalg.norm(b[ei]-a[ei])>MAX_LINK: return False
            if blocked_segments(a[ei], b[ei], points[others[ei]]).any(): return False
            candidates = unrelated[ei]
            c, d = a[candidates], b[candidates]
            r, s = b[ei]-a[ei], d-c
            den = cross(r, s)
            safe = np.where(np.abs(den)<1e-8, 1e-8, den)
            t, u = cross(c-a[ei], s)/safe, cross(c-a[ei], r)/safe
            if ((t>=0)&(t<=1)&(u>=0)&(u<=1)).any(): return False
        return True

    invalid = [ids[i] for i in range(len(ids)) if not clear(i)]
    if invalid: raise RuntimeError(f'Invalid route seed: {invalid}')
    accepted = 0
    for _ in range(32000):
        i = rng.randrange(len(ids))
        if i in pinned: continue
        lane, depth, original_radius = lane_info[i]
        route = routes[lane]
        old = points[i].copy()
        relative = old-CENTER
        angle = math.atan2(relative[1], relative[0])+math.tau
        radius = np.linalg.norm(relative)+rng.gauss(0, 85)
        angle += rng.gauss(0, .018)
        before = points[index[route[depth-1]]]-CENTER
        after = points[index[route[depth+1]]]-CENTER
        low_angle = math.atan2(before[1], before[0])+math.tau+.035
        high_angle = math.atan2(after[1], after[0])+math.tau-.035
        low_radius, high_radius = radial_bounds[lane]
        if depth<3:
            low_radius, high_radius = original_radius-230, original_radius+230
        if not (low_angle<angle<high_angle and max(INNER, low_radius)<radius<min(OUTER, high_radius)):
            continue
        points[i] = CENTER+np.array([math.cos(angle), math.sin(angle)])*radius
        if clear(i): accepted += 1
        else: points[i] = old
    points = np.round(points, 2)
    invalid = [ids[i] for i in range(len(ids)) if not clear(i)]
    if invalid: raise RuntimeError(f'Rounding violated route clearance: {invalid}')
    result = {
        'schema': 1,
        'description': 'Three independent, mixed single-parent routes across a compact 120-degree annular arc. Each family stays on one route in tier order. All future nodes are visible; progression and saved tier ownership remain authoritative.',
        'shape': {'kind': 'annular_arc', 'coverage': 1/3, 'sweep_degrees': 120,
                  'center': CENTER.tolist(), 'inner_radius': INNER, 'outer_radius': OUTER,
                  'start_angle_degrees': 210, 'direction': 1, 'seed': SEED},
        'routes': [[list(node) for node in route] for route in routes],
        'nodes': [{'id': list(node), 'position': points[i].tolist()} for i, node in enumerate(ids)],
        'edges': [{'from': list(ids[a]), 'to': list(ids[b]), 'points': [points[a].tolist(), points[b].tolist()]} for a, b in edges]
    }
    print(f'{accepted} accepted independent moves; {len(ids)} nodes, {len(edges)} straight edges; route lengths {list(map(len, routes))}')
    return result


def preview(data, destination):
    destination.mkdir(parents=True, exist_ok=True)
    positions = {tuple(n['id']): np.array(n['position']) for n in data['nodes']}
    points = np.array(list(positions.values()))
    low, high = points.min(axis=0)-180, points.max(axis=0)+180
    scale = 1750/(high-low)[0]
    picture = Image.new('RGB', tuple(np.ceil((high-low)*scale).astype(int)), '#dce9d8')
    draw = ImageDraw.Draw(picture)
    def screen(p): return tuple((np.array(p)-low)*scale)
    for edge in data['edges']:
        draw.line([screen(p) for p in edge['points']], fill='#526e5c', width=2)
    names = ['Feed', 'Power', 'Bounce', 'Ricochet', 'Split', 'Impact', 'Gold', 'Time']
    colors = ['#d2ab85', '#e1a390', '#dfb7d6', '#eadc8f', '#b7cf91', '#dba86a', '#f0cf70', '#a6c6c1']
    for (family, tier), p in positions.items():
        x, y = screen(p)
        r = TILE*.5*scale
        draw.rounded_rectangle((x-r,y-r,x+r,y+r),radius=8,fill=colors[family],outline='#556b57',width=1)
        draw.text((x,y),f'{names[family]}\n{tier}',anchor='mm',align='center',fill='#344a37')
    picture.save(destination/'layout-preview.png')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview-dir', type=Path)
    args = parser.parse_args()
    result = author()
    target = PROJECT/'data/upgrade_layout.json'
    target.write_text(json.dumps(result,indent=2)+'\n')
    if args.preview_dir: preview(result,args.preview_dir)
    print(target)

"""Author Gelato's winding tree geometry and reproducible placement guide.

Graph sequences own upgrade identities; this tool owns positions and clearance.
Runtime reads the baked JSON and uses no placement randomness.
"""
import json
import math
from pathlib import Path
import re

PROJECT = Path(__file__).resolve().parents[1]
ART = PROJECT.parent / "concept-art/gelato-tree-v2"
WORLD_RECT = [-4600, -12250, 9200, 13800]
MINIMUM_SPACING = 340.0
MIN_ZOOM = .055
LINK_KEEPOUT = 64.0
TREE_RESERVES = [
    {"id": "central_fountain", "rect": [-800, -5400, 1200, 1500]},
    {"id": "central_kiosk", "rect": [-550, -9700, 1100, 1600]},
    {"id": "central_pavilion", "rect": [-450, -7800, 1700, 1500]},
    {"id": "central_flower_island", "rect": [-260, -3300, 520, 1200]},
    {"id": "left_upper_garden", "rect": [-4250, -10600, 1000, 2400]},
    {"id": "right_upper_garden", "rect": [3250, -10100, 1000, 2600]},
    {"id": "left_lower_garden", "rect": [-4000, -6200, 850, 2200]},
    {"id": "right_lower_garden", "rect": [3150, -5900, 850, 2300]},
    {"id": "bottom_left_flowers", "rect": [-3300, -1100, 1500, 1600]},
    {"id": "bottom_right_flowers", "rect": [1900, -900, 1500, 1500]},
    {"id": "entry_left_topiary", "rect": [-900, 600, 600, 550]},
    {"id": "entry_right_topiary", "rect": [300, 600, 600, 550]},
]
LEFT_STEM = [
    (-500, -280), (-650, -640), (-950, -1000), (-1510, -1080),
    (-2000, -1260), (-2420, -1460), (-2480, -1900), (-2480, -2340),
    (-2500, -2780), (-3030, -3380), (-3360, -3980), (-3520, -4580),
    (-3500, -5180), (-3290, -5780),
]
OUTER_TINE = [(-1250, -1360), (-1550, -1720), (-1780, -2080),
              (-1900, -2440), (-1900, -2800), (-1200, -3160)]
NESTED_TINE = [(-3200, -1660), (-3420, -1960), (-3560, -2300),
               (-3820, -2680), (-4000, -3100), (-4100, -3540)]
INNER_TINE = [(-1900, -3260), (-2400, -3660), (-2290, -4100),
              (-2070, -4540), (-1840, -4980)]
VERTICAL_STRETCH = 1.25


def segment_intersection(a, b, c, d):
    cross = lambda u, v: u[0] * v[1] - u[1] * v[0]
    sub = lambda u, v: (u[0] - v[0], u[1] - v[1])
    r, s = sub(b, a), sub(d, c)
    denominator = cross(r, s)
    if abs(denominator) < 1e-9:
        return False
    return 0 <= cross(sub(c, a), s) / denominator <= 1 and 0 <= cross(sub(c, a), r) / denominator <= 1


def intersection_points(a, b, c, d):
    cross = lambda u,v:u[0]*v[1]-u[1]*v[0]
    r,s = delta(a,b),delta(c,d)
    denominator = cross(r,s)
    if abs(denominator)>1e-9:
        t,u = cross(delta(a,c),s)/denominator,cross(delta(a,c),r)/denominator
        return [(a[0]+t*r[0],a[1]+t*r[1])] if -1e-8<=t<=1+1e-8 and -1e-8<=u<=1+1e-8 else []
    if abs(cross(delta(a,c),r))>1e-6: return []
    def on_segment(p,x,y):
        return min(x[0],y[0])-1e-6<=p[0]<=max(x[0],y[0])+1e-6 and min(x[1],y[1])-1e-6<=p[1]<=max(x[1],y[1])+1e-6
    return [p for p in [a,b,c,d] if on_segment(p,a,b) and on_segment(p,c,d)]


def line_rect_intersection(a, b, rect):
    x, y, w, h = rect
    inside = lambda p: x < p[0] < x + w and y < p[1] < y + h
    if inside(a) or inside(b):
        return True
    corners = [(x, y), (x+w, y), (x+w, y+h), (x, y+h)]
    return any(segment_intersection(a, b, corners[i], corners[(i+1) % 4]) for i in range(4))


def rects_overlap(a, b):
    return a[0] < b[0]+b[2] and a[0]+a[2] > b[0] and a[1] < b[1]+b[3] and a[1]+a[3] > b[1]


def point(side, value):
    return (float(value[0] if side == 0 else -value[0]), float(value[1] * VERTICAL_STRETCH))


def warp(p):
    """Continuous, one-to-one bend: paths retain topology while the tree sways."""
    x, y = p
    if y >= -350:
        return (round(x, 4), round(y, 4))
    height = -y
    stretched = 350 + (height-350)*1.52
    fade = 1-math.exp(-(height-350)/850)
    width = 1-.38*fade
    drift = fade*420*math.sin((stretched-350)/880)
    return (round(x*width+drift, 4), round(-stretched, 4))


def delta(a, b):
    return (b[0]-a[0], b[1]-a[1])


def distance(a, b):
    return math.hypot(*delta(a, b))


def tangent(previous, current, following):
    if previous is None: return delta(current, following)
    if following is None: return delta(previous, current)
    direction = delta(previous, following)
    length = math.hypot(*direction)
    magnitude = min(distance(previous,current),distance(current,following))
    return tuple(v*magnitude/length for v in direction)


def cubic(a, b, ta, tb):
    # Cubic Hermite links share tangents at ordinary nodes. True forks have
    # distinct outgoing tangents, and the terminal tine follows the incoming
    # tangent so the continuing side route is not advertised by a straight stem.
    samples = []
    for step in range(25):
        t = step/24
        h00, h10 = 2*t**3-3*t*t+1, t**3-2*t*t+t
        h01, h11 = -2*t**3+3*t*t, t**3-t*t
        samples.append(warp(tuple(h00*a[i]+h10*ta[i]+h01*b[i]+h11*tb[i] for i in range(2))))
    return samples


def curve_paths(positions, routes, branches, root):
    paths = {}
    fork_child = {b['anchor']:b['nodes'][0] for b in branches}
    deep_forks = {b['anchor'] for b in branches if b['fork_depth']==9}
    for route in routes:
        chain = [root]+route
        for i in range(len(chain)-1):
            parent, node = chain[i:i+2]
            previous = positions[chain[i-1]] if i else None
            following = positions[chain[i+2]] if i+2<len(chain) else None
            ta = tangent(previous,positions[parent],positions[node])
            tb = tangent(positions[parent],positions[node],following)
            if parent in fork_child:
                ta = delta(positions[parent],positions[node])
                if parent in deep_forks:
                    # The strong global S-bend otherwise masks this last side
                    # turn under its tile. Bow only the continuing link outward
                    # so its visible exit clearly branches off the straight tine.
                    ta = (ta[0]*2.5,ta[1])
            if node in fork_child:
                tb = delta(positions[parent],positions[node])
            paths[(parent,node)] = cubic(positions[parent],positions[node],ta,tb)
    for branch in branches:
        route = routes[branch['route_index']]
        anchor_index = route.index(branch['anchor'])
        before_anchor = positions[route[anchor_index-1]]
        chain = [branch['anchor']]+branch['nodes']
        for i in range(len(chain)-1):
            parent,node = chain[i:i+2]
            previous = positions[chain[i-1]] if i else before_anchor
            following = positions[chain[i+2]] if i+2<len(chain) else None
            outgoing = tuple(v*2.2 for v in delta(previous,positions[parent])) if i==0 else tangent(previous,positions[parent],positions[node])
            paths[(parent,node)] = cubic(positions[parent],positions[node],
                outgoing,
                tangent(positions[parent],positions[node],following))
    return paths


def visible_tangent(path, incoming, half_size):
    """Actual polyline direction where it exits the opaque square node face."""
    ordered = list(reversed(path)) if incoming else path
    center = ordered[0]
    for index in range(1,len(ordered)):
        if max(abs(ordered[index][axis]-center[axis]) for axis in range(2))>=half_size:
            return delta(ordered[index],ordered[index-1]) if incoming else delta(ordered[index-1],ordered[index])
    raise AssertionError('Curve has no visible section outside its node')


def guide(geometry):
    from PIL import Image, ImageDraw, ImageFont
    width, height = 1200, 1800
    image = Image.new("RGB", (width, height), "#e8d8ef")
    draw = ImageDraw.Draw(image)
    px = lambda p: ((p[0]-WORLD_RECT[0])*width/WORLD_RECT[2], (p[1]-WORLD_RECT[1])*height/WORLD_RECT[3])
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 15)
        small = ImageFont.truetype("C:/Windows/Fonts/arial.ttf", 11)
    except OSError:
        font = small = ImageFont.load_default()
    for reserve in TREE_RESERVES:
        x, y, w, h = reserve["rect"]
        a, b = px((x, y)), px((x+w, y+h))
        draw.rounded_rectangle((*a, *b), radius=18, fill="#c4ddbf", outline="#558d66", width=3)
        draw.multiline_text((a[0]+8, a[1]+12), reserve['id'].replace('_','\n').upper(), font=small, fill="#315f3c")
    for edge in geometry["links"]:
        draw.line([px(p) for p in edge["points"]], fill="#b58e6c", width=6)
    for node in geometry["nodes"]:
        x, y = px(node["position"])
        keepout = node['keepout_rect']
        a,b = px(keepout[:2]),px((keepout[0]+keepout[2],keepout[1]+keepout[3]))
        draw.rectangle((*a,*b), fill="#dac9df", outline="#bda9c5", width=1)
        half = 112*width/WORLD_RECT[2]
        fill = "#f8eccd" if node["id"] != (8,1) else "#ddd9e3"
        draw.rounded_rectangle((x-half, y-half, x+half, y+half), 7, fill=fill, outline="#977549", width=2)
        label = "START" if node["id"] == (0,1) else ("DUAL" if node["id"] == (8,1) else f"{node['id'][0]}:{node['id'][1]}")
        box = draw.textbbox((0,0),label,font=small)
        draw.text((x-(box[2]-box[0])/2,y-5),label,font=small,fill="#584434")
    draw.text((36,32),"GELATO WINDING TREE — EXACT PLACEMENT GUIDE",font=font,fill="#584434")
    draw.text((36,58),"Lavender: maximum UI footprint. Green: artwork islands. Brown: sampled curved links.",font=small,fill="#584434")
    image.save(ART / "layout-guide.png")


def author():
    source = (PROJECT / "scripts/gelato_upgrade_graph.gd").read_text(encoding="utf-8-sig")
    families = json.loads(re.search(r"const ROUTE_FAMILIES = (\[[\s\S]*?\n\])", source).group(1))
    specs = json.loads(re.search(r"const BRANCH_SPECS = (\[[\s\S]*?\n\])", source).group(1))
    caps = json.loads(re.search(r"const CAPS = (\[[^\n]+\])", source).group(1))
    counts = [1,0,0,0,0,0,0,0]
    root = (0,1)
    positions = {root:(0.0,0.0)}
    parents, routes = {}, []
    for side, sequence in enumerate(families):
        parent = root
        route = []
        for depth, family in enumerate(sequence):
            counts[family] += 1
            node = (family, counts[family])
            positions[node] = point(side, LEFT_STEM[depth])
            parents[node] = parent
            route.append(node)
            parent = node
        routes.append(route)
    branches = []
    for index, spec in enumerate(specs):
        anchor = tuple(spec["anchor"])
        parent = anchor
        nodes = []
        coords = [OUTER_TINE, NESTED_TINE, INNER_TINE][index % 3]
        for depth, family in enumerate(spec["families"]):
            counts[family] += 1
            node = (family, counts[family])
            positions[node] = point(spec["route_index"],coords[depth])
            parents[node] = parent
            nodes.append(node)
            parent = node
        branches.append({"anchor":anchor,"nodes":nodes,"route_index":spec["route_index"],
                         "parent_branch":spec["parent_branch"],"nested":False,
                         "length":len(nodes),"fork_depth":[3,6,9][index % 3]})
    assert counts == caps, (counts,caps)
    ordered = [root]
    for depth in range(max(map(len,routes))):
        ordered.extend(route[depth] for route in routes if depth<len(route))
    for branch in branches:
        ordered.extend(branch["nodes"])
    assert len(ordered) == len(set(ordered)) == 62
    special = {"id":(8,1),"parent":root,"position":(0.0,440.0),
               "requires":{"tray":8,"power":6},"always_visible":True}
    paths = curve_paths(positions,routes,branches,root)
    positions = {node:warp(p) for node,p in positions.items()}
    all_positions = {**positions,special["id"]:special["position"]}
    edges = [(parents[n],n) for n in ordered if n != root]
    all_edges = edges+[(root,special["id"])]
    paths[(root,special["id"])] = [positions[root],special['position']]
    minimum = math.inf
    nearest = {node:math.inf for node in all_positions}
    for index, (a,p) in enumerate(all_positions.items()):
        for b,q in list(all_positions.items())[index+1:]:
            spacing = max(abs(p[0]-q[0]),abs(p[1]-q[1]))
            minimum = min(minimum,spacing)
            nearest[a] = min(nearest[a],spacing)
            nearest[b] = min(nearest[b],spacing)
            assert spacing>=MINIMUM_SPACING-1e-6,(a,b,spacing)
    # At overview zoom, readable icons expand in world space; reserve their
    # worst actual footprint, not only the 224-unit full-detail square.
    keepouts, footprints = {}, {}
    for node,p in all_positions.items():
        peak_zoom = max(MIN_ZOOM,min(1.55,38/nearest[node]))
        compact_peak = min(max(224*peak_zoom,36),nearest[node]*peak_zoom-2)/peak_zoom
        footprint_size = max(224,compact_peak)
        footprints[node] = [p[0]-footprint_size/2,p[1]-footprint_size/2,footprint_size,footprint_size]
        size = footprint_size+60
        keepouts[node] = [p[0]-size/2,p[1]-size/2,size,size]
        rect = keepouts[node]
        assert rect[0]>=WORLD_RECT[0] and rect[1]>=WORLD_RECT[1]
        assert rect[0]+rect[2]<=WORLD_RECT[0]+WORLD_RECT[2]
        assert rect[1]+rect[3]<=WORLD_RECT[1]+WORLD_RECT[3]
    for index,node in enumerate(all_positions):
        for other in list(all_positions)[index+1:]:
            assert not rects_overlap(footprints[node],footprints[other]),('compact tile overlap',node,other)
    for index, edge in enumerate(all_edges):
        curve = paths[edge]
        for segment,(a,b) in enumerate(zip(curve,curve[1:])):
            for c,d in list(zip(curve,curve[1:]))[segment+2:]:
                assert not intersection_points(a,b,c,d),('self-crossing curve',edge)
        for other in all_edges[index+1:]:
            shared = set(edge)&set(other)
            other_curve = paths[other]
            for a,b in zip(curve,curve[1:]):
                for c,d in zip(other_curve,other_curve[1:]):
                    if shared:
                        for crossing in intersection_points(a,b,c,d):
                            assert any(distance(crossing,all_positions[node])<.001 for node in shared),('crossing beyond shared endpoint',edge,other)
                    else:
                        assert not intersection_points(a,b,c,d),(edge,other)
        for node,p in all_positions.items():
            if node in edge: continue
            for a,b in zip(curve,curve[1:]):
                rect = footprints[node]
                padded = [rect[0]-LINK_KEEPOUT,rect[1]-LINK_KEEPOUT,rect[2]+2*LINK_KEEPOUT,rect[3]+2*LINK_KEEPOUT]
                assert not line_rect_intersection(a,b,padded),("curve through compact tile",edge,node,a,b,padded)
    for reserve in TREE_RESERVES:
        rect = reserve["rect"]
        for node,p in all_positions.items():
            assert not rects_overlap(keepouts[node],rect),(reserve,node)
        padded = [rect[0]-LINK_KEEPOUT,rect[1]-LINK_KEEPOUT,rect[2]+2*LINK_KEEPOUT,rect[3]+2*LINK_KEEPOUT]
        for edge in all_edges:
            curve = paths[edge]
            for a,b in zip(curve,curve[1:]):
                assert not line_rect_intersection(a,b,padded),(reserve,edge)
    handoffs = []
    for branch in branches:
        route = routes[branch["route_index"]]
        depth = route.index(branch["anchor"])
        incoming_path = paths[(route[depth-1],branch['anchor'])]
        continuing_path = paths[(branch['anchor'],route[depth+1])]
        terminal_path = paths[(branch['anchor'],branch['nodes'][0])]
        incoming = delta(incoming_path[-2],incoming_path[-1])
        continuing = delta(continuing_path[0],continuing_path[1])
        terminal = delta(terminal_path[0],terminal_path[1])
        dot = lambda a,b:sum(a[i]*b[i] for i in range(2))/(math.hypot(*a)*math.hypot(*b))
        terminal_dot,continuing_dot = dot(incoming,terminal),dot(incoming,continuing)
        assert terminal_dot>continuing_dot+.05,('fork gives away real continuation',branch['anchor'],terminal_dot,continuing_dot)
        visible_margins = {}
        for name,half in [('full_detail',112),('peak_compact',footprints[branch['anchor']][2]/2)]:
            arrival = visible_tangent(incoming_path,True,half)
            direct = visible_tangent(terminal_path,False,half)
            turning = visible_tangent(continuing_path,False,half)
            margin = dot(arrival,direct)-dot(arrival,turning)
            assert margin>0,('visible fork gives away real continuation',branch['anchor'],name,margin)
            visible_margins[name] = round(margin,6)
        handoffs.append({"anchor":branch["anchor"],"incoming":route[depth-1],
                         "continuation":route[depth+1],"terminal_branch":branch["nodes"][0],
                         "route_index":branch["route_index"],"fork_depth":depth+1,
                         "terminal_tangent_dot":round(terminal_dot,6),"continuation_tangent_dot":round(continuing_dot,6),
                         "visible_tangent_margins":visible_margins})
    data = {
        "schema":1,
        "description":"A narrow, tall Gelato tree winds through a garden. Sampled curves connect two mixed-upgrade routes; at three successive forks the apparent side branch continues while the straighter tine ends after 4-6 upgrades. A central starter and visible Dual Shot below it remain fixed. Each of the 62 upgrade slots has a stable identity and reveals only after its actual parent is owned.",
        "shape":{"kind":"winding_tree","root":[0,0],"minimum_center_spacing":MINIMUM_SPACING,
                 "world_rect":WORLD_RECT,"entry":"center","scenery_reserves":TREE_RESERVES,
                 "branch_lengths":[len(b["nodes"]) for b in branches],"curve_samples":25,
                 "minimum_overview_zoom":MIN_ZOOM},
        "routes":routes,"branches":branches,"spine_handoffs":handoffs,"special_nodes":[special],
        "nodes":[{"id":n,"position":positions[n]} for n in ordered],
        "edges":[{"from":parent,"to":node,"points":paths[(parent,node)]} for parent,node in edges],
    }
    (PROJECT / "data/gelato_upgrade_layout.json").write_text(json.dumps(data,indent=2)+"\n",encoding="utf-8")
    geometry = {"layout":"PLINKO/data/gelato_upgrade_layout.json","world_rect":WORLD_RECT,
                "scenery_reserves":TREE_RESERVES,"branches":branches,"spine_handoffs":handoffs,
                "nodes":[{"id":n,"position":p,"keepout_rect":keepouts[n],"maximum_footprint":footprints[n]} for n,p in all_positions.items()],
                "links":[{"from":parent,"to":node,"points":paths[(parent,node)],"keepout_radius":LINK_KEEPOUT} for parent,node in all_edges]}
    ART.mkdir(parents=True,exist_ok=True)
    (ART / "geometry.json").write_text(json.dumps(geometry,indent=2)+"\n",encoding="utf-8")
    guide(geometry)
    stats = {"nodes":len(ordered),"edges":len(edges),"route_lengths":list(map(len,routes)),
                      "branch_lengths":[len(b["nodes"]) for b in branches],"spine_handoffs":len(handoffs),
                      "minimum_spacing":minimum,"world_rect":WORLD_RECT,"twin":special,
                      "node_bounds":[min(p[0] for p in all_positions.values()),min(p[1] for p in all_positions.values()),max(p[0] for p in all_positions.values()),max(p[1] for p in all_positions.values())],
                      "scenery_islands":len(TREE_RESERVES),"curved_links":len(edges),"curve_samples":25,
                      "compact_keepouts_validated":True,"shared_endpoint_and_self_crossings_checked":True,
                      "fork_tangent_handoffs_validated":True,"full_detail_and_peak_compact_visible_handoffs_validated":True}
    (ART/'geometry-stats.json').write_text(json.dumps(stats,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(stats))


if __name__ == "__main__":
    author()

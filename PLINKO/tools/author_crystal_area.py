"""Author Crystal's twelve aimed-shot trays and independent faceted shop map."""
import itertools
import json
import math
from pathlib import Path
import re

PROJECT=Path(__file__).resolve().parents[1]
ART=PROJECT.parent/'concept-art/crystal-candyworks-v1'
WORLD=[-3300,-9000,6600,9900]

def write(path,value):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,indent=2)+'\n',encoding='utf-8')

def rows(*specs):
    return [[x,y] for y,xs in specs for x in xs]

def boards():
    designs=[
      ('First Refraction','crystal_lanes','Aim through the wide center lane, then bank toward the outside crystals.',rows((390,[250,470]),(500,[190,360,530]),(630,[250,360,470]),(760,[360]))),
      ('Mirror Wings','crystal_banks','Side clusters reward a clean wall bank before the center group.',rows((380,[100,210,510,620]),(510,[100,270,450,620]),(650,[210,360,510]))),
      ('Split Gate','crystal_gate','Two gate openings give different lines into the lower crystals.',rows((370,[150,250,470,570]),(490,[210,310,410,510]),(620,[150,250,470,570]),(750,[300,420]))),
      ('Silver Shelves','crystal_shelves','Staggered shelves leave alternating entry angles.',rows((370,[130,245,475,590]),(490,[190,305,415,530]),(610,[130,245,475,590]),(740,[190,305,415,530]))),
      ('Banking Hall','crystal_hall','The center opens into side walls of crystals and a lower crossbar.',rows((360,[100,200,520,620]),(475,[100,275,445,620]),(590,[100,200,520,620]),(710,[150,255,360,465,570]),(820,[275,445]))),
      ('Prism Workshop','crystal_workshop','Use the center channel to reach protected lower groups.',rows((360,[140,250,470,580]),(470,[195,305,415,525]),(580,[140,250,470,580]),(690,[195,305,415,525]),(800,[250,360,470]))),
      ('Gold Galleries','crystal_galleries','Offset gold galleries reward longer angled ricochets.',rows((355,[110,220,500,610]),(465,[165,275,445,555]),(575,[110,220,360,500,610]),(685,[165,275,445,555]),(795,[110,220,360,500,610]))),
      ('Faceted Crown','crystal_crown','Break the crown through either shoulder and aim into the lower fan.',rows((350,[250,360,470]),(455,[140,250,470,580]),(560,[90,200,310,410,520,630]),(665,[140,250,360,470,580]),(770,[90,200,310,410,520,630]))),
      ('Glass Foundry','crystal_foundry','Three staggered columns offer deliberate bank-shot choices.',rows((350,[100,210,320,430,540,620]),(460,[155,265,455,565]),(570,[100,210,320,430,540,620]),(680,[155,265,455,565]),(790,[100,210,320,430,540,620]))),
      ('Diamond Arcade','crystal_arcade','Dense arcade bays retain vertical and diagonal escape gaps.',rows((350,[100,205,310,410,515,620]),(455,[150,255,465,570]),(560,[100,205,310,410,515,620]),(665,[150,255,360,465,570]),(770,[100,205,310,410,515,620]),(875,[255,465]))),
      ('Crystal Loom','crystal_loom','Weave straight shots through alternating narrow lanes.',rows((350,[100,205,310,410,515,620]),(455,[150,255,360,465,570]),(560,[100,205,310,410,515,620]),(665,[150,255,360,465,570]),(770,[100,205,310,410,515,620]),(875,[205,360,515]))),
      ('Candyworks Heart','crystal_heart','The final layered crystal chamber rewards sustained banks and both prism offers.',rows((350,[100,205,310,410,515,620]),(455,[150,255,360,465,570]),(560,[100,205,310,410,515,620]),(665,[150,255,360,465,570]),(770,[100,205,310,410,515,620]),(875,[150,255,360,465,570])))
    ]
    result=[]
    for index,(name,family,brief,positions) in enumerate(designs):
        level=index+1
        assert 1<=len(positions)<=48
        assert all(50<=x<=670 and 290<=y<=900 for x,y in positions)
        assert min(math.dist(a,b) for a,b in itertools.combinations(positions,2))>=65
        result.append({'level':level,'name':name,'family':family,'trait_brief':brief,
            'peg_count':len(positions),'base_hp':[6,12,18,24][index//3],
            'armored_count':0 if level<=3 else (1 if level<=6 else 2 if level<=9 else 3),
            'armored_hp_multiplier':1.8,'clock_peg_count':0 if level==1 else 2,
            'recommended_module':None if level<3 else ('ricochet' if level<7 else 'splitter'),
            'positions':positions,'strength_tier':['bronze','silver','gold','diamond'][index//3]})
    write(PROJECT/'data/crystal_board_design.json',{'schema_version':1,'area_id':'crystal',
        'chapter':'Crystal Candyworks','status':'Authored straight-shot banks and gaps; provisional tuning requires device playtesting.',
        'base_timer_seconds':10,'boards':result})

def shop():
    source=(PROJECT/'scripts/upgrade_graph.gd').read_text(encoding='utf-8-sig')
    families=json.loads(re.search(r'const ROUTE_FAMILIES = (\[[\s\S]*?\n\])',source).group(1))
    counts=[1,0,0,0,0,0,0,0];root=(0,1)
    positions={root:(0.,0.)};parents={};routes=[]
    for side,sequence in enumerate(families):
        route=[];parent=root
        for depth,family in enumerate(sequence):
            counts[family]+=1;node=(family,counts[family])
            if depth==0:p=[(-430.,-350.),(0.,-560.),(430.,-350.)][side]
            else:
                y=-350-depth*365 if side!=1 else -560-depth*365
                x=(-1050-230*math.sin(depth*.77)) if side==0 else (125*math.sin(depth*.79) if side==1 else 1050+230*math.sin(depth*.69))
                p=(round(x,4),float(y))
            positions[node]=p;parents[node]=parent;route.append(node);parent=node
        routes.append(route)
    assert counts==[10,10,6,6,6,6,8,10]
    ordered=[root]
    for depth in range(max(map(len,routes))):ordered += [r[depth] for r in routes if depth<len(r)]
    special={'id':(8,1),'parent':root,'position':(0.,440.),'always_visible':True,'requires':{'tray':6,'power':4}}
    all_pos={**positions,(8,1):special['position']}
    spacing={n:min(max(abs(p[i]-q[i]) for i in range(2)) for m,q in all_pos.items() if m!=n) for n,p in all_pos.items()}
    assert min(spacing.values())>=340
    edges=[]
    for node in ordered[1:]:
        parent=parents[node];a,b=positions[parent],positions[node]
        points=[a,b] if parent==root else [a,(a[0],a[1]+(b[1]-a[1])*.2),(b[0],a[1]+(b[1]-a[1])*.8),b]
        edges.append({'from':parent,'to':node,'points':points})
    # Reuse the winding-tree author's strict segment/rectangle primitives.
    import author_gelato_u_map as audit
    keepouts={}
    for node,p in all_pos.items():
        z=max(.055,min(1.55,38/spacing[node]))
        size=max(224,min(max(224*z,36),spacing[node]*z-2)/z)
        keepouts[node]=[p[0]-size/2-30,p[1]-size/2-30,size+60,size+60]
    for a,b in itertools.combinations(keepouts,2):
        ra,rb=keepouts[a],keepouts[b]
        assert not audit.rects_overlap([ra[0]+30,ra[1]+30,ra[2]-60,ra[3]-60],[rb[0]+30,rb[1]+30,rb[2]-60,rb[3]-60]),('compact marker overlap',a,b)
    all_edges=edges+[{'from':root,'to':(8,1),'points':[positions[root],special['position']]}]
    for index,edge in enumerate(all_edges):
        for other in all_edges[index+1:]:
            common=set([edge['from'],edge['to']])&set([other['from'],other['to']])
            for a,b in zip(edge['points'],edge['points'][1:]):
                for c,d in zip(other['points'],other['points'][1:]):
                    for p in audit.intersection_points(a,b,c,d):
                        assert common and any(math.dist(p,all_pos[n])<.001 for n in common),(edge,other)
        for node,rect in keepouts.items():
            if node in [edge['from'],edge['to']]:continue
            padded=[rect[0]-34,rect[1]-34,rect[2]+68,rect[3]+68]
            for a,b in zip(edge['points'],edge['points'][1:]):
                assert not audit.line_rect_intersection(a,b,padded),(edge,node)
    data={'schema':1,'description':'Three faceted Crystal spires use independent sequential-family routes. Second Prism is visible beneath the starter; tray6 andPower4 gate the optional purchase.',
        'shape':{'kind':'crystal_spires','world_rect':WORLD,'entry':'center','minimum_center_spacing':340},
        'routes':routes,'special_nodes':[special],
        'nodes':[{'id':n,'position':positions[n]} for n in ordered],'edges':edges}
    write(PROJECT/'data/crystal_upgrade_layout.json',data)
    geometry={'world_rect':WORLD,'nodes':[{'id':n,'position':p,'keepout_rect':keepouts[n]} for n,p in all_pos.items()],
        'links':[dict(e,keepout_radius=64) for e in all_edges]}
    write(ART/'geometry.json',geometry)
    from PIL import Image,ImageDraw,ImageFont
    image=Image.new('RGB',(1200,1800),'#dcecf3');draw=ImageDraw.Draw(image)
    px=lambda p:((p[0]-WORLD[0])*1200/WORLD[2],(p[1]-WORLD[1])*1800/WORLD[3])
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',12)
    for edge in all_edges:draw.line([px(p) for p in edge['points']],fill='#568a9e',width=4)
    for n,p in all_pos.items():
        r=keepouts[n];a,b=px(r[:2]),px((r[0]+r[2],r[1]+r[3]));draw.rectangle((*a,*b),fill='#d0dce7',outline='#9badc4')
        x,y=px(p);s=112*1200/WORLD[2];draw.rounded_rectangle((x-s,y-s,x+s,y+s),5,fill='#f6e8c9',outline='#8f896c')
        text='START' if n==root else 'PRISM' if n==(8,1) else f'{n[0]}:{n[1]}'
        draw.text((x-16,y-5),text,font=font,fill='#41465b')
    draw.text((30,30),'CRYSTAL CANDYWORKS — THREE FACETED SPIRES',font=font,fill='#41465b')
    draw.text((30,52),'Keep detailed artwork outside shaded node footprints and blue live links.',font=font,fill='#41465b')
    image.save(ART/'layout-guide.png')
    stats={'nodes':len(ordered),'special_nodes':1,'edges':len(edges),'minimum_spacing':min(spacing.values()),'world_rect':WORLD,'peak_compact_footprints_checked':True,'unrelated_tile_path_stroke_clearance':64,
        'node_bounds':[min(p[0] for p in all_pos.values()),min(p[1] for p in all_pos.values()),max(p[0] for p in all_pos.values()),max(p[1] for p in all_pos.values())]}
    write(ART/'geometry-stats.json',stats);print(json.dumps(stats))

if __name__=='__main__':
    boards();shop()

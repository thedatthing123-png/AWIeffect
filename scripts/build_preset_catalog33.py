"""Reproduce the authored Build 33 preset manifests. Rows are deliberate recipes,
not a Cartesian product of color/strength variants. Runtime uses the JSON only.
"""
from pathlib import Path
import json,re
ROOT=Path(__file__).resolve().parents[1]
FX={}
def fx(code,id,**values):FX[code]={'id':id,'values':values}
fx('G','awi.deepGlow',radius=28,exposure=-0.6,threshold=12,mix=70)
fx('A','awi.rgbSplit',amount=3,angle=15)
fx('B','ae.gaussianBlur',blurriness=4)
fx('D','ae.directionalBlur',length=16,direction=0)
fx('H','awi.halftone',size=5)
fx('P','awi48.craft.paper',first=5,second=2,third=.4)
fx('T','awi48.craft.stamp',first=7,second=1.15,third=.9)
fx('F','awi48.craft.fringe',first=7,second=3,third=.4)
fx('C','awi48.craft.stitch',first=7,second=5,third=1)
fx('S','awi48.craft.sequin',first=9,second=25,third=.1)
fx('J','awi48.craft.junctions',first=18,second=1,third=.45,gain=10,halo=5,energy=.7)
fx('L','awi48.craft.flowLight',first=22,second=1,third=2,halo=5,energy=.8)
fx('R','awi48.craft.chromaTrails',first=18,second=1,third=2,halo=6,energy=.7)
fx('Q','awi48.craft.prismInk',first=3,second=1,third=.06,halo=4,energy=.6)
fx('W','awi46.spectral.dispersion',first=5,angle=0)
fx('K','awi46.spectral.quadrature',first=35,angle=30)
fx('X','awi46.spectral.scramble',first=.16,seed=11,speed=.2)
fx('N','awi36.light.annularGlow',radius=9,width=1.2,softness=.8,intensity=.7)
fx('O','awi36.light.spectralHalo',radius=10,dispersion=55,width=1.4,softness=.8,intensity=.8)
fx('U','awi36.light.spiralLight',angle=35,pull=16,softness=1,intensity=.8)
fx('Z','awi36.light.lensGhosts',spacing=40,count=3,dispersion=2,softness=1,intensity=.5)
fx('E','awi37.retro.ccdSmear',length=35,threshold=40,softness=1,gain=.8)
fx('V','awi37.retro.plateRegistration')
fx('Y','awi37.retro.compositeCrosstalk')
fx('M','awi.manga')
fx('I','awi37.draw.ridgeInk')
fx('AH','awi37.draw.adaptiveHatch')
fx('ES','awi37.draw.edgeStretch')
fx('CT','awi37.draw.curvature')
fx('ME','awi37.draw.mezzotint')
fx('SE','awi37.draw.spiralEngraving')
fx('EL','awi37.draw.edgeSolarize')
for index,name in enumerate(['rowDuplicate','columnMelt','chromaShatter','tileSlip','scanlineRipple','lumaShards','rasterSkew','blockDesync','bitplaneSlip','signalDrop'],1):fx('g'+str(index),'awi31.'+name)
fx('Sort','awi31.segmentSort',length=24,low=20,high=90,blend=65)
fx('Bend','awi6.bend',angle=18,start=15)
fx('Skin','awi44.finish.brushed')
fx('Contour','awi41.contour.light')

def effects(codes):return [FX[code].copy() for code in codes.split('+') if code!='-']
def slug(name):return re.sub('[^a-z0-9]+','-',name.lower()).strip('-')
TEXT=[]
def text(category,rows):
 for line in rows.strip().splitlines():
  name,motion,unit,order,amplitude,overlap,accent,stack,material=line.split('|')
  TEXT.append(dict(id='craft33.text.'+slug(name),name=name,category=category,motion=motion,unit=unit,order=order,amplitude=float(amplitude),overlap=float(overlap),accent=accent,effects=effects(stack),material=None if material=='-' else material))
text('In','''
Baseline Focus|rise|characters|forward|0.8|42|focus|B|-
Soft Column Reveal|rise|lines|forward|0.65|28|none|-|-
Quiet Tracking|tracking|words|forward|0.45|55|none|-|-
Letter Lift and Land|elastic|characters|forward|0.75|24|rebound|-|-
Split Slab Arrival|shutter|words|reverse|1|20|squeeze|P|-
Narrow Door Reveal|hinge|characters|forward|0.65|30|counter|-|-
Reverse Reading|slide|words|reverse|0.7|42|none|D|-
Soft Ink Arrival|focus|characters|forward|0.7|45|none|I|-
Corner Turn Type|arc|words|forward|0.75|34|counter|-|-
Track and Resolve|tracking|characters|forward|0.8|38|squeeze|Q|-
Falling Letter Blocks|drop|characters|random|0.8|22|rebound|P|-
Measured Word Step|baseline|words|forward|0.6|16|none|-|-
Open Caption|shutter|lines|forward|0.85|50|none|-|-
Subtle Lens Arrival|depth|words|forward|0.5|48|focus|Z|-
Wipe Into Focus|focus|lines|reverse|0.6|35|trail|D|-
Rounded Letter Pop|scale|characters|forward|0.85|18|squeeze|N|-
Glass Edge Entry|perspective|words|forward|0.5|40|focus|Q|-
Compressed Headline|stretch|lines|forward|0.7|36|squeeze|-|-
Rail Slide Caption|slide|lines|forward|1|22|none|A|-
Ink Stamp Settle|scale|words|random|0.9|22|rebound|T|-
''')
text('Kinetic','''
Word Train|whip|words|forward|0.8|18|counter|D|-
Accordion Headline|tracking|characters|reverse|1|20|squeeze|P|-
Elastic Baseline|elastic|words|forward|1.1|26|rebound|G|-
Orbit Word Assembly|orbit|words|random|0.65|30|lift|Q|-
Rotating Slabs|rotate|words|forward|0.8|24|counter|P|-
Diagonal Dispatch|arc|lines|forward|1|22|trail|D+A|-
Print Roller|roll|characters|forward|0.8|14|squeeze|V|-
Fan Deck Reveal|fan|words|reverse|0.7|35|counter|A|-
Stack Snap|drop|lines|forward|1.15|12|rebound|N|-
Crosswind Headline|skew|words|reverse|0.9|30|trail|D|-
Rubber Letter Train|stretch|characters|forward|1.2|18|squeeze|L|-
Scatter Then Align|scatter|characters|random|0.8|35|counter|R|-
Front Row Slam|slam|words|forward|0.7|14|rebound|O|-
Pop Through Ink|scale|characters|random|1.1|24|focus|I+N|-
Word Card Deal|hinge|words|random|0.9|22|counter|P+A|-
Rising Zigzag Type|baseline|characters|reverse|1.1|16|rebound|Q|-
Zoom Cut Sentence|depth|lines|forward|0.9|8|trail|R|-
Skew and Squeeze|skew|characters|forward|1.1|26|squeeze|T|-
Paper Flip Sentence|fold|words|forward|0.9|18|lift|P|-
Focus Relay|focus|words|random|1|20|focus|J|-
''')
text('Out','''
Letter Conveyor Exit|slide|characters|forward|0.8|28|none|D|-
Ink Evaporation|focus|words|random|1.3|36|focus|I+G|-
Fold Away Caption|fold|lines|reverse|0.9|24|none|P|-
Fall Through Baseline|drop|characters|reverse|1.1|18|counter|E|-
Track Apart Words|tracking|words|forward|1.4|28|none|A|-
Shred the Sentence|scatter|characters|random|1.2|18|trail|g6|-
Pinch to a Line|shutter|lines|forward|1|35|squeeze|N|-
Spin Off Label|rotate|words|reverse|1.3|24|counter|R|-
Burnt Print Exit|skew|characters|random|0.7|32|focus|ME+V|-
Signal Breakdown|decode|characters|reverse|1|24|none|g10+A|-
''')
text('3D Out','''
Deep Card Exit|depth|words|reverse|1.1|28|lift|Z|Chrome
Hinge Back Caption|hinge|lines|forward|0.9|30|counter|Q|Plastic
Tumbling Letter Exit|roll|characters|random|1.1|20|none|R|Gold
Metal Fan Exit|fan|words|reverse|1|24|lift|J|Chrome
Glass Fold Away|fold|characters|forward|1.05|25|focus|O|Glass
Side Door Exit|perspective|words|forward|1.2|18|trail|D|Plastic
Neon Orbit Away|orbit|characters|reverse|1|32|focus|G|Neon
Stone Blocks Fall|drop|words|random|1.25|14|counter|P|Stone
Spinning Word Door|flip|words|reverse|1.2|22|none|A|Gold
Backplane Pull|depth|lines|forward|1.5|18|none|Q+Z|Chrome
''')
text('Typewriter','''
Plain Terminal|type|characters|forward|1|4|none|-|-
Word Processor|type|words|forward|1|8|none|-|-
Line by Line Caption|type|lines|forward|1|10|none|-|-
Scrambled Terminal|decode|characters|forward|0.6|12|none|g1|-
Signal Lock Letters|decode|characters|random|1.1|18|focus|A|-
Printed Receipt|type|characters|forward|1|2|none|T|-
Carbon Copy Caption|type|words|reverse|1|10|edge|V|-
Quiet Subtitle Keys|type|characters|forward|0.8|7|focus|B|-
Type and Bump|type|words|forward|1|5|rebound|-|-
Cursor Glow Trail|type|characters|forward|1|6|edge|L|-
Stitched Nameplate|type|characters|forward|1|10|none|C|-
Wrong Channel Decode|decode|words|random|0.9|24|counter|g3|-
Teletext Arrival|shutter|characters|forward|0.7|8|none|g5|-
Stamp by Stamp|scale|characters|forward|0.7|8|squeeze|T+V|-
Analog Letter Keys|type|characters|random|1|9|none|Y|-
Code Rain Resolve|drop|characters|random|0.55|12|focus|g2|-
Punched Tape Caption|type|words|forward|1|3|edge|H|-
Wireframe Decode|decode|characters|reverse|0.8|15|edge|Q|-
Reverse Terminal|type|characters|reverse|1|5|none|E|-
Fluorescent Word Keys|type|words|random|1|12|focus|O|-
''')
text('Glitch','''
Channel Lock Reveal|decode|characters|random|1.2|26|focus|g3+A|-
Raster Headline|skew|words|forward|0.8|18|trail|g7|-
Column Corruption|drop|characters|random|0.7|16|none|g2|-
Codec Word Shuffle|scatter|words|random|0.55|20|counter|g4|-
Red Blue Relay|tracking|characters|reverse|0.6|25|focus|g3+Q|-
Signal Return Caption|focus|lines|forward|0.8|12|none|g10|-
Bitplane Alphabet|decode|characters|forward|0.7|14|edge|g9|-
Scan Comb Resolve|shutter|words|forward|0.8|24|none|g5+E|-
Broken Printer Type|type|characters|random|1|8|none|g1+V|-
Luma Shard Name|scale|words|random|1.1|18|rebound|g6|-
Pixel Sorted Recall|decode|words|reverse|0.9|28|none|Sort|-
Phase Scrambled Caption|focus|lines|forward|0.65|42|focus|X|-
Sideband Headline|whip|words|forward|0.6|16|trail|g8+A|-
Unstable Baseline|rattle|characters|random|0.6|22|counter|g7+Y|-
Ghost Channel Entry|orbit|words|reverse|0.4|30|focus|g10+Z|-
Chroma Melt Resolve|stretch|characters|random|0.9|24|squeeze|g2+R|-
Torn Frame Words|hinge|words|reverse|0.55|20|counter|g4+g6|-
Carrier Wave Type|wave|characters|forward|0.75|12|trail|W|-
Quadrature Caption|tracking|lines|forward|0.6|40|edge|K|-
Packet Burst Letters|slam|characters|random|0.7|10|rebound|g8+J|-
''')
text('Impact','''
Heavy Word Hit|punch|words|forward|1.2|22|squeeze|N|-
Ink Hammer Type|slam|characters|forward|0.8|18|rebound|I|-
Cracked Caption Hit|rattle|lines|forward|1.1|24|counter|g6|-
Lens Punch Title|punch|lines|forward|1.3|35|focus|Z+G|-
SFX Letter Smash|slam|characters|random|1.2|12|squeeze|M|-
Rubber Word Impact|squash|words|forward|1.3|20|rebound|L|-
Flash Print Hit|punch|lines|reverse|0.85|28|edge|T+O|-
Double Take Caption|bounce|words|reverse|1.1|24|counter|A|-
Recoil Nameplate|rattle|words|forward|0.9|18|trail|D|-
Glowing Contact Frame|focusPulse|lines|forward|1.1|30|edge|J+G|-
Flat Panel Smash|squash|lines|forward|1.4|22|squeeze|P|-
Scratched Letter Hit|rattle|characters|random|0.8|20|edge|AH|-
Chromatic Thump|punch|words|random|1|14|trail|R+A|-
Stamp and Shake|rattle|words|forward|1.2|16|rebound|T|-
Skewed Caption Pop|skew|lines|forward|0.9|22|counter|Q|-
Ringing Headline|punch|lines|reverse|0.7|26|focus|N+O|-
Snap Focus Word|focusPulse|words|forward|0.75|16|none|B+J|-
Metal Contact Title|punch|words|forward|0.8|18|lift|Q|Chrome
Paper Crunch Letters|squash|characters|random|0.95|24|squeeze|P+V|-
Wire Snap Hit|rattle|lines|forward|1.4|16|edge|C+L|-
''')
text('Emphasis','''
Keyword Lift|baseline|words|forward|0.5|24|none|-|-
Underline Glow Pass|wave|words|forward|0.35|30|edge|L|-
Focus Keyword|focusPulse|words|forward|0.6|22|none|G|-
Tracking Accent|trackingWave|characters|forward|0.7|24|none|-|-
Outline Sweep|hue|words|forward|0.45|26|edge|Q|-
Tiny Rubber Emphasis|squash|words|forward|0.4|30|rebound|-|-
Word Bounce Accent|bounce|words|reverse|0.55|18|rebound|N|-
Soft Lens Highlight|focusPulse|lines|forward|0.45|45|focus|Z|-
Ink Weight Accent|punch|words|forward|0.45|20|edge|I|-
Color Registration Pass|trackingWave|characters|reverse|0.5|28|counter|V|-
Raised Foil Accent|depthWave|words|forward|0.55|22|lift|J|Gold
Prism Word Sweep|hue|words|reverse|0.7|30|focus|Q+O|-
Letter Nudge|wave|characters|forward|0.3|12|none|-|-
Sewn Caption Accent|baseline|words|forward|0.35|26|edge|C|-
Soft Shadow Step|baseline|lines|reverse|0.4|32|rebound|P|-
Held Breath Title|breath|lines|forward|0.75|40|focus|G|-
Half-Tone Emphasis|punch|words|forward|0.6|18|squeeze|H|-
Channel Edge Accent|rattle|words|random|0.3|20|edge|A|-
Spiral Highlight Pass|hue|lines|forward|0.5|42|focus|U|-
Split Ink Word|trackingWave|words|reverse|0.8|25|edge|EL|-
''')
text('Lyric','''
Breathing Lyric Line|rise|lines|forward|0.4|60|none|-|-
Word by Word Focus|focus|words|forward|0.7|24|focus|B|-
Late Night Subtitle|type|words|forward|1|10|focus|G|-
Floating Verse|wave|words|forward|0.5|6|none|O|-
Soft Word Steps|baseline|words|forward|0.5|28|rebound|-|-
Split Verse Arrival|shutter|lines|reverse|0.8|42|none|Q|-
Rising Ink Lyric|rise|words|forward|0.65|30|none|I|-
Recorded Voice Caption|type|characters|forward|1|5|none|Y|-
Reflective Chorus|orbit|words|reverse|0.4|38|lift|Z|Glass
Chorus Impact|punch|words|forward|0.8|24|squeeze|N+G|-
Thin Line Verse|tracking|words|forward|0.45|48|edge|C|-
Focus Echo Lyric|depth|words|forward|0.45|38|focus|R|-
Warm Film Caption|rise|lines|reverse|0.5|45|none|V+G|-
Two-Step Word Reveal|elastic|words|forward|0.55|18|counter|-|-
Quiet Decode Lyric|decode|words|forward|0.4|35|none|A|-
Paper Song Title|fold|words|forward|0.6|30|rebound|P|-
Out of the Chorus|slide|lines|reverse|0.7|35|trail|D|-
Silver Lyric Cards|hinge|words|forward|0.5|35|lift|Q|Chrome
Drifting Last Word|arc|words|reverse|0.45|22|none|L|-
Lyric Frame Punch|punch|lines|forward|0.5|40|focus|J+O|-
''')
text('Manga/AMV','''
Ink Panel Caption|shutter|words|forward|1|20|edge|I+V|-
Speech Balloon Pop|scale|words|random|0.7|20|rebound|P|-
Speedline Letter Rush|whip|characters|forward|1.2|15|trail|D+R|-
Screentone Slab|slam|lines|forward|0.8|15|squeeze|H|-
Hatching Reveal|rise|characters|reverse|0.85|24|edge|AH|-
Misprinted Battle Cry|rattle|words|random|1.25|20|counter|V+A|-
Stretched SFX|stretch|characters|forward|1.4|16|rebound|M|-
Broken Ink Dispatch|scatter|words|random|0.9|18|trail|I+g6|-
Curved Action Caption|arc|words|forward|1.25|22|counter|CT|-
Frayed Sound Effect|slam|characters|random|0.9|14|edge|F|-
Embroidered Panel Name|type|characters|forward|1|8|edge|C+P|-
Inverted Motion Letter|roll|words|reverse|1|18|none|EL|-
Crosshatched Word Fan|fan|characters|forward|0.9|20|counter|AH+V|-
Torn Color Caption|skew|lines|reverse|1.1|24|trail|g6+Q|-
Plexus Sound Burst|scatter|characters|random|0.7|16|focus|J+L|-
Engraved Hero Name|depth|words|forward|0.75|25|edge|SE|Stone
Panel Print Resolve|tracking|lines|forward|0.8|30|squeeze|T+H|-
Foil Action Word|flip|characters|random|0.7|20|lift|S|Gold
Two-Tone Impact Ink|punch|words|reverse|1.1|22|edge|M+R|-
Perspective Caption Slash|perspective|words|forward|0.8|18|trail|ES+D|-
''')
text('Loop','''
Baseline Tide|wave|characters|forward|0.7|8|none|-|-
Slow Caption Breathe|breath|lines|forward|0.7|10|none|G|-
Rubber Alphabet|rubber|characters|forward|0.8|5|none|-|-
Swinging Word Tags|pendulum|words|forward|0.8|5|none|P|-
Tracking Current|trackingWave|characters|forward|0.8|7|none|A|-
Neon Alphabet Buzz|flicker|characters|random|0.5|6|none|G+Q|-
Ink Boil Caption|rattle|characters|random|0.25|10|none|I|-
Chromatic River Type|wave|words|forward|0.8|4|none|R|-
Hue Walk Letters|hue|characters|forward|1|9|none|-|-
Sequin Marquee|breath|words|forward|0.5|8|none|S|-
Wire Current Caption|trackingWave|words|reverse|0.5|5|edge|L+C|-
Paper Pendulum|pendulum|characters|forward|0.55|7|none|P+V|-
Trembling Print|rattle|words|random|0.3|8|none|ME|-
Prism Focus Cycle|focusPulse|characters|forward|0.65|6|none|Q|-
Wavy Analog Line|wave|lines|forward|0.6|4|none|Y|-
Ring Light Words|breath|words|reverse|0.8|6|none|N|-
Spectral Ribbon Type|twist|characters|forward|0.6|8|none|W|-
Glitch Relay Loop|flicker|words|random|0.4|5|none|g8+A|-
Fringe Sway Caption|pendulum|words|forward|0.65|8|none|F|-
Silver Edge Pulse|focusPulse|lines|forward|0.55|6|none|O+J|-
''')
text('3D In','''
Chrome Card Assembly|hinge|characters|forward|0.8|25|lift|Q|Chrome
Gold Word Flythrough|depth|words|forward|0.8|30|focus|Z|Gold
Glass Letter Turn|flip|characters|forward|0.75|30|none|O|Glass
Plastic Block Drop|drop|words|random|0.9|18|rebound|N|Plastic
Stone Headline Rise|rise|lines|forward|0.8|38|edge|I|Stone
Neon Depth Resolve|depth|characters|random|0.65|32|focus|G|Neon
Toon Word Fan|fan|words|reverse|0.85|22|counter|P|Toon
Beveled Side Entry|perspective|words|forward|0.75|30|lift|J|Chrome
Orbiting Gold Type|orbit|characters|forward|0.75|28|counter|U|Gold
Glass Ribbons Assemble|fold|words|random|0.8|26|focus|Q+Z|Glass
Extruded Caption Slam|slam|lines|forward|0.65|18|rebound|N+G|Plastic
Metal Letter Roller|roll|characters|forward|0.85|20|squeeze|V|Chrome
Neon Scaffold Type|type|characters|forward|1|8|edge|C+L|Neon
Stone Slab Rotation|rotate|words|random|0.7|20|counter|AH|Stone
Toon Elastic Blocks|elastic|characters|forward|0.9|24|squeeze|P|Toon
Prismatic Door Type|hinge|words|reverse|0.9|22|focus|Q+O|Glass
Gold Tracking Name|tracking|lines|forward|0.8|35|edge|J|Gold
Chrome Caption Sweep|arc|words|forward|0.8|28|trail|D|Chrome
Pixel Metal Resolve|decode|characters|random|0.8|25|lift|g9+A|Chrome
Backlit Block Letter|scale|words|forward|0.85|20|focus|E+G|Plastic
''')
text('3D Loop','''
Chrome Letter Carousel|spin|characters|forward|0.7|7|none|Q|Chrome
Gold Depth Current|depthWave|words|forward|0.85|5|none|J|Gold
Glass Torsion Caption|twist|characters|forward|0.7|6|none|O|Glass
Neon Orbit Current|spin|words|reverse|0.8|5|focus|G|Neon
Plastic Accordion|rubber|characters|forward|0.8|7|none|P|Plastic
Stone Hanging Words|pendulum|words|forward|0.6|5|none|I|Stone
Toon Letter Bounce|wave|characters|forward|1|6|rebound|N|Toon
Floating Chrome Line|depthWave|lines|forward|0.55|8|none|Z|Chrome
Glass Focus Drift|focusPulse|words|forward|0.65|5|none|Q+Z|Glass
Gold Tracking Machine|trackingWave|characters|reverse|0.8|8|none|S|Gold
Neon Baseline Current|wave|words|forward|0.7|5|edge|L|Neon
Plastic Tumble Chain|twist|words|forward|0.9|4|none|A|Plastic
Stone Engraving Turn|spin|lines|forward|0.55|9|none|SE|Stone
Toon Spring Chain|rubber|words|reverse|0.75|4|rebound|P+V|Toon
Chrome Signal Loop|flicker|characters|random|0.4|8|none|g3|Chrome
Glass Word Pendulum|pendulum|characters|forward|0.75|7|none|O+Q|Glass
Gold Foil Breath|breath|words|forward|0.8|6|none|S+J|Gold
Neon Focus Orbit|depthWave|characters|reverse|0.6|7|focus|G+U|Neon
Plastic Rattle Blocks|rattle|words|random|0.5|5|none|g1|Plastic
Metal Wave Ribbon|wave|characters|forward|1.1|10|none|W+Q|Chrome
''')
# 240 authored animation recipes, including 50 true-geometry 3D treatments.
assert len(TEXT)==240,len(TEXT)
for items in [TEXT]:
 assert len({r['id'] for r in items})==len(items)
 assert len({r['name'].lower() for r in items})==len(items)
(ROOT/'Resources/text-premades33.json').write_text(json.dumps(TEXT,indent=2)+'\n')
print('Text motion recipes:',len(TEXT))
LOOK=[]
def looks(category,rows):
 for line in rows.strip().splitlines():
  name,fill,colors,stroke,stroke2,shadow,softness,glow,material,depth,bevel,stack=line.split('|')
  LOOK.append(dict(id='look.craft33.'+slug(name),name=name,category=category,fill=fill,colors=colors.split(','),stroke=float(stroke),stroke2=float(stroke2),shadow=float(shadow),softness=float(softness),glow=float(glow),material=None if material=='-' else material,depth=float(depth),bevel=float(bevel),effects=effects(stack)))
looks('Minimal','''
Fine Caption Ink|solid|F7F6F2|0|0|2|2|0|-|0|0|-
Narrow Outline Label|solid|EEEEEE|1|0|0|0|0|-|0|0|-
Soft Editorial Type|linear|FFFFFF,D3D7DF|0|0|4|6|0|-|0|0|B
Blind Emboss Print|solid|B8C1CB|1|0|2|0|0|-|0|0|CT
Night Caption Light|solid|F0F5FF|0|0|3|4|5|-|0|0|G
''')
looks('Sticker','''
Die Cut Lettering|solid|FFF3CF|2|5|6|0|0|-|0|0|-
Paper Stack Name|linear|FFF8EC,D8C8AC|2|2|9|1|0|-|0|0|P
Stitched Patch Letters|solid|E8D4A2|2|1|3|2|0|-|0|0|C
Frayed Cloth Caption|solid|ED9E8C|1|3|4|1|0|-|0|0|F
Stamped Label Type|solid|F5ECDA|2|0|2|0|0|-|0|0|T+V
''')
looks('Neon','''
Thin Neon Tube|solid|88F8FF|1|0|0|0|12|-|0|0|Q
Neon Halation Letters|linear|ED8DFF,88B8FF|0|0|0|0|20|-|0|0|O+G
Light Traced Type|solid|C2FFF2|1|0|0|0|8|-|0|0|L
Wet Prism Caption|radial|FFFFFF,6C9CFF,ED78C4|1|1|4|6|6|-|0|0|Q+R
Spark Junction Lettering|solid|FFF9D6|0|0|1|2|7|-|0|0|J
''')
looks('Glitch','''
Misregistered Ink Title|solid|EEEBDD|1|0|2|0|0|-|0|0|V+A
Composite Monitor Text|solid|9CEAD2|0|0|1|0|3|-|0|0|Y
Chroma Damaged Caption|linear|FBFBFF,B2BDFF|0|0|0|0|0|-|0|0|g3+Q
Bitplane Print Label|solid|F2F0DB|2|0|2|0|0|-|0|0|g9+T
Carrier Noise Outline|solid|EEF1FF|1|1|0|0|2|-|0|0|X+K
''')
looks('Manga/AMV','''
Heavy Manga Sound|solid|FFF9EC|5|2|8|0|0|-|0|0|M
Crosshatched Nameplate|linear|E9E5DB,B0A992|2|0|5|1|0|-|0|0|AH
Screentone Cut Letters|solid|FAF8F1|3|1|5|0|0|-|0|0|H+I
Ink Solarized Caption|solid|DCD7FF|1|3|3|0|0|-|0|0|EL
Engraved Chapter Title|linear|F0E3C7,916D4D|2|1|4|2|0|-|0|0|SE
''')
looks('Impact','''
Foil Impact Face|linear|F9FAFF,909BAA,FAFCFF|2|2|6|1|2|-|0|0|S
Ringed SFX Outline|solid|FFF0B5|4|1|3|0|6|-|0|0|N
Chroma Impact Label|linear|FFFFFF,FFC8CD|3|1|6|0|0|-|0|0|A+R
Raised Panel Typeface|solid|F4F1E9|2|3|10|0|0|-|0|0|P+J
Dense Tonal Lettering|solid|E4E6DD|3|0|5|1|0|-|0|0|T+H
''')
looks('Cinematic','''
Silver Screen Caption|linear|FFFFFF,ACB7C8|0|0|4|8|4|-|0|0|Z
Charge Bloom Title|solid|F6F1E8|0|0|2|4|7|-|0|0|E+G
Prism Edge Credit|solid|EDF3FF|1|0|3|4|3|-|0|0|Q+O
Soft Film Print|linear|F5E9D8,CCB8A1|0|0|3|3|0|-|0|0|V+Y
Spiral Light Heading|radial|FFFFFF,D1D8F2|0|0|2|6|5|-|0|0|U
''')
looks('Lyric','''
Embossed Lyric Paper|linear|FFFCEF,E8D4B3|1|0|2|1|0|-|0|0|P
Quiet Rainbow Edge|solid|F7F7FF|0|1|2|3|3|-|0|0|A+Q
Silk Verse Lettering|linear|FFEEEE,DDB9E4|0|0|3|5|4|-|0|0|L+G
Faded Print Subtitle|solid|EFE7D8|1|0|1|0|0|-|0|0|ME+V
Woven Verse Outline|solid|F5E1B6|1|2|3|0|0|-|0|0|C+F
''')
looks('3D','''
Machined Chrome Title|linear|F8FAFF,ACB5C8|0|0|0|0|0|Chrome|28|2|Q
Heavy Gold Slab|solid|FFE2A3|0|0|0|0|0|Gold|44|1|J
Clear Beveled Glass|radial|F1FBFF,A4D5F1|0|0|0|0|0|Glass|16|5|O
Blue Molded Letters|solid|9CBFFF|0|0|0|0|0|Plastic|30|6|N
Carved Stone Title|linear|C8C2B6,807D76|0|0|0|0|0|Stone|38|2|AH
Red Toon Block|solid|F7A89E|0|0|0|0|0|Toon|22|3|P
Edge Lit Neon Glass|solid|88FFF0|0|0|0|0|6|Neon|12|2|L
Foil Ribbon Extrusion|linear|FFF2C8,BDA985,F9F5DB|0|0|0|0|0|Gold|8|1|S
Deep Chrome Channel|solid|DFE7FA|0|0|0|0|0|Chrome|60|3|Z
Hollow Glass Caption|solid|DAF5FF|1|0|0|0|0|Glass|25|1|Q+O
Pressed Plastic Plate|linear|FFE7C9,D6A572|0|0|0|0|0|Plastic|10|.7|P
Cut Granite Face|solid|A3B3BF|0|0|0|0|0|Stone|46|1|CT
Neon Circuit Blocks|solid|BDC7FF|0|0|0|0|4|Neon|32|1|C+L
Toon Stamp Extrusion|solid|FFE59A|0|0|0|0|0|Toon|18|.8|T
Brushed Silver Face|linear|E7F1FF,7489A4|0|0|0|0|0|Chrome|20|4|V
Smoked Glass Heading|radial|C1D5E3,7A92AD|0|0|0|0|0|Glass|36|4|E
Gold Spiral Engraving|solid|F4CF86|0|0|0|0|0|Gold|26|2|SE
Paper Toon Facade|linear|FFF3DE,CAA57B|0|0|0|0|0|Toon|14|2|P+V
Phosphor Neon Frame|solid|C1FFD8|1|0|0|0|9|Neon|6|.5|Y
Chrome Spark Marquee|linear|FFFFFF,B5C2DD|0|0|0|0|0|Chrome|34|5|J+N
''')
assert len(LOOK)==60,len(LOOK)
(ROOT/'Resources/text-looks33.json').write_text(json.dumps(LOOK,indent=2)+'\n')

fx('Hold','awi33.time.hold',rate=8,phase=0)
fx('Echo','awi33.time.echo',span=.22,samples=3,decay=48,blend=45)
fx('Exposure','awi33.time.exposure',span=.14,samples=3,blend=45)
fx('Ripple','ae.waveWarp')
fx('Quake','awi14.earthquake',intensity=4,block=15,frequency=8,cracks=20)
LAYER=[]
def layers(category,rows):
 for line in rows.strip().splitlines():
  name,motion,amplitude,duration,angle,stack=line.split('|')
  LAYER.append(dict(id='craft33.layer.'+slug(name),name=name,category=category,motion=motion,amplitude=float(amplitude),duration=float(duration),angle=float(angle),effects=effects(stack)))
layers('Shakes','''
Small Handheld Nudge|shake|.7|.65|25|-
Soft Shoulder Shake|shake|1.2|.8|70|D
Heavy Contact Shake|shake|8|.45|15|Quake
Big Screen Recoil|shake|13|.7|40|D+A
Short Rattle Hit|shake|4|.28|105|g1
Lens Jolt|shake|3|.55|15|Z+G
Ink Shake Burst|shake|6|.6|80|I+A
Digital Trip Shake|shake|7|.4|140|g8
Sway Then Settle|shake|2.2|1.2|10|B
Chroma Recoil|shake|5|.5|45|R
Paper Impact Tremor|shake|3.5|.75|110|P+V
Bass Hit Screen|shake|10|.55|90|N+G
''')
layers('In','''
Smooth Focus Push|zoom|18|.65|0|B
Long Lens Arrival|zoom|40|.8|0|Z
Side Rail Whip|whip|90|.4|0|D
Diagonal Card Entry|slide|70|.65|135|A
Front Plane Drop|slide|60|.55|270|P
Tilt Into Frame|tilt|55|.7|0|Q
Soft Fade Print|fadeIn|0|.85|0|V
Camera Rush Entry|zoom|120|.45|0|R+D
Rolled Page Arrival|spin|35|.7|0|P
Pulse and Land|squash|24|.55|0|N
Chroma Slide Return|whip|55|.6|180|g3
Ink Focus Entry|fadeIn|0|.7|0|I
Backlit Image Reveal|fadeIn|0|1|0|E+G
Split Signal Arrival|slide|45|.45|60|g4+A
''')
layers('Out','''
Defocus Fade Away|fadeOut|0|.8|0|B
Print Slide Exit|pull|35|.7|0|V
Fast Side Exit|whip|100|.4|180|D+R
Tumbling Card Exit|spin|100|.6|0|Q
Signal Loss Exit|fadeOut|0|.55|0|g10
Pull Through Lens|pull|140|.7|0|Z+A
Ink Dissolve Fade|fadeOut|0|.65|0|I+ME
Downward Page Cut|slide|70|.5|90|P+E
Packet Break Exit|fadeOut|0|.45|0|g8+g6
Dim Halo Exit|fadeOut|0|.9|0|N+G
''')
layers('Glow & Light','''
Soft Highlight Halo|none|0|1|0|G
Ring Highlight Pop|none|0|.65|0|N
Prismatic Light Edge|none|0|.85|0|Q+O
Corner Spark Sweep|none|0|.75|0|J
Ink Light Current|none|0|1.2|0|L
Chromatic Speed Trail|none|0|.65|0|R
Lens Reflection Hit|zoom|8|.7|0|Z
Spiral Light Recall|spin|6|1.1|0|U
Spectral Rim Pulse|breath|3|1|0|O
Sensor Charge Burst|none|0|.55|0|E+G
Wireframe Light Drift|none|0|1.5|0|C+L
Glitter Foil Sweep|none|0|1.1|0|S+J
Color Separated Halation|none|0|1|0|A+G
Circular Prism Hit|zoom|5|.6|0|N+Q
Light Echo Frame|none|0|.85|0|Echo+G
Double Aperture Contact|none|0|.7|0|N+Z
''')
layers('Loops','''
Slow Camera Breathe|breath|3|2.4|0|-
Floating Object Cycle|bounce|2|2|90|-
Gentle Paper Sway|shake|.9|2.8|15|P
Rubber Object Pulse|squash|12|1.5|0|-
Neon Circuit Cycle|breath|2|1.2|0|L+G
Color Trail Sway|bounce|3|1.8|30|R
Noisy Screen Rattle|shake|1.5|1.1|70|Y
Fringe Cloth Swing|bounce|1.7|2.6|15|F
Foil Surface Flutter|breath|2.5|2|0|S
Chromatic Film Wobble|shake|1.2|2.2|110|V+A
Printed Object Bounce|bounce|2.8|1.4|90|T
Signal Clock Jitter|shake|2|.95|20|g1+g5
''')
layers('Manga & AMV','''
Hatched Panel Smash|zoom|35|.45|0|AH
Manga Contact Frame|shake|7|.4|30|M
Paper Layer Pop|squash|18|.6|0|P
Ink Ridge Flash|none|0|.35|0|I
Action Chroma Slash|whip|35|.55|25|ES+A
Tonal Print Stamp|zoom|15|.65|0|T
Frame Shard Impact|shake|8|.5|80|g6
Crossed Color Panel|none|0|.75|0|V+Q
Sewn Object Label|bounce|2|.8|90|C
Solarized Ink Hit|none|0|.45|0|EL
Curved Panel Pull|pull|22|.75|0|CT
Halftone Camera Rush|zoom|55|.55|0|H+D
Engraved Object Reveal|fadeIn|0|.85|0|SE
Prism Panel Break|shake|6|.6|40|Q+g3
Frayed Paper Shock|squash|28|.7|0|F+P
Codec Action Freeze|none|0|.6|0|Hold+g4
''')
layers('Looks & CC','''
Registered Film Print|none|0|1|0|V+Y
High Contrast Ink Face|none|0|1|0|I+H
Layered Paper Finish|none|0|1|0|P+T
Small Lens Color Fringe|none|0|1|0|A+Q
Screen Codec Patina|none|0|1|0|g3+Y
Metal Disc Mosaic|none|0|1|0|S
Directional Spectral Image|none|0|1|0|K
Curved Engraving Finish|none|0|1|0|SE+CT
Torn Fabric Border|none|0|1|0|F+C
Luminous Contour Ink|none|0|1|0|L+I
Chroma Plate Collage|none|0|1|0|V+P+A
Dispersed Wave Image|none|0|1|0|W
''')
layers('Velocity','''
Eight Frame Hold|none|0|1|0|Hold
Temporal Light Drag|none|0|.9|0|Exposure+G
Echo Speed Push|zoom|30|.6|0|Echo+D
Staccato Camera Pull|pull|45|.8|0|Hold+A
Trailing Flash Contact|shake|4|.6|20|Echo+N
Analog Frame Trails|none|0|1.2|0|Exposure+Y
Held Panel Rush|whip|65|.7|0|Hold+R
Ghost Frame Breathing|breath|7|1.4|0|Echo+Q
''')
assert len(LAYER)==100,len(LAYER)
for name,items in [('text',TEXT),('look',LOOK),('layer',LAYER)]:
 assert len({r['id'] for r in items})==len(items),name
 assert len({r['name'].lower() for r in items})==len(items),name
 # No recipe can reference an unknown local effect shorthand.
 for recipe in items:
  for spec in recipe['effects']:assert spec['id']
(ROOT/'Resources/layer-premades33.json').write_text(json.dumps(LAYER,indent=2)+'\n')
print('Text looks:',len(LOOK),'General recipes:',len(LAYER),'Total new text entries:',len(TEXT)+len(LOOK))

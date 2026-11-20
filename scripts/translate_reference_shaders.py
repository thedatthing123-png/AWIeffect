"""Compile supported reference fragment shaders through glslang and SPIRV-Cross.

This is an offline feasibility audit, not an automatic catalog importer. Outputs
stay under build_out until semantic mapping, native integration and render review.
No reference binary is executed. Unsupported native/multipass inputs are reported.
"""
import argparse
import json
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET
import zipfile


HEADER = '''#version 450
layout(location=0) out vec4 finalColor;
layout(set=0, binding=0, std140) uniform ReferenceUniformsSLUG {
    layout(offset=0) vec4 refScreen;
    layout(offset=16) vec4 refLayer;
    layout(offset=32) vec4 refComposition;
    layout(offset=48) mat4 refLayerToScreen;
    layout(offset=112) mat4 refScreenToLayer;
FIELDS
};
layout(set=1, binding=0) uniform sampler2D refInput;
IMAGEDECLS
#define acScreenNorm (gl_FragCoord.xy / refScreen.xy)
#define acScreenSize (refScreen.xy)
#define acPreviewSize (refScreen.xy)
#define acProjectSize (refComposition.xy)
#define acTime (refScreen.z)
#define acLayerSize (refLayer.zw)
#define acLayerNorm ((gl_FragCoord.xy-refLayer.xy)/refLayer.zw)
#define acLayerCenter (vec2(refLayer.x+refLayer.z*.5, refScreen.y-refLayer.y-refLayer.w*.5))
#define acLayerCenterNorm (acLayerCenter/refScreen.xy)
#define acLayerSizeNorm (refLayer.zw/refScreen.xy)
#define acLayerToScreen refLayerToScreen
#define acScreenToLayer refScreenToLayer
#define acShowGuides false
vec2 getTexSize(vec2 size) { return size; }
float saturate(float v) { return clamp(v,0.,1.); }
vec2 saturate(vec2 v) { return clamp(v,0.,1.); }
vec3 saturate(vec3 v) { return clamp(v,0.,1.); }
vec4 saturate(vec4 v) { return clamp(v,0.,1.); }
vec4 texture2DCv(sampler2D source,vec2 uv) { return texture(source,uv); }
vec4 referenceColor;
'''


def translate(root, slug, images=None):
    shaders = root.findall('.//shader')
    if len(shaders) != 1 or shaders[0].get('type') != 'fragment':
        raise ValueError('requires native or multiple shader stages')
    code = ''.join(shaders[0].itertext())
    clean = re.sub(r'/\*.*?\*/|//[^\n]*', '', code, flags=re.S)
    globals_used = set(re.findall(r'\bac[A-Z]\w*', clean))
    known = set(re.findall(r'#define (ac\w+)', HEADER))
    if globals_used - known:
        raise ValueError('requires native context: ' + ', '.join(sorted(globals_used - known)))
    parent = root.find('params')
    if parent is None:
        raise ValueError('no parameter definitions')
    textures = [p for p in parent if p.tag == 'texture']
    if not textures or textures[0].get('srcType') != 'content' or any(p.get('srcType') != 'image' for p in textures[1:]):
        raise ValueError('requires buffer, background or secondary texture adapter')
    texture = textures[0].get('id')
    code = code.replace(texture + '.texture', 'refInput').replace(texture + '.size', 'refScreen.xy')
    image_declarations = []
    for index, texture in enumerate(textures[1:], start=1):
        key = texture.get('id')
        if not images or key not in images:
            raise ValueError('missing packaged image: ' + str(texture.get('src')))
        image = images[key]
        image_declarations.append(f'layout(set=1, binding={index}) uniform sampler2D refImage{index};')
        code = code.replace(key + '.texture', f'refImage{index}')
        code = code.replace(key + '.size', f'vec2({image["width"]}.,{image["height"]}.)')
    fields, controls, slot = [], [], 11
    for p in parent:
        kind, key = p.tag, p.get('id')
        if kind in {'texture', 'section'}:
            continue
        if not key or not re.fullmatch(r'[A-Za-z_]\w*', key):
            raise ValueError('unsupported parameter identifier')
        if kind in {'spinner', 'slider'}:
            glsl_type = 'float'
        elif kind in {'point', 'point3d'}:
            glsl_type = 'vec2' if kind == 'point' else 'vec3'
        elif kind == 'color':
            glsl_type = 'vec4'
        elif kind == 'switch':
            glsl_type = 'bool'
        elif kind == 'selector':
            glsl_type = 'int'
        elif kind in {'float', 'int'} and p.get('value') is not None:
            code = f'const {kind} {key} = {p.get("value")};\n' + code
            continue
        else:
            raise ValueError('unsupported control: ' + kind)
        fields.append(f'    layout(offset={slot * 16}) {glsl_type} {key};')
        controls.append({'slot': slot, 'glsl_type': glsl_type, **p.attrib, 'control': kind,
                         'choices': [c.attrib for c in p.findall('choice')]})
        slot += 1
    if slot * 16 > 4096:
        raise ValueError('uniform block exceeds inline Metal constant limit')
    code = re.sub(r'^\s*precision\s+\w+\s+\w+\s*;', '', code, flags=re.M)
    code = re.sub(r'\bgl_FragColor\b', 'referenceColor', code)
    code, count = re.subn(r'\bvoid\s+main\s*\(\s*(?:void)?\s*\)', 'void referenceMain()', code)
    if count != 1:
        raise ValueError('missing or ambiguous main')
    source = HEADER.replace('SLUG', slug).replace('FIELDS', '\n'.join(fields)).replace('IMAGEDECLS', '\n'.join(image_declarations)) + code
    source += '''
void main() {
    referenceColor = vec4(0.);
    referenceMain();
    if (any(isnan(referenceColor)) || any(isinf(referenceColor))) referenceColor=vec4(0.);
    referenceColor.a=clamp(referenceColor.a,0.,1.);
    if (referenceColor.a<=0.) referenceColor=vec4(0.);
    finalColor=referenceColor;
}
'''
    return source, controls, slot


def run(args):
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    with zipfile.ZipFile(args.ipa) as archive:
        for filename in archive.namelist():
            if not filename.endswith('.xml') or '/AEMotionQuarantine/' in filename:
                continue
            root = ET.fromstring(archive.read(filename))
            if root.tag != 'effect' or root.get('deprecated') == 'true':
                continue
            slug = 'e' + __import__('hashlib').sha256(filename.encode()).hexdigest()[:12]
            record = {'file': filename, 'id': root.get('id'), 'slug': slug}
            try:
                images = {}
                for texture in root.findall('params/texture'):
                    if texture.get('srcType') != 'image':
                        continue
                    from PIL import Image
                    from io import BytesIO
                    src = texture.get('src', '')
                    asset = str(Path(filename).parent.as_posix()) + '/' + src
                    if asset not in archive.namelist():
                        continue
                    raw = archive.read(asset)
                    image = Image.open(BytesIO(raw))
                    asset_name = 'amref-' + __import__('hashlib').sha256(raw).hexdigest()[:16] + Path(src).suffix
                    (args.output / asset_name).write_bytes(raw)
                    images[texture.get('id')] = {'file': asset_name, 'source': asset, 'width': image.width, 'height': image.height}
                source, controls, slots = translate(root, slug, images)
                glsl = args.output / (slug + '.frag')
                spirv = args.output / (slug + '.spv')
                metal = args.output / (slug + '.metal')
                glsl.write_text(source, encoding='utf8')
                result = subprocess.run([str(args.glslang), '-V', '-S', 'frag', str(glsl), '-o', str(spirv)], capture_output=True, text=True)
                if result.returncode:
                    raise ValueError(result.stdout + result.stderr)
                result = subprocess.run([str(args.cross), str(spirv), '--msl', '--msl-version', '20100', '--msl-decoration-binding', '--rename-entry-point', 'main', 'refAM35_' + slug, 'frag', '--output', str(metal)], capture_output=True, text=True)
                if result.returncode:
                    raise ValueError(result.stdout + result.stderr)
                original_code = '\n'.join(''.join(s.itertext()) for s in root.findall('.//shader'))
                comments = re.findall(r'/\*.*?\*/|//[^\n]*', original_code, flags=re.S)
                provenance = '// Native translation of supplied ' + filename + '\n'
                provenance += '// Original source comments and attribution:\n' + '\n'.join(comments) + '\n'
                metal.write_text(provenance + metal.read_text(encoding='utf8'), encoding='utf8')
                record.update(status='translated-not-integrated', controls=controls, slots=slots, metal=str(metal), images=images)
            except ValueError as error:
                record.update(status='requires-adapter-or-repair', reason=str(error))
            records.append(record)
    (args.output / 'translation-report.json').write_text(json.dumps(records, indent=2), encoding='utf8')
    from collections import Counter
    print(json.dumps(dict(Counter(r['status'] for r in records)), indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--glslang', type=Path, required=True)
    parser.add_argument('--cross', type=Path, required=True)
    parser.add_argument('--output', type=Path, default=Path('build_out/reference-translation'))
    run(parser.parse_args())

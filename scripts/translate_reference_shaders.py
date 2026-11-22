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
#define acPass floatBitsToInt(refComposition.z)
vec2 getTexSize(vec2 size) { return size; }
float saturate(float v) { return clamp(v,0.,1.); }
vec2 saturate(vec2 v) { return clamp(v,0.,1.); }
vec3 saturate(vec3 v) { return clamp(v,0.,1.); }
vec4 saturate(vec4 v) { return clamp(v,0.,1.); }
vec4 texture2DCv(sampler2D source,vec2 uv) { return texture(source,uv); }
mat4 referenceEuler(vec3 degrees, bool inverted) {
    vec3 r=radians(degrees); vec3 s=sin(r),c=cos(r);
    mat4 rx=mat4(1,0,0,0, 0,c.x,-s.x,0, 0,s.x,c.x,0, 0,0,0,1);
    mat4 ry=mat4(c.y,0,s.y,0, 0,1,0,0, -s.y,0,c.y,0, 0,0,0,1);
    mat4 rz=mat4(c.z,-s.z,0,0, s.z,c.z,0,0, 0,0,1,0, 0,0,0,1);
    mat4 m=rz*rx*ry; return inverted ? transpose(m) : m;
}
vec4 referenceColor;
'''


def pass_graph(root, available_ids=None):
    passes = root.findall('passes/pass')
    if not passes:
        return []
    supported = {None, 'com.alightcreative.effects.gaussianblur', 'com.alightcreative.effects.boxblur2',
                 'com.alightcreative.effects.boxblurplus', 'com.alightcreative.effects.fastadj',
                 'com.alightcreative.effects.findedges-edgeglow'}
    supported.update(available_ids or [])
    if any(p.get('effect') not in supported for p in passes):
        raise ValueError('requires external native pass implementation')
    if any(set(p.attrib) - {'target', 'blend', 'effect', 'src'} for p in passes):
        raise ValueError('unsupported pass graph attribute')
    if any(p.get('blend', 'overwrite') != 'overwrite' for p in passes):
        raise ValueError('requires pass blend adapter')
    if passes[-1].get('target'):
        raise ValueError('pass graph has no final output')
    return [p.get('target', '') for p in passes]


def shader_code(root):
    shaders = root.findall('.//shader')
    fragments = [s for s in shaders if s.get('type') == 'fragment']
    vertices = [s for s in shaders if s.get('type') == 'vertex']
    if len(fragments) != 1 or len(vertices) > 1 or len(shaders) != len(fragments) + len(vertices):
        raise ValueError('requires native or multiple shader stages')
    code = ''.join(fragments[0].itertext())
    if vertices:
        vertex = ''.join(vertices[0].itertext())
        # These vertex programs calculate uniform-only matrices, never mesh
        # geometry. Evaluating the same setup before the fragment preserves the
        # source math without inventing vertex attributes or dropping rotation.
        if re.search(r'\b(?:gl_Position|gl_VertexID|attribute)\b', vertex):
            raise ValueError('requires geometry vertex adapter')
        varyings = re.findall(r'varying\s+(\w+)\s+(\w+)\s*;', vertex)
        if not varyings or any(kind != 'mat4' for kind, _ in varyings):
            raise ValueError('requires interpolated vertex adapter')
        vertex = re.sub(r'varying\s+\w+\s+\w+\s*;', '', vertex)
        functions = []
        pattern = r'\b(?:void|mat4|vec[234]|float)\s+(\w+)\s*\([^;{}]*\)\s*\{'
        for match in re.finditer(pattern, vertex):
            depth, end = 1, match.end()
            while depth and end < len(vertex):
                depth += (vertex[end] == '{') - (vertex[end] == '}'); end += 1
            name = match[1]
            body = vertex[match.start():end]
            if name == 'main':
                body = re.sub(r'\bmain\b', 'referenceVertexInit', body, count=1)
                body = body.replace('vertShaderInit();', '')
            functions.append(body)
        helper_code = '\n'.join(functions)
        for match in re.finditer(pattern, vertex):
            if match[1] != 'main':
                helper_code = re.sub(r'\b' + re.escape(match[1]) + r'\b', 'referenceVertex_' + match[1], helper_code)
        code = re.sub(r'\bvarying\s+\w+\s+\w+\s*;', '', code)
        declarations = '\n'.join(f'{kind} {name};' for kind, name in varyings)
        code = declarations + '\n' + helper_code + '\n' + code
        code = re.sub(r'(\bvoid\s+main\s*\(\s*(?:void)?\s*\)\s*\{)', r'\1\n referenceVertexInit();', code)
    if re.search(r'\bmat4\s+inverse\s*\(', code):
        code = re.sub(r'\binverse\b', 'referenceRigidInverse', code)
    return code


def dependency_files(roots):
    active = [root for root in roots.values() if root.tag == 'effect' and root.get('deprecated') != 'true']
    active_ids = {root.get('id') for root in active}
    required = {p.get('effect') for root in active for p in root.findall('passes/pass') if p.get('effect')}
    selected = set()
    while True:
        added = {filename for filename,root in roots.items() if root.tag == 'effect' and
                 root.get('deprecated') == 'true' and root.get('id') in required-active_ids and filename not in selected}
        if not added: return selected
        selected.update(added)
        required.update(p.get('effect') for filename in added for p in roots[filename].findall('passes/pass') if p.get('effect'))


def translate(root, slug, images=None, filename='', external_ids=None):
    code = shader_code(root)
    # Retain attribution separately in the emitted Metal preamble. Normalize
    # executable text only: patching commented examples can introduce live code.
    code = re.sub(r'/\*.*?\*/|//[^\n]*', '', code, flags=re.S)
    basename = Path(filename).name
    if basename == 'jpegquality.xml':
        code = 'const float split = 0.0;\n' + code
    if 'AC_ImageInfo' in code:
        code = code.replace('AC_ImageInfo', 'sampler2D')
        for name in re.findall(r'\bsampler2D\s+(\w+)', code):
            code = code.replace(name + '.texture', name).replace(name + '.size', f'vec2(textureSize({name},0))')
    # Native-format corrections found during render review. The original IPA is
    # retained; geometry/noise math is unchanged by these alpha adaptations.
    if basename == 'pixeledge.xml':
        code = code.replace('float gradBias = gradientBias;', 'float gradBias = clamp(gradientBias, 0.0001, 0.9999);')
    if basename == 'square_break_3d.xml':
        code = code.replace('vec4(c.rgb,c.a*inside*(1.-smoothstep(.82,1.,t)))', 'c*(inside*(1.-smoothstep(.82,1.,t)))')
    if basename == 'colorama.xml':
        code = code.replace('mix(src.rgb, col, clamp(blend, 0.0, 1.0))', 'mix(src.rgb / max(src.a, 0.00001), col, clamp(blend, 0.0, 1.0))')
        code = code.replace('vec3 outRGB =', 'if (blend <= 0.0 && alpha >= 1.0) { gl_FragColor = src; return; }\n      vec3 outRGB =')
    if basename == 'ink_splash.xml':
        code = code.replace('vec4(texColor.rgb, texColor.a * mask)', 'texColor * mask')
    if basename == 'radialshadow2.xml':
        code = code.replace('dot(a,b)/dot(b,b)', 'dot(a,b)/max(dot(b,b),0.000001)')
        code = code.replace('normalize(lightDirection)', '(lightDirection/max(length(lightDirection),0.000001))')
        code = code.replace('vec2(light.x,-light.y)/1000.0', 'vec2(light.x,-light.y)/1000.0*acLayerSizeNorm')
        code = code.replace('min(size,length(lightDirection))', 'min(size*min(acLayerSizeNorm.x,acLayerSizeNorm.y),length(lightDirection))')
        code = code.replace('vec4 result = mix(color * alpha * (1.0-dist*fade) * resultAlpha, baseColor, baseColor.a * fill);',
                            'vec4 shadow = vec4(color.rgb * color.a, color.a) * alpha * (1.0-dist*fade) * resultAlpha;\n            vec4 result = baseColor * fill + shadow * (1.0-baseColor.a*fill);')
    if basename == 'ribbon.xml':
        code = code.replace('vec4 c = mixedColor * p;', 'mixedColor.rgb *= mixedColor.a;\n            vec4 c = mixedColor * p;')
        code = code.replace('smoothstep(y1,y2,st.y)', 'clamp((st.y-y1)/(abs(y2-y1)>0.000001 ? y2-y1 : 0.000001),0.0,1.0)')
        code = code.replace('c *= texColor.a;', '')
        code = code.replace('gl_FragColor = c + (texColor*(1.0-c.a));', 'gl_FragColor = vec4(c.rgb*texColor.a + texColor.rgb*(1.0-c.a),texColor.a);')
    if basename == 'radial_rays.xml':
        code = code.replace('vec4 adjColor = color * p;', 'vec4 adjColor = vec4(color.rgb*color.a,color.a) * p;')
        code = code.replace('result = adjColor*texColor.a;\n                result = texColor*(1.-result.a) + result;',
                            'result = vec4(adjColor.rgb*texColor.a + texColor.rgb*(1.-adjColor.a),texColor.a);')
    if basename == 'waveloq-3.xml':
        code = code.replace('vec3 srcCol  = texture2DCv(inputImg.texture, dotCenter).rgb;',
                            'vec4 dotSource = texture2DCv(inputImg.texture,dotCenter);\n            vec3 srcCol = dotSource.rgb/max(dotSource.a,0.00001);')
        code = code.replace('mix(src.rgb, result, blend)', 'mix(src.rgb, result*src.a, blend)')
    if basename == 'highlight-shadow.xml':
        code = code.replace('float luminance = dot(source.rgb, luminanceWeighting);',
                            'if (source.a <= 0.0) { gl_FragColor=vec4(0.0); return; }\n            source.rgb /= source.a;\n            float luminance = clamp(dot(source.rgb, luminanceWeighting),0.00001,0.99999);')
        code = code.replace('2.0-highlights', 'max(2.0-highlights,0.00001)')
        code = code.replace('vec4(result.rgb, source.a)', 'vec4(result.rgb * source.a, source.a)')
    if basename == 'Adamagedots.xml':
        code = code.replace('vec3 mixed = mix(base.rgb, dotRGB, clamp(mixAmount, 0.0, 1.0));',
                            'vec3 mixed = mix(base.rgb, dotColor.rgb * base.a, clamp(mixAmount * opacity * m, 0.0, 1.0));')
        code = code.replace('vec3 dotRGB = dotColor.rgb * opacity * m;', 'vec3 dotRGB = dotColor.rgb * opacity * m * base.a;')
    if basename == 'metalballs.xml':
        code = code.replace('vec3 col = texture2DCv(inputImg.texture, uv).rgb;',
                            'vec4 sourcePixel = texture2DCv(inputImg.texture, uv);\n      float coverage = sourcePixel.a;\n      vec3 col = sourcePixel.rgb / max(sourcePixel.a,0.00001);')
        code = code.replace('col = sphereCol;', 'coverage = ballColor.a + sourcePixel.a * (1.0-ballColor.a);\n      col = (sphereCol * ballColor.a + sourcePixel.rgb * (1.0-ballColor.a)) / max(coverage,0.00001);')
        code = code.replace('gl_FragColor = vec4(col, 1.0);', 'gl_FragColor = vec4(col*coverage, coverage);')
    if basename == 'skexnxxcomet.xml':
        code = code.replace('(scale-0.5)', '(abs(scale-0.5)>0.001 ? scale-0.5 : 0.001)')
    if basename == 'skexnxxfworks.xml':
        code = code.replace('(PI2 / max(abs(SPARKS), 1.0) * i;', '(PI2 / max(abs(SPARKS), 1.0)) * i;')
    if basename == 'skexnxxspointunnel.xml':
        code = code.replace('float pz = 1.0 - (float(i) / max(abs(TUNNEL_LAYERS), 1.0);',
                            'float pz = 1.0 - (float(i) / max(abs(TUNNEL_LAYERS), 1.0));')
        code = code.replace('pz -= mod(camZ, 4.0 / max(abs(TUNNEL_LAYERS), 1.0);',
                            'pz -= mod(camZ, 4.0 / max(abs(TUNNEL_LAYERS), 1.0));')
    if basename == 'flip3.xml':
        code = re.sub(r'\binverse\b', 'referenceRigidInverse', code)
    # Avoid zero-alpha divisions without clamping HDR color values.
    if basename in {'skexnxxcomet.xml', 'radial_rays.xml'}:
        code = code.replace('texColor.rgb/texColor.a', 'texColor.rgb/max(texColor.a,0.00001)')
    clean = re.sub(r'/\*.*?\*/|//[^\n]*', '', code, flags=re.S)
    # acLTS is a local matrix argument in several complete helpers, not a
    # missing host global. Do not reject a shader merely for that spelling.
    globals_used = set(re.findall(r'\bac[A-Z]\w*', clean))
    if re.search(r'\bmat4\s+acLTS\b', clean):
        globals_used.discard('acLTS')
    known = set(re.findall(r'#define (ac\w+)', HEADER))
    if globals_used - known:
        raise ValueError('requires native context: ' + ', '.join(sorted(globals_used - known)))
    parent = root.find('params')
    if parent is None:
        raise ValueError('no parameter definitions')
    graph_names = {p.get(field) for p in root.findall('passes/pass') for field in ['target', 'src'] if p.get(field)}
    textures = [p for p in parent if p.tag == 'texture' and
                (p.get('id') in graph_names or re.search(r'\b' + re.escape(p.get('id', '')) + r'\b', clean))]
    buffers = [p for p in textures if p.get('srcType') == 'buffer']
    passes = pass_graph(root, external_ids) if 'acPass' in globals_used or buffers else []
    if buffers and not passes:
        raise ValueError('requires buffer, background or secondary texture adapter')
    if any(p.get('srcType') not in {'content', 'image', 'buffer', 'comp'} for p in textures):
        raise ValueError('requires buffer, background or secondary texture adapter')
    if any(target and target not in {p.get('id') for p in buffers} for target in passes):
        raise ValueError('pass target is not a declared buffer')
    for texture in textures:
        if texture.get('srcType') == 'content':
            key = texture.get('id')
            code = code.replace(key + '.texture', 'refInput').replace(key + '.size', 'vec2(textureSize(refInput,0))')
            code = re.sub(r'\b' + re.escape(key) + r'\b', 'refInput', code)
    image_declarations = []
    for index, texture in enumerate([p for p in textures if p.get('srcType') == 'image'], start=1):
        key = texture.get('id')
        if not images or key not in images:
            raise ValueError('missing packaged image: ' + str(texture.get('src')))
        image = images[key]
        image_declarations.append(f'layout(set=1, binding={index}) uniform sampler2D refImage{index};')
        code = code.replace(key + '.texture', f'refImage{index}')
        code = code.replace(key + '.size', f'vec2({image["width"]}.,{image["height"]}.)')
    buffer_records = []
    first_buffer = 1 + sum(p.get('srcType') == 'image' for p in textures)
    for index, texture in enumerate(buffers, start=first_buffer):
        key = texture.get('id')
        image_declarations.append(f'layout(set=1, binding={index}) uniform sampler2D refBuffer{index};')
        code = code.replace(key + '.texture', f'refBuffer{index}')
        downsample = max(1, int(texture.get('downsample', '1')))
        code = code.replace(key + '.size', f'max(floor(vec2(refComposition.w,refScreen.w)/{downsample}.0),vec2(1.0))')
        buffer_records.append({'name': key, 'binding': index, 'downsample': max(1, int(texture.get('downsample', '1')))})
    reference_binding = None
    references = [p for p in textures if p.get('srcType') == 'comp']
    if references:
        reference_binding = first_buffer + len(buffers)
        image_declarations.append(f'layout(set=1, binding={reference_binding}) uniform sampler2D refReference;')
        for texture in references:
            key = texture.get('id')
            code = code.replace(key + '.texture', 'refReference').replace(key + '.size', 'vec2(textureSize(refReference,0))')
    fields, controls, aliases, slot = [], [], [], 11
    for p in parent:
        kind, key = p.tag, p.get('id')
        if kind in {'texture', 'section', 'tip'}:
            continue
        if not key or not re.fullmatch(r'[A-Za-z_]\w*', key):
            raise ValueError('unsupported parameter identifier')
        if kind in {'spinner', 'slider'}:
            glsl_type = 'float'
        elif kind in {'xyz', 'hue-disc', 'orient'}:
            glsl_type = 'vec3'
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
        field_key = key + '_euler' if kind == 'orient' else key
        if kind == 'orient':
            aliases.append(f'#define {key} referenceEuler({field_key},' + ('true' if p.get('invert') == 'true' else 'false') + ')')
        fields.append(f'    layout(offset={slot * 16}) {glsl_type} {field_key};')
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
    source = HEADER.replace('SLUG', slug).replace('FIELDS', '\n'.join(fields)).replace('IMAGEDECLS', '\n'.join(image_declarations)) + '\n'.join(aliases) + '\n' + code
    # ES permits identifiers that became reserved in Vulkan GLSL. Rename full
    # tokens, including uniform declarations, while retaining serialized IDs.
    # SPIRV-Cross lowers GLSL pow() to Metal powr(). A source variable
    # named powr would otherwise shadow those generated function calls.
    for reserved in ('sample', 'active', 'filter', 'smooth', 'powr'):
        source = re.sub(r'\b' + reserved + r'\b', 'ref_' + reserved, source)
    source = re.sub(r'\btexture2D\s*\(', 'texture(', source)
    source = re.sub(r'\(void\)\s*\w+\s*;', '', source)
    source = re.sub(r'\b(?:lowp|mediump|highp)\s+', '', source)
    source += '''
void main() {
    referenceColor = vec4(0.);
    referenceMain();
NATIVE_ALPHA_ADAPTER
    if (any(isnan(referenceColor)) || any(isinf(referenceColor))) referenceColor=vec4(0.);
    referenceColor.a=clamp(referenceColor.a,0.,1.);
    if (referenceColor.a<=0.) referenceColor=vec4(0.);
    // The render target is rgba16Float. Preserve HDR while avoiding overflow
    // during the final float32-to-float16 conversion.
    referenceColor.rgb=clamp(referenceColor.rgb,vec3(-65504.),vec3(65504.));
    finalColor=referenceColor;
}
'''
    alpha_adapter = ''
    if basename in {'pixeledge.xml', 'irridescence2.xml'}:
        alpha_adapter = 'float nativeAlpha = texture(refInput, acScreenNorm).a;\n    referenceColor = vec4(referenceColor.rgb * nativeAlpha, nativeAlpha);'
    source = source.replace('NATIVE_ALPHA_ADAPTER', alpha_adapter)
    return source, controls, slot, buffer_records, passes, reference_binding


def run(args):
    args.output.mkdir(parents=True, exist_ok=True)
    records = []
    old_report = args.output / 'translation-report.json'
    previous = {r['file']: r for r in json.loads(old_report.read_text(encoding='utf8'))} if args.only and old_report.exists() else {}
    with zipfile.ZipFile(args.ipa) as archive:
        roots = {filename: ET.fromstring(archive.read(filename)) for filename in archive.namelist()
                 if filename.endswith('.xml') and '/AEMotionQuarantine/' not in filename}
        dependencies = dependency_files(roots)
        for filename in archive.namelist():
            if not filename.endswith('.xml') or '/AEMotionQuarantine/' in filename:
                continue
            root = ET.fromstring(archive.read(filename))
            if root.tag != 'effect' or (root.get('deprecated') == 'true' and filename not in dependencies):
                continue
            if args.only and Path(filename).name not in args.only:
                if filename not in previous:
                    raise RuntimeError('Incremental translation needs the complete prior report')
                records.append(previous[filename])
                continue
            slug = 'e' + __import__('hashlib').sha256(filename.encode()).hexdigest()[:12]
            record = {'file': filename, 'id': root.get('id'), 'slug': slug, 'dependency_only': filename in dependencies}
            try:
                for texture in root.findall('params/texture'):
                    if texture.get('srcType') is None and texture.get('src'):
                        texture.set('srcType', 'image')
                images = {}
                shader_text = '\n'.join(''.join(s.itertext()) for s in root.findall('.//shader'))
                shader_text = re.sub(r'/\*.*?\*/|//[^\n]*', '', shader_text, flags=re.S)
                for texture in root.findall('params/texture'):
                    if texture.get('srcType') != 'image':
                        continue
                    if not re.search(r'\b' + re.escape(texture.get('id', '')) + r'\s*\.', shader_text):
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
                source, controls, slots, buffers, passes, reference_binding = translate(root, slug, images, filename,
                    external_ids={r.get('id') for p,r in roots.items() if r.tag == 'effect' and (r.get('deprecated') != 'true' or p in dependencies)})
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
                external_passes = {str(i): p.get('effect') for i, p in enumerate(root.findall('passes/pass')) if p.get('effect')} if passes else {}
                source_passes = {str(i): p.get('src') for i, p in enumerate(root.findall('passes/pass')) if p.get('src')} if passes else {}
                iterations = root.find('iterations')
                record.update(status='translated-not-integrated', controls=controls, slots=slots, metal=str(metal), images=images,
                              buffers=buffers, passes=passes, reference_binding=reference_binding, external_passes=external_passes,
                              source_passes=source_passes, iteration_parameter=iterations.get('param') if iterations is not None else None)
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
    parser.add_argument('--only', action='append', help='Rebuild named XML files while retaining prior audit entries')
    run(parser.parse_args())

"""Prepare translated reference sources and typed bindings outside the app.

The audit catalog includes overlapping references for comparison, not duplicate
public browser entries. Public candidates are explicit and still require native
compile, parameter, transparency, motion and visual checks before release.
"""
import argparse
import json
import math
from pathlib import Path
import shutil


PUBLIC = {
    'skexnxxlinescape.xml': ('Linescape', 'Layered noise-driven terrain lines with perspective, rotation and two colors.'),
    'pixeledge.xml': ('Pixelate Edge', 'Pixelate image detail around edges while retaining the source transparency.'),
    'colorama.xml': ('Fractal Color Bands', 'Fractal noise drives moving HSV color bands, with editable octaves, gain and hue density.'),
    'tileshift2.xml': ('Tile Shift', 'Offset alternating tile rows or columns while repeating the source.'),
    'palette-map.xml': ('Palette Map', 'Quantize and remap source colors into a selected palette.'),
    'irridescence2.xml': ('Iridescence', 'Nested fractal noise produces a flowing iridescent texture.'),
    'waveloq-3.xml': ('Wave Dot Display', 'Sample the source on a luminous dot grid with independent wave, signal, chaos and burst displacement patterns.'),
    'radialshadow2.xml': ('Radial Shadow', 'Project a shadow radially from a chosen origin.'),
    'skexnxxcomet.xml': ('Comet Trails', 'Layer-colored falling streaks or a perspective streak tunnel. Animate Travel to move along the trails.'),
    'square_break_3d.xml': ('Tile Break', 'Animate Progress to break the source into delayed, rotating tiles with gravity and a fading finish.'),
    'heatmap_perlin_noise.xml': ('Heatmap', 'Noise-modulated heat color bands driven by the source.'),
    'tilerotate2.xml': ('Tile Rotate', 'Rotate repeating tiles around their individual centers.'),
    'omino-diffusion.xml': ('Error Diffusion', 'Quantize into a palette while propagating sample error along a chosen direction.'),
    'skexnxxfractaltexture.xml': ('Fractal Texture', 'An evolving fractal texture with offset, scale and rotation.'),
    'skexnxxmoney.xml': ('Money Filter', 'Convert tonal detail into an engraved banknote-style pattern.'),
    'ribbon.xml': ('Ribbon', 'A procedural ribbon field with adjustable shape and color.'),
    'radial_rays.xml': ('Bent Rays', 'Solid radial wedges with sinusoidal angular bending, independent angular and radial softness, and an editable inner and outer radius.'),
    'metalballs.xml': ('Glass Spheres', 'Scatter refractive spheres with source reflections, Fresnel rims, lighting and independently adjustable depth and motion.'),
    'highlight-shadow.xml': ('Highlights and Shadows', 'Adjust dark and bright tonal regions independently.'),
    'Adamagedots.xml': ('Film Damage Dots', 'Animated film damage made from localized marks and dots.'),
    'psykostripes.xml': ('Psykostripes', 'Procedural psychedelic stripe bands with editable phase and color.'),
    'channelmaphsv.xml': ('Channel Remap HSV', 'Reassign hue, saturation and value channels independently.'),
    'ink_splash.xml': ('Ink Splash', 'Procedural splashed ink with adjustable shape and coverage.'),
    'rounded_edge_mask.xml': ('Rounded Edge Mask', 'Mask the image to a rounded rectangular boundary.'),
    'blocknoise2.xml': ('Block Noise', 'A discrete block-based noise generator with editable pattern controls.'),
    's_warp_waves2.xml': ('Dual Wave Warp', 'Combine two independent wave fields, each with its own wave and displacement directions, phase and speed. Choose transparent, tiled or reflected edges.'),
    'hand_drawn.xml': ('Line Boil', 'Animated hand-drawn jitter with an independently controlled outline and redraw frame rate.'),
    'streakstrips.xml': ('Streak Strips', 'Stretch the source through alternating angled strips. Animate Phase to move the strip pattern.'),
    'warpblur.xml': ('Fractal Blur', 'Blur along a fractal displacement field with radial, angular, X, Y and XY sampling directions, evolving noise, bias and octave control.'),
    'mystery_book.xml': ('Opening Book', 'A raymarched opening book with the source image mapped onto its pages. Animate Opening; adjust camera zoom and rotation.'),
    'monitor_on_table.xml': ('Monitor Scene', 'Map the source onto a monitor in a raymarched table scene, with camera zoom and orbit.'),
    'colormatch.xml': ('Color Transfer', 'Match the source color distribution to a selected reference layer, with adjustable strength and sampling region.'),
    'colorhot.xml': ('Hot Color', 'Map luminance through two hue-controlled tonal colors, with saturation, gamma, cutoff and bias controls.'),
    'glitch_pro.xml': ('Precision Glitch', 'Combine individually adjustable scanline tears, block corruption, static and color-band interference with controlled trigger timing.'),
    'skexnxxhardglitch.xml': ('Fractal Glitch', 'Displace channels through a fractal block field, with threshold selection, blockiness, narrowing and independent channel colors.'),
    'holomatrix2.xml': ('Holomatrix', 'An editable holographic signal stack: low resolution, scan lines, line drift, channel separation, static, flicker, distortion and threshold glow.'),
    'skexnxxinstantgrass.xml': ('2D Grass', 'Wind-driven procedural grass blades with editable density, growth, stretch and colors, using the complete inherited shader stage.'),
    'skexnxxplexustriangle.xml': ('Plexus Faces', 'An evolving triangular plexus field with separate motion, rotation and color controls.'),
    'skexnxxfibersglow.xml': ('Glow Fibers', 'Flowing luminous strands with editable evolution, color and gradient mapping.'),
    'skexnxxhexagonlens.xml': ('Hex Lens', 'A raymarched hexagonal lens field with orientation, reflection highlights and flare controls.'),
    'contourstrips.xml': ('Contour Strips', 'Build strips from a smoothed source contour field, with independently adjustable strip appearance.'),
    'grunge.xml': ('Grunge', 'Extract and composite a textured surface treatment from a smoothed source, with color and contrast control.'),
}

# Promoted only after still/motion review of run 44683887738. Other candidates
# remain in the internal audit catalog, including neutral defaults needing
# dedicated utility fixtures and entries overlapping the accepted catalog.
APPROVED = {
    'skexnxxlinescape.xml', 'pixeledge.xml', 'colorama.xml', 'tileshift2.xml',
    'palette-map.xml', 'irridescence2.xml', 'heatmap_perlin_noise.xml',
    'skexnxxfractaltexture.xml', 'omino-diffusion.xml', 'skexnxxmoney.xml',
    'psykostripes.xml', 'square_break_3d.xml', 'rounded_edge_mask.xml',
    'blocknoise2.xml', 'tilerotate2.xml',
    'waveloq-3.xml', 'radialshadow2.xml', 'skexnxxcomet.xml', 'ribbon.xml',
    'radial_rays.xml', 'metalballs.xml', 'highlight-shadow.xml', 'Adamagedots.xml',
    'channelmaphsv.xml', 'ink_splash.xml',
}
DEFAULTS = {
    'square_break_3d.xml': {'progress': '0.35'},
    'rounded_edge_mask.xml': {'scaleX': '0.8', 'scaleY': '0.8'},
    'psykostripes.xml': {'stripeMag': '12', 'phaseGreen': '2.094', 'phaseBlue': '4.189', 'edgeAmt': '0.45'},
    'ribbon.xml': {'width': '1.6', 'amplitude': '0.4'},
    'radial_rays.xml': {'bendStrength': '0.45', 'bendFrequency': '18', 'pointCount': '9'},
    'radialshadow2.xml': {'alpha': '0.65', 'light': '-120,-160', 'quality': '96'},
    'highlight-shadow.xml': {'highlights': '0.85', 'shadows': '1.15'},
    'Adamagedots.xml': {'density': '400', 'dotSize': '5'},
    'waveloq-3.xml': {'thickness': '3.5', 'glow': '2', 'pitch': '7'},
    'mystery_book.xml': {'openProgress': '0.65'},
}
LABELS = {
    'tilerotate2.xml': {'strength': 'Random Rotation', 'rotation': 'Tile Rotation', 'angle': 'Grid Angle', 'amount': 'Tile Count'},
    'colorama.xml': {'blend': 'Effect Mix', 'alpha': 'Opacity', 'timeSpeed': 'Evolution Speed', 'hueScale': 'Color Bands', 'value': 'Brightness'},
    'psykostripes.xml': {'stripeMag': 'Stripe Density', 'freqColors': 'Color Frequency', 'offset': 'Phase Offset'},
    'waveloq-3.xml': {'preset': 'Pattern', 'animSpeed': 'Wave Speed', 'pitch': 'Dot Spacing', 'thickness': 'Dot Size', 'range': 'Luma Range', 'fade': 'Threshold Softness', 'generators': 'Wave Layers', 'compress': 'Displacement Scale', 'blend': 'Effect Mix'},
    'skexnxxcomet.xml': {'progressa': 'Travel', 'color1': 'Trail Color', 'color2': 'Tunnel Color 2', 'color3': 'Tunnel Color 3'},
    'radialshadow2.xml': {'quality': 'Samples', 'fill': 'Source Opacity', 'alpha': 'Shadow Opacity', 'size': 'Shadow Length'},
    'ribbon.xml': {'amplitude': 'Wave Height', 'phase': 'Travel', 'smoothing': 'Edge Softness', 'tint': 'Tint Mix'},
    'radial_rays.xml': {'pointCount': 'Wedges', 'bendStrength': 'Bend', 'bendFrequency': 'Bend Frequency', 'bendPhase': 'Bend Phase', 'feather': 'Angular Edge', 'radialFeather': 'Radial Edge'},
    'metalballs.xml': {'ballColor': 'Glass Tint', 'progress': 'Travel', 'posX': 'Offset X', 'posY': 'Offset Y', 'posZ': 'Depth Offset'},
    'mystery_book.xml': {'openProgress': 'Opening', 'camRot': 'Camera Orbit', 'zoom': 'Camera Zoom'},
}


def string(value):
    return json.dumps(value, ensure_ascii=False)


def number(value, fallback=0):
    result = float(value) if value not in (None, '') else fallback
    if not math.isfinite(result):
        raise ValueError('non-finite parameter metadata')
    return repr(result)


def parameter(control, labels):
    key = control['id']
    label = labels.get(key, key).replace('Heigth', 'Height')
    prefix = f'ReferenceFragmentParameter(definition: '
    kind = control['control']
    if kind in {'xyz', 'point3d', 'orient', 'hue-disc'}:
        def vector(field, default):
            values = [v.strip() for v in control.get(field, default).split(',')]
            return values * 3 if len(values) == 1 else values
        defaults = vector('default', '0,0,0')
        low = vector('min', '-3600,-3600,-3600' if kind in {'orient', 'hue-disc'} or control.get('type') == 'rotate' else '-10000,-10000,-10000')
        high = vector('max', '3600,3600,3600' if kind in {'orient', 'hue-disc'} or control.get('type') == 'rotate' else '10000,10000,10000')
        names = ['Hue', 'Saturation', 'Bias'] if kind == 'hue-disc' else ['X', 'Y', 'Z']
        if kind == 'hue-disc':
            low, high = ['-3600', '0', '-1'], ['3600', '2', '1']
        result = []
        for component, axis in enumerate(names):
            component_id = key + '_' + axis.lower()
            definition = '.number(' + string(component_id) + ', ' + string(label + ' ' + axis) + ', ' + ', '.join(number(v) for v in [defaults[component], low[component], high[component]]) + ', step: 0.01)'
            result.append(prefix + definition + f', slot: {control["slot"]}, component: {component})')
        return '\n'.join(result)
    common = f'{string(key)}, {string(label)}, '
    choice_values = []
    extras = []
    if kind in {'spinner', 'slider'}:
        if control.get('type') == 'angle':
            definition = '.angle(' + common + number(control.get('default')) + ')'
        else:
            percent = control.get('type') == 'percent'
            scale = 100 if percent else 1
            definition = '.number(' + common + ', '.join(number(float(control.get(k, default)) * scale) for k, default in [('default', 0), ('min', -1000), ('max', 1000)]) + ', step: ' + number(float(control.get('step', 0)) * scale)
            if percent:
                definition += ', unit: "%"'
                extras.append('scalarScale: 0.01')
            definition += ')'
    elif kind == 'point':
        defaults = [float(v.strip()) for v in control.get('default', '0,0').split(',')]
        definition = '.point(' + common + f'Vec2({number(defaults[0])}, {number(defaults[1])}))'
        for field, property in [('min', 'pointMinimum'), ('max', 'pointMaximum')]:
            if field in control:
                values = [float(v.strip()) for v in control[field].split(',')]
                if len(values) == 2:
                    extras.append(property + f': Vec2({number(values[0])}, {number(values[1])})')
    elif kind == 'color':
        raw = control.get('default', '#FFFFFFFF').lstrip('#')
        if len(raw) == 6:
            raw = 'FF' + raw
        if len(raw) != 8:
            raise ValueError('unsupported color default')
        a, r, g, b = [int(raw[i:i+2], 16) / 255 for i in range(0, 8, 2)]
        definition = '.color(' + common + f'RGBA({r}, {g}, {b}, {a}))'
    elif kind == 'switch':
        definition = '.toggle(' + common + ('true' if control.get('default') == 'true' else 'false') + ')'
    elif kind == 'selector':
        choices = control['choices']
        choice_values = [int(float(c['value'])) for c in choices]
        selected = int(float(control.get('default', choice_values[0])))
        index = choice_values.index(selected)
        options = [labels.get(key + '/' + str(i), c.get('label', c['value'])) for i, c in enumerate(choices)]
        definition = '.choice(' + common + '[' + ', '.join(string(o) for o in options) + f'], {index})'
    else:
        raise ValueError('needs native parameter UI: ' + kind)
    if choice_values:
        extras.append('choiceValues: ' + str(choice_values))
        targets = [c.get('enableTargets', '').split(',') if c.get('enableTargets') else [] for c in control['choices']]
        if any(targets):
            extras.append('choiceTargets: ' + json.dumps(targets))
    extra = ', ' + ', '.join(extras) if extras else ''
    return prefix + definition + f', slot: {control["slot"]}' + extra + ')'


def prepare(args):
    translated = json.loads((args.translated / 'translation-report.json').read_text(encoding='utf8'))
    # A compiled final fragment is not a complete effect if a required native
    # prepass is absent. Never register that incomplete graph as a working tool.
    ready = {r['file']: r for r in translated if r['status'] == 'translated-not-integrated'}
    removed = {}
    while True:
        source_ids = {r.get('id') for r in ready.values()}
        invalid = {filename: [value for value in row.get('external_passes', {}).values() if value not in source_ids]
                   for filename, row in ready.items()}
        invalid = {filename: missing for filename, missing in invalid.items() if missing}
        if not invalid: break
        for filename, missing in invalid.items():
            removed[filename] = missing
            del ready[filename]
    inventory = json.loads(args.inventory.read_text(encoding='utf8'))['effects']
    inventory = {r['file']: r for r in inventory}
    destination = args.output
    metal = destination / 'Metal'
    textures = destination / 'Textures'
    metal.mkdir(parents=True, exist_ok=True)
    textures.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(Path(__file__).parent / 'reference' / 'ReferenceFragmentEffects.swift.template', destination / 'ReferenceFragmentEffects.swift')
    shutil.copyfile(Path(__file__).parent / 'reference' / 'ReferenceFragmentAuditTests.swift.template', destination / 'ReferenceFragmentAuditTests.swift')
    functions, symbols, public, promoted, report = [], [], [], [], []
    category = {'procedural': 'generate', '3d': 'generate', 'blur': 'blur', 'color': 'color', 'distort': 'distort', 'drawing': 'stylize', 'transform': 'motion', 'matte': 'keying', 'opacity': 'keying', 'text': 'text', 'repeat': 'motion', 'other': 'stylize'}
    for row in translated:
        if row['status'] != 'translated-not-integrated':
            report.append({'file': row['file'], 'status': row['status'], 'reason': row.get('reason')})
            continue
        if row['file'] in removed:
            report.append({'file':row['file'], 'status':'requires-native-dependency', 'reason':', '.join(removed[row['file']])})
            continue
        reference = inventory[row['file']]
        labels = {p.get('id'): p.get('label', p.get('id', '')) for p in reference['params']}
        labels.update(LABELS.get(Path(row['file']).name, {}))
        for p in reference['params']:
            labels.update({p.get('id', '') + '/' + str(i): c.get('label', '') for i, c in enumerate(p.get('choices', []))})
        try:
            controls = [parameter({**c, **({'default': DEFAULTS[Path(row['file']).name][c['id']]} if c['id'] in DEFAULTS.get(Path(row['file']).name, {}) else {})}, labels) for c in row['controls']]
        except (ValueError, IndexError, KeyError) as error:
            report.append({'file': row['file'], 'status': 'needs-parameter-adapter', 'reason': str(error)})
            continue
        symbol = row['slug']
        name, summary = PUBLIC.get(Path(row['file']).name, (reference['name'], 'Internal reference shader for comparison and adapter validation.'))
        image_names = [v['file'] for v in row.get('images', {}).values()]
        body = [f'    private static func make_{symbol}() -> ReferenceFragmentDefinition {{', '        var parameters: [ReferenceFragmentParameter] = []']
        body += ['        parameters.append(' + c + ')' for group in controls for c in group.splitlines()]
        selected_category = {'square_break_3d.xml': 'transition', 'colorama.xml': 'generate', 'omino-diffusion.xml': 'stylize', 'blocknoise2.xml': 'stylize'}.get(Path(row['file']).name, category[reference['category']])
        buffers = ', '.join(f'ReferenceFragmentBuffer(name: {string(b["name"])}, binding: {b["binding"]}, downsample: {b["downsample"]})' for b in row.get('buffers', []))
        passes = ', '.join(string(p) for p in row.get('passes', []))
        binding = row.get('reference_binding')
        binding = 'nil' if binding is None else str(binding)
        external = ', '.join(str(k) + ': ' + string(v) for k, v in row.get('external_passes', {}).items())
        external = '[' + external + ']' if external else '[:]'
        sources = ', '.join(str(k) + ': ' + string(v) for k,v in row.get('source_passes', {}).items())
        sources = '[' + sources + ']' if sources else '[:]'
        # Several source files name an absent "iter" parameter. They have
        # no repeat control and run once, just like a missing iterations tag.
        iteration_key=row.get('iteration_parameter')
        iteration=string(iteration_key) if any(c.get('id') == iteration_key for c in row.get('controls', [])) else 'nil'
        body += [f'        return ReferenceFragmentDefinition(id: "awi.amref.{symbol}", name: {string(name)}, summary: {string(summary)},', f'            category: .{selected_category}, function: "refAM35_{symbol}", slots: {row["slots"]},', '            parameters: parameters, images: [' + ', '.join(string(n) for n in image_names) + f'], buffers: [{buffers}], passes: [{passes}], referenceBinding: {binding}, sourceID: {string(row.get("id", ""))}, externalPasses: {external}, sourcePasses: {sources}, iterationParameter: {iteration})', '    }']
        functions.append('\n'.join(body))
        symbols.append(symbol)
        if Path(row['file']).name in PUBLIC:
            public.append(symbol)
        if Path(row['file']).name in APPROVED:
            promoted.append(symbol)
        shutil.copyfile(args.translated / (symbol + '.metal'), metal / (symbol + '.metal'))
        for name in image_names:
            shutil.copyfile(args.translated / name, textures / name)
        report.append({'file': row['file'], 'status': 'promoted-pending-validation' if symbol in promoted else 'internal-audit', 'id': 'awi.amref.' + symbol, 'dependency_only':row.get('dependency_only',False), 'public_candidate': symbol in public, 'promoted': symbol in promoted, 'source_name': reference['name'], 'existing_name_matches': reference['existing_name_matches']})
    code = 'import Foundation\nimport Metal\n\n// Generated by scripts/prepare_reference_import.py. Do not edit bindings by hand.\nenum ReferenceFragmentCatalog {\n'
    code += '\n'.join(f'    static let {symbol} = make_{symbol}()' for symbol in symbols)
    code += '\n    static let all: [ReferenceFragmentDefinition] = [' + ', '.join(symbols) + ']\n'
    code += '    static let bySourceID = Dictionary(all.map { ($0.sourceID, $0) }, uniquingKeysWith: { first, _ in first })\n'
    code += '    static let publicCandidates: [ReferenceFragmentDefinition] = [' + ', '.join(public) + ']\n'
    code += '    static let promoted: [ReferenceFragmentDefinition] = [' + ', '.join(promoted) + ']\n'
    code += '\n\n'.join(functions) + '\n}\n'
    (destination / 'ReferenceFragmentCatalog.swift').write_text(code, encoding='utf8')
    (destination / 'preparation-report.json').write_text(json.dumps(report, indent=2), encoding='utf8')
    (metal / 'ReferenceVertex.metal').write_text('''#include <metal_stdlib>
using namespace metal;
vertex float4 referenceVertexAM35(uint index [[vertex_id]]) {
    const float2 positions[3] = {float2(-1., -1.), float2(3., -1.), float2(-1., 3.)};
    return float4(positions[index], 0., 1.);
}
''', encoding='utf8')
    print(json.dumps({'prepared_internal_descriptors': len(symbols), 'public_review_candidates': len(public),
                      'promoted_pending_validation':len(promoted), 'output': str(destination)}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--translated', type=Path, default=Path('build_out/reference-translation-images'))
    parser.add_argument('--inventory', type=Path, default=Path('build_out/reference-audit/reference-inventory.json'))
    parser.add_argument('--output', type=Path, default=Path('build_out/prepared-reference-import'))
    prepare(parser.parse_args())

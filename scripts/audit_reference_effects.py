"""Inventory the supplied reference IPA without executing or extracting its binaries.

Name matches are review hints, never evidence of equivalent rendering. Pass the
registered-effects.json CI artifact to compare against the actual live registry.
"""
import argparse
import collections
import csv
import hashlib
import json
from pathlib import Path
import plistlib
import re
import xml.etree.ElementTree as ET
import zipfile


def normalize(value):
    return re.sub(r'[^a-z0-9]', '', value.lower())


def audit(ipa, catalog, output):
    existing = json.loads(catalog.read_text(encoding='utf-8')) if catalog else []
    names = collections.defaultdict(list)
    for effect in existing:
        names[normalize(effect['name'])].append(effect['id'])
    records, failures = [], []
    with zipfile.ZipFile(ipa) as archive:
        labels = plistlib.loads(archive.read('Payload/AlightMotion.app/en.lproj/Localizable.strings'))

        def label(value, root):
            if value.startswith('@am:string/'):
                return labels.get(value.split('/')[-1], value)
            if value.startswith('@string/'):
                key = value.split('/')[-1]
                node = root.find(f".//locale[@lang='en']/string[@name='{key}']")
                return node.text if node is not None else value
            return value

        for filename in archive.namelist():
            if not filename.endswith('.xml'):
                continue
            raw = archive.read(filename)
            try:
                root = ET.fromstring(raw)
            except ET.ParseError as error:
                failures.append({'file': filename, 'error': str(error)})
                continue
            if root.tag != 'effect':
                continue
            name = label(root.get('name', ''), root)
            code = '\n'.join(''.join(s.itertext()) for s in root.findall('.//shader'))
            # Ignore comments for control-use hints. Native properties may be consumed
            # outside shaders, so unused-in-shader is explicitly NOT a broken-control verdict.
            stripped = re.sub(r'/\*.*?\*/|//[^\n]*', '', code, flags=re.S)
            params = []
            parent = root.find('params')
            for node in parent if parent is not None else []:
                param = {'control': node.tag, **node.attrib}
                param['label'] = label(node.get('label', node.get('id', '')), root)
                param['choices'] = [{**c.attrib, 'label': label(c.get('label', ''), root)} for c in node.findall('choice')]
                param['referenced_in_shader'] = bool(node.get('id') and re.search(r'\b' + re.escape(node.get('id')) + r'\b', stripped))
                params.append(param)
            quarantined = '/AEMotionQuarantine/' in filename
            deprecated = root.get('deprecated') == 'true'
            records.append({
                'file': filename, 'id': root.get('id'), 'name': name,
                'category': root.get('category'), 'deprecated': deprecated,
                'quarantined': quarantined, 'params': params,
                'shader_count': len(root.findall('.//shader')),
                'shader_sha256': hashlib.sha256(code.encode()).hexdigest() if code else None,
                'source_sha256': hashlib.sha256(raw).hexdigest(),
                'existing_name_matches': names[normalize(name)],
                'review': 'excluded-quarantine' if quarantined else 'legacy-reference' if deprecated else 'pending-semantic-review',
            })
    output.mkdir(parents=True, exist_ok=True)
    (output / 'reference-inventory.json').write_text(json.dumps({'effects': records, 'parse_errors': failures}, indent=2, ensure_ascii=False), encoding='utf-8')
    with (output / 'reference-comparison.csv').open('w', encoding='utf-8-sig', newline='') as stream:
        writer = csv.writer(stream)
        writer.writerow(['reference_file', 'name', 'category', 'status', 'existing_name_candidates', 'shader_count', 'controls'])
        for row in records:
            writer.writerow([row['file'], row['name'], row['category'], row['review'], ', '.join(row['existing_name_matches']), row['shader_count'], ', '.join(p.get('label', '') for p in row['params'] if p['control'] not in {'texture', 'section'})])
    active = [r for r in records if not r['deprecated'] and not r['quarantined']]
    print(json.dumps({'reference_definitions': len(records), 'current_reference_definitions': len(active), 'parse_errors': len(failures), 'registered_awi_effects': len(existing), 'output': str(output)}, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('ipa', type=Path)
    parser.add_argument('--catalog', type=Path)
    parser.add_argument('--output', type=Path, default=Path('build_out/reference-audit'))
    args = parser.parse_args()
    audit(args.ipa, args.catalog, args.output)

"""Disjoint XCTest selectors. Every discovered test belongs to exactly one shard.
No test is disabled to make a shard green; CI records the complete inventory.
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SHARDS = ['core', 'effects-a', 'effects-b', 'renders', 'ui', 'text-core',
          'text-motion-a', 'text-motion-b', 'general-premades']
EFFECT_A = {'EffectTests', 'GlowLightRemakeTests', 'ShakeBlurRemakeTests',
            'DistortTransitionRemakeTests', 'StylizeRetroRemakeTests',
            'EffectsPhaseOneTests', 'RenewColorEffectsTests', 'BackgroundColorRemakeTests'}
EFFECT_B = {'DataEffectTests', 'DCTEffectTests', 'DistanceEffectTests', 'Expansion50EffectTests',
            'FlowEffectTests', 'PoissonEffectTests', 'ProjectionEffectTests',
            'SegmentPixelSortTests', 'SurfaceEffectTests', 'SurfaceFinishTests',
            'TemporalAnalysisTests', 'TemporalEffectTests', 'TextGeometryEffectTests'}
RENDERS = {'ReferenceFragmentAuditTests', 'ExpansionRenderTests', 'ContactSheetTests', 'BackgroundExpansionTests'}
TEXT = {'CraftPresets33Tests', 'TextPresetLibraryTests', 'TextStudioTests',
        'TextStudioEngineTests', 'Text3DTests', 'TextTests'}
SCOPES = {
    'reference-repairs': ['EffectTests', 'ReviewedReferenceEffectsTests', 'ContainerInteractionTests', 'LayerSelectionResponseTests', 'ContainerInteractionUITests', 'EditorPolishUITests', 'ReviewedReferenceEffectsUITests'],
    'motion-blur': ['EditorPolishUITests', 'MotionBlurTests'],
    'segmentation': ['CutoutStudioTests', 'ArtStudioRenewTests'],
    'audit': ['AuditRegressionTests', 'AuditRenderRegressionTests', 'PrecompMaskImportTests',
              'EssentialRegressionTests', 'DrawStudioTests', 'VisionTests', 'VideoDecodeTests',
              'EditorPolishRegressionTests', 'EditorPolishUITests'],
    'timing': ['AnimationTimingUITests', 'GraphRemakeUITests', 'GraphRemakeTests'],
    'stability': ['InlineToolsTests', 'InlineToolsUITests', 'EditorPolishUITests',
                  'StabilityUITests', 'AnimationTimingUITests', 'ResponsivePreviewTests',
                  'LayerSelectionResponseTests'],
    'authoring': ['RigOverhaulTests', 'BoneMeshTests', 'BoneAuthoringTests', 'BugBatchBTests',
                  'TextStudioTests', 'AdvancedAuthoringRenderTests', 'GraphRemakeTests', 'RigAuthoringUITests'],
}
REPAIR_CLASSES = {'InteractiveSelectionTests', 'LibraryTests', 'RenderSpeedTests', 'MemoryTests',
                  'ArtStudioRenewTests', 'Text3DTests', 'CraftPresets33Tests', 'TextPresetLibraryTests',
                  'ResponsivePreviewTests', 'LayerSelectionResponseTests', 'DistanceEffectTests',
                  'SurfaceFinishTests', 'Expansion50EffectTests', 'DCTEffectTests'}

def needs_repair_check(target, cls, method):
    if target == 'AWIeffectUITests': return True  # Previous UI runner never initialized.
    if cls in REPAIR_CLASSES: return True
    if cls == 'TextPresetSheetTests': return not method.startswith('testGeneral')
    if cls == 'EffectTests': return method == 'testEveryNumericControlIsWired' or method.startswith('testNumericControlsPart')
    if cls == 'ExpansionRenderTests':
        return method in {'testFrequencyFiltersKeepCoverageAndEmptyPixelsClean', 'testWriteRemainingFamilyReviewArtifacts'} or method.startswith('testRemainingReviewPart')
    return False

def needs_final_repair_check(target, cls, method):
    if cls in {'LibraryTests','LayerSelectionResponseTests','ContainerInteractionTests','ContainerInteractionUITests'}: return True
    if cls == 'TextPresetSheetTests': return method == 'testGeneralGlow'
    if cls == 'EditorPolishUITests':
        return method in {'testHeaderHoldStartsRangeSelectionWhileTracksRemainScrollable','testTrackHoldCanLiftAndReorderUnselectedClip'}
    if cls == 'EssentialUITests': return method == 'testGroupOpensItsOwnEditorAndReturnsToParent'
    if cls == 'Expansion50EffectTests':
        return method in {'testJunctionFlaresSeeFlatCutoutCornersAndKeepEmptyInputEmpty','testDefaultsChangeRichSourceAndBlendZeroIsExact','testOldSerializedInstancesUseIdenticalParameterFallbacks'}
    return False

def active_shards(scope):
    if scope == 'quick': return ['quick']
    if scope == 'all':
        return [shard for shard in SHARDS if any(shard_for(*test)==shard for test in inventory())]
    if scope in {'repairs','final-repairs'}:
        predicate=needs_repair_check if scope=='repairs' else needs_final_repair_check
        return [shard for shard in SHARDS if any(predicate(*test) and shard_for(*test)==shard for test in inventory())]
    return ['scope']

def inventory():
    result = []
    for target, directory in [('AWIeffectTests', 'Tests'), ('AWIeffectUITests', 'UITests')]:
        for path in sorted((ROOT / directory).glob('*.swift')):
            source = path.read_text(encoding='utf-8-sig')
            classes = list(re.finditer(r'\bclass\s+(\w+)\s*:\s*XCTestCase\b', source))
            for i, match in enumerate(classes):
                end = classes[i+1].start() if i+1 < len(classes) else len(source)
                for method in re.findall(r'\bfunc\s+(test\w+)\s*\(', source[match.end():end]):
                    result.append((target, match[1], method))
    assert result and len(set(result)) == len(result), 'Missing or duplicate test inventory'
    return result

def shard_for(target, cls, method):
    if target == 'AWIeffectUITests': return 'ui'
    if cls == 'TextPresetSheetTests':
        if method.startswith('testGeneral'): return 'general-premades'
        if method in {'testTextIn', 'testTextOut', 'testTextLoop', 'testTextEmphasis',
                      'testTextGlitch', 'testTextTypewriter', 'testTextKinetic'}: return 'text-motion-a'
        return 'text-motion-b'
    if cls in EFFECT_A: return 'effects-a'
    if cls in EFFECT_B: return 'effects-b'
    if cls in RENDERS: return 'renders'
    if cls in TEXT: return 'text-core'
    return 'core'

def selectors(scope, shard):
    tests = inventory()
    if scope in {'all','repairs','final-repairs'}:
        predicate=needs_repair_check if scope=='repairs' else needs_final_repair_check
        chosen = [test for test in tests if shard_for(*test) == shard and (scope=='all' or predicate(*test))]
    else:
        assert scope in SCOPES, scope
        chosen = [test for test in tests if test[1] in SCOPES[scope]]
        assert {test[1] for test in chosen} == set(SCOPES[scope]), 'A scoped test class disappeared'
    assert chosen, f'Empty test shard: {scope}/{shard}'
    return ['-only-testing:' + '/'.join(test) for test in chosen]

def check():
    tests = inventory()
    selected = [s for shard in active_shards('all') for s in selectors('all', shard)]
    assert len(selected) == len(tests) == len(set(selected)), 'Shards overlap or omit tests'
    for scope in SCOPES: selectors(scope, 'scope')
    repair_tests=[test for test in tests if needs_repair_check(*test)]
    repair_flags=[flag for shard in active_shards('repairs') for flag in selectors('repairs',shard)]
    assert len(repair_flags)==len(repair_tests)==len(set(repair_flags))
    final_tests=[test for test in tests if needs_final_repair_check(*test)]
    final_flags=[flag for shard in active_shards('final-repairs') for flag in selectors('final-repairs',shard)]
    assert len(final_flags)==len(final_tests)==len(set(final_flags))
    return {shard: len(selectors('all', shard)) for shard in active_shards('all')}

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--scope', default='all')
    parser.add_argument('--shard')
    parser.add_argument('--output')
    args = parser.parse_args()
    counts = check()
    if args.shard:
        flags = selectors(args.scope, args.shard)
        if args.output: Path(args.output).write_text('\n'.join(flags) + '\n')
        else: print('\n'.join(flags))
    else:
        print(json.dumps(counts, indent=2))

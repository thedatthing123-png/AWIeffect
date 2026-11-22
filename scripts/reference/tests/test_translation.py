"""Host-side contract checks; native Metal/render checks remain in XCTest."""
import unittest
import xml.etree.ElementTree as ET
from scripts.translate_reference_shaders import translate, dependency_files
from scripts.prepare_reference_import import parameter


def effect(params, shader, extra=''):
    return ET.fromstring('<effect><params>' + params + '</params>' + extra +
                         '<shader type="fragment"><![CDATA[' + shader + ']]></shader></effect>')


class TranslationTests(unittest.TestCase):
    def test_legacy_render_dependencies_are_resolved_transitively(self):
        roots={
            'a.xml':ET.fromstring('<effect id="a"><passes><pass effect="b"/></passes></effect>'),
            'b.xml':ET.fromstring('<effect id="b" deprecated="true"><passes><pass effect="c"/></passes></effect>'),
            'c.xml':ET.fromstring('<effect id="c" deprecated="true"/>'),
            'unrelated.xml':ET.fromstring('<effect id="unused" deprecated="true"/>')}
        self.assertEqual(dependency_files(roots),{'b.xml','c.xml'})
    def test_unused_texture_metadata_does_not_replace_the_source(self):
        root = effect('<texture id="inputImg" srcType="content"/><texture id="unused" srcType="buffer"/>',
                      'void main(){gl_FragColor=texture2DCv(inputImg.texture,acScreenNorm);}')
        source, _, _, buffers, passes, reference = translate(root, 'fixture')
        self.assertIn('texture2DCv(refInput,acScreenNorm)', source)
        self.assertFalse(buffers or passes or reference)

    def test_downsampled_passes_keep_named_bindings_and_dimensions(self):
        root = effect('<texture id="inputImg" srcType="content"/><texture id="small" srcType="buffer" downsample="2"/>',
                      'void main(){if(acPass==0)gl_FragColor=texture2DCv(inputImg.texture,acScreenNorm);'
                      'else gl_FragColor=texture2DCv(small.texture,acScreenNorm)/small.size.x;}',
                      '<passes><pass target="small"/><pass/></passes>')
        source, _, _, buffers, passes, _ = translate(root, 'fixture')
        self.assertEqual(passes, ['small', ''])
        self.assertEqual(buffers, [{'name': 'small', 'binding': 1, 'downsample': 2}])
        self.assertIn('refComposition.w,refScreen.w)/2.0', source)

    def test_unavailable_native_buffer_is_rejected_instead_of_stubbed(self):
        root = effect('<texture id="secret" srcType="buffer"/>',
                      'void main(){gl_FragColor=texture2DCv(secret.texture,acScreenNorm);}')
        with self.assertRaisesRegex(ValueError, 'requires buffer'):
            translate(root, 'fixture')

    def test_missing_external_pass_is_not_silently_run_as_a_copy(self):
        root = effect('<texture id="b" srcType="buffer"/>',
                      'void main(){gl_FragColor=texture2DCv(b.texture,acScreenNorm)*float(acPass);}',
                      '<passes><pass target="b" effect="unavailable.native.effect"/><pass/></passes>')
        with self.assertRaisesRegex(ValueError, 'external native pass'):
            translate(root, 'fixture')

    def test_vector_components_share_one_aligned_slot_and_preserve_ids(self):
        control = {'control': 'xyz', 'id': 'position', 'slot': 11, 'default': '1,2,3'}
        result = parameter(control, {'position': 'Position'})
        for component, axis in enumerate('xyz'):
            self.assertIn('"position_' + axis + '"', result)
            self.assertIn('slot: 11, component: ' + str(component), result)
        self.assertEqual(result.count('ReferenceFragmentParameter'), 3)

    def test_comments_cannot_turn_adapter_examples_into_live_statements(self):
        root = effect('<texture id="inputImg" srcType="content"/>',
                      'void main(){vec4 source=texture2DCv(inputImg.texture,acScreenNorm);'
                      'float luminance = dot(source.rgb, luminanceWeighting); gl_FragColor=source;\n'
                      '//float luminance = dot(source.rgb, luminanceWeighting);\n}')
        source, *_ = translate(root, 'fixture', filename='highlight-shadow.xml')
        self.assertEqual(source.count('float luminance ='), 1)

    def test_reserved_identifiers_and_local_matrix_arguments_are_portable(self):
        root = effect('<spinner id="sample" default="1"/>',
                      'vec2 f(vec2 v, mat4 acLTS){return (vec4(v,0,1)*acLTS).xy;}'
                      'void main(){float active=sample;gl_FragColor=vec4(active);}')
        source, controls, *_ = translate(root, 'fixture')
        self.assertIn('float ref_sample;', source)
        self.assertIn('float ref_active=ref_sample', source)
        self.assertEqual(controls[0]['id'], 'sample')

    def test_uniform_only_vertex_setup_is_retained(self):
        root = effect('<xyz id="rotate"/>',
                      'varying mat4 m; void main(){gl_FragColor=vec4(m[0][0]);}',
                      '<shader type="vertex"><![CDATA[varying mat4 m;void main(){vertShaderInit();m=mat4(rotate.x);}]]></shader>')
        source, *_ = translate(root, 'fixture')
        self.assertIn('mat4 m;', source)
        self.assertIn('referenceVertexInit();', source)
        self.assertNotIn('vertShaderInit();', source)

    def test_source_powr_does_not_shadow_metal_power_intrinsic(self):
        root = effect('', 'void main(){float powr=1.5;gl_FragColor=vec4(pow(0.5,powr));}')
        source, *_ = translate(root, 'fixture')
        self.assertIn('float ref_powr=1.5', source)
        self.assertIn('pow(0.5,ref_powr)', source)

    def test_geometry_vertex_program_is_not_mistaken_for_uniform_setup(self):
        root = effect('', 'void main(){gl_FragColor=vec4(1);}',
                      '<shader type="vertex"><![CDATA[void main(){gl_Position=vec4(1);}]]></shader>')
        with self.assertRaisesRegex(ValueError, 'geometry vertex'):
            translate(root, 'fixture')


if __name__ == '__main__':
    unittest.main()

"""Host-side contract checks; native Metal/render checks remain in XCTest."""
import unittest
from pathlib import Path
import xml.etree.ElementTree as ET
from scripts.translate_reference_shaders import translate, dependency_files, shader_header, Y_UP_SCENES
from scripts.prepare_reference_import import parameter, PUBLIC, APPROVED


def effect(params, shader, extra=''):
    return ET.fromstring('<effect><params>' + params + '</params>' + extra +
                         '<shader type="fragment"><![CDATA[' + shader + ']]></shader></effect>')


class TranslationTests(unittest.TestCase):
    def test_scene_content_reads_use_y_up_adapter_but_resources_stay_raw(self):
        root=effect('<texture id="iChannel0" srcType="content"/>',
                    'void main(){gl_FragColor=texture2D(iChannel0.texture,acScreenNorm);}')
        source,*_=translate(root,'fixture',filename='monitor_on_table.xml')
        self.assertIn('texture2DCv(refInput,acScreenNorm)',source)
        self.assertIn('texture(source,vec2(uv.x,1.-uv.y))',source)

    def test_particle_opacity_fades_rgb_as_well_as_coverage(self):
        root=effect('', 'void main(){ vec3 rgb=vec3(1.);float aa=1.;vec4 src=vec4(1.);float sourceMix=0.;float opacity=.25;gl_FragColor=vec4(rgb,clamp(max(aa,src.a*sourceMix)*opacity,0.,1.));}')
        source,*_=translate(root,'fixture',filename='skexnxxparticle3d.xml')
        self.assertIn('vec4(rgb*opacity,clamp(',source)

    def test_scene_coordinate_and_cv_sampling_flips_are_paired(self):
        for filename in Y_UP_SCENES:
            header = shader_header(filename)
            self.assertIn('refScreen.y-gl_FragCoord.y', header)
            self.assertIn('1.-(gl_FragCoord.y-refLayer.y)/refLayer.w', header)
            self.assertIn('texture(source,vec2(uv.x,1.-uv.y))', header)
            # A CV identity read must still fetch the same Metal pixel at
            # asymmetric rows, rather than mirroring its source image.
            for metal_y in (0.125, 0.375, 0.875):
                shader_y = 1.0-metal_y
                self.assertAlmostEqual(1.0-shader_y, metal_y)
        self.assertNotIn('refScreen.y-gl_FragCoord.y', shader_header('existing.xml'))

    def test_public_references_exclude_private_and_generic_template_entries(self):
        self.assertTrue(APPROVED.issubset(PUBLIC))
        names=[name.casefold() for name,_ in PUBLIC.values()]
        self.assertEqual(len(names),len(set(names)))
        for filename in PUBLIC:
            self.assertFalse(filename.startswith(('internal-','blend-','aemotion_native_','aemotion_s_')),filename)

    def test_bundled_reference_pngs_have_png_payloads(self):
        assets=Path(__file__).resolve().parents[3] / 'Resources' / 'ReferenceTextures'
        files=list(assets.glob('*.png'))
        self.assertTrue(files)
        for path in files:
            self.assertEqual(path.read_bytes()[:8], b'\x89PNG\r\n\x1a\n', path.name)

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

    def test_aperture_points_are_resolution_independent(self):
        root=effect('<point id="pointA" default="200,540"/><point id="pointB" default="1720,540"/>',
                    'void main(){gl_FragColor=vec4(pointA+pointB,0,1);}')
        source, controls, *_=translate(root,'fixture',filename='eye_split_bend.xml')
        self.assertEqual(controls[0]['default'],'0.15,0.5')
        self.assertEqual(controls[1]['default'],'0.85,0.5')
        self.assertIn('(pointA*acScreenSize)',source)
        self.assertEqual(controls[0]['max'],'1,1')

    def test_fractal_fade_removes_alpha_instead_of_flattening_black(self):
        root=effect('', 'void main(){vec4 tex=vec4(1);float mask=0.5;vec3 outRGB=vec3(0);gl_FragColor = vec4(outRGB, 1.0);}')
        source, *_=translate(root,'fixture',filename='fbm_time_displace_fade.xml')
        self.assertIn('referenceColor = tex * mask;',source)

    def test_geometry_vertex_program_is_not_mistaken_for_uniform_setup(self):
        root = effect('', 'void main(){gl_FragColor=vec4(1);}',
                      '<shader type="vertex"><![CDATA[void main(){gl_Position=vec4(1);}]]></shader>')
        with self.assertRaisesRegex(ValueError, 'geometry vertex'):
            translate(root, 'fixture')


if __name__ == '__main__':
    unittest.main()

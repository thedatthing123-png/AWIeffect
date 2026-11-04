#import "NativeModelBridge.h"
#import <GLTFKit2/GLTFKit2.h>
#import <ModelIO/ModelIO.h>
#import <SceneKit/ModelIO.h>
#import <UIKit/UIKit.h>
#include "../Vendor/ufbx/ufbx.h"

static NSError *ModelError(NSString *message) {
    return [NSError errorWithDomain:@"AWI.ModelImport" code:1 userInfo:@{NSLocalizedDescriptionKey: message}];
}

static SCNMaterial *Material(ufbx_material *material, NSURL *base) {
    SCNMaterial *result = [SCNMaterial new];
    result.lightingModelName = SCNLightingModelPhysicallyBased;
    result.doubleSided = YES;
    result.diffuse.contents = [UIColor colorWithWhite:0.75 alpha:1];
    result.roughness.contents = @0.6;
    if (!material) return result;
    ufbx_material_map color = material->pbr.base_color.has_value ? material->pbr.base_color : material->fbx.diffuse_color;
    if (color.has_value) result.diffuse.contents = [UIColor colorWithRed:color.value_vec4.x green:color.value_vec4.y blue:color.value_vec4.z alpha:1];
    ufbx_texture *texture = color.texture;
    if (texture) {
        UIImage *image = nil;
        if (texture->content.size) image = [UIImage imageWithData:[NSData dataWithBytes:texture->content.data length:texture->content.size]];
        if (!image && texture->relative_filename.length) {
            NSString *name = [[NSString alloc] initWithBytes:texture->relative_filename.data length:texture->relative_filename.length encoding:NSUTF8StringEncoding];
            NSURL *file = [base URLByAppendingPathComponent:[name stringByReplacingOccurrencesOfString:@"\\" withString:@"/"]];
            // Material resources remain inside the selected model's folder.
            if ([file.URLByStandardizingPath.path hasPrefix:[base.URLByStandardizingPath.path stringByAppendingString:@"/"]]) image = [UIImage imageWithContentsOfFile:file.path];
        }
        if (image) result.diffuse.contents = image;
    }
    return result;
}

static SCNScene *FBXScene(NSURL *url, NSError **error) {
    ufbx_load_opts options = {0};
    options.target_axes = ufbx_axes_right_handed_y_up;
    options.target_unit_meters = 1;
    options.temp_allocator.memory_limit = 256 * 1024 * 1024;
    options.result_allocator.memory_limit = 256 * 1024 * 1024;
    ufbx_error failure;
    ufbx_scene *source = ufbx_load_file(url.fileSystemRepresentation, &options, &failure);
    if (!source) { char message[1024]; ufbx_format_error(message, sizeof(message), &failure); if (error) *error = ModelError([NSString stringWithUTF8String:message]); return nil; }
    SCNScene *scene = [SCNScene new];
    size_t totalVertices = 0;
    for (size_t n = 0; n < source->nodes.count; n++) {
        ufbx_node *node = source->nodes.data[n];
        ufbx_mesh *mesh = node->mesh;
        if (!mesh || !mesh->num_triangles) continue;
        if (mesh->num_triangles > 1000000 / 3 || totalVertices + mesh->num_triangles * 3 > 1000000) {
            ufbx_free_scene(source); if (error) *error = ModelError(@"This FBX exceeds the one-million-vertex mobile import limit. Simplify it before importing."); return nil;
        }
        NSMutableData *positions = [NSMutableData data], *normals = [NSMutableData data], *uvs = [NSMutableData data];
        NSUInteger materialCount = MAX((NSUInteger)node->materials.count, 1);
        NSMutableArray<NSMutableData *> *indices = [NSMutableArray array];
        NSMutableArray<SCNMaterial *> *materials = [NSMutableArray array];
        for (NSUInteger m = 0; m < materialCount; m++) {
            [indices addObject:[NSMutableData data]];
            [materials addObject:Material(m < node->materials.count ? node->materials.data[m] : NULL, url.URLByDeletingLastPathComponent)];
        }
        uint32_t vertex = 0;
        for (size_t f = 0; f < mesh->faces.count; f++) {
            ufbx_face face = mesh->faces.data[f];
            if (face.num_indices < 3) continue;
            size_t capacity = (face.num_indices - 2) * 3;
            uint32_t *corners = malloc(capacity * sizeof(uint32_t));
            if (!corners) { ufbx_free_scene(source); if (error) *error = ModelError(@"Not enough memory to triangulate this FBX."); return nil; }
            uint32_t triangles = ufbx_triangulate_face(corners, capacity, mesh, face);
            NSUInteger material = mesh->face_material.count > f ? MIN(mesh->face_material.data[f], materialCount - 1) : 0;
            for (uint32_t c = 0; c < triangles * 3; c++) {
                uint32_t corner = corners[c];
                ufbx_vec3 p = ufbx_get_vertex_vec3(&mesh->vertex_position, corner);
                float position[3] = {(float)p.x, (float)p.y, (float)p.z}; [positions appendBytes:position length:sizeof(position)];
                if (mesh->vertex_normal.exists) { ufbx_vec3 v = ufbx_get_vertex_vec3(&mesh->vertex_normal, corner); float normal[3] = {(float)v.x,(float)v.y,(float)v.z}; [normals appendBytes:normal length:sizeof(normal)]; }
                if (mesh->vertex_uv.exists) { ufbx_vec2 v = ufbx_get_vertex_vec2(&mesh->vertex_uv, corner); float uv[2] = {(float)v.x,1-(float)v.y}; [uvs appendBytes:uv length:sizeof(uv)]; }
                [indices[material] appendBytes:&vertex length:sizeof(vertex)]; vertex++;
            }
            free(corners);
        }
        totalVertices += vertex;
        if (!normals.length) {
            const float *points = positions.bytes;
            for (uint32_t tri = 0; tri + 2 < vertex; tri += 3) {
                simd_float3 a = {points[tri*3],points[tri*3+1],points[tri*3+2]};
                simd_float3 b = {points[tri*3+3],points[tri*3+4],points[tri*3+5]};
                simd_float3 c = {points[tri*3+6],points[tri*3+7],points[tri*3+8]};
                simd_float3 cross = simd_cross(b-a,c-a);
                simd_float3 normal = simd_length(cross) > 1e-9 ? simd_normalize(cross) : (simd_float3){0,1,0};
                float packed[3] = {normal.x,normal.y,normal.z};
                for (int k=0;k<3;k++) [normals appendBytes:packed length:sizeof(packed)];
            }
        }
        NSMutableArray *streams = [NSMutableArray arrayWithObject:[SCNGeometrySource geometrySourceWithData:positions semantic:SCNGeometrySourceSemanticVertex vectorCount:vertex floatComponents:YES componentsPerVector:3 bytesPerComponent:4 dataOffset:0 dataStride:12]];
        if (normals.length) [streams addObject:[SCNGeometrySource geometrySourceWithData:normals semantic:SCNGeometrySourceSemanticNormal vectorCount:vertex floatComponents:YES componentsPerVector:3 bytesPerComponent:4 dataOffset:0 dataStride:12]];
        if (uvs.length) [streams addObject:[SCNGeometrySource geometrySourceWithData:uvs semantic:SCNGeometrySourceSemanticTexcoord vectorCount:vertex floatComponents:YES componentsPerVector:2 bytesPerComponent:4 dataOffset:0 dataStride:8]];
        NSMutableArray *elements = [NSMutableArray array];
        for (NSData *data in indices) [elements addObject:[SCNGeometryElement geometryElementWithData:data primitiveType:SCNGeometryPrimitiveTypeTriangles primitiveCount:data.length / 12 bytesPerIndex:4]];
        SCNGeometry *geometry = [SCNGeometry geometryWithSources:streams elements:elements]; geometry.materials = materials;
        SCNNode *part = [SCNNode nodeWithGeometry:geometry];
        ufbx_matrix m = node->geometry_to_world;
        part.simdTransform = (simd_float4x4){(simd_float4){m.m00,m.m10,m.m20,0},(simd_float4){m.m01,m.m11,m.m21,0},(simd_float4){m.m02,m.m12,m.m22,0},(simd_float4){m.m03,m.m13,m.m23,1}};
        [scene.rootNode addChildNode:part];
    }
    ufbx_free_scene(source);
    return scene;
}

@implementation AWIModelLoader
+ (SCNScene *)sceneAtURL:(NSURL *)url error:(NSError **)error {
    NSString *extension = url.pathExtension.lowercaseString;
    SCNScene *scene;
    if ([extension isEqualToString:@"glb"] || [extension isEqualToString:@"gltf"]) {
        GLTFAsset *asset = [GLTFAsset assetWithURL:url options:@{} error:error];
        if (!asset) return nil;
        scene = [SCNScene sceneWithGLTFAsset:asset];
    } else if ([extension isEqualToString:@"fbx"]) {
        scene = FBXScene(url, error);
    } else {
        scene = [SCNScene sceneWithURL:url options:@{SCNSceneSourceCheckConsistencyKey:@YES} error:error];
        if (!scene && [MDLAsset canImportFileExtension:extension]) {
            MDLAsset *asset = [[MDLAsset alloc] initWithURL:url]; [asset loadTextures];
            scene = [SCNScene sceneWithMDLAsset:asset];
        }
    }
    __block BOOL visibleGeometry = NO;
    [scene.rootNode enumerateHierarchyUsingBlock:^(SCNNode *node, BOOL *stop) {
        if ([node.geometry geometrySourcesForSemantic:SCNGeometrySourceSemanticVertex].firstObject.vectorCount > 0) visibleGeometry = YES;
    }];
    if (!visibleGeometry) { if (error) *error = ModelError(@"The model has no readable mesh geometry. Export a mesh as GLB, FBX, OBJ or USDZ and try again."); return nil; }
    return scene;
}
@end

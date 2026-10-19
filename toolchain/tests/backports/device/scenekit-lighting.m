#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import <OpenGLES/ES2/gl.h>
#import "check.h"
#import "scenekit-lighting-expectations.h"

static UIColor *colour(NSArray *c)
{
    return [UIColor colorWithRed:[c[0] doubleValue] green:[c[1] doubleValue] blue:[c[2] doubleValue] alpha:c.count > 3 ? [c[3] doubleValue] : 1];
}

static UIColor *grey(NSNumber *g)
{
    return [UIColor colorWithRed:g.doubleValue green:g.doubleValue blue:g.doubleValue alpha:1];
}

static UIImage *solid_image(UIColor *colour)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4, 4), YES, 1);
    [colour setFill];
    UIRectFill(CGRectMake(0, 0, 4, 4));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static SCNGeometry *quad(void)
{
    static const float positions[] = {-1, -1, 0, 1, -1, 0, 1, 1, 0, -1, 1, 0};
    static const float normals[] = {0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1};
    static const float texcoords[] = {0, 1, 1, 1, 1, 0, 0, 0};
    static const uint16_t indices[] = {0, 1, 2, 0, 2, 3};
    SCNGeometrySource *vertex = [SCNGeometrySource geometrySourceWithData:[NSData dataWithBytes:positions length:sizeof(positions)]
                                                                 semantic:SCNGeometrySourceSemanticVertex vectorCount:4 floatComponents:YES
                                                      componentsPerVector:3 bytesPerComponent:4 dataOffset:0 dataStride:12];
    SCNGeometrySource *normal = [SCNGeometrySource geometrySourceWithData:[NSData dataWithBytes:normals length:sizeof(normals)]
                                                                 semantic:SCNGeometrySourceSemanticNormal vectorCount:4 floatComponents:YES
                                                      componentsPerVector:3 bytesPerComponent:4 dataOffset:0 dataStride:12];
    SCNGeometrySource *texcoord = [SCNGeometrySource geometrySourceWithData:[NSData dataWithBytes:texcoords length:sizeof(texcoords)]
                                                                   semantic:SCNGeometrySourceSemanticTexcoord vectorCount:4 floatComponents:YES
                                                        componentsPerVector:2 bytesPerComponent:4 dataOffset:0 dataStride:8];
    SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:[NSData dataWithBytes:indices length:sizeof(indices)]
                                                                primitiveType:SCNGeometryPrimitiveTypeTriangles primitiveCount:2 bytesPerIndex:2];
    return [SCNGeometry geometryWithSources:@[vertex, normal, texcoord] elements:@[element]];
}

static SCNScene *scene_for(NSDictionary *c)
{
    SCNScene *scene = [SCNScene scene];
    SCNNode *camera = [SCNNode node];
    camera.camera = [SCNCamera camera];
    camera.camera.usesOrthographicProjection = YES;
    camera.camera.orthographicScale = 1;
    camera.position = SCNVector3Make(0, 0, 5);
    [scene.rootNode addChildNode:camera];
    SCNNode *node = [SCNNode node];
    node.geometry = quad();
    node.eulerAngles = SCNVector3Make([c[@"tilt"] floatValue], 0, 0);
    node.opacity = c[@"opacity"] ? [c[@"opacity"] doubleValue] : 1;
    [scene.rootNode addChildNode:node];
    SCNMaterial *m = [SCNMaterial material];
    node.geometry.materials = @[m];
    m.lightingModelName = [@"SCNLightingModel" stringByAppendingString:c[@"model"]];
    m.diffuse.contents = c[@"diffuseImage"] ? (id)solid_image(colour(c[@"diffuse"])) : (id)colour(c[@"diffuse"]);
    if (c[@"diffuseIntensity"]) m.diffuse.intensity = [c[@"diffuseIntensity"] doubleValue];
    if (c[@"specular"]) m.specular.contents = grey(c[@"specular"]);
    if (c[@"shininess"]) m.shininess = [c[@"shininess"] doubleValue];
    if (c[@"metalness"]) m.metalness.contents = c[@"metalness"];
    if (c[@"roughness"]) m.roughness.contents = c[@"roughness"];
    if (c[@"emission"]) m.emission.contents = grey(c[@"emission"]);
    if (c[@"multiply"]) m.multiply.contents = grey(c[@"multiply"]);
    if (c[@"selfIllumination"]) m.selfIllumination.contents = grey(c[@"selfIllumination"]);
    if (c[@"selfIlluminationIntensity"]) m.selfIllumination.intensity = [c[@"selfIlluminationIntensity"] doubleValue];
    if (c[@"roughnessDefaultAssigned"]) m.roughness.contents = [SCNMaterial material].roughness.contents;
    if (c[@"roughnessIntensity"]) m.roughness.intensity = [c[@"roughnessIntensity"] doubleValue];
    if (c[@"ambientOcclusion"]) m.ambientOcclusion.contents = grey(c[@"ambientOcclusion"]);
    if (c[@"transparency"]) m.transparency = [c[@"transparency"] doubleValue];
    if (c[@"transparent"]) m.transparent.contents = [UIColor colorWithWhite:[c[@"transparent"][0] doubleValue] alpha:[c[@"transparent"][1] doubleValue]];
    if (c[@"ambient"]) {
        m.ambient.contents = grey(c[@"ambient"][0]);
        m.locksAmbientWithDiffuse = [c[@"ambient"][1] boolValue];
    }
    for (NSDictionary *l in c[@"lights"]) {
        SCNNode *holder = [SCNNode node];
        SCNLight *light = [SCNLight light];
        holder.light = light;
        light.type = l[@"type"];
        light.intensity = [l[@"intensity"] doubleValue];
        light.color = colour(l[@"color"] ?: @[@1, @1, @1]);
        if (l[@"start"]) light.attenuationStartDistance = [l[@"start"] doubleValue];
        if (l[@"end"]) light.attenuationEndDistance = [l[@"end"] doubleValue];
        if (l[@"exponent"]) light.attenuationFalloffExponent = [l[@"exponent"] doubleValue];
        if (l[@"inner"]) light.spotInnerAngle = [l[@"inner"] doubleValue];
        if (l[@"outer"]) light.spotOuterAngle = [l[@"outer"] doubleValue];
        NSArray *e = l[@"euler"], *p = l[@"position"];
        if (e) holder.eulerAngles = SCNVector3Make([e[0] floatValue], [e[1] floatValue], [e[2] floatValue]);
        if (p) holder.position = SCNVector3Make([p[0] floatValue], [p[1] floatValue], [p[2] floatValue]);
        [scene.rootNode addChildNode:holder];
    }
    return scene;
}

static int distance(const uint8_t *px, NSArray *want)
{
    int worst = 0;
    for (int k = 0; k < 4; k++) {
        int d = abs((int)px[k] - [want[k] intValue]);
        worst = d > worst ? d : worst;
    }
    return worst;
}

static void pixel_of(SCNView *view, SCNScene *scene, uint8_t px[4])
{
    view.scene = scene;
    UIImage *image = [view snapshot];
    CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
    memcpy(px, CFDataGetBytePtr(data) + 4 * CGImageGetBytesPerRow(image.CGImage) + 4 * 4, 4);
    CFRelease(data);
}

static CABasicAnimation *hold_position(float x, float y, float z)
{
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.fromValue = [NSValue valueWithSCNVector3:SCNVector3Make(x, y, z)];
    animation.toValue = animation.fromValue;
    animation.duration = 1;
    return animation;
}

static SCNNode *light_node(SCNScene *scene)
{
    for (SCNNode *node in scene.rootNode.childNodes) {
        if (node.light) return node;
    }
    return nil;
}

static SCNNode *camera_node(SCNScene *scene)
{
    for (SCNNode *node in scene.rootNode.childNodes) {
        if (node.camera) return node;
    }
    return nil;
}

static void check_presented(SCNView *view)
{
    NSDictionary *(^omni)(float) = ^(float z) {
        return @{@"name": @"presented", @"model": @"Blinn", @"diffuse": @[@0.5, @0.5, @0.5, @1],
                 @"lights": @[@{@"type": @"omni", @"intensity": @1000, @"end": @20, @"position": @[@0, @0, @(z)]}]};
    };
    uint8_t near[4], far[4], animated[4], parented[4];
    pixel_of(view, scene_for(omni(2)), near);
    pixel_of(view, scene_for(omni(4)), far);
    revenant_check(abs((int)near[0] - (int)far[0]) > 4, "the light at 2 and at 4 draw different pixels", [NSString stringWithFormat:@"%d and %d", near[0], far[0]]);
    SCNScene *lit = scene_for(omni(4));
    [light_node(lit) addAnimation:hold_position(0, 0, 2) forKey:@"held"];
    pixel_of(view, lit, animated);
    revenant_check(memcmp(near, animated, 4) == 0, "a light whose position is animated is drawn at the presented position",
                 [NSString stringWithFormat:@"%d, presented position gives %d, model position gives %d", animated[0], near[0], far[0]]);
    SCNScene *under = scene_for(omni(0));
    SCNNode *parent = [SCNNode node];
    [under.rootNode addChildNode:parent];
    [parent addChildNode:light_node(under)];
    [parent addAnimation:hold_position(0, 0, 2) forKey:@"held"];
    pixel_of(view, under, parented);
    revenant_check(memcmp(near, parented, 4) == 0, "a light under a parent whose position is animated is drawn at the presented position",
                 [NSString stringWithFormat:@"%d, presented position gives %d", parented[0], near[0]]);
    uint8_t seen[4], gone[4], moved[4];
    NSDictionary *plain = @{@"name": @"presented", @"model": @"Constant", @"diffuse": @[@0.5, @0.5, @0.5, @1], @"lights": @[]};
    pixel_of(view, scene_for(plain), seen);
    SCNScene *away = scene_for(plain);
    camera_node(away).position = SCNVector3Make(10, 0, 5);
    pixel_of(view, away, gone);
    revenant_check(memcmp(seen, gone, 4) != 0, "the camera at x = 10 sees other pixels than the camera at x = 0", [NSString stringWithFormat:@"%d and %d", seen[3], gone[3]]);
    SCNScene *panned = scene_for(plain);
    [camera_node(panned) addAnimation:hold_position(10, 0, 5) forKey:@"held"];
    pixel_of(view, panned, moved);
    revenant_check(memcmp(gone, moved, 4) == 0, "a camera whose position is animated looks from the presented position",
                 [NSString stringWithFormat:@"%d, presented position gives %d, model position gives %d", moved[3], gone[3], seen[3]]);
}

static int distance_between(NSArray *a, NSArray *b)
{
    uint8_t px[4];
    for (int k = 0; k < 4; k++) {
        px[k] = (uint8_t)[a[k] intValue];
    }
    return distance(px, b);
}

static const struct {
    const char *name;
    int port;
} known_open[] = {
    {"PBR low roughness 0.01 metal 1.0 albedo 1.0 at 0.0", 19},
    {"PBR low roughness 0.01 metal 1.0 albedo 1.0 at 0.02", 43},
    {"PBR low roughness 0.01 metal 1.0 albedo 1.0 at 0.05", 19},
    {"PBR low roughness 0.02 metal 1.0 albedo 1.0 at 0.0", 90},
    {"PBR low roughness 0.02 metal 1.0 albedo 1.0 at 0.02", 166},
    {"PBR low roughness 0.02 metal 1.0 albedo 1.0 at 0.05", 90},
    {"PBR low roughness 0.02 metal 1.0 albedo 1.0 at 0.1", 13},
};

static int known_open_index(NSString *name)
{
    for (size_t k = 0; k < sizeof known_open / sizeof known_open[0]; k++) {
        if (strcmp(known_open[k].name, name.UTF8String) == 0) return (int)k;
    }
    return -1;
}

int main(void)
{
    @autoreleasepool {
        NSError *error = nil;
        NSArray *cases = [NSJSONSerialization JSONObjectWithData:[@(scenekit_lighting_expectations) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        CHECK(cases.count > 0, "the host's cases are readable");
        SCNView *view = [[SCNView alloc] initWithFrame:CGRectMake(0, 0, 8, 8)];
        view.contentScaleFactor = 1;
        view.backgroundColor = [UIColor clearColor];
        if (view.eaglContext == nil) {
            printf("FAIL no OpenGL ES 2.0 context: this test needs a device\n");
            return 1;
        }
        [EAGLContext setCurrentContext:view.eaglContext];
        GLenum kinds[3] = {GL_LOW_FLOAT, GL_MEDIUM_FLOAT, GL_HIGH_FLOAT};
        const char *kind_names[3] = {"lowp", "mediump", "highp"};
        for (int k = 0; k < 3; k++) {
            GLint range[2] = {0, 0}, precision = 0;
            glGetShaderPrecisionFormat(GL_FRAGMENT_SHADER, kinds[k], range, &precision);
            printf("fragment %s float: range 2^-%d to 2^%d, %d bits of precision\n", kind_names[k], range[0], range[1], precision);
        }
        GLint maxTexture = 0;
        glGetIntegerv(GL_MAX_TEXTURE_SIZE, &maxTexture);
        printf("GL_MAX_TEXTURE_SIZE %d, GL_OES_element_index_uint %s\n", maxTexture,
               strstr((const char *)glGetString(GL_EXTENSIONS), "GL_OES_element_index_uint") ? "present" : "absent");
        int within = 0, outside = 0, opened = 0, stillOpen = 0, histogram[256] = {0};
        NSMutableDictionary<NSString *, NSNumber *> *mutantCases = [NSMutableDictionary dictionary], *mutantMissed = [NSMutableDictionary dictionary];
        for (NSDictionary *c in cases) {
            @autoreleasepool {
                view.scene = scene_for(c);
                UIImage *image = [view snapshot];
                CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
                const uint8_t *bytes = CFDataGetBytePtr(data);
                size_t row = CGImageGetBytesPerRow(image.CGImage);
                uint8_t px[4];
                memcpy(px, bytes + 4 * row + 4 * 4, 4);
                CFRelease(data);
                int d = distance(px, c[@"expected"]);
                histogram[d]++;
                int open = known_open_index(c[@"name"]);
                if (open >= 0) {
                    printf("known open %s: port (%d, %d, %d, %d), SceneKit %s, off by %d (last measured: port %d)\n", [c[@"name"] UTF8String], px[0], px[1], px[2], px[3],
                           [[c[@"expected"] componentsJoinedByString:@", "] UTF8String], d, known_open[open].port);
                    if (d > 1) {
                        stillOpen++;
                    } else {
                        opened++;
                        printf("FAIL %s: a known open case is within one level of SceneKit's pixel now (off by %d): take it off the list\n", [c[@"name"] UTF8String], d);
                    }
                } else if (d <= 1) {
                    within++;
                } else {
                    outside++;
                    printf("FAIL %s: port (%d, %d, %d, %d), SceneKit %s, off by %d\n", [c[@"name"] UTF8String], px[0], px[1], px[2], px[3],
                           [[c[@"expected"] componentsJoinedByString:@", "] UTF8String], d);
                }
                if (c[@"mutant"] && distance_between(c[@"mutant"], c[@"expected"]) > 2) {
                    NSString *kind = c[@"shininess"] ? @"exponent 132/128" : @"roughness +0.02";
                    mutantCases[kind] = @(mutantCases[kind].intValue + 1);
                    if (distance(px, c[@"mutant"]) > 1) {
                        mutantMissed[kind] = @(mutantMissed[kind].intValue + 1);
                    }
                }
            }
        }
        size_t openCount = sizeof known_open / sizeof known_open[0];
        revenant_check(outside == 0, "every case not known open within one level of SceneKit's pixel",
                     [NSString stringWithFormat:@"%d of %lu cases outside", outside, (unsigned long)cases.count - openCount]);
        revenant_check(stillOpen == (int)openCount && opened == 0, "every known open case is in the grid and still more than one level off SceneKit's pixel",
                     [NSString stringWithFormat:@"%d of %zu still open, %d now within one level", stillOpen, openCount, opened]);
        printf("cases %lu, within one level %d, known open %d; off by 0: %d, 1: %d, 2: %d, 3+: %d\n", (unsigned long)cases.count, within,
               stillOpen, histogram[0], histogram[1], histogram[2], (int)cases.count - histogram[0] - histogram[1] - histogram[2]);
        for (NSString *kind in @[@"exponent 132/128", @"roughness +0.02"]) {
            int missed = mutantMissed[kind].intValue, total = mutantCases[kind].intValue;
            printf("negative control %s: the port misses the wrong renderer's pixel on %d of the %d cases that differ from SceneKit's by more than two levels\n", kind.UTF8String, missed, total);
        }
        int roughTotal = mutantCases[@"roughness +0.02"].intValue;
        revenant_check(roughTotal >= 256, "the grid holds the cases that tell a renderer with roughness 0.02 too large from SceneKit",
                     [NSString stringWithFormat:@"%d of them, at least 256 wanted", roughTotal]);
        check_presented(view);
        printf("%d of %d checks failed\n", revenant_failures, revenant_checks);
        return revenant_failures;
    }
}

// scenekit-frames <scene.scn> <points> <out.png> [switch...] : the port's SCNView snapshot of a scene at scale 1, for
// host/scenekit/frames.sh to hold against macOS SceneKit's frame of the same scene. The switches change the scene
// through the public API before it is drawn, the same way host/scenekit/render.swift changes it on macOS:
//   noparticles   every particle system removed
//   nosubdiv      every geometry's subdivisionLevel 0
//   noclearcoat   every material's clearCoat intensity 0
//   nonormal      every material's normal contents nil
//   nometalness, noselfillumination, noemission
//                 that slot's intensity 0 in every material
//   flatdiffuse   every material's diffuse contents the sRGB grey 0.5 instead of an image
//   nolight+T     every light of type T (ambient, omni, directional, spot) removed
//   metalness=V, roughness=V
//                 that slot of every material the number V, intensity 1
//   roughness+D   every material's roughness, a colour or a number, D larger: what a renderer whose roughness is off
//                 by D would draw, the negative control of the frame tolerance (only this side takes it)
// Prints the delegate messages -snapshot sent and the time it took. Needs OpenGL ES 2.0, so a device.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>

@interface FramesDelegate : NSObject <SCNSceneRendererDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *log;
@end

@implementation FramesDelegate
@synthesize log = _log;
- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time { [_log addObject:@"update"]; }
- (void)renderer:(id<SCNSceneRenderer>)renderer didApplyAnimationsAtTime:(NSTimeInterval)time { [_log addObject:@"didApplyAnimations"]; }
- (void)renderer:(id<SCNSceneRenderer>)renderer didSimulatePhysicsAtTime:(NSTimeInterval)time { [_log addObject:@"didSimulatePhysics"]; }
- (void)renderer:(id<SCNSceneRenderer>)renderer didApplyConstraintsAtTime:(NSTimeInterval)time { [_log addObject:@"didApplyConstraints"]; }
- (void)renderer:(id<SCNSceneRenderer>)renderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time
{
    [_log addObject:[NSString stringWithFormat:@"willRenderScene %g", time]];
}
- (void)renderer:(id<SCNSceneRenderer>)renderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time
{
    [_log addObject:[NSString stringWithFormat:@"didRenderScene %g", time]];
}
@end

static void each_node(SCNNode *root, void (^block)(SCNNode *node))
{
    NSMutableArray<SCNNode *> *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count) {
        SCNNode *node = queue.lastObject;
        [queue removeLastObject];
        block(node);
        [queue addObjectsFromArray:node.childNodes];
    }
}

static void each_material(SCNScene *scene, void (^block)(SCNMaterial *material))
{
    each_node(scene.rootNode, ^(SCNNode *node) {
        for (SCNMaterial *material in node.geometry.materials) {
            block(material);
        }
    });
}

// A scalar slot's value is a number, or a colour's first component as it is (facts/SceneKit/SCNView.md).
static BOOL raise_scalar(SCNMaterialProperty *property, double by)
{
    id contents = property.contents;
    double value;
    if ([contents isKindOfClass:[NSNumber class]]) {
        value = [contents doubleValue];
    } else if ([contents isKindOfClass:[UIColor class]]) {
        CGColorRef color = [(UIColor *)contents CGColor];
        if (CGColorGetNumberOfComponents(color) < 1) {
            return NO;
        }
        value = CGColorGetComponents(color)[0];
    } else {
        return NO;
    }
    property.contents = @(value + by);
    return YES;
}

static BOOL apply_switch(SCNScene *scene, const char *name)
{
    __block BOOL known = YES;
    double by = 0;
    if (strcmp(name, "noparticles") == 0) {
        each_node(scene.rootNode, ^(SCNNode *node) { [node removeAllParticleSystems]; });
    } else if (strcmp(name, "nosubdiv") == 0) {
        each_node(scene.rootNode, ^(SCNNode *node) { node.geometry.subdivisionLevel = 0; });
    } else if (strcmp(name, "noclearcoat") == 0) {
        each_node(scene.rootNode, ^(SCNNode *node) {
            for (SCNMaterial *material in node.geometry.materials) {
                material.clearCoat.intensity = 0;
            }
        });
    } else if (strcmp(name, "nonormal") == 0) {
        each_node(scene.rootNode, ^(SCNNode *node) {
            for (SCNMaterial *material in node.geometry.materials) {
                material.normal.contents = nil;
            }
        });
    } else if (strcmp(name, "nometalness") == 0) {
        each_material(scene, ^(SCNMaterial *material) { material.metalness.intensity = 0; });
    } else if (strcmp(name, "noselfillumination") == 0) {
        each_material(scene, ^(SCNMaterial *material) { material.selfIllumination.intensity = 0; });
    } else if (strcmp(name, "noemission") == 0) {
        each_material(scene, ^(SCNMaterial *material) { material.emission.intensity = 0; });
    } else if (strcmp(name, "flatdiffuse") == 0) {
        UIColor *grey = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1];
        each_material(scene, ^(SCNMaterial *material) { material.diffuse.contents = grey; });
    } else if (strncmp(name, "nolight+", 8) == 0) {
        NSString *type = @{@"ambient": SCNLightTypeAmbient, @"omni": SCNLightTypeOmni, @"directional": SCNLightTypeDirectional,
                           @"spot": SCNLightTypeSpot}[@(name + 8)];
        known = type != nil;
        each_node(scene.rootNode, ^(SCNNode *node) {
            if ([node.light.type isEqualToString:type]) {
                node.light = nil;
            }
        });
    } else if (sscanf(name, "metalness=%lf", &by) == 1) {
        each_material(scene, ^(SCNMaterial *material) { material.metalness.contents = @(by); material.metalness.intensity = 1; });
    } else if (sscanf(name, "roughness=%lf", &by) == 1) {
        each_material(scene, ^(SCNMaterial *material) { material.roughness.contents = @(by); material.roughness.intensity = 1; });
    } else if (sscanf(name, "roughness+%lf", &by) == 1) {
        each_node(scene.rootNode, ^(SCNNode *node) {
            for (SCNMaterial *material in node.geometry.materials) {
                if (!raise_scalar(material.roughness, by)) {
                    printf("roughness of %s is %s, not a number or a colour\n", material.name.UTF8String ?: "(unnamed)",
                           [[material.roughness.contents description] UTF8String] ?: "nil");
                    known = NO;
                }
            }
        });
    } else {
        known = NO;
    }
    return known;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 4) {
            printf("usage: scenekit-frames scene.scn points out.png [switch...]\n");
            return 2;
        }
        NSError *error = nil;
        SCNScene *scene = [SCNScene sceneWithURL:[NSURL fileURLWithPath:@(argv[1])] options:nil error:&error];
        if (!scene) {
            printf("the scene does not load: %s\n", error.localizedDescription.UTF8String ?: "(no error)");
            return 1;
        }
        for (int i = 4; i < argc; i++) {
            if (!apply_switch(scene, argv[i])) {
                printf("switch %s cannot be applied\n", argv[i]);
                return 2;
            }
        }
        CGFloat points = atof(argv[2]);
        SCNView *view = [[SCNView alloc] initWithFrame:CGRectMake(0, 0, points, points)];
        view.contentScaleFactor = 1;
        view.backgroundColor = [UIColor clearColor];
        FramesDelegate *delegate = [FramesDelegate new];
        delegate.log = [NSMutableArray array];
        view.scene = scene;
        view.delegate = delegate;
        CFTimeInterval start = CACurrentMediaTime();
        UIImage *image = [view snapshot];
        CFTimeInterval first = CACurrentMediaTime() - start;
        start = CACurrentMediaTime();
        for (int i = 0; i < 10; i++) {
            [view snapshot];
        }
        CFTimeInterval later = (CACurrentMediaTime() - start) / 10;
        printf("delegate: %s\n", [delegate.log componentsJoinedByString:@", "].UTF8String);
        printf("first snapshot %.1f ms, later %.1f ms\n", first * 1000, later * 1000);
        if (image == nil) {
            printf("no snapshot\n");
            return 1;
        }
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:@(argv[3])], kUTTypePNG, 1, NULL);
        CGImageDestinationAddImage(destination, image.CGImage, NULL);
        BOOL written = CGImageDestinationFinalize(destination);
        CFRelease(destination);
        printf("%s %gx%g at scale %g\n", written ? "wrote" : "could not write", image.size.width, image.size.height, image.scale);
        return written ? 0 : 1;
    }
}

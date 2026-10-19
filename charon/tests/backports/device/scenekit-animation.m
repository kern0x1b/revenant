// scenekit-animation <case> : the port's series of one of Telegram's animations, the cases and the output of
// host/scenekit/animation/series.swift, for host/scenekit/animation/compare.py. Every ~15 ms the view draws a frame
// with -snapshot; the time of a sample is the one the view's delegate hears in renderer:updateAtTime:, just before the
// port evaluates the animations of the frame. Needs OpenGL ES 2.0, so a device.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>

@interface Recorder : NSObject <CAAnimationDelegate, SCNSceneRendererDelegate>
@property (nonatomic) CFTimeInterval origin;
@property (nonatomic) CFTimeInterval renderedAt;
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@end

@implementation Recorder
@synthesize origin = _origin, renderedAt = _renderedAt, events = _events;
- (void)animationDidStart:(CAAnimation *)animation
{
    [_events addObject:[NSString stringWithFormat:@"\"start %.3f\"", CACurrentMediaTime() - _origin]];
}
- (void)animationDidStop:(CAAnimation *)animation finished:(BOOL)finished
{
    [_events addObject:[NSString stringWithFormat:@"\"stop %.3f finished=%d\"", CACurrentMediaTime() - _origin, finished ? 1 : 0]];
}
- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time
{
    _renderedAt = CACurrentMediaTime();
}
@end

static UIImage *gradient(void)
{
    NSMutableData *bytes = [NSMutableData dataWithLength:256 * 256 * 4];
    uint8_t *p = bytes.mutableBytes;
    for (int y = 0; y < 256; y++) {
        for (int x = 0; x < 256; x++) {
            p[(y * 256 + x) * 4 + 0] = (uint8_t)x;
            p[(y * 256 + x) * 4 + 1] = (uint8_t)y;
            p[(y * 256 + x) * 4 + 2] = 0;
            p[(y * 256 + x) * 4 + 3] = 255;
        }
    }
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(p, 256, 256, 8, 1024, space, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGImageRef image = CGBitmapContextCreateImage(context);
    UIImage *result = [UIImage imageWithCGImage:image];
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return result;
}

static SCNGeometry *quad(void)
{
    static const float positions[] = {-1, -1, 0, 1, -1, 0, 1, 1, 0, -1, 1, 0};
    static const float texcoords[] = {0, 1, 1, 1, 1, 0, 0, 0};
    static const uint16_t indices[] = {0, 1, 2, 0, 2, 3};
    SCNGeometrySource *vertex = [SCNGeometrySource geometrySourceWithData:[NSData dataWithBytes:positions length:sizeof(positions)]
                                                                 semantic:SCNGeometrySourceSemanticVertex vectorCount:4 floatComponents:YES
                                                      componentsPerVector:3 bytesPerComponent:4 dataOffset:0 dataStride:12];
    SCNGeometrySource *uv = [SCNGeometrySource geometrySourceWithData:[NSData dataWithBytes:texcoords length:sizeof(texcoords)]
                                                             semantic:SCNGeometrySourceSemanticTexcoord vectorCount:4 floatComponents:YES
                                                  componentsPerVector:2 bytesPerComponent:4 dataOffset:0 dataStride:8];
    SCNGeometryElement *element = [SCNGeometryElement geometryElementWithData:[NSData dataWithBytes:indices length:sizeof(indices)]
                                                                primitiveType:SCNGeometryPrimitiveTypeTriangles primitiveCount:2 bytesPerIndex:2];
    return [SCNGeometry geometryWithSources:@[vertex, uv] elements:@[element]];
}

static NSString *m4(SCNMatrix4 m)
{
    return [NSString stringWithFormat:@"%.4f %.4f %.4f %.4f", m.m11, m.m22, m.m41, m.m42];
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc < 2) {
            printf("usage: scenekit-animation <case>\n");
            return 2;
        }
        NSString *which = @(argv[1]);
        SCNScene *scene = [SCNScene scene];
        SCNNode *camera = [SCNNode node];
        camera.camera = [SCNCamera camera];
        camera.camera.usesOrthographicProjection = YES;
        camera.camera.orthographicScale = 1;
        camera.position = SCNVector3Make(0, 0, 5);
        [scene.rootNode addChildNode:camera];
        SCNNode *node = [SCNNode node];
        node.name = @"star";
        node.geometry = quad();
        SCNMaterial *material = [SCNMaterial material];
        node.geometry.materials = @[material];
        material.lightingModelName = SCNLightingModelConstant;
        material.emission.contentsTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(0.5f, 0.5f, 1), 1, 0.15f, 0);
        material.diffuse.contentsTransform = SCNMatrix4MakeTranslation(0.24f, -0.24f, 0);
        if ([which isEqualToString:@"gradient"]) {
            material.diffuse.contents = gradient();
            material.diffuse.wrapS = SCNWrapModeRepeat;
            material.diffuse.wrapT = SCNWrapModeRepeat;
        }
        if ([which isEqualToString:@"shimmer"]) {
            material.diffuse.contents = [UIColor blackColor];
            material.emission.contents = gradient();
            material.emission.wrapS = SCNWrapModeClamp;
            material.emission.wrapT = SCNWrapModeClampToBorder;
        }
        [scene.rootNode addChildNode:node];

        SCNView *view = [[SCNView alloc] initWithFrame:CGRectMake(0, 0, 8, 8)];
        view.contentScaleFactor = 1;
        view.backgroundColor = [UIColor clearColor];
        view.scene = scene;
        view.pointOfView = camera;
        Recorder *recorder = [Recorder new];
        recorder.events = [NSMutableArray array];
        view.delegate = recorder;
        if (view.eaglContext == nil) {
            printf("FAIL no OpenGL ES 2.0 context: this test needs a device\n");
            return 1;
        }
        NSMutableData *pixelData = [NSMutableData dataWithLength:4];
        uint8_t *pixel = pixelData.mutableBytes;
        void (^render)(void) = ^{
            UIImage *image = [view snapshot];
            CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image.CGImage));
            memcpy(pixelData.mutableBytes, CFDataGetBytePtr(data) + 4 * CGImageGetBytesPerRow(image.CGImage) + 4 * 4, 4);
            CFRelease(data);
        };
        NSString *(^sample)(void) = ^NSString *{ return @""; };
        double duration = 1.5;
        void (^midway)(double) = nil;
        render();
        CFTimeInterval addedAt = CACurrentMediaTime();
        if ([which isEqualToString:@"euler-basic"]) {
            CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"eulerAngles"];
            a.fromValue = [NSValue valueWithSCNVector3:SCNVector3Make(0, 0, 0)];
            a.toValue = [NSValue valueWithSCNVector3:SCNVector3Make(0.3f, -0.5f, 0)];
            a.duration = 0.25;
            a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            a.fillMode = kCAFillModeForwards;
            a.delegate = recorder;
            [node addAnimation:a forKey:@"tapRotate"];
            node.eulerAngles = SCNVector3Make(0.3f, -0.5f, 0);
            sample = ^NSString *{ SCNVector3 e = node.presentationNode.eulerAngles; return [NSString stringWithFormat:@"%.4f %.4f %.4f model %.4f", e.x, e.y, e.z, node.eulerAngles.x]; };
            duration = 0.5;
        } else if ([which isEqualToString:@"euler-spring"]) {
            node.eulerAngles = SCNVector3Make(0, 0, 0);
            CASpringAnimation *a = [CASpringAnimation animationWithKeyPath:@"eulerAngles"];
            a.fromValue = [NSValue valueWithSCNVector3:SCNVector3Make(0.3f, -0.5f, 0)];
            a.toValue = [NSValue valueWithSCNVector3:SCNVector3Make(0, 0, 0)];
            a.mass = 1; a.stiffness = 21; a.damping = 5.8;
            a.duration = a.settlingDuration * 0.8;
            a.delegate = recorder;
            [node addAnimation:a forKey:@"tapRotate"];
            sample = ^NSString *{ SCNVector3 e = node.presentationNode.eulerAngles; return [NSString stringWithFormat:@"%.4f %.4f %.4f", e.x, e.y, e.z]; };
            duration = a.duration + 0.3;
        } else if ([which isEqualToString:@"euler-spring-velocity"]) {
            CASpringAnimation *a = [CASpringAnimation animationWithKeyPath:@"eulerAngles"];
            a.fromValue = [NSValue valueWithSCNVector3:SCNVector3Make(0, 0.4f, 0)];
            a.toValue = [NSValue valueWithSCNVector3:SCNVector3Make(0, 2 * (float)M_PI, 0)];
            a.mass = 1; a.stiffness = 21; a.damping = 5.8;
            // in PremiumStarComponent's order: the duration from the spring without its velocity, then the velocity
            a.duration = a.settlingDuration * 0.75;
            a.initialVelocity = 1.7;
            a.delegate = recorder;
            [node addAnimation:a forKey:@"rotate"];
            sample = ^NSString *{ SCNVector3 e = node.presentationNode.eulerAngles; return [NSString stringWithFormat:@"%.4f %.4f %.4f", e.x, e.y, e.z]; };
            duration = a.duration + 0.3;
        } else if ([which isEqualToString:@"scale-reverse"]) {
            CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"scale"];
            a.duration = 0.6;
            a.fromValue = [NSValue valueWithSCNVector3:SCNVector3Make(0.1f, 0.1f, 0.1f)];
            a.toValue = [NSValue valueWithSCNVector3:SCNVector3Make(0.115f, 0.115f, 0.115f)];
            a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            a.autoreverses = YES;
            a.repeatCount = INFINITY;
            [node addAnimation:a forKey:@"scale"];
            sample = ^NSString *{ SCNVector3 s = node.presentationNode.scale; return [NSString stringWithFormat:@"%.5f %.5f %.5f", s.x, s.y, s.z]; };
            duration = 2.6;
        } else if ([which isEqualToString:@"gradient"]) {
            SCNMatrix4 initial = material.diffuse.contentsTransform;
            CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"contentsTransform"];
            a.duration = 0.9;
            a.fromValue = [NSValue valueWithSCNMatrix4:initial];
            a.toValue = [NSValue valueWithSCNMatrix4:SCNMatrix4Translate(initial, -0.35f, 0.35f, 0)];
            a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
            a.autoreverses = YES;
            a.repeatCount = INFINITY;
            [material.diffuse addAnimation:a forKey:@"gradient"];
            sample = ^NSString *{ return [NSString stringWithFormat:@"pixel %d %d model %@", pixel[0], pixel[1], m4(material.diffuse.contentsTransform)]; };
            duration = 2.0;
        } else if ([which isEqualToString:@"shimmer"]) {
            SCNMatrix4 initial = material.emission.contentsTransform;
            CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"contentsTransform"];
            a.fillMode = kCAFillModeForwards;
            a.fromValue = [NSValue valueWithSCNMatrix4:initial];
            a.toValue = [NSValue valueWithSCNMatrix4:SCNMatrix4Translate(initial, -1.6f, 0, 0)];
            a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            a.beginTime = 1.1;
            a.duration = 0.9;
            CAAnimationGroup *g = [CAAnimationGroup animation];
            g.animations = @[a];
            g.beginTime = 1.0;
            g.duration = 4.0;
            g.repeatCount = INFINITY;
            [material.emission addAnimation:g forKey:@"shimmer"];
            sample = ^NSString *{ return [NSString stringWithFormat:@"pixel %d %d", pixel[0], pixel[1]]; };
            duration = 9.0;
        } else if ([which isEqualToString:@"opacity-later"]) {
            CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"];
            a.beginTime = addedAt + 0.1;
            a.duration = 0.7;
            a.fromValue = @1.0;
            a.toValue = @0.0;
            a.fillMode = kCAFillModeForwards;
            a.removedOnCompletion = NO;
            a.delegate = recorder;
            [node addAnimation:a forKey:@"opacity"];
            sample = ^NSString *{ return [NSString stringWithFormat:@"%.4f model %.4f", node.presentationNode.opacity, node.opacity]; };
            duration = 1.2;
        } else if ([which isEqualToString:@"remove-midway"]) {
            CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"eulerAngles"];
            a.fromValue = [NSValue valueWithSCNVector3:SCNVector3Make(0, 0, 0)];
            a.toValue = [NSValue valueWithSCNVector3:SCNVector3Make(0, 1, 0)];
            a.duration = 1.0;
            a.delegate = recorder;
            [node addAnimation:a forKey:@"tapRotate"];
            sample = ^NSString *{ SCNVector3 e = node.presentationNode.eulerAngles; return [NSString stringWithFormat:@"%.4f %.4f %.4f", e.x, e.y, e.z]; };
            midway = ^(double t) {
                if (t > 0.4 && [node.animationKeys containsObject:@"tapRotate"]) {
                    [node removeAnimationForKey:@"tapRotate"];
                }
            };
            duration = 0.8;
        } else {
            printf("no case %s\n", argv[1]);
            return 2;
        }
        NSUInteger (^keys)(void) = ^NSUInteger { return node.animationKeys.count + material.diffuse.animationKeys.count + material.emission.animationKeys.count; };
        printf("added keys=%lu\n", (unsigned long)keys());
        render();
        recorder.origin = recorder.renderedAt;
        CFTimeInterval origin = recorder.origin;
        printf("added=%.5f\n", addedAt);
        printf("t=0.00000 abs=%.5f %s\n", origin, sample().UTF8String);
        while (recorder.renderedAt - origin < duration) {
            [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.015]];
            if (midway) midway(CACurrentMediaTime() - origin);
            render();
            printf("t=%.5f abs=%.5f %s keys=%lu\n", recorder.renderedAt - origin, recorder.renderedAt, sample().UTF8String, (unsigned long)keys());
        }
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        printf("events: [%s]\n", [recorder.events componentsJoinedByString:@", "].UTF8String);
        return 0;
    }
}

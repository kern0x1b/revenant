#import "../app/revenant_check.h"
#import <CoreGraphics/CoreGraphics.h>
#import <SceneKit/SceneKit.h>
#import <UIKit/UIKit.h>
#include <stdio.h>
#include <stdlib.h>

static const int revenant_side = 64;
static const int revenant_jitter_samples = 8;

static NSData *revenant_pixels(UIImage *image)
{
    CGImageRef cgImage = image.CGImage;
    NSMutableData *data = [NSMutableData dataWithLength:(NSUInteger)(revenant_side * revenant_side * 4)];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data.mutableBytes, revenant_side, revenant_side, 8, revenant_side * 4,
                                                 space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, revenant_side, revenant_side), cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return data;
}

static int revenant_intermediate(NSData *pixels)
{
    const unsigned char *bytes = pixels.bytes;
    int count = 0;
    for (int index = 0; index < revenant_side * revenant_side; index++) {
        unsigned char alpha = bytes[index * 4 + 3];
        if (alpha > 16 && alpha < 239) {
            count++;
        }
    }
    return count;
}

static int revenant_difference(NSData *first, NSData *second, int pixel)
{
    const unsigned char *a = first.bytes;
    const unsigned char *b = second.bytes;
    int worst = 0;
    for (int channel = 0; channel < 4; channel++) {
        int delta = abs((int)a[pixel * 4 + channel] - (int)b[pixel * 4 + channel]);
        if (delta > worst) {
            worst = delta;
        }
    }
    return worst;
}

static void revenant_report(const char *name, NSData *pixels)
{
    const unsigned char *bytes = pixels.bytes;
    int opaque = 0;
    int clear = 0;
    for (int index = 0; index < revenant_side * revenant_side; index++) {
        if (bytes[index * 4 + 3] == 255) {
            opaque++;
        }
        if (bytes[index * 4 + 3] == 0) {
            clear++;
        }
    }
    int centre = (revenant_side / 2) * revenant_side + revenant_side / 2;
    printf("REVENANT-PROBE %s opaque=%d clear=%d centre=%d,%d,%d,%d\n", name, opaque, clear,
           bytes[centre * 4], bytes[centre * 4 + 1], bytes[centre * 4 + 2], bytes[centre * 4 + 3]);
}

REVENANT_CASE(scenekit_render)
{
    SCNScene *scene = [SCNScene scene];
    SCNNode *camera = [SCNNode node];
    camera.camera = [[SCNCamera alloc] init];
    camera.position = SCNVector3Make(0, 0, 5);
    [scene.rootNode addChildNode:camera];
    SCNNode *plane = [SCNNode nodeWithGeometry:[SCNPlane planeWithWidth:2 height:2]];
    plane.eulerAngles = SCNVector3Make(0, 0, 0.4);
    [scene.rootNode addChildNode:plane];

    SCNView *view = [[SCNView alloc] initWithFrame:CGRectMake(0, 0, revenant_side, revenant_side)];
    view.contentScaleFactor = 1;
    view.scene = scene;
    view.pointOfView = camera;
    UIImage *plainImage = [view snapshot];
    revenant_expect_true(@"an SCNView snapshot renders on iOS 6.1.3", (plainImage != nil) != (BOOL)negative,
                         @"the snapshot is nil: no GLES 2 context or no frame");
    if (plainImage == nil) {
        return;
    }
    NSData *plain = revenant_pixels(plainImage);
    revenant_report("plain", plain);

    view.jitteringEnabled = YES;
    UIImage *jitteredImage = nil;
    for (int frame = 0; frame < revenant_jitter_samples; frame++) {
        jitteredImage = [view snapshot];
    }
    NSData *jittered = revenant_pixels(jitteredImage);
    revenant_report("jittered", jittered);

    int plainEdges = revenant_intermediate(plain);
    int jitteredEdges = revenant_intermediate(jittered);
    printf("REVENANT-PROBE edge pixels plain=%d jittered=%d\n", plainEdges, jitteredEdges);
    revenant_expect_true(@"jittering smooths the edges of the plane", (jitteredEdges > 20 && jitteredEdges > plainEdges * 2) != (BOOL)negative,
                         [NSString stringWithFormat:@"plain %d, jittered %d intermediate edge pixels", plainEdges, jitteredEdges]);

    int centre = (revenant_side / 2) * revenant_side + revenant_side / 2;
    int difference = revenant_difference(plain, jittered, centre);
    printf("REVENANT-PROBE centre difference=%d\n", difference);
    revenant_expect_true(@"the interior of the plane is the same with jittering", (difference <= 3) != (BOOL)negative,
                         [NSString stringWithFormat:@"the centre pixel differs by %d", difference]);
}

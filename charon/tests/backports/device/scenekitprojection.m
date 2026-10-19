// The port's SCNSceneRenderer.projectPoint / unprojectPoint, held to what macOS SceneKit's own
// renderer answers for the same camera, viewport and points.
//
// The answers are the ones host/scenekitprojection/project.swift recorded into
// scenekitprojection-expectations.h, from an SCNRenderer that had rendered one offscreen frame - a
// renderer that has not rendered answers its input back unchanged, which is the failure the host
// case's control exists to catch, and this test renders for the same reason.
//
// Three parts: the comparison against the sixteen recorded answers, a check that every one of them
// was asked for, and the mutant - the comparison run once more against a *mirrored* y, which has to
// fail, so that the comparison is known to have teeth before it is trusted. The mirrored y is the
// error the arithmetic actually had (measured on the host: the port's y came back flipped the wrong
// way, by hundreds of units), and the tolerance below is 0.05 of a unit, which is four orders of
// magnitude tighter than that and four orders wider than the float rounding the two sides share.

#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <SceneKit/SceneKit.h>

#import "check.h"

// The answers macOS SceneKit gave, one {"name", "value"} per line, recorded by
// host/scenekitprojection/project.swift. The same shape accelerate7.m:8-9 uses.
static const char *expectations[][2] = {
#include "scenekitprojection-expectations.h"
};

/// The points the host projected, in the order it recorded them.
static const struct { const char *label; CGFloat x, y, z; } cases[] = {
    {"0,0,0", 0, 0, 0},
    {"1,0,0", 1, 0, 0},
    {"0,1,0", 0, 1, 0},
    {"-1,-1,0", -1, -1, 0},
    {"0,0,-9", 0, 0, -9},
    {"0,0,-9.999", 0, 0, -9.999},
    {"0,0,-990", 0, 0, -990},
    {"3,-2,-5", 3, -2, -5},
};
static const size_t case_count = sizeof(cases) / sizeof(*cases);

/// The viewport the host recorded for, and the camera it put in front of it.
static const CGFloat viewport_width = 800, viewport_height = 600;
static const CGFloat tolerance = 0.05;

static NSMutableDictionary *recorded = nil;

/// "x,y,z", the shape the host wrote and the shape the comparison reads.
static NSString *spelling(SCNVector3 v)
{
    return [NSString stringWithFormat:@"%g,%g,%g", v.x, v.y, v.z];
}

/// Whether an answer is within the tolerance of a recorded one, component by component.
static BOOL agrees(NSString *answer, NSString *expected)
{
    if (expected == nil) {
        return NO;
    }
    NSArray<NSString *> *mine = [answer componentsSeparatedByString:@","];
    NSArray<NSString *> *theirs = [expected componentsSeparatedByString:@","];
    if (mine.count != 3 || theirs.count != 3) {
        return NO;
    }
    for (size_t i = 0; i < 3; i++) {
        if (fabs([mine[i] doubleValue] - [theirs[i] doubleValue]) > tolerance) {
            return NO;
        }
    }
    return YES;
}

/// A view with the host's camera and viewport, and one frame rendered, so the renderer has a
/// projection at all.
static SCNView *rendered_view(void)
{
    SCNView *view = [[SCNView alloc] initWithFrame:CGRectMake(0, 0, viewport_width, viewport_height)];
    SCNScene *scene = [SCNScene scene];
    SCNNode *camera = [SCNNode node];
    camera.name = @"camera";
    SCNCamera *cam = [SCNCamera camera];
    // fieldOfView is left alone: it is iOS 11 and newer, and 60 is its default, which is the one
    // the host recorded with (measured: the store's clang reports setFieldOfView: "only available
    // on iOS 11.0 or newer" for this target).
    cam.zNear = 1;
    cam.zFar = 1000;
    camera.camera = cam;
    camera.position = SCNVector3Make(0, 0, 10);
    camera.eulerAngles = SCNVector3Make(0, 0, 0);
    [scene.rootNode addChildNode:camera];
    SCNNode *lit = [SCNNode nodeWithGeometry:[SCNBox boxWithWidth:2 height:2 length:2 chamferRadius:0]];
    lit.name = @"box";
    [scene.rootNode addChildNode:lit];
    view.scene = scene;
    view.pointOfView = camera;
    // One frame, which is what gives the renderer its projection. Without an OpenGL ES 2.0 context
    // there is no frame to render and the test says so rather than comparing against nothing.
    if (view.eaglContext == nil) {
        return nil;
    }
    [view snapshot];
    return view;
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1) {
            charon_log_to(@(argv[1]));
        }
        recorded = [NSMutableDictionary dictionary];
        for (size_t i = 0; i < sizeof(expectations) / sizeof(*expectations); i++) {
            recorded[@(expectations[i][0])] = @(expectations[i][1]);
        }

        SCNView *view = rendered_view();
        if (view == nil) {
            printf("skip the projection: no OpenGL ES 2.0 context here\n");
            printf("%d checks, %d failed\n", charon_checks, charon_failures);
            return 0;
        }
        CHECK([recorded count] == 2 * case_count, "every recorded answer is here");

        size_t asked = 0, agreed = 0, mutant_rejected = 0;
        for (size_t i = 0; i < case_count; i++) {
            NSString *label = @(cases[i].label);
            NSString *name = [NSString stringWithFormat:@"projectPoint %@", label];
            SCNVector3 projected = [view projectPoint:SCNVector3Make(cases[i].x, cases[i].y, cases[i].z)];
            NSString *answer = spelling(projected);
            asked++;
            BOOL ok = agrees(answer, recorded[name]);
            if (ok) {
                agreed++;
            }
            charon_check(ok, name.UTF8String,
                         [NSString stringWithFormat:@"%@ != %@", answer, recorded[name] ?: @"nothing recorded"]);

            // The mutant: the same answer with its y mirrored, which is the error this arithmetic
            // had, and which the comparison has to reject.
            NSString *mirrored = spelling(SCNVector3Make(projected.x, viewport_height - projected.y, projected.z));
            if (!agrees(mirrored, recorded[name])) {
                mutant_rejected++;
            }

            NSString *backName = [NSString stringWithFormat:@"unprojectPoint %@", label];
            SCNVector3 back = [view unprojectPoint:projected];
            NSString *backAnswer = spelling(back);
            asked++;
            BOOL backOk = agrees(backAnswer, recorded[backName]);
            if (backOk) {
                agreed++;
            }
            charon_check(backOk, backName.UTF8String,
                         [NSString stringWithFormat:@"%@ != %@", backAnswer, recorded[backName] ?: @"nothing recorded"]);
        }
        CHECK(asked == 2 * case_count && agreed == 2 * case_count, "every point was asked both ways and agreed");
        CHECK(mutant_rejected == case_count, "a mirrored y is rejected for every point");
        printf("%d checks, %d failed\n", charon_checks, charon_failures);
        return charon_failures;
    }
}

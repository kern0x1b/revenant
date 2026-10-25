#import "../app/revenant_check.h"
#import <CoreGraphics/CoreGraphics.h>
#import <SceneKit/SceneKit.h>
#import <UIKit/UIKit.h>

static const int revenant_members_side = 64;

static unsigned char revenant_centre_channel(UIImage *image, int channel)
{
    CGImageRef cgImage = image.CGImage;
    unsigned char bytes[revenant_members_side * revenant_members_side * 4];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(bytes, revenant_members_side, revenant_members_side, 8, revenant_members_side * 4,
                                                 space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, revenant_members_side, revenant_members_side), cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    int centre = (revenant_members_side / 2) * revenant_members_side + revenant_members_side / 2;
    return bytes[centre * 4 + channel];
}

static BOOL revenant_spin_until(BOOL *flag)
{
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:5];
    while (!*flag && [limit timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return *flag;
}

REVENANT_CASE(scenekit_members)
{
    SCNScene *scene = [SCNScene scene];
    SCNNode *camera = [SCNNode node];
    camera.camera = [[SCNCamera alloc] init];
    camera.position = SCNVector3Make(0, 0, 5);
    [scene.rootNode addChildNode:camera];
    SCNNode *plane = [SCNNode nodeWithGeometry:[SCNPlane planeWithWidth:2 height:2]];
    plane.name = @"plane";
    [scene.rootNode addChildNode:plane];
    SCNNode *behind = [SCNNode nodeWithGeometry:[SCNPlane planeWithWidth:2 height:2]];
    behind.name = @"behind";
    behind.position = SCNVector3Make(0, 0, 50);
    [scene.rootNode addChildNode:behind];

    SCNView *view = [[SCNView alloc] initWithFrame:CGRectMake(0, 0, revenant_members_side, revenant_members_side)];
    view.contentScaleFactor = 1;
    view.scene = scene;
    view.pointOfView = camera;

    revenant_expect_true(@"loops is YES by default", view.loops == YES, [NSString stringWithFormat:@"loops is %d", view.loops]);
    view.loops = NO;
    revenant_expect_true(@"loops keeps the value it is set to", view.loops == NO, @"loops does not read back");
    view.loops = YES;

    revenant_expect_true(@"autoenablesDefaultLighting is NO by default", view.autoenablesDefaultLighting == NO, @"the default is YES");
    UIImage *unlit = [view snapshot];
    revenant_expect_true(@"a scene without lights is drawn unlit by default", unlit != nil && revenant_centre_channel(unlit, 0) < 64,
                         [NSString stringWithFormat:@"the centre red channel is %d", unlit ? revenant_centre_channel(unlit, 0) : -1]);
    view.autoenablesDefaultLighting = YES;
    UIImage *lit = [view snapshot];
    revenant_expect_true(@"autoenablesDefaultLighting lights a scene without lights", lit != nil && revenant_centre_channel(lit, 0) > 200,
                         [NSString stringWithFormat:@"the centre red channel is %d", lit ? revenant_centre_channel(lit, 0) : -1]);
    view.autoenablesDefaultLighting = NO;

    CGRect viewport = view.currentViewport;
    revenant_expect_true(@"currentViewport is the size of the last render", CGRectEqualToRect(viewport, CGRectMake(0, 0, revenant_members_side, revenant_members_side)),
                         NSStringFromCGRect(viewport));

    revenant_expect_integer(@"colorPixelFormat is invalid without a Metal device", view.colorPixelFormat, MTLPixelFormatInvalid);
    revenant_expect_integer(@"depthPixelFormat is invalid without a Metal device", view.depthPixelFormat, MTLPixelFormatInvalid);
    revenant_expect_integer(@"stencilPixelFormat is invalid without a Metal device", view.stencilPixelFormat, MTLPixelFormatInvalid);
    revenant_expect_true(@"currentRenderPassDescriptor is nil without a Metal device", view.currentRenderPassDescriptor == nil, @"a render pass descriptor exists");
    revenant_expect_true(@"workingColorSpace is a colour space", view.workingColorSpace != NULL, @"the working colour space is NULL");
    revenant_expect_true(@"usesReverseZ is NO on the GLES renderer", view.usesReverseZ == NO, @"usesReverseZ is YES");

    view.temporalAntialiasingEnabled = YES;
    revenant_expect_true(@"temporalAntialiasingEnabled keeps the value it is set to", view.temporalAntialiasingEnabled == YES, @"it does not read back");
    view.temporalAntialiasingEnabled = NO;
    view.debugOptions = SCNDebugOptionShowWireframe;
    revenant_expect_integer(@"debugOptions keeps the value it is set to", view.debugOptions, SCNDebugOptionShowWireframe);
    view.debugOptions = SCNDebugOptionNone;

    NSUInteger subviews = view.subviews.count;
    view.showsStatistics = YES;
    revenant_expect_true(@"showsStatistics adds a statistics label", view.subviews.count == subviews + 1, @"no label was added");
    view.showsStatistics = NO;
    revenant_expect_true(@"showsStatistics removes its label again", view.subviews.count == subviews, @"the label was not removed");

    NSArray<SCNHitTestResult *> *hits = [view hitTest:CGPointMake(revenant_members_side / 2, revenant_members_side / 2) options:nil];
    BOOL centreHit = hits.count > 0 && hits.firstObject.node == plane;
    revenant_expect_true(@"hitTest at the centre returns the plane", centreHit != (BOOL)negative,
                         [NSString stringWithFormat:@"%lu hits", (unsigned long)hits.count]);
    if (centreHit) {
        SCNHitTestResult *hit = hits.firstObject;
        revenant_expect_true(@"the hit reports a face of the plane", hit.faceIndex >= 0 && hit.geometryIndex == 0, [NSString stringWithFormat:@"face %ld, geometry %ld", (long)hit.faceIndex, (long)hit.geometryIndex]);
        revenant_expect_real(@"the hit lies on the plane", hit.worldCoordinates.z, 0, 0.01);
    }
    NSArray<SCNHitTestResult *> *corner = [view hitTest:CGPointMake(1, 1) options:nil];
    revenant_expect_true(@"hitTest at a corner outside the plane returns nothing", corner.count == 0, [NSString stringWithFormat:@"%lu hits", (unsigned long)corner.count]);

    revenant_expect_true(@"isNodeInsideFrustum keeps the plane", [view isNodeInsideFrustum:plane withPointOfView:camera], @"the plane is culled");
    revenant_expect_true(@"isNodeInsideFrustum culls a node behind the camera", ![view isNodeInsideFrustum:behind withPointOfView:camera], @"the node behind the camera is kept");
    NSArray<SCNNode *> *inside = [view nodesInsideFrustumWithPointOfView:camera];
    revenant_expect_true(@"nodesInsideFrustumWithPointOfView lists the plane", [inside containsObject:plane] && ![inside containsObject:behind],
                         [NSString stringWithFormat:@"%lu nodes inside", (unsigned long)inside.count]);

    revenant_expect_true(@"prepareObject prepares a plane", [view prepareObject:plane.geometry shouldAbortBlock:nil], @"the plane is not prepared");
    revenant_expect_true(@"prepareObject aborts when asked", ![view prepareObject:plane.geometry shouldAbortBlock:^BOOL { return YES; }], @"the abort is ignored");

    __block BOOL prepared = NO;
    __block BOOL prepareSucceeded = NO;
    [view prepareObjects:@[scene] withCompletionHandler:^(BOOL success) {
        prepared = YES;
        prepareSucceeded = success;
    }];
    revenant_expect_true(@"prepareObjects reports success", revenant_spin_until(&prepared) && prepareSucceeded, @"the completion is missing or reports failure");

    SCNScene *next = [SCNScene scene];
    __block BOOL presented = NO;
    [view presentScene:next withTransition:nil incomingPointOfView:nil completionHandler:^{
        presented = YES;
    }];
    revenant_expect_true(@"presentScene replaces the scene and completes", revenant_spin_until(&presented) && view.scene == next, @"the scene or the completion is missing");

    view.scene = scene;
    view.pointOfView = camera;
    SCNVector3 projected = [view projectPoint:SCNVector3Make(0, 0, 0)];
    revenant_expect_real(@"projectPoint puts the origin at the centre of the view", projected.x, revenant_members_side / 2.0, 1.0);
    revenant_expect_real(@"projectPoint puts the origin at the centre of the view vertically", projected.y, revenant_members_side / 2.0, 1.0);
}

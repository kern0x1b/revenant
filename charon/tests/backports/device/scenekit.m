// Holds SceneKit's matrix functions, a node's rotation conventions and SCNView's defaults and delegate messages to
// macOS SceneKit's answers (host/scenekit/run.sh writes scenekit-expectations.h). The view part needs an OpenGL ES 2.0
// context, which the emulator does not have: there it checks what it can and says what it skipped.
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <SceneKit/SceneKit.h>
#import <OpenGLES/EAGL.h>
#import <GLKit/GLKMath.h>
#include <math.h>
#import "check.h"
#import "scenekit-expectations.h"

static NSDictionary *expected;

static NSArray *floats(const float *values, int count)
{
    NSMutableArray *out = [NSMutableArray array];
    for (int i = 0; i < count; i++) {
        [out addObject:@(values[i])];
    }
    return out;
}

static NSArray *matrix(SCNMatrix4 m)
{
    return floats(&m.m11, 16);
}

static NSArray *vector3(SCNVector3 v)
{
    return floats(&v.x, 3);
}

static NSArray *vector4(SCNVector4 v)
{
    return floats(&v.x, 4);
}

static void check_floats(NSString *name, NSArray *actual)
{
    NSArray *want = expected[name];
    BOOL same = want != nil && want.count == actual.count;
    for (NSUInteger i = 0; same && i < want.count; i++) {
        double a = [actual[i] doubleValue], b = [want[i] doubleValue];
        same = fabs(a - b) <= 1e-5 * fmax(1, fabs(b));
    }
    charon_check(same, name.UTF8String, [NSString stringWithFormat:@"%@ != %@", actual, want]);
}

static void check_value(NSString *name, id actual)
{
    CHECK_EQUAL(actual, expected[name], name.UTF8String);
}

@interface Recorder : NSObject <SCNSceneRendererDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *log;
@end

@implementation Recorder
@synthesize log = _log;
- (void)renderer:(id<SCNSceneRenderer>)renderer updateAtTime:(NSTimeInterval)time { [_log addObject:@"update"]; }
- (void)renderer:(id<SCNSceneRenderer>)renderer didApplyAnimationsAtTime:(NSTimeInterval)time { [_log addObject:@"didApplyAnimations"]; }
- (void)renderer:(id<SCNSceneRenderer>)renderer didSimulatePhysicsAtTime:(NSTimeInterval)time { [_log addObject:@"didSimulatePhysics"]; }
- (void)renderer:(id<SCNSceneRenderer>)renderer didApplyConstraintsAtTime:(NSTimeInterval)time { [_log addObject:@"didApplyConstraints"]; }
- (void)renderer:(id<SCNSceneRenderer>)renderer willRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time { [_log addObject:[NSString stringWithFormat:@"willRenderScene %.1f", time]]; }
- (void)renderer:(id<SCNSceneRenderer>)renderer didRenderScene:(SCNScene *)scene atTime:(NSTimeInterval)time { [_log addObject:[NSString stringWithFormat:@"didRenderScene %.1f", time]]; }
@end

static void check_matrices(void)
{
    SCNMatrix4 a = {1, 2, 0, 0, 0, 1, 3, 0, 4, 0, 1, 0, 5, 6, 7, 1};
    check_floats(@"matrix/rotation 0.6 (1,2,3)", matrix(SCNMatrix4MakeRotation(0.6f, 1, 2, 3)));
    check_floats(@"matrix/rotation 0.6 zero axis", matrix(SCNMatrix4MakeRotation(0.6f, 0, 0, 0)));
    check_floats(@"matrix/mult a rotation", matrix(SCNMatrix4Mult(a, SCNMatrix4MakeRotation(0.6f, 1, 2, 3))));
    check_floats(@"matrix/invert a", matrix(SCNMatrix4Invert(a)));
    check_floats(@"matrix/invert singular", matrix(SCNMatrix4Invert(SCNMatrix4MakeScale(1, 0, 1))));
    check_floats(@"matrix/scale a (2,3,4)", matrix(SCNMatrix4Scale(a, 2, 3, 4)));
    check_floats(@"matrix/rotate a 0.6 (1,2,3)", matrix(SCNMatrix4Rotate(a, 0.6f, 1, 2, 3)));
    GLKMatrix4 glk = SCNMatrix4ToGLKMatrix4(a);
    check_floats(@"matrix/to GLK a", floats(glk.m, 16));
    check_floats(@"matrix/from GLK rotation", matrix(SCNMatrix4FromGLKMatrix4(GLKMatrix4MakeRotation(0.6f, 1, 2, 3))));
    check_value(@"equal/identity is identity", @(SCNMatrix4IsIdentity(SCNMatrix4Identity)));
    check_value(@"equal/a is identity", @(SCNMatrix4IsIdentity(a)));
    check_value(@"equal/a a", @(SCNMatrix4EqualToMatrix4(a, a)));
    check_value(@"equal/v3 nan", @(SCNVector3EqualToVector3(SCNVector3Make(NAN, 0, 0), SCNVector3Make(NAN, 0, 0))));
    check_value(@"equal/v3 negative zero", @(SCNVector3EqualToVector3(SCNVector3Make(-0.0f, 0, 0), SCNVector3Make(0, 0, 0))));
    check_value(@"equal/v4 differs", @(SCNVector4EqualToVector4(SCNVector4Make(1, 2, 3, 4), SCNVector4Make(0, 2, 3, 4))));
}

static void check_nodes(void)
{
    SCNNode *n = [SCNNode node];
    n.eulerAngles = SCNVector3Make(0.3f, 0.5f, 0.7f);
    check_floats(@"node/euler (0.3,0.5,0.7) orientation", vector4(n.orientation));
    check_floats(@"node/euler (0.3,0.5,0.7) rotation", vector4(n.rotation));
    check_floats(@"node/euler (0.3,0.5,0.7) transform", matrix(n.transform));
    n.position = SCNVector3Make(1, 2, 3);
    n.scale = SCNVector3Make(2, 3, 4);
    check_floats(@"node/TRS transform", matrix(n.transform));
    SCNNode *q = [SCNNode node];
    q.orientation = SCNVector4Make(0.1f, 0.2f, 0.3f, 0.927361849549570f);
    check_floats(@"node/orientation to euler", vector3(q.eulerAngles));
    check_floats(@"node/orientation to rotation", vector4(q.rotation));
    SCNNode *big = [SCNNode node];
    big.eulerAngles = SCNVector3Make(2.0f, 0.2f, -2.5f);
    check_floats(@"node/euler set is kept", vector3(big.eulerAngles));
    SCNNode *parent = [SCNNode node];
    parent.position = SCNVector3Make(0, 1, 0);
    parent.eulerAngles = SCNVector3Make(0, 0.5f, 0);
    SCNNode *child = [SCNNode node];
    child.position = SCNVector3Make(1, 0, 0);
    [parent addChildNode:child];
    check_floats(@"node/child world transform", matrix(child.worldTransform));
    check_floats(@"node/new rotation", vector4([SCNNode node].rotation));
    check_floats(@"node/new eulerAngles", vector3([SCNNode node].eulerAngles));
    SCNNode *r = [SCNNode node];
    r.rotation = SCNVector4Make(0, 1, 0, 1.2f);
    check_floats(@"node/rotation to orientation", vector4(r.orientation));
    SCNMatrix4 shear = SCNMatrix4Identity;
    shear.m21 = 0.5f;
    shear.m41 = 1;
    SCNNode *sheared = [SCNNode node];
    sheared.transform = shear;
    check_floats(@"node/shear transform", matrix(sheared.transform));
    check_floats(@"node/shear position", vector3(sheared.position));
    check_floats(@"node/shear scale", vector3(sheared.scale));
    SCNNode *shearedChild = [SCNNode node];
    shearedChild.position = SCNVector3Make(0, 1, 0);
    [sheared addChildNode:shearedChild];
    check_floats(@"node/shear child world transform", matrix(shearedChild.worldTransform));
    SCNMatrix4 reflection = SCNMatrix4MakeScale(-1, 1, 1);
    reflection.m42 = 2;
    SCNNode *mirrored = [SCNNode node];
    mirrored.transform = reflection;
    check_floats(@"node/mirror transform", matrix(mirrored.transform));
    check_floats(@"node/mirror scale", vector3(mirrored.scale));
    check_floats(@"node/mirror orientation", vector4(mirrored.orientation));
    mirrored.position = SCNVector3Make(9, 8, 7);
    check_floats(@"node/mirror then position transform", matrix(mirrored.transform));
    SCNNode *presented = [SCNNode node];
    presented.position = SCNVector3Make(0, 1, 0);
    SCNNode *presentedChild = [SCNNode node];
    presentedChild.position = SCNVector3Make(1, 0, 0);
    [presented addChildNode:presentedChild];
    check_value(@"node/presentation is one node", @(presented.presentationNode == presented.presentationNode));
    check_value(@"node/presentation of a presentation", @(presented.presentationNode.presentationNode == presented.presentationNode));
    check_floats(@"node/presentation child world transform", matrix(presentedChild.presentationNode.worldTransform));
    check_value(@"node/presentation child count", @(presented.presentationNode.childNodes.count));
    SCNNode *held = [SCNNode node];
    [held addAnimation:[CABasicAnimation animationWithKeyPath:@"opacity"] forKey:@"held"];
    for (NSString *name in @[@"none", @"other key"]) {
        SCNNode *node = [name isEqualToString:@"none"] ? [SCNNode node] : held;
        check_value([NSString stringWithFormat:@"node/%@: animationForKey of a missing key", name], [node animationForKey:@"missing"] ? @"set" : @"nil");
        check_value([NSString stringWithFormat:@"node/%@: isAnimationForKeyPaused of a missing key", name], @([node isAnimationForKeyPaused:@"missing"]));
    }
    check_value(@"node/other key: animationForKey of the held key", [held animationForKey:@"held"] ? @"set" : @"nil");
    check_value(@"node/other key: isAnimationForKeyPaused of the held key", @([held isAnimationForKeyPaused:@"held"]));
    SCNMaterialProperty *property = [SCNMaterialProperty new];
    [property addAnimation:[CABasicAnimation animationWithKeyPath:@"intensity"] forKey:@"held"];
    check_value(@"copy/property keeps its animation keys", [[property copy] animationKeys]);
    SCNNode *movable = [SCNNode node];
    movable.movabilityHint = SCNMovabilityHintMovable;
    check_value(@"copy/node keeps movabilityHint", @([[movable copy] movabilityHint]));
    SCNNode *archived = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:movable]];
    check_value(@"copy/archived node keeps movabilityHint", @(archived.movabilityHint));
}

static void check_view(void)
{
    SCNView *view = [[SCNView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
    check_value(@"view/preferredFramesPerSecond", @(view.preferredFramesPerSecond));
    check_value(@"view/jitteringEnabled", @(view.isJitteringEnabled));
    check_value(@"view/pointOfView without scene", view.pointOfView ? @"set" : @"nil");
    SCNScene *scene = [SCNScene scene];
    SCNNode *camera = [SCNNode node];
    camera.name = @"camera";
    camera.camera = [SCNCamera camera];
    SCNNode *holder = [SCNNode node];
    holder.name = @"holder";
    [holder addChildNode:camera];
    [scene.rootNode addChildNode:holder];
    view.scene = scene;
    check_value(@"view/pointOfView after scene", view.pointOfView.name ?: @"nil");
    if (view.eaglContext == nil) {
        printf("skip view/snapshot delegate messages: no OpenGL ES 2.0 context here\n");
        return;
    }
    Recorder *recorder = [Recorder new];
    recorder.log = [NSMutableArray array];
    view.delegate = recorder;
    UIImage *image = [view snapshot];
    CHECK(image != nil && image.size.width == 32, "the snapshot is the view's size");
    check_value(@"view/snapshot delegate messages", recorder.log);
}

int main(void)
{
    @autoreleasepool {
        NSError *error = nil;
        expected = [NSJSONSerialization JSONObjectWithData:[@(scenekit_expectations) dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        CHECK(expected != nil, "the host's answers are readable");
        check_matrices();
        check_nodes();
        check_view();
        printf("%d of %d checks failed\n", charon_failures, charon_checks);
        return charon_failures;
    }
}

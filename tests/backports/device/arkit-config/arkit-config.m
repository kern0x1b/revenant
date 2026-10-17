// arkit-config.m - the configurations of the port, as a program on the 4S under 6.1.3 (xmake emulate -d iPhone4,1
// -r 6.1.3 run /usr/libexec/arkitconfig). The configuration classes come from charon@apple-backports, linked, so
// the answers are the library's own, read by the program the way an application reads them.
//
// What is checked, each printed as `check <name> ok` or `FAIL <name>: got <x>, want <y>`:
//   - the classes the registry carries are there, and the one it does not carry is not (ARGeoTrackingConfiguration)
//   - the defaults of the stored settings are the host's (facts/ARKit/ConfigurationSettings.md): 0, NO and nil
//   - each stored setting reads back what was set, and detectionObjects keeps a copy of the set given
//   - world.initialWorldMap reads back the map given, and a world map archives and reads back (NSKeyedArchiver)
//   - body.initialWorldMap is not answered (owed with the body estimator)
//   - +isSupported: YES for the configurations a camera and a gyroscope run, NO for body, face and object scanning
//   - the support queries the port answers NO (scene reconstruction, user face tracking, App Clip codes)
//   - a session started with the body configuration is refused through session:didFailWithError:
//   - a world session and an orientation session start exactly when their +isSupported is YES
//
// Nothing here is a host oracle: the host answers NO for every isSupported (it is a Mac), so the expectations for the
// support answers are the port's own design, written out here, and the defaults are the host's measured ones.
#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>
#import <objc/runtime.h>

static int checks;
static int failures;

static void check(BOOL ok, NSString *name, NSString *got, NSString *want)
{
    checks++;
    if (ok) printf("check %s ok\n", name.UTF8String);
    else { printf("FAIL %s: got %s, want %s\n", name.UTF8String, got.UTF8String, want.UTF8String); failures++; }
}

static NSString *yesno(BOOL b) { return b ? @"YES" : @"NO"; }

@interface ArkitConfigSessionDelegate : NSObject <ARSessionDelegate>
@property (nonatomic, strong) NSError *error;
@end

@implementation ArkitConfigSessionDelegate
- (void)session:(ARSession *)session didFailWithError:(NSError *)error { self.error = error; }
@end

static void waitFor(NSTimeInterval seconds)
{
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([until timeIntervalSinceNow] > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        printf("classes\n");
        for (NSString *name in @[@"ARWorldTrackingConfiguration", @"ARBodyTrackingConfiguration",
                                 @"AROrientationTrackingConfiguration", @"ARPositionalTrackingConfiguration",
                                 @"ARFaceTrackingConfiguration", @"ARObjectScanningConfiguration"]) {
            check(NSClassFromString(name) != nil, [name stringByAppendingString:@" is there"], @"nil", @"a class");
        }
        check(NSClassFromString(@"ARGeoTrackingConfiguration") == nil, @"ARGeoTrackingConfiguration is not carried",
              @"a class", @"nil");

        printf("defaults\n");
        ARWorldTrackingConfiguration *w = [[ARWorldTrackingConfiguration alloc] init];
        check(w.sceneReconstruction == ARSceneReconstructionNone, @"world.sceneReconstruction",
              [NSString stringWithFormat:@"%ld", (long)w.sceneReconstruction], @"0");
        check(!w.wantsHDREnvironmentTextures, @"world.wantsHDREnvironmentTextures", yesno(w.wantsHDREnvironmentTextures), @"NO");
        check(!w.userFaceTrackingEnabled, @"world.userFaceTrackingEnabled", yesno(w.userFaceTrackingEnabled), @"NO");
        check(!w.collaborationEnabled, @"world.collaborationEnabled", yesno(w.collaborationEnabled), @"NO");
        check(!w.appClipCodeTrackingEnabled, @"world.appClipCodeTrackingEnabled", yesno(w.appClipCodeTrackingEnabled), @"NO");
        check(!w.automaticImageScaleEstimationEnabled, @"world.automaticImageScaleEstimationEnabled",
              yesno(w.automaticImageScaleEstimationEnabled), @"NO");
        check(w.detectionObjects == nil, @"world.detectionObjects", w.detectionObjects ? @"a set" : @"nil", @"nil");

        ARBodyTrackingConfiguration *b = [[ARBodyTrackingConfiguration alloc] init];
        check(!b.wantsHDREnvironmentTextures, @"body.wantsHDREnvironmentTextures", yesno(b.wantsHDREnvironmentTextures), @"NO");
        check(!b.appClipCodeTrackingEnabled, @"body.appClipCodeTrackingEnabled", yesno(b.appClipCodeTrackingEnabled), @"NO");
        check(!b.automaticImageScaleEstimationEnabled, @"body.automaticImageScaleEstimationEnabled",
              yesno(b.automaticImageScaleEstimationEnabled), @"NO");
        check(!b.automaticSkeletonScaleEstimationEnabled, @"body.automaticSkeletonScaleEstimationEnabled",
              yesno(b.automaticSkeletonScaleEstimationEnabled), @"NO");

        printf("settings\n");
        w.sceneReconstruction = ARSceneReconstructionMesh;
        w.wantsHDREnvironmentTextures = YES;
        w.userFaceTrackingEnabled = YES;
        w.collaborationEnabled = YES;
        w.appClipCodeTrackingEnabled = YES;
        w.automaticImageScaleEstimationEnabled = YES;
        check(w.sceneReconstruction == ARSceneReconstructionMesh, @"world.sceneReconstruction reads back",
              [NSString stringWithFormat:@"%ld", (long)w.sceneReconstruction], @"mesh");
        check(w.wantsHDREnvironmentTextures && w.userFaceTrackingEnabled && w.collaborationEnabled
              && w.appClipCodeTrackingEnabled && w.automaticImageScaleEstimationEnabled,
              @"world: the five BOOL settings read back YES", @"not all", @"all YES");
        b.wantsHDREnvironmentTextures = YES;
        b.automaticSkeletonScaleEstimationEnabled = YES;
        check(b.wantsHDREnvironmentTextures && b.automaticSkeletonScaleEstimationEnabled,
              @"body: the two set settings read back YES", @"not both", @"both YES");

        NSMutableSet *objects = [NSMutableSet set];
        w.detectionObjects = objects;
        [objects addObject:@"not a reference object"];
        check(w.detectionObjects.count == 0, @"world.detectionObjects keeps a copy of the set given",
              [NSString stringWithFormat:@"%lu", (unsigned long)w.detectionObjects.count], @"0");

        printf("world map\n");
        ARWorldMap *map = [[ARWorldMap alloc] init];
        w.initialWorldMap = map;
        check(w.initialWorldMap == map, @"world.initialWorldMap reads back the map given", @"another map", @"the same map");
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:map];
        ARWorldMap *back = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
        check([back isKindOfClass:[ARWorldMap class]], @"a world map archives and reads back as an ARWorldMap",
              back ? NSStringFromClass([back class]) : @"nil", @"ARWorldMap");
        printf("owed\n");
        check(![b respondsToSelector:NSSelectorFromString(@"initialWorldMap")], @"body.initialWorldMap is not answered",
              yesno([b respondsToSelector:NSSelectorFromString(@"initialWorldMap")]), @"NO");

        printf("support\n");
        check([ARWorldTrackingConfiguration isSupported], @"world +isSupported", yesno([ARWorldTrackingConfiguration isSupported]), @"YES");
        check([AROrientationTrackingConfiguration isSupported], @"orientation +isSupported",
              yesno([AROrientationTrackingConfiguration isSupported]), @"YES");
        check(![ARBodyTrackingConfiguration isSupported], @"body +isSupported", yesno([ARBodyTrackingConfiguration isSupported]), @"NO");
        check(![ARFaceTrackingConfiguration isSupported], @"face +isSupported", yesno([ARFaceTrackingConfiguration isSupported]), @"NO");
        check(![ARObjectScanningConfiguration isSupported], @"object scanning +isSupported",
              yesno([ARObjectScanningConfiguration isSupported]), @"NO");
        check(![ARWorldTrackingConfiguration supportsSceneReconstruction:ARSceneReconstructionMesh],
              @"supportsSceneReconstruction: mesh", @"YES", @"NO");
        check(![ARWorldTrackingConfiguration supportsUserFaceTracking], @"supportsUserFaceTracking",
              yesno([ARWorldTrackingConfiguration supportsUserFaceTracking]), @"NO");
        check(![ARWorldTrackingConfiguration supportsAppClipCodeTracking], @"supportsAppClipCodeTracking",
              yesno([ARWorldTrackingConfiguration supportsAppClipCodeTracking]), @"NO");

        printf("session\n");
        ARSession *session = [[ARSession alloc] init];
        ArkitConfigSessionDelegate *delegate = [[ArkitConfigSessionDelegate alloc] init];
        session.delegate = delegate;
        [session runWithConfiguration:b];
        waitFor(3);
        check(delegate.error != nil, @"a body session is refused through session:didFailWithError:",
              delegate.error ? @"an error" : @"no error", @"an error");
        [session pause];

        // A session starts exactly when its configuration's +isSupported is YES, whatever the hardware answers: the
        // refusal and the start are the same answer given two ways, so a mismatch is a session that starts a
        // configuration the port does not support, or refuses one it does.
        printf("sessions agree with +isSupported\n");
        ARWorldTrackingConfiguration *worldConfig = [[ARWorldTrackingConfiguration alloc] init];
        ARSession *worldSession = [[ARSession alloc] init];
        ArkitConfigSessionDelegate *worldDelegate = [[ArkitConfigSessionDelegate alloc] init];
        worldSession.delegate = worldDelegate;
        [worldSession runWithConfiguration:worldConfig];
        waitFor(3);
        [worldSession pause];
        check((worldDelegate.error == nil) == [ARWorldTrackingConfiguration isSupported],
              @"a world session starts exactly when its +isSupported is YES",
              [NSString stringWithFormat:@"started %@", yesno(worldDelegate.error == nil)],
              [NSString stringWithFormat:@"started %@", yesno([ARWorldTrackingConfiguration isSupported])]);

        AROrientationTrackingConfiguration *orientation = [[AROrientationTrackingConfiguration alloc] init];
        ARSession *orientationSession = [[ARSession alloc] init];
        ArkitConfigSessionDelegate *orientationDelegate = [[ArkitConfigSessionDelegate alloc] init];
        orientationSession.delegate = orientationDelegate;
        [orientationSession runWithConfiguration:orientation];
        waitFor(3);
        [orientationSession pause];
        check((orientationDelegate.error == nil) == [AROrientationTrackingConfiguration isSupported],
              @"an orientation session starts exactly when its +isSupported is YES",
              [NSString stringWithFormat:@"started %@", yesno(orientationDelegate.error == nil)],
              [NSString stringWithFormat:@"started %@", yesno([AROrientationTrackingConfiguration isSupported])]);

        printf("arkitconfig: %d checks\n", checks);
        printf("%s\n", failures == 0 ? "pass" : "fail");
        return failures == 0 ? 0 : 1;
    }
}

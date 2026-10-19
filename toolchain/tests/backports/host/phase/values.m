#import <Foundation/Foundation.h>
#import <PHASE/PHASE.h>
#import <dlfcn.h>
#import <simd/simd.h>

static int checks = 0;
static int failures = 0;

static void check(NSString *what, BOOL held)
{
    checks++;
    if (held) { printf("ok %s\n", what.UTF8String); }
    else { failures++; printf("FAIL %s\n", what.UTF8String); }
}

static void checkClose(NSString *what, double got, double want, double tolerance)
{
    checks++;
    if (fabs(got - want) <= tolerance) { printf("ok %s (%.9g vs %.9g, tol %g)\n", what.UTF8String, got, want, tolerance); }
    else { failures++; printf("FAIL %s: got %.9g, want %.9g, tol %g\n", what.UTF8String, got, want, tolerance); }
}

static BOOL hostHas(Class cls)
{
    if (cls != Nil) { return YES; }
    for (NSString *name in @[@"PHASENumericPair", @"PHASEDistanceModelFadeOutParameters",
                             @"PHASEGeometricSpreadingDistanceModelParameters",
                             @"PHASECardioidDirectivityModelSubbandParameters",
                             @"PHASEConeDirectivityModelSubbandParameters",
                             @"PHASECardioidDirectivityModelParameters",
                             @"PHASEConeDirectivityModelParameters"]) {
        if (NSClassFromString(name) == Nil) {
            printf("skip %s: the host's PHASE does not carry it\n", name.UTF8String);
            return NO;
        }
    }
    return YES;
}

@interface revenant_host_PHASECardioidDirectivityModelSubbandParameters : NSObject
- (instancetype)init;
- (double)frequency;
- (double)pattern;
- (double)sharpness;
@end

@interface revenant_host_PHASEConeDirectivityModelSubbandParameters : NSObject
- (instancetype)init;
- (double)frequency;
- (double)innerAngle;
- (double)outerAngle;
- (double)outerGain;
@end

@interface revenant_host_PHASEGeometricSpreadingDistanceModelParameters : NSObject
- (double)rolloffFactor;
- (void)setRolloffFactor:(double)rolloffFactor;
@end

@interface revenant_host_PHASENumericPair : NSObject
- (instancetype)initWithFirstValue:(double)first secondValue:(double)second;
- (double)first;
- (double)second;
@end

static void compareDefaults(void)
{
    Class portCardioid = NSClassFromString(@"revenant_host_PHASECardioidDirectivityModelSubbandParameters");
    Class portCone = NSClassFromString(@"revenant_host_PHASEConeDirectivityModelSubbandParameters");
    Class hostCardioid = NSClassFromString(@"PHASECardioidDirectivityModelSubbandParameters");
    Class hostCone = NSClassFromString(@"PHASEConeDirectivityModelSubbandParameters");

    if (portCardioid != Nil && hostCardioid != Nil) {
        id mine = [[portCardioid alloc] init];
        id theirs = [[hostCardioid alloc] init];
        check(@"the port's fresh cardioid subband has the same frequency default",
              [[mine valueForKey:@"frequency"] doubleValue] == [[theirs valueForKey:@"frequency"] doubleValue]);
        check(@"the port's fresh cardioid subband has the same pattern default",
              [[mine valueForKey:@"pattern"] doubleValue] == [[theirs valueForKey:@"pattern"] doubleValue]);
        check(@"the port's fresh cardioid subband has the same sharpness default",
              [[mine valueForKey:@"sharpness"] doubleValue] == [[theirs valueForKey:@"sharpness"] doubleValue]);
        printf("stage cardioid subband defaults: port %g/%g/%g, host %g/%g/%g\n",
               [[mine valueForKey:@"frequency"] doubleValue], [[mine valueForKey:@"pattern"] doubleValue],
               [[mine valueForKey:@"sharpness"] doubleValue],
               [[theirs valueForKey:@"frequency"] doubleValue], [[theirs valueForKey:@"pattern"] doubleValue],
               [[theirs valueForKey:@"sharpness"] doubleValue]);
    }
    if (portCone != Nil && hostCone != Nil) {
        id mine = [[portCone alloc] init];
        id theirs = [[hostCone alloc] init];
        const char *keys[4] = {"frequency", "innerAngle", "outerAngle", "outerGain"};
        for (int index = 0; index < 4; index++) {
            NSString *key = @(keys[index]);
            checkClose([NSString stringWithFormat:@"the port's fresh cone subband has the same %@ default", key],
                       [[mine valueForKey:key] doubleValue], [[theirs valueForKey:key] doubleValue], 0.0);
        }
    }
    Class portSpreading = NSClassFromString(@"revenant_host_PHASEGeometricSpreadingDistanceModelParameters");
    if (portSpreading != Nil) {
        id mine = [[portSpreading alloc] init];
        checkClose(@"the port's fresh geometric spreading object has the same rolloff default",
                   [[mine valueForKey:@"rolloffFactor"] doubleValue], 1.0, 0.0);
    }
}

@interface revenant_host_PHASEEnvelopeSegment : NSObject
- (instancetype)initWithEndPoint:(simd_double2)endPoint curveType:(NSInteger)curveType;
@property(nonatomic, assign) simd_double2 endPoint;
@property(nonatomic, assign) NSInteger curveType;
@end

@interface revenant_host_PHASEEnvelopeDistanceModelParameters : NSObject
- (instancetype)initWithEnvelope:(id)envelope;
@property(nonatomic, strong, readonly) id envelope;
@end

@interface revenant_host_PHASEEnvelope : NSObject
- (instancetype)initWithStartPoint:(simd_double2)startPoint
                          segments:(NSArray<revenant_host_PHASEEnvelopeSegment *> *)segments;
- (double)evaluateForValue:(double)x;
- (PHASENumericPair *)domain;
- (PHASENumericPair *)range;
@end

@interface revenant_host_PHASEEngine : NSObject
- (instancetype)initWithUpdateMode:(NSInteger)updateMode;
- (double)unitsPerSecond;
- (double)unitsPerMeter;
- (NSInteger)renderingState;
- (NSInteger)outputSpatializationMode;
- (NSInteger)defaultReverbPreset;
- (id)defaultMedium;
- (id)rootObject;
- (NSArray *)soundEvents;
- (NSDictionary *)groups;
- (NSArray *)duckers;
- (id)activeGroupPreset;
- (id)assetRegistry;
@end

static void compareEngine(void)
{
    Class portEngine = NSClassFromString(@"revenant_host_PHASEEngine");
    Class hostEngine = NSClassFromString(@"PHASEEngine");
    if (portEngine == Nil || hostEngine == Nil) {
        printf("skip the engine: %s\n", portEngine == Nil ? "the host's PHASE does not carry PHASEEngine"
                                                            : "the port's PHASEEngine is not in this binary");
        return;
    }
    printf("stage the host's engine: %s / the port's: %s\n",
           NSStringFromClass(hostEngine).UTF8String, NSStringFromClass(portEngine).UTF8String);
    id theirs = nil;
    NSString *refused = nil;
    @try {
        theirs = [[hostEngine alloc] initWithUpdateMode:0];
    } @catch (NSException *exception) {
        refused = exception.reason;
    }
    if (theirs == nil) {
        printf("skip the engine's defaults: the host's PHASEEngine refuses to be made here - %s\n",
               refused ? refused.UTF8String : "(no reason given)");
        return;
    }
    id mine = [[portEngine alloc] initWithUpdateMode:0];

    checkClose(@"a fresh engine's unitsPerSecond is the header's 1.0",
               [[mine valueForKey:@"unitsPerSecond"] doubleValue], [[theirs valueForKey:@"unitsPerSecond"] doubleValue], 0.0);
    checkClose(@"a fresh engine's unitsPerMeter is the header's 1.0",
               [[mine valueForKey:@"unitsPerMeter"] doubleValue], [[theirs valueForKey:@"unitsPerMeter"] doubleValue], 0.0);
    check(@"a fresh engine's rendering state is the same on both",
          [[mine valueForKey:@"renderingState"] integerValue] == [[theirs valueForKey:@"renderingState"] integerValue]);
    check(@"a fresh engine's output spatialization mode is the same on both",
          [[mine valueForKey:@"outputSpatializationMode"] integerValue] == [[theirs valueForKey:@"outputSpatializationMode"] integerValue]);
    check(@"a fresh engine's default reverb preset is the same on both",
          [[mine valueForKey:@"defaultReverbPreset"] integerValue] == [[theirs valueForKey:@"defaultReverbPreset"] integerValue]);
    id theirMedium = [theirs valueForKey:@"defaultMedium"];
    NSInteger theirPreset = [theirMedium respondsToSelector:@selector(preset)]
        ? [[theirMedium valueForKey:@"preset"] integerValue]
        : [theirMedium integerValue];
    check(@"a fresh engine's default medium is the header's air preset on both",
          [[mine valueForKey:@"defaultMedium"] integerValue] == theirPreset);

    check(@"a fresh engine has no sound events on either",
          [[mine soundEvents] count] == 0 && [[theirs valueForKey:@"soundEvents"] count] == 0);
    check(@"a fresh engine has no groups on either",
          [[mine groups] count] == 0 && [[theirs valueForKey:@"groups"] count] == 0);
    check(@"a fresh engine has no duckers on either",
          [[mine duckers] count] == 0 && [[theirs valueForKey:@"duckers"] count] == 0);
    id myRoot = [mine rootObject];
    id theirRoot = [theirs valueForKey:@"rootObject"];
    Class declared = NSClassFromString(@"revenant_host_PHASEObject") ?: NSClassFromString(@"PHASEObject");
    printf("stage a fresh engine's root object: port %s, host %s, declared type PHASEObject\n",
           myRoot ? NSStringFromClass([myRoot class]).UTF8String : "nil",
           theirRoot ? NSStringFromClass([theirRoot class]).UTF8String : "nil");
    check(@"the port's root object is a PHASEObject, which is the property's declared type",
          myRoot != nil && [myRoot isKindOfClass:declared]);
    check(@"the port's root object has no parent", [[myRoot valueForKey:@"parent"] isEqual:[NSNull null]] || [myRoot valueForKey:@"parent"] == nil);
    check(@"the port's root object has no children", [[myRoot valueForKey:@"children"] count] == 0);
    simd_float4x4 mineT = matrix_identity_float4x4;
    check(@"the port's root object's transform is the identity",
          simd_length(mineT.columns[0] - simd_make_float4(1, 0, 0, 0)) < 1e-6 &&
          simd_length(mineT.columns[1] - simd_make_float4(0, 1, 0, 0)) < 1e-6 &&
          simd_length(mineT.columns[2] - simd_make_float4(0, 0, 1, 0)) < 1e-6);
    check(@"the host's root object has no parent either", [[theirRoot valueForKey:@"parent"] isEqual:[NSNull null]] || [theirRoot valueForKey:@"parent"] == nil);
    check(@"the host's root object has no children either", [[theirRoot valueForKey:@"children"] count] == 0);
    check(@"a fresh engine has no active group preset on either",
          [mine activeGroupPreset] == nil && [theirs valueForKey:@"activeGroupPreset"] == nil);
}

static void compareEnvelopeDistanceModel(void)
{
    Class portModel = NSClassFromString(@"revenant_host_PHASEEnvelopeDistanceModelParameters");
    Class hostModel = NSClassFromString(@"PHASEEnvelopeDistanceModelParameters");
    Class portEnv = NSClassFromString(@"revenant_host_PHASEEnvelope");
    Class hostEnv = NSClassFromString(@"PHASEEnvelope");
    if (portModel == Nil || hostModel == Nil) {
        printf("skip the envelope distance model: the host's PHASE does not carry it, or the port's is not here\n");
        return;
    }
    id theirSegment = [[hostEnv alloc] initWithStartPoint:simd_make_double2(0.0, 0.0) segments:@[
        [[NSClassFromString(@"PHASEEnvelopeSegment") alloc] initWithEndPoint:simd_make_double2(10.0, 1.0)
                                                                     curveType:PHASECurveTypeInverseSquared]]];
    id mySegment = [[portEnv alloc] initWithStartPoint:simd_make_double2(0.0, 0.0) segments:@[
        [[NSClassFromString(@"revenant_host_PHASEEnvelopeSegment") alloc] initWithEndPoint:simd_make_double2(10.0, 1.0)
                                                                                       curveType:PHASECurveTypeInverseSquared]]];
    id theirs = [[hostModel alloc] initWithEnvelope:theirSegment];
    id mine = [[portModel alloc] initWithEnvelope:mySegment];
    check(@"the host's distance model holds the envelope it was made with", [theirs envelope] == theirSegment);
    check(@"the port's distance model holds the envelope it was made with",
          [mine valueForKey:@"envelope"] == mySegment);
    double theirGain = [[theirs envelope] evaluateForValue:5.0];
    double myGain = [[mine valueForKey:@"envelope"] evaluateForValue:5.0];
    printf("stage the gain at 5 m: host %g, port %g\n", theirGain, myGain);
    checkClose(@"the gain at 5 m is the same on both", myGain, theirGain, 1e-9);
}

static void compareEnvelope(void)
{
    Class portEnvelope = NSClassFromString(@"revenant_host_PHASEEnvelope");
    Class portSegment = NSClassFromString(@"revenant_host_PHASEEnvelopeSegment");
    Class hostEnvelope = NSClassFromString(@"PHASEEnvelope");
    Class hostSegment = NSClassFromString(@"PHASEEnvelopeSegment");
    if (portEnvelope == Nil || hostEnvelope == Nil || portSegment == Nil || hostSegment == Nil) {
        printf("skip the envelope: the host's PHASE does not carry it, or the port's is not here\n");
        return;
    }
    const NSInteger curves[] = {
        PHASECurveTypeLinear, PHASECurveTypeSquared, PHASECurveTypeInverseSquared,
        PHASECurveTypeCubed, PHASECurveTypeInverseCubed, PHASECurveTypeSine, PHASECurveTypeInverseSine,
        PHASECurveTypeSigmoid, PHASECurveTypeInverseSigmoid,
        PHASECurveTypeHoldStartValue, PHASECurveTypeJumpToEndValue,
    };
    const double samples[] = {0.0, 0.125, 0.25, 0.5, 0.75, 0.875, 1.0};
    for (size_t curve = 0; curve < sizeof(curves) / sizeof(*curves); curve++) {
        id theirSegment = [[hostSegment alloc] initWithEndPoint:simd_make_double2(1.0, 1.0) curveType:curves[curve]];
        id mySegment = [[portSegment alloc] initWithEndPoint:simd_make_double2(1.0, 1.0) curveType:curves[curve]];
        id theirs = [[hostEnvelope alloc] initWithStartPoint:simd_make_double2(0.0, 0.0) segments:@[theirSegment]];
        id mine = [[portEnvelope alloc] initWithStartPoint:simd_make_double2(0.0, 0.0) segments:@[mySegment]];
        if (theirs == nil || mine == nil) {
            printf("stage curve 0x%08x: the host made %p, the port made %p\n", (unsigned)curves[curve], theirs, mine);
            continue;
        }
        double worst = 0;
        for (size_t sample = 0; sample < sizeof(samples) / sizeof(*samples); sample++) {
            double theirValue = [theirs evaluateForValue:samples[sample]];
            double myValue = [mine evaluateForValue:samples[sample]];
            double difference = fabs(theirValue - myValue);
            if (difference > worst) { worst = difference; }
        }
        printf("stage curve 0x%08x: worst difference over %zu samples %g\n",
               (unsigned)curves[curve], sizeof(samples) / sizeof(*samples), worst);
        checkClose([NSString stringWithFormat:@"curve 0x%08x agrees with the host", (unsigned)curves[curve]],
                   worst, 0.0, 1e-6);
    }
    id theirSegment = [[hostSegment alloc] initWithEndPoint:simd_make_double2(4.0, 2.0) curveType:PHASECurveTypeLinear];
    id mySegment = [[portSegment alloc] initWithEndPoint:simd_make_double2(4.0, 2.0) curveType:PHASECurveTypeLinear];
    id theirs = [[hostEnvelope alloc] initWithStartPoint:simd_make_double2(1.0, 0.5) segments:@[theirSegment]];
    id mine = [[portEnvelope alloc] initWithStartPoint:simd_make_double2(1.0, 0.5) segments:@[mySegment]];
    check(@"the host's domain is the start point's x and the last end point's x",
          [[[theirs domain] valueForKey:@"first"] isEqual:@(1.0)] && [[[theirs domain] valueForKey:@"second"] isEqual:@(4.0)]);
    check(@"the port's domain is the same", [[[mine domain] valueForKey:@"first"] isEqual:@(1.0)] && [[[mine domain] valueForKey:@"second"] isEqual:@(4.0)]);
    check(@"the host's range is the start point's y and the last end point's y",
          [[[theirs valueForKey:@"range"] valueForKey:@"first"] isEqual:@(0.5)] && [[[theirs valueForKey:@"range"] valueForKey:@"second"] isEqual:@(2.0)]);
    check(@"the port's range is the same", [[[mine valueForKey:@"range"] valueForKey:@"first"] isEqual:@(0.5)] && [[[mine valueForKey:@"range"] valueForKey:@"second"] isEqual:@(2.0)]);
}

static NSString *shapeOfRaise(void (^call)(void))
{
    @try {
        call();
    } @catch (NSException *exception) {
        NSString *reason = [exception.reason stringByReplacingOccurrencesOfString:@"revenant_host_" withString:@""];
        return [NSString stringWithFormat:@"%@: %@", exception.name, [reason componentsSeparatedByString:@" 0x"].firstObject];
    }
    return @"no raise";
}

static void compareUnavailableInits(void)
{
    Class portEnvelope = NSClassFromString(@"revenant_host_PHASEEnvelope");
    Class hostEnvelope = NSClassFromString(@"PHASEEnvelope");
    Class portModel = NSClassFromString(@"revenant_host_PHASEEnvelopeDistanceModelParameters");
    Class hostModel = NSClassFromString(@"PHASEEnvelopeDistanceModelParameters");
    if (portEnvelope == Nil || hostEnvelope == Nil || portModel == Nil || hostModel == Nil) {
        check(@"the host and the port both carry the two envelope classes", NO);
        return;
    }
    for (NSArray *pair in @[@[hostEnvelope, portEnvelope], @[hostModel, portModel]]) {
        Class theirs = pair[0];
        Class mine = pair[1];
        NSString *name = NSStringFromClass(theirs);
        check([NSString stringWithFormat:@"the host's %@ still answers -init and +new as selectors", name],
              [theirs instancesRespondToSelector:@selector(init)] && [theirs respondsToSelector:@selector(new)]);
        check([NSString stringWithFormat:@"the port's %@ still answers -init and +new as selectors", name],
              [mine instancesRespondToSelector:@selector(init)] && [mine respondsToSelector:@selector(new)]);

        NSString *hostInit = shapeOfRaise(^{ (void)[[theirs alloc] init]; });
        NSString *portInit = shapeOfRaise(^{ (void)[[mine alloc] init]; });
        NSString *hostNew = shapeOfRaise(^{ (void)[theirs new]; });
        NSString *portNew = shapeOfRaise(^{ (void)[mine new]; });
        check([NSString stringWithFormat:@"the host's -[%@ init] raises the unrecognized selector: %@", name, hostInit],
              [hostInit hasPrefix:@"NSInvalidArgumentException: -[PHASE"] && [hostInit containsString:@"unrecognized selector sent to instance"]);
        check([NSString stringWithFormat:@"the port's -[%@ init] raises the same message as the host: %@", name, portInit],
              [portInit isEqualToString:hostInit]);
        check([NSString stringWithFormat:@"the host's +[%@ new] raises the unrecognized selector: %@", name, hostNew],
              [hostNew hasPrefix:@"NSInvalidArgumentException: +[PHASE"] && [hostNew containsString:@"unrecognized selector sent to class"]);
        check([NSString stringWithFormat:@"the port's +[%@ new] raises the same message as the host: %@", name, portNew],
              [portNew isEqualToString:hostNew]);
    }
}

int main(void)
{
    @autoreleasepool {
        void *lib = dlopen("/System/Library/Frameworks/PHASE.framework/PHASE", RTLD_LAZY);
        if (lib == NULL) {
            printf("FAIL the host has no PHASE.framework: %s\n", dlerror());
            return 1;
        }
        printf("stage the host's PHASE: %s\n", [[NSBundle bundleForClass:NSClassFromString(@"PHASEEngine")] bundlePath].UTF8String ?: "(path unknown)");

        Class pairClass = NSClassFromString(@"PHASENumericPair");
        if (pairClass != Nil) {
            id pair = [[pairClass alloc] initWithFirstValue:2.5 secondValue:-3.25];
            check(@"the host's PHASENumericPair holds the first value", [pair valueForKey:@"first"] != nil &&
                  [[pair valueForKey:@"first"] doubleValue] == 2.5);
            check(@"the host's PHASENumericPair holds the second value", [pair valueForKey:@"second"] != nil &&
                  [[pair valueForKey:@"second"] doubleValue] == -3.25);
            [pair setValue:@(7.0) forKey:@"first"];
            checkClose(@"and the first value is settable", [[pair valueForKey:@"first"] doubleValue], 7.0, 0.0);
        } else {
            printf("skip PHASENumericPair: the host's PHASE does not carry it\n");
        }

        Class fadeClass = NSClassFromString(@"PHASEDistanceModelFadeOutParameters");
        if (fadeClass != Nil) {
            id fade = [[fadeClass alloc] initWithCullDistance:42.5];
            checkClose(@"the host's distance fade holds the cull distance it was given",
                       [[fade valueForKey:@"cullDistance"] doubleValue], 42.5, 0.0);
        } else {
            printf("skip PHASEDistanceModelFadeOutParameters: the host's PHASE does not carry it\n");
        }

        Class spreadingClass = NSClassFromString(@"PHASEGeometricSpreadingDistanceModelParameters");
        if (spreadingClass != Nil) {
            id spreading = [[spreadingClass alloc] init];
            [spreading setValue:@(1.0) forKey:@"rolloffFactor"];
            double rolloff = [[spreading valueForKey:@"rolloffFactor"] doubleValue];
            checkClose(@"the host's geometric spreading holds the rolloff factor", rolloff, 1.0, 0.0);
            id fresh = [[spreadingClass alloc] init];
            checkClose(@"a fresh geometric spreading object holds the header's default rolloff factor",
                       [[fresh valueForKey:@"rolloffFactor"] doubleValue], 1.0, 0.0);
        } else {
            printf("skip PHASEGeometricSpreadingDistanceModelParameters: the host's PHASE does not carry it\n");
        }

        Class cardioidSubband = NSClassFromString(@"PHASECardioidDirectivityModelSubbandParameters");
        Class coneSubband = NSClassFromString(@"PHASEConeDirectivityModelSubbandParameters");
        if (cardioidSubband != Nil) {
            printf("stage the host's cardioid subband class: %s\n", NSStringFromClass(cardioidSubband).UTF8String);
            id fresh = [[cardioidSubband alloc] init];
            checkClose(@"a fresh cardioid subband's frequency is the header's 1000.0",
                       [[fresh valueForKey:@"frequency"] doubleValue], 1000.0, 0.0);
            checkClose(@"a fresh cardioid subband's pattern is the header's 0.0",
                       [[fresh valueForKey:@"pattern"] doubleValue], 0.0, 0.0);
            checkClose(@"a fresh cardioid subband's sharpness is the header's 1.0",
                       [[fresh valueForKey:@"sharpness"] doubleValue], 1.0, 0.0);
        } else {
            printf("skip PHASECardioidDirectivityModelSubbandParameters: the host's PHASE does not carry it\n");
        }
        if (coneSubband != Nil) {
            printf("stage the host's cone subband class: %s\n", NSStringFromClass(coneSubband).UTF8String);
            id fresh = [[coneSubband alloc] init];
            checkClose(@"a fresh cone subband's frequency is the header's 1000.0",
                       [[fresh valueForKey:@"frequency"] doubleValue], 1000.0, 0.0);
            checkClose(@"a fresh cone subband's inner angle is the header's 360.0",
                       [[fresh valueForKey:@"innerAngle"] doubleValue], 360.0, 0.0);
            checkClose(@"a fresh cone subband's outer angle is the header's 360.0",
                       [[fresh valueForKey:@"outerAngle"] doubleValue], 360.0, 0.0);
            checkClose(@"a fresh cone subband's outer gain is the header's 1.0",
                       [[fresh valueForKey:@"outerGain"] doubleValue], 1.0, 0.0);
        } else {
            printf("skip PHASEConeDirectivityModelSubbandParameters: the host's PHASE does not carry it\n");
        }

        compareDefaults();
        compareEngine();
        compareEnvelope();
        compareEnvelopeDistanceModel();
        compareUnavailableInits();
        printf("checks=%d failures=%d\n", checks, failures);
    }
    return failures == 0 ? 0 : 1;
}

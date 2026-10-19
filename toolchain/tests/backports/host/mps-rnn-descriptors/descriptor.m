#import <Foundation/Foundation.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <stdio.h>

static int failures;
static int checks;

static void check(int ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", [line UTF8String]);
    else { printf("  FAIL %s\n", [line UTF8String]); failures++; }
}

typedef NS_ENUM(int, Kind) { KindUInt, KindBool, KindFloat, KindEnum, KindWeights };

static NSArray *member(NSString *name, Kind kind)
{
    return @[name, @(kind)];
}

static NSArray *baseMembers(void)
{
    return @[member(@"inputFeatureChannels", KindUInt), member(@"outputFeatureChannels", KindUInt),
             member(@"useLayerInputUnitTransformMode", KindBool), member(@"useFloat32Weights", KindBool),
             member(@"layerSequenceDirection", KindEnum)];
}

static NSArray *ownMembers(NSString *cls)
{
    if ([cls isEqualToString:@"MPSRNNSingleGateDescriptor"]) {
        return @[member(@"inputWeights", KindWeights), member(@"recurrentWeights", KindWeights)];
    }
    if ([cls isEqualToString:@"MPSGRUDescriptor"]) {
        return @[member(@"inputGateInputWeights", KindWeights), member(@"inputGateRecurrentWeights", KindWeights),
                 member(@"recurrentGateInputWeights", KindWeights), member(@"recurrentGateRecurrentWeights", KindWeights),
                 member(@"outputGateInputWeights", KindWeights), member(@"outputGateRecurrentWeights", KindWeights),
                 member(@"outputGateInputGateWeights", KindWeights),
                 member(@"gatePnormValue", KindFloat), member(@"flipOutputGates", KindBool)];
    }
    if ([cls isEqualToString:@"MPSLSTMDescriptor"]) {
        return @[member(@"memoryWeightsAreDiagonal", KindBool),
                 member(@"inputGateInputWeights", KindWeights), member(@"inputGateRecurrentWeights", KindWeights),
                 member(@"inputGateMemoryWeights", KindWeights),
                 member(@"forgetGateInputWeights", KindWeights), member(@"forgetGateRecurrentWeights", KindWeights),
                 member(@"forgetGateMemoryWeights", KindWeights),
                 member(@"outputGateInputWeights", KindWeights), member(@"outputGateRecurrentWeights", KindWeights),
                 member(@"outputGateMemoryWeights", KindWeights),
                 member(@"cellGateInputWeights", KindWeights), member(@"cellGateRecurrentWeights", KindWeights),
                 member(@"cellGateMemoryWeights", KindWeights),
                 member(@"cellToOutputNeuronType", KindEnum),
                 member(@"cellToOutputNeuronParamA", KindFloat), member(@"cellToOutputNeuronParamB", KindFloat),
                 member(@"cellToOutputNeuronParamC", KindFloat)];
    }
    return @[];
}

static NSArray *allMembers(NSString *cls)
{
    return [baseMembers() arrayByAddingObjectsFromArray:ownMembers(cls)];
}

static NSString *portName(NSString *cls)
{
    return [@"CharonHost" stringByAppendingString:cls];
}

static id makeInit(NSString *cls, BOOL port)
{
    id c = NSClassFromString(port ? portName(cls) : cls);
    return [[c alloc] init];
}

static id makeFactory(NSString *cls, BOOL port, NSUInteger inCh, NSUInteger outCh)
{
    id c = NSClassFromString(port ? portName(cls) : cls);
    if ([cls isEqualToString:@"MPSRNNSingleGateDescriptor"]) {
        return [c createRNNSingleGateDescriptorWithInputFeatureChannels:inCh outputFeatureChannels:outCh];
    }
    if ([cls isEqualToString:@"MPSGRUDescriptor"]) {
        return [c createGRUDescriptorWithInputFeatureChannels:inCh outputFeatureChannels:outCh];
    }
    if ([cls isEqualToString:@"MPSLSTMDescriptor"]) {
        return [c createLSTMDescriptorWithInputFeatureChannels:inCh outputFeatureChannels:outCh];
    }
    [NSException raise:NSInvalidArgumentException format:@"makeFactory: no factory for %@", cls];
    return nil;
}

static NSString *describeValue(id v, Kind kind)
{
    switch (kind) {
    case KindUInt:    return [NSString stringWithFormat:@"%lu", (unsigned long)[v unsignedLongValue]];
    case KindBool:    return [v boolValue] ? @"YES" : @"NO";
    case KindFloat:   return [NSString stringWithFormat:@"%.9g", [v floatValue]];
    case KindEnum:    return [NSString stringWithFormat:@"%ld", (long)[v longValue]];
    case KindWeights: return v ? @"set" : @"nil";
    }
    return @"?";
}

static NSDictionary *snapshot(id obj, NSArray *members)
{
    NSMutableDictionary *s = [NSMutableDictionary dictionary];
    for (NSArray *m in members) {
        NSString *name = m[0];
        Kind kind = (Kind)[m[1] intValue];
        @try {
            s[name] = describeValue([obj valueForKey:name], kind);
        } @catch (NSException *e) {
            s[name] = @"MISSING";
        }
    }
    return s;
}

static void printValues(NSDictionary *a, NSArray *members)
{
    for (NSArray *m in members)
        printf("       %-34s %s\n", [m[0] UTF8String], [a[m[0]] UTF8String]);
}

static void compareSnapshots(NSString *label, NSDictionary *a, NSDictionary *p, NSArray *members)
{
    int same = [a isEqualToDictionary:p];
    check(same, [NSString stringWithFormat:@"%@: the port's members read as Apple's (%lu)", label, (unsigned long)members.count]);
    if (!same) {
        for (NSArray *m in members) {
            NSString *name = m[0];
            if (![a[name] isEqualToString:p[name]])
                printf("       %s: apple %s, port %s\n", [name UTF8String], [a[name] UTF8String], [p[name] UTF8String]);
        }
    }
}

static void setAway(id obj, NSArray *members, NSDictionary *standIns)
{
    for (NSArray *m in members) {
        NSString *name = m[0];
        Kind kind = (Kind)[m[1] intValue];
        id value = nil;
        switch (kind) {
        case KindUInt:
            value = [name isEqualToString:@"outputFeatureChannels"] ? @9 : @7;
            break;
        case KindBool:
            value = @YES;
            break;
        case KindFloat:
            if ([name isEqualToString:@"cellToOutputNeuronParamA"]) value = @0.5;
            else if ([name isEqualToString:@"cellToOutputNeuronParamB"]) value = @2.0;
            else if ([name isEqualToString:@"cellToOutputNeuronParamC"]) value = @3.0;
            else value = @2.5;
            break;
        case KindEnum:
            value = [name isEqualToString:@"layerSequenceDirection"] ? @(MPSRNNSequenceDirectionBackward)
                                                                     : @(MPSCNNNeuronTypeReLU);
            break;
        case KindWeights:
            value = standIns[name];
            break;
        }
        @try {
            [obj setValue:value forKey:name];
        } @catch (NSException *e) {
            printf("       set %s raised %s\n", [name UTF8String], [e.name UTF8String]);
        }
    }
}

static NSDictionary *standInsFor(NSArray *members)
{
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSArray *m in members) {
        if ((Kind)[m[1] intValue] == KindWeights)
            d[m[0]] = [[NSObject alloc] init];
    }
    return d;
}

static int weightsReadBackByIdentity(id obj, NSArray *members, NSDictionary *standIns)
{
    for (NSArray *m in members) {
        if ((Kind)[m[1] intValue] != KindWeights) continue;
        NSString *name = m[0];
        if ([obj valueForKey:name] != standIns[name]) return 0;
    }
    return 1;
}

static NSString *copyOutcome(id obj)
{
    @try {
        (void)[obj copy];
        return @"answered";
    } @catch (NSException *e) {
        return e.name;
    }
}

static NSString *copySignature(id fresh, id set)
{
    return [NSString stringWithFormat:@"NSCopying=%d NSSecureCoding=%d copy(fresh)=%@ copy(set)=%@",
            [[fresh class] conformsToProtocol:@protocol(NSCopying)],
            [[fresh class] conformsToProtocol:@protocol(NSSecureCoding)],
            copyOutcome(fresh), copyOutcome(set)];
}

static NSString *equalitySignature(id fresh, id freshTwin, id set, id setTwin)
{
    return [NSString stringWithFormat:
            @"fresh-self=%d fresh-twin=%d fresh-twin-hash=%d fresh-nil=%d set-self=%d set-twin=%d set-vs-fresh=%d",
            [fresh isEqual:fresh], [fresh isEqual:freshTwin], [fresh hash] == [freshTwin hash], [fresh isEqual:nil],
            [set isEqual:set], [set isEqual:setTwin], [set isEqual:fresh]];
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        NSArray *classes = @[@"MPSRNNDescriptor", @"MPSRNNSingleGateDescriptor", @"MPSGRUDescriptor", @"MPSLSTMDescriptor"];
        for (NSString *cls in classes) {
            check(NSClassFromString(cls) != nil, [NSString stringWithFormat:@"%@: Apple's class is in the framework", cls]);
            check(NSClassFromString(portName(cls)) != nil,
                  [NSString stringWithFormat:@"%@: the port's class is built in this process", cls]);
        }
        if (failures)
            return 1;

        printf("defaults: each class from alloc and init, every member the 16.4 header declares\n");
        for (NSString *cls in classes) {
            NSArray *members = allMembers(cls);
            NSDictionary *a = snapshot(makeInit(cls, NO), members);
            NSDictionary *p = snapshot(makeInit(cls, YES), members);
            printf("   Apple's %s:\n", [cls UTF8String]);
            printValues(a, members);
            compareSnapshots([NSString stringWithFormat:@"%@ defaults", cls], a, p, members);
        }

        printf("factories: the class method each header gives, and the base class's init, answer the same\n");
        NSArray *factories = @[@[@"MPSRNNSingleGateDescriptor", @3, @5], @[@"MPSRNNSingleGateDescriptor", @0, @0],
                               @[@"MPSGRUDescriptor", @3, @5], @[@"MPSLSTMDescriptor", @3, @5]];
        for (NSArray *f in factories) {
            NSString *cls = f[0];
            NSUInteger inCh = [f[1] unsignedIntegerValue], outCh = [f[2] unsignedIntegerValue];
            id apple = makeFactory(cls, NO, inCh, outCh);
            id port = makeFactory(cls, YES, inCh, outCh);
            NSArray *members = allMembers(cls);
            NSString *label = [NSString stringWithFormat:@"%@ factory (%lu, %lu)", cls, (unsigned long)inCh, (unsigned long)outCh];
            check(apple != nil && port != nil, [NSString stringWithFormat:@"%@: both sides answer an object", label]);
            check([apple isKindOfClass:NSClassFromString(cls)] && [port isKindOfClass:NSClassFromString(portName(cls))],
                  [NSString stringWithFormat:@"%@: each answers an instance of its own class", label]);
            compareSnapshots(label, snapshot(apple, members), snapshot(port, members), members);
        }

        printf("set values: every member set away from its default, weight sources by identity\n");
        for (NSString *cls in classes) {
            NSArray *members = allMembers(cls);
            id apple = makeInit(cls, NO), port = makeInit(cls, YES);
            NSDictionary *appleStandIns = standInsFor(members), *portStandIns = standInsFor(members);
            setAway(apple, members, appleStandIns);
            setAway(port, members, portStandIns);
            compareSnapshots([NSString stringWithFormat:@"%@ set", cls],
                             snapshot(apple, members), snapshot(port, members), members);
            check(weightsReadBackByIdentity(apple, members, appleStandIns) &&
                  weightsReadBackByIdentity(port, members, portStandIns),
                  [NSString stringWithFormat:@"%@ set: each of its %lu weight sources reads back as the object set", cls,
                   (unsigned long)appleStandIns.count]);
        }

        printf("copy: NSCopying, NSSecureCoding and what copy does, fresh and set\n");
        for (NSString *cls in classes) {
            NSArray *members = allMembers(cls);
            id appleFresh = makeInit(cls, NO), portFresh = makeInit(cls, YES);
            id appleSet = makeInit(cls, NO), portSet = makeInit(cls, YES);
            setAway(appleSet, members, standInsFor(members));
            setAway(portSet, members, standInsFor(members));
            NSString *a = copySignature(appleFresh, appleSet);
            NSString *p = copySignature(portFresh, portSet);
            printf("   Apple's %s: %s\n", [cls UTF8String], [a UTF8String]);
            check([a isEqualToString:p], [NSString stringWithFormat:@"%@ copy: the port's answer is Apple's (%@)", cls, p]);
        }

        printf("equality: identity for fresh and set values, and hash\n");
        for (NSString *cls in classes) {
            NSArray *members = allMembers(cls);
            id appleFresh = makeInit(cls, NO), appleFreshTwin = makeInit(cls, NO);
            id appleSet = makeInit(cls, NO), appleSetTwin = makeInit(cls, NO);
            setAway(appleSet, members, standInsFor(members));
            setAway(appleSetTwin, members, standInsFor(members));
            id portFresh = makeInit(cls, YES), portFreshTwin = makeInit(cls, YES);
            id portSet = makeInit(cls, YES), portSetTwin = makeInit(cls, YES);
            setAway(portSet, members, standInsFor(members));
            setAway(portSetTwin, members, standInsFor(members));
            NSString *a = equalitySignature(appleFresh, appleFreshTwin, appleSet, appleSetTwin);
            NSString *p = equalitySignature(portFresh, portFreshTwin, portSet, portSetTwin);
            printf("   Apple's %s: %s\n", [cls UTF8String], [a UTF8String]);
            check([a isEqualToString:p], [NSString stringWithFormat:@"%@ equality: the port's answers are Apple's", cls]);
        }
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}

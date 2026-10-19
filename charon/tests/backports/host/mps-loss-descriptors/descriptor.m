/* descriptor.m - the loss and neuron descriptors of MetalPerformanceShaders, compared with Apple's own objects.
 *
 * MPSCNNLossDataDescriptor (11.3), MPSCNNLossDescriptor (11.3), MPSCNNYOLOLossDescriptor (12.0) and MPSNNNeuronDescriptor
 * (11.3). Each value is built twice in one process: by Apple's framework, and by the port under CharonHost<Name>. The
 * defaults of each factory and of -init, every setter's read back, copies, equality and coding are compared member by
 * member. A disagreement names the case, the member and both values.
 *
 * A REFUSAL IS A CHILD PROCESS. Apple asserts, and the process aborts, on a value these descriptors refuse. Each such
 * call is made in a fork on Apple's object, and the exit status says whether Apple refused: an abort is a refusal, a
 * clean exit is an acceptance. The port refuses by answering nil, or by leaving a value as it was, in this process, and
 * the two must agree.
 *
 * NO DEVICE IS CREATED. A descriptor asks a device nothing.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#include <sys/wait.h>
#include <unistd.h>
#include <objc/message.h>

static int failures;
static int checks;

static void check(int ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", [line UTF8String]);
    else { printf("  FAIL %s\n", [line UTF8String]); failures++; }
}

/* Runs the block in a child process: 0 for a clean exit, the signal number for a crash (an assertion is SIGABRT, 6). */
static int inChild(void (^block)(void))
{
    fflush(stdout);
    pid_t pid = fork();
    if (pid == 0) {
        freopen("/dev/null", "w", stderr);
        @autoreleasepool { block(); }
        _exit(0);
    }
    int st = 0;
    waitpid(pid, &st, 0);
    return WIFEXITED(st) ? 0 : WTERMSIG(st);
}

/* -init is NS_UNAVAILABLE in the header, so the compiler will not send it; the runtime does (measured: a zeroed object). */
static id initUnavailable(Class cls)
{
    return ((id (*)(id, SEL))objc_msgSend)([cls alloc], @selector(init));
}

static NSString *f(float v) { return [NSString stringWithFormat:@"%.9g", v]; }
static NSString *n(NSUInteger v) { return [NSString stringWithFormat:@"%lu", (unsigned long)v]; }
static NSString *i(NSInteger v) { return [NSString stringWithFormat:@"%ld", (long)v]; }

/* Prints the members that differ and reports whether the two read the same. */
static int sameSnapshot(NSDictionary *apple, NSDictionary *port, NSString *what)
{
    if ([apple isEqualToDictionary:port])
        return 1;
    printf("       %s\n", [what UTF8String]);
    NSMutableSet *keys = [NSMutableSet setWithArray:apple.allKeys];
    [keys addObjectsFromArray:port.allKeys];
    for (NSString *key in [[keys allObjects] sortedArrayUsingSelector:@selector(compare:)]) {
        NSString *a = apple[key] ?: @"(missing)", *p = port[key] ?: @"(missing)";
        if (![a isEqualToString:p])
            printf("         %s: apple %s, port %s\n", [key UTF8String], [a UTF8String], [p UTF8String]);
    }
    return 0;
}

static void compareSnapshots(NSDictionary *apple, NSDictionary *port, NSString *what)
{
    check(sameSnapshot(apple, port, what), [NSString stringWithFormat:@"%@: the port reads as Apple's", what]);
}

/* A refusal is the same answer on both sides: Apple aborts (or, for a value it takes, accepts) and the port answers
 * nil or accepts in the same way. */
static void refusal(NSString *what, BOOL appleRefused, BOOL portRefused)
{
    check(appleRefused == portRefused,
          [NSString stringWithFormat:@"%@: the port answers as Apple does (Apple %@, port %@)", what,
           appleRefused ? @"refuses" : @"accepts", portRefused ? @"refuses" : @"accepts"]);
}

/* Records, under a prefix, whether two objects are equal and whether they hash alike. */
static void equalities(NSMutableDictionary *s, NSString *prefix, id x, id y)
{
    s[[prefix stringByAppendingString:@".isEqual"]] = [x isEqual:y] ? @"YES" : @"NO";
    s[[prefix stringByAppendingString:@".hash"]] = [x hash] == [y hash] ? @"YES" : @"NO";
}

/* ---- snapshots: every member the header declares for the class, as text ---- */

static NSDictionary *lossDataSnapshot(MPSCNNLossDataDescriptor *d)
{
    if (!d) return @{ @"object": @"nil" };
    return @{ @"layout": n(d.layout),
              @"size": [NSString stringWithFormat:@"%lux%lux%lu", (unsigned long)d.size.width, (unsigned long)d.size.height,
                        (unsigned long)d.size.depth],
              @"bytesPerRow": n(d.bytesPerRow),
              @"bytesPerImage": n(d.bytesPerImage) };
}

static NSDictionary *lossSnapshot(MPSCNNLossDescriptor *d)
{
    if (!d) return @{ @"object": @"nil" };
    return @{ @"lossType": i(d.lossType),
              @"reductionType": i(d.reductionType),
              @"reduceAcrossBatch": d.reduceAcrossBatch ? @"YES" : @"NO",
              @"weight": f(d.weight),
              @"labelSmoothing": f(d.labelSmoothing),
              @"numberOfClasses": n(d.numberOfClasses),
              @"epsilon": f(d.epsilon),
              @"delta": f(d.delta) };
}

static void addLoss(NSMutableDictionary *s, NSString *prefix, MPSCNNLossDescriptor *loss)
{
    NSDictionary *l = lossSnapshot(loss);
    for (NSString *k in l)
        s[[NSString stringWithFormat:@"%@.%@", prefix, k]] = l[k];
}

static NSDictionary *yoloSnapshot(MPSCNNYOLOLossDescriptor *d)
{
    if (!d) return @{ @"object": @"nil" };
    /* reduceAcrossBatch is not read here: the port does not carry it (iOS 14.0 in the header, outside this class's 12.0). */
    NSMutableDictionary *s = [NSMutableDictionary dictionary];
    s[@"rescore"] = d.rescore ? @"YES" : @"NO";
    s[@"scaleXY"] = f(d.scaleXY);
    s[@"scaleWH"] = f(d.scaleWH);
    s[@"scaleNoObject"] = f(d.scaleNoObject);
    s[@"scaleObject"] = f(d.scaleObject);
    s[@"scaleClass"] = f(d.scaleClass);
    s[@"minIOUForObjectPresence"] = f(d.minIOUForObjectPresence);
    s[@"maxIOUForObjectAbsence"] = f(d.maxIOUForObjectAbsence);
    s[@"numberOfAnchorBoxes"] = n(d.numberOfAnchorBoxes);
    s[@"reductionType"] = i(d.reductionType);
    s[@"anchorBoxes"] = d.anchorBoxes ? [d.anchorBoxes description] : @"nil";
    addLoss(s, @"XY", d.XYLossDescriptor);
    addLoss(s, @"WH", d.WHLossDescriptor);
    addLoss(s, @"confidence", d.confidenceLossDescriptor);
    addLoss(s, @"classes", d.classesLossDescriptor);
    return s;
}

static NSDictionary *neuronSnapshot(MPSNNNeuronDescriptor *d)
{
    if (!d) return @{ @"object": @"nil" };
    return @{ @"neuronType": i(d.neuronType),
              @"a": f(d.a),
              @"b": f(d.b),
              @"c": f(d.c),
              @"data": d.data ? [d.data description] : @"nil" };
}

/* ---- the setters the header gives MPSCNNLossDescriptor a validity for ---- */

static const char *setterNames[] = { "labelSmoothing", "numberOfClasses", "epsilon", "delta" };
static const float setterValues[] = { 0.25f, 7.0f, 0.001f, 2.0f };

static void setOne(int which, id object)
{
    MPSCNNLossDescriptor *d = object;
    switch (which) {
    case 0: d.labelSmoothing = setterValues[0]; break;
    case 1: d.numberOfClasses = (NSUInteger)setterValues[1]; break;
    case 2: d.epsilon = setterValues[2]; break;
    default: d.delta = setterValues[3]; break;
    }
}

static float readOne(int which, id object)
{
    MPSCNNLossDescriptor *d = object;
    switch (which) {
    case 0: return d.labelSmoothing;
    case 1: return (float)d.numberOfClasses;
    case 2: return d.epsilon;
    default: return d.delta;
    }
}

static NSData *floats(NSUInteger count, const float *values)
{
    return [NSData dataWithBytes:values length:count * sizeof(float)];
}

/* ---- MPSCNNLossDataDescriptor ---- */

static void lossDataCases(Class port)
{
    printf("MPSCNNLossDataDescriptor (11.3)\n");

    printf("  the factory over both layouts and five sizes, a dense array\n");
    static const NSUInteger shapes[5][3] = { {3, 2, 4}, {5, 3, 2}, {1, 1, 1}, {7, 11, 13}, {0, 2, 2} };
    int same = 1;
    for (NSUInteger layout = 0; layout <= 1; layout++) {
        for (int s = 0; s < 5; s++) {
            MTLSize size = MTLSizeMake(shapes[s][0], shapes[s][1], shapes[s][2]);
            NSData *data = [NSMutableData dataWithLength:size.width * size.height * size.depth * sizeof(float)];
            MPSCNNLossDataDescriptor *apple = [MPSCNNLossDataDescriptor cnnLossDataDescriptorWithData:data
                                                                                              layout:(MPSDataLayout)layout
                                                                                                size:size];
            MPSCNNLossDataDescriptor *mine = [port cnnLossDataDescriptorWithData:data layout:(MPSDataLayout)layout size:size];
            same = sameSnapshot(lossDataSnapshot(apple), lossDataSnapshot(mine),
                                [NSString stringWithFormat:@"layout %lu, size %lux%lux%lu", (unsigned long)layout,
                                 (unsigned long)size.width, (unsigned long)size.height, (unsigned long)size.depth]) && same;
        }
    }
    check(same, @"factory: both layouts over five sizes read as Apple's (the byte counts too)");

    printf("  the data is short and empty, and the release takes it as given\n");
    NSData *short10 = [NSMutableData dataWithLength:10];
    compareSnapshots(lossDataSnapshot([MPSCNNLossDataDescriptor cnnLossDataDescriptorWithData:short10 layout:0 size:MTLSizeMake(3, 2, 4)]),
                     lossDataSnapshot([port cnnLossDataDescriptorWithData:short10 layout:0 size:MTLSizeMake(3, 2, 4)]),
                     @"factory: ten bytes for ninety-six, accepted");

    printf("  an unset descriptor: -init, which the header marks NS_UNAVAILABLE\n");
    MPSCNNLossDataDescriptor *appleUnset = initUnavailable([MPSCNNLossDataDescriptor class]);
    MPSCNNLossDataDescriptor *myUnset = initUnavailable(port);
    compareSnapshots(lossDataSnapshot(appleUnset), lossDataSnapshot(myUnset), @"init: a zeroed descriptor");

    printf("  a set descriptor, its copy, and equality\n");
    NSData *data = [NSMutableData dataWithLength:96];
    MPSCNNLossDataDescriptor *apple = [MPSCNNLossDataDescriptor cnnLossDataDescriptorWithData:data
                                                                                        layout:MPSDataLayoutFeatureChannelsxHeightxWidth
                                                                                          size:MTLSizeMake(3, 2, 4)];
    MPSCNNLossDataDescriptor *mine = [port cnnLossDataDescriptorWithData:data layout:MPSDataLayoutFeatureChannelsxHeightxWidth
                                                                     size:MTLSizeMake(3, 2, 4)];
    apple.bytesPerRow = 100;
    apple.bytesPerImage = 777;
    mine.bytesPerRow = 100;
    mine.bytesPerImage = 777;
    compareSnapshots(lossDataSnapshot(apple), lossDataSnapshot(mine), @"set: bytesPerRow and bytesPerImage read back as set");
    MPSCNNLossDataDescriptor *appleCopy = [apple copy];
    MPSCNNLossDataDescriptor *myCopy = [mine copy];
    compareSnapshots(lossDataSnapshot(appleCopy), lossDataSnapshot(myCopy), @"copy: every member of a set descriptor");
    apple.bytesPerImage = 5;
    mine.bytesPerImage = 5;
    check(appleCopy.bytesPerImage == 777 && myCopy.bytesPerImage == 777,
          @"copy: the copy keeps its own bytesPerImage when the original changes");
    NSMutableDictionary *eq = [NSMutableDictionary dictionary], *peq = [NSMutableDictionary dictionary];
    equalities(eq, @"copy", apple, appleCopy);
    equalities(peq, @"copy", mine, myCopy);
    equalities(eq, @"self", apple, apple);
    equalities(peq, @"self", mine, mine);
    equalities(eq, @"unset", apple, appleUnset);
    equalities(peq, @"unset", mine, myUnset);
    compareSnapshots(eq, peq, @"equality: a copy, the object itself, and an unset one");
}

/* ---- MPSCNNLossDescriptor ---- */

static void lossCases(Class port)
{
    printf("MPSCNNLossDescriptor (11.3)\n");

    printf("  the factory over every loss type and reduction type the release takes\n");
    int same = 1;
    for (int t = 0; t <= 9; t++) {
        for (int r = -1; r <= 3; r++) {
            MPSCNNLossDescriptor *apple = [MPSCNNLossDescriptor cnnLossDescriptorWithType:(MPSCNNLossType)t reductionType:(MPSCNNReductionType)r];
            MPSCNNLossDescriptor *mine = [port cnnLossDescriptorWithType:(MPSCNNLossType)t reductionType:(MPSCNNReductionType)r];
            same = sameSnapshot(lossSnapshot(apple), lossSnapshot(mine), [NSString stringWithFormat:@"type %d, reduction %d", t, r]) && same;
        }
    }
    check(same, @"factory: loss types 0 to 9 and reduction types -1 to 3 read their defaults as Apple's");

    printf("  the factory refuses what the release asserts on\n");
    refusal(@"factory: loss type 10",
            inChild(^{ [MPSCNNLossDescriptor cnnLossDescriptorWithType:(MPSCNNLossType)10 reductionType:MPSCNNReductionTypeMean]; }) != 0,
            [port cnnLossDescriptorWithType:(MPSCNNLossType)10 reductionType:MPSCNNReductionTypeMean] == nil);
    refusal(@"factory: loss type -1",
            inChild(^{ [MPSCNNLossDescriptor cnnLossDescriptorWithType:(MPSCNNLossType)-1 reductionType:MPSCNNReductionTypeMean]; }) != 0,
            [port cnnLossDescriptorWithType:(MPSCNNLossType)-1 reductionType:MPSCNNReductionTypeMean] == nil);
    refusal(@"factory: reduction type 4",
            inChild(^{ [MPSCNNLossDescriptor cnnLossDescriptorWithType:MPSCNNLossTypeHuber reductionType:(MPSCNNReductionType)4]; }) != 0,
            [port cnnLossDescriptorWithType:MPSCNNLossTypeHuber reductionType:(MPSCNNReductionType)4] == nil);
    refusal(@"factory: reduction type -1",
            inChild(^{ [MPSCNNLossDescriptor cnnLossDescriptorWithType:MPSCNNLossTypeHuber reductionType:(MPSCNNReductionType)-1]; }) != 0,
            [port cnnLossDescriptorWithType:MPSCNNLossTypeHuber reductionType:(MPSCNNReductionType)-1] == nil);

    printf("  an unset descriptor: -init, which the header marks NS_UNAVAILABLE\n");
    compareSnapshots(lossSnapshot(initUnavailable([MPSCNNLossDescriptor class])), lossSnapshot(initUnavailable(port)),
                     @"init: a zeroed descriptor");

    printf("  setters the release validates, each against the loss type it names\n");
    for (int which = 0; which < 4; which++) {
        int agree = 1;
        NSMutableString *appleTypes = [NSMutableString string], *portTypes = [NSMutableString string];
        for (int t = 0; t <= 9; t++) {
            int appleAccepts = inChild(^{
                MPSCNNLossDescriptor *d = [MPSCNNLossDescriptor cnnLossDescriptorWithType:(MPSCNNLossType)t reductionType:MPSCNNReductionTypeMean];
                setOne(which, d);
            }) == 0;
            id mine = [port cnnLossDescriptorWithType:(MPSCNNLossType)t reductionType:MPSCNNReductionTypeMean];
            setOne(which, mine);
            int portAccepts = readOne(which, mine) == setterValues[which];
            if (appleAccepts != portAccepts) {
                agree = 0;
                printf("       %s, loss type %d: apple %s it, port %s it\n", setterNames[which], t,
                       appleAccepts ? "accepts" : "refuses", portAccepts ? "accepts" : "refuses");
            }
            if (appleAccepts) {
                id apple = [MPSCNNLossDescriptor cnnLossDescriptorWithType:(MPSCNNLossType)t reductionType:MPSCNNReductionTypeMean];
                setOne(which, apple);
                if (readOne(which, apple) != readOne(which, mine)) {
                    agree = 0;
                    printf("       %s, loss type %d: apple reads %g, port reads %g\n", setterNames[which], t,
                           readOne(which, apple), readOne(which, mine));
                }
                [appleTypes appendFormat:@" %d", t];
            }
            if (portAccepts)
                [portTypes appendFormat:@" %d", t];
        }
        check(agree, [NSString stringWithFormat:@"%s: the port takes it for the loss types Apple takes it for (Apple:%@; port:%@)",
                      setterNames[which], appleTypes, portTypes]);
    }

    printf("  setters the release does not check\n");
    MPSCNNLossDescriptor *apple = [MPSCNNLossDescriptor cnnLossDescriptorWithType:MPSCNNLossTypeHuber reductionType:MPSCNNReductionTypeMean];
    MPSCNNLossDescriptor *mine = [port cnnLossDescriptorWithType:MPSCNNLossTypeHuber reductionType:MPSCNNReductionTypeMean];
    apple.lossType = (MPSCNNLossType)10;
    mine.lossType = (MPSCNNLossType)10;
    apple.reductionType = (MPSCNNReductionType)4;
    mine.reductionType = (MPSCNNReductionType)4;
    compareSnapshots(lossSnapshot(apple), lossSnapshot(mine), @"setters: loss type 10 and reduction 4 are stored as set");

    printf("  a set descriptor, its copy, and equality\n");
    apple = [MPSCNNLossDescriptor cnnLossDescriptorWithType:MPSCNNLossTypeSoftMaxCrossEntropy reductionType:MPSCNNReductionTypeSum];
    mine = [port cnnLossDescriptorWithType:MPSCNNLossTypeSoftMaxCrossEntropy reductionType:MPSCNNReductionTypeSum];
    for (int side = 0; side < 2; side++) {
        MPSCNNLossDescriptor *d = side ? mine : apple;
        d.labelSmoothing = 0.25f;
        d.numberOfClasses = 7;
        d.lossType = MPSCNNLossTypeLog;
        d.epsilon = 0.001f;
        d.lossType = MPSCNNLossTypeHuber;
        d.delta = 2.0f;
        d.weight = 2.5f;
        d.reduceAcrossBatch = YES;
        d.reductionType = MPSCNNReductionTypeMean;
    }
    compareSnapshots(lossSnapshot(apple), lossSnapshot(mine), @"set: every member read back as set");
    MPSCNNLossDescriptor *appleCopy = [apple copy];
    MPSCNNLossDescriptor *myCopy = [mine copy];
    compareSnapshots(lossSnapshot(appleCopy), lossSnapshot(myCopy), @"copy: every member of a set descriptor");
    apple.weight = 9.0f;
    mine.weight = 9.0f;
    check(appleCopy.weight == 2.5f && myCopy.weight == 2.5f, @"copy: the copy keeps its own weight when the original changes");
    NSMutableDictionary *eq = [NSMutableDictionary dictionary], *peq = [NSMutableDictionary dictionary];
    equalities(eq, @"copy", apple, appleCopy);
    equalities(peq, @"copy", mine, myCopy);
    equalities(eq, @"self", apple, apple);
    equalities(peq, @"self", mine, mine);
    equalities(eq, @"unset", apple, initUnavailable([MPSCNNLossDescriptor class]));
    equalities(peq, @"unset", mine, initUnavailable(port));
    compareSnapshots(eq, peq, @"equality: a copy, the object itself, and an unset one");
}

/* ---- MPSCNNYOLOLossDescriptor ---- */

static void yoloCases(Class port, Class lossPort)
{
    printf("MPSCNNYOLOLossDescriptor (12.0)\n");
    static const float boxesOne[4] = { 1.0f, 2.0f, 3.0f, 4.0f };
    static const float boxesTwo[6] = { 0.5f, 0.75f, 1.5f, 2.25f, 3.0f, 4.5f };
    NSData *anchors = floats(4, boxesOne);

    printf("  the factory, two sets of types and reductions\n");
    MPSCNNYOLOLossDescriptor *apple = [MPSCNNYOLOLossDescriptor cnnLossDescriptorWithXYLossType:MPSCNNLossTypeMeanSquaredError
                                                                                      WHLossType:MPSCNNLossTypeHuber
                                                                              confidenceLossType:MPSCNNLossTypeSigmoidCrossEntropy
                                                                                 classesLossType:MPSCNNLossTypeSoftMaxCrossEntropy
                                                                                   reductionType:MPSCNNReductionTypeMean
                                                                                     anchorBoxes:anchors
                                                                             numberOfAnchorBoxes:2];
    MPSCNNYOLOLossDescriptor *mine = [port cnnLossDescriptorWithXYLossType:MPSCNNLossTypeMeanSquaredError
                                                                 WHLossType:MPSCNNLossTypeHuber
                                                         confidenceLossType:MPSCNNLossTypeSigmoidCrossEntropy
                                                            classesLossType:MPSCNNLossTypeSoftMaxCrossEntropy
                                                              reductionType:MPSCNNReductionTypeMean
                                                                anchorBoxes:anchors
                                                        numberOfAnchorBoxes:2];
    compareSnapshots(yoloSnapshot(apple), yoloSnapshot(mine), @"factory: the defaults and the sub-descriptors of one set of types");

    NSData *anchorsTwo = floats(6, boxesTwo);
    apple = [MPSCNNYOLOLossDescriptor cnnLossDescriptorWithXYLossType:MPSCNNLossTypeHinge
                                                           WHLossType:MPSCNNLossTypeLog
                                                   confidenceLossType:MPSCNNLossTypeCosineDistance
                                                      classesLossType:MPSCNNLossTypeKullbackLeiblerDivergence
                                                        reductionType:MPSCNNReductionTypeSum
                                                          anchorBoxes:anchorsTwo
                                                  numberOfAnchorBoxes:3];
    mine = [port cnnLossDescriptorWithXYLossType:MPSCNNLossTypeHinge
                                      WHLossType:MPSCNNLossTypeLog
                              confidenceLossType:MPSCNNLossTypeCosineDistance
                                 classesLossType:MPSCNNLossTypeKullbackLeiblerDivergence
                                   reductionType:MPSCNNReductionTypeSum
                                     anchorBoxes:anchorsTwo
                             numberOfAnchorBoxes:3];
    compareSnapshots(yoloSnapshot(apple), yoloSnapshot(mine), @"factory: a second set of types, reduction Sum and three anchors");

    printf("  the factory refuses what the release asserts on\n");
    NSData *box = anchors;
    refusal(@"factory: reduction type 4",
            inChild(^{ [MPSCNNYOLOLossDescriptor cnnLossDescriptorWithXYLossType:MPSCNNLossTypeMeanSquaredError WHLossType:MPSCNNLossTypeHuber confidenceLossType:MPSCNNLossTypeSigmoidCrossEntropy classesLossType:MPSCNNLossTypeSoftMaxCrossEntropy reductionType:(MPSCNNReductionType)4 anchorBoxes:box numberOfAnchorBoxes:2]; }) != 0,
            [port cnnLossDescriptorWithXYLossType:MPSCNNLossTypeMeanSquaredError WHLossType:MPSCNNLossTypeHuber confidenceLossType:MPSCNNLossTypeSigmoidCrossEntropy classesLossType:MPSCNNLossTypeSoftMaxCrossEntropy reductionType:(MPSCNNReductionType)4 anchorBoxes:box numberOfAnchorBoxes:2] == nil);
    refusal(@"factory: reduction type -1",
            inChild(^{ [MPSCNNYOLOLossDescriptor cnnLossDescriptorWithXYLossType:MPSCNNLossTypeMeanSquaredError WHLossType:MPSCNNLossTypeHuber confidenceLossType:MPSCNNLossTypeSigmoidCrossEntropy classesLossType:MPSCNNLossTypeSoftMaxCrossEntropy reductionType:(MPSCNNReductionType)-1 anchorBoxes:box numberOfAnchorBoxes:2]; }) != 0,
            [port cnnLossDescriptorWithXYLossType:MPSCNNLossTypeMeanSquaredError WHLossType:MPSCNNLossTypeHuber confidenceLossType:MPSCNNLossTypeSigmoidCrossEntropy classesLossType:MPSCNNLossTypeSoftMaxCrossEntropy reductionType:(MPSCNNReductionType)-1 anchorBoxes:box numberOfAnchorBoxes:2] == nil);
    refusal(@"factory: XY loss type 10",
            inChild(^{ [MPSCNNYOLOLossDescriptor cnnLossDescriptorWithXYLossType:(MPSCNNLossType)10 WHLossType:MPSCNNLossTypeHuber confidenceLossType:MPSCNNLossTypeSigmoidCrossEntropy classesLossType:MPSCNNLossTypeSoftMaxCrossEntropy reductionType:MPSCNNReductionTypeMean anchorBoxes:box numberOfAnchorBoxes:2]; }) != 0,
            [port cnnLossDescriptorWithXYLossType:(MPSCNNLossType)10 WHLossType:MPSCNNLossTypeHuber confidenceLossType:MPSCNNLossTypeSigmoidCrossEntropy classesLossType:MPSCNNLossTypeSoftMaxCrossEntropy reductionType:MPSCNNReductionTypeMean anchorBoxes:box numberOfAnchorBoxes:2] == nil);

    printf("  an unset descriptor: -init, which the header marks NS_UNAVAILABLE\n");
    compareSnapshots(yoloSnapshot(initUnavailable([MPSCNNYOLOLossDescriptor class])), yoloSnapshot(initUnavailable(port)),
                     @"init: a zeroed descriptor with no sub-descriptors");

    printf("  a set descriptor: every setter, then the reduction type the release does not check\n");
    apple = [MPSCNNYOLOLossDescriptor cnnLossDescriptorWithXYLossType:MPSCNNLossTypeMeanSquaredError
                                                           WHLossType:MPSCNNLossTypeHuber
                                                   confidenceLossType:MPSCNNLossTypeSigmoidCrossEntropy
                                                      classesLossType:MPSCNNLossTypeSoftMaxCrossEntropy
                                                        reductionType:MPSCNNReductionTypeMean
                                                          anchorBoxes:anchors
                                                  numberOfAnchorBoxes:2];
    mine = [port cnnLossDescriptorWithXYLossType:MPSCNNLossTypeMeanSquaredError
                                      WHLossType:MPSCNNLossTypeHuber
                              confidenceLossType:MPSCNNLossTypeSigmoidCrossEntropy
                                 classesLossType:MPSCNNLossTypeSoftMaxCrossEntropy
                                   reductionType:MPSCNNReductionTypeMean
                                     anchorBoxes:anchors
                             numberOfAnchorBoxes:2];
    for (int side = 0; side < 2; side++) {
        MPSCNNYOLOLossDescriptor *d = side ? mine : apple;
        Class lossClass = side ? lossPort : [MPSCNNLossDescriptor class];
        d.rescore = NO;
        d.scaleXY = 1.5f;
        d.scaleWH = 2.5f;
        d.scaleNoObject = 3.5f;
        d.scaleObject = 4.5f;
        d.scaleClass = 5.5f;
        d.minIOUForObjectPresence = 0.6f;
        d.maxIOUForObjectAbsence = 0.2f;
        d.numberOfAnchorBoxes = 3;
        d.anchorBoxes = floats(6, boxesTwo);
        d.reductionType = MPSCNNReductionTypeSum;
        d.XYLossDescriptor = [lossClass cnnLossDescriptorWithType:MPSCNNLossTypeHinge reductionType:MPSCNNReductionTypeSum];
        d.WHLossDescriptor = [lossClass cnnLossDescriptorWithType:MPSCNNLossTypeLog reductionType:MPSCNNReductionTypeSum];
        d.confidenceLossDescriptor = [lossClass cnnLossDescriptorWithType:MPSCNNLossTypeHuber reductionType:MPSCNNReductionTypeSum];
        d.classesLossDescriptor = [lossClass cnnLossDescriptorWithType:MPSCNNLossTypeSoftMaxCrossEntropy reductionType:MPSCNNReductionTypeSum];
    }
    compareSnapshots(yoloSnapshot(apple), yoloSnapshot(mine), @"set: every setter read back as set, with four new sub-descriptors");
    apple.reductionType = (MPSCNNReductionType)4;
    mine.reductionType = (MPSCNNReductionType)4;
    compareSnapshots(yoloSnapshot(apple), yoloSnapshot(mine), @"setter: reduction type 4 is stored as set");

    printf("  a copy: sub-descriptors copied, anchor boxes shared, and the copy kept when the original changes\n");
    MPSCNNYOLOLossDescriptor *appleCopy = [apple copy];
    MPSCNNYOLOLossDescriptor *myCopy = [mine copy];
    compareSnapshots(yoloSnapshot(appleCopy), yoloSnapshot(myCopy), @"copy: every member, the sub-descriptors included");
    check((appleCopy.XYLossDescriptor != apple.XYLossDescriptor) == (myCopy.XYLossDescriptor != mine.XYLossDescriptor),
          @"copy: the sub-descriptors are copies on both sides, not shared");
    check((appleCopy.anchorBoxes == apple.anchorBoxes) == (myCopy.anchorBoxes == mine.anchorBoxes),
          @"copy: the anchor boxes are shared on both sides");
    apple.XYLossDescriptor.weight = 7.0f;
    mine.XYLossDescriptor.weight = 7.0f;
    compareSnapshots(yoloSnapshot(appleCopy), yoloSnapshot(myCopy), @"copy: a copy's sub-descriptor keeps its weight when the original's changes");

    NSMutableDictionary *eq = [NSMutableDictionary dictionary], *peq = [NSMutableDictionary dictionary];
    equalities(eq, @"copy", apple, appleCopy);
    equalities(peq, @"copy", mine, myCopy);
    equalities(eq, @"self", apple, apple);
    equalities(peq, @"self", mine, mine);
    equalities(eq, @"unset", apple, initUnavailable([MPSCNNYOLOLossDescriptor class]));
    equalities(peq, @"unset", mine, initUnavailable(port));
    compareSnapshots(eq, peq, @"equality: a copy, the object itself, and an unset one");
}

/* ---- MPSNNNeuronDescriptor ---- */

static void neuronCases(Class port)
{
    printf("MPSNNNeuronDescriptor (11.3)\n");

    printf("  the type-only factory over every type that takes no parameters from it\n");
    int same = 1;
    static const int types[] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15 };
    for (unsigned k = 0; k < sizeof(types) / sizeof(types[0]); k++) {
        MPSNNNeuronDescriptor *apple = [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:(MPSCNNNeuronType)types[k]];
        MPSNNNeuronDescriptor *mine = [port cnnNeuronDescriptorWithType:(MPSCNNNeuronType)types[k]];
        same = sameSnapshot(neuronSnapshot(apple), neuronSnapshot(mine), [NSString stringWithFormat:@"type %d", types[k]]) && same;
    }
    check(same, @"type-only factory: the parameters default to 1, as Apple's do, for each of fifteen types");

    printf("  the factories with parameters\n");
    compareSnapshots(neuronSnapshot([MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypeReLU a:2.5f]),
                     neuronSnapshot([port cnnNeuronDescriptorWithType:MPSCNNNeuronTypeReLU a:2.5f]),
                     @"factory (type, a): b and c take 1");
    compareSnapshots(neuronSnapshot([MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypeReLUN a:2.5f b:6.5f]),
                     neuronSnapshot([port cnnNeuronDescriptorWithType:MPSCNNNeuronTypeReLUN a:2.5f b:6.5f]),
                     @"factory (type, a, b): c takes 1");
    compareSnapshots(neuronSnapshot([MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypePower a:2.5f b:6.5f c:0.5f]),
                     neuronSnapshot([port cnnNeuronDescriptorWithType:MPSCNNNeuronTypePower a:2.5f b:6.5f c:0.5f]),
                     @"factory (type, a, b, c): the three as given");
    compareSnapshots(neuronSnapshot([MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:(MPSCNNNeuronType)-1 a:1.0f b:2.0f c:3.0f]),
                     neuronSnapshot([port cnnNeuronDescriptorWithType:(MPSCNNNeuronType)-1 a:1.0f b:2.0f c:3.0f]),
                     @"factory (-1, a, b, c): a negative type is accepted");

    printf("  the PReLU factory keeps the array it is given\n");
    static const float prelu[3] = { 0.1f, 0.2f, 0.3f };
    NSData *preluData = floats(3, prelu);
    for (int noCopy = 0; noCopy <= 1; noCopy++) {
        MPSNNNeuronDescriptor *apple = [MPSNNNeuronDescriptor cnnNeuronPReLUDescriptorWithData:preluData noCopy:noCopy];
        MPSNNNeuronDescriptor *mine = [port cnnNeuronPReLUDescriptorWithData:preluData noCopy:noCopy];
        NSString *what = [NSString stringWithFormat:@"PReLU factory, noCopy %d", noCopy];
        compareSnapshots(neuronSnapshot(apple), neuronSnapshot(mine), what);
        check((apple.data == preluData) == (mine.data == preluData),
              [NSString stringWithFormat:@"%@: the data is the object given on both sides (Apple %d)", what, apple.data == preluData]);
    }

    printf("  the factories refuse what the release asserts on\n");
    refusal(@"type-only factory: PReLU",
            inChild(^{ [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypePReLU]; }) != 0,
            [port cnnNeuronDescriptorWithType:MPSCNNNeuronTypePReLU] == nil);
    refusal(@"type-only factory: type 16",
            inChild(^{ [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:(MPSCNNNeuronType)16]; }) != 0,
            [port cnnNeuronDescriptorWithType:(MPSCNNNeuronType)16] == nil);
    refusal(@"type-only factory: type 99",
            inChild(^{ [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:(MPSCNNNeuronType)99]; }) != 0,
            [port cnnNeuronDescriptorWithType:(MPSCNNNeuronType)99] == nil);
    refusal(@"factory (type, a): PReLU",
            inChild(^{ [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypePReLU a:1.0f]; }) != 0,
            [port cnnNeuronDescriptorWithType:MPSCNNNeuronTypePReLU a:1.0f] == nil);
    refusal(@"factory (type, a, b): PReLU",
            inChild(^{ [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypePReLU a:1.0f b:1.0f]; }) != 0,
            [port cnnNeuronDescriptorWithType:MPSCNNNeuronTypePReLU a:1.0f b:1.0f] == nil);
    refusal(@"factory (type, a, b, c): PReLU",
            inChild(^{ [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypePReLU a:1.0f b:1.0f c:1.0f]; }) != 0,
            [port cnnNeuronDescriptorWithType:MPSCNNNeuronTypePReLU a:1.0f b:1.0f c:1.0f] == nil);
    refusal(@"factory (type, a, b, c): type 16",
            inChild(^{ [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:(MPSCNNNeuronType)16 a:1.0f b:1.0f c:1.0f]; }) != 0,
            [port cnnNeuronDescriptorWithType:(MPSCNNNeuronType)16 a:1.0f b:1.0f c:1.0f] == nil);
    int lengthsAgree = 1;
    static const NSUInteger lengths[] = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 12 };
    for (unsigned k = 0; k < sizeof(lengths) / sizeof(lengths[0]); k++) {
        NSData *bytes = [NSMutableData dataWithLength:lengths[k]];
        int appleRefuses = inChild(^{ [MPSNNNeuronDescriptor cnnNeuronPReLUDescriptorWithData:bytes noCopy:NO]; }) != 0;
        int portRefuses = [port cnnNeuronPReLUDescriptorWithData:bytes noCopy:NO] == nil;
        if (appleRefuses != portRefuses) {
            lengthsAgree = 0;
            printf("       PReLU data of %lu bytes: apple %s it, port %s it\n", (unsigned long)lengths[k],
                   appleRefuses ? "refuses" : "accepts", portRefuses ? "refuses" : "accepts");
        }
    }
    check(lengthsAgree, @"PReLU factory: the port refuses the same data lengths as Apple, from 0 to 12 bytes (a positive multiple of four is taken)");

    printf("  an unset descriptor: -init, which the header marks NS_UNAVAILABLE\n");
    compareSnapshots(neuronSnapshot(initUnavailable([MPSNNNeuronDescriptor class])), neuronSnapshot(initUnavailable(port)),
                     @"init: a zeroed descriptor");

    printf("  setters the release does not check\n");
    MPSNNNeuronDescriptor *apple = [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypeReLU];
    MPSNNNeuronDescriptor *mine = [port cnnNeuronDescriptorWithType:MPSCNNNeuronTypeReLU];
    apple.neuronType = MPSCNNNeuronTypePReLU;
    mine.neuronType = MPSCNNNeuronTypePReLU;
    compareSnapshots(neuronSnapshot(apple), neuronSnapshot(mine), @"setter: PReLU is stored as set, without its data");
    apple.neuronType = (MPSCNNNeuronType)16;
    mine.neuronType = (MPSCNNNeuronType)16;
    compareSnapshots(neuronSnapshot(apple), neuronSnapshot(mine), @"setter: type 16 is stored as set");

    printf("  a set descriptor, its copy, and equality\n");
    NSMutableData *pd = [NSMutableData dataWithBytes:prelu length:sizeof(prelu)];
    apple = [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypeELU a:3 b:4 c:5];
    mine = [port cnnNeuronDescriptorWithType:MPSCNNNeuronTypeELU a:3 b:4 c:5];
    apple.data = pd;
    mine.data = pd;
    compareSnapshots(neuronSnapshot(apple), neuronSnapshot(mine), @"set: every member read back as set");
    check((apple.data == pd) && (mine.data == pd), @"set: the data is retained, the object given (both sides)");
    MPSNNNeuronDescriptor *appleCopy = [apple copy];
    MPSNNNeuronDescriptor *myCopy = [mine copy];
    compareSnapshots(neuronSnapshot(appleCopy), neuronSnapshot(myCopy), @"copy: every member of a set descriptor");
    check((appleCopy.data == pd) == (myCopy.data == pd),
          @"copy: a mutable data is copied on both sides, not shared");
    ((float *)pd.mutableBytes)[0] = 7.0f;
    compareSnapshots(neuronSnapshot(appleCopy), neuronSnapshot(myCopy), @"copy: the copy keeps its data when the original's array changes");
    apple.a = 30.0f;
    mine.a = 30.0f;
    check(appleCopy.a == 3.0f && myCopy.a == 3.0f, @"copy: the copy keeps its a when the original changes");
    NSData *immutable = floats(3, prelu);
    MPSNNNeuronDescriptor *appleImmutable = [MPSNNNeuronDescriptor cnnNeuronPReLUDescriptorWithData:immutable noCopy:NO];
    MPSNNNeuronDescriptor *myImmutable = [port cnnNeuronPReLUDescriptorWithData:immutable noCopy:NO];
    MPSNNNeuronDescriptor *appleImmutableCopy = [appleImmutable copy];
    MPSNNNeuronDescriptor *myImmutableCopy = [myImmutable copy];
    check((appleImmutableCopy.data == immutable) == (myImmutableCopy.data == immutable),
          @"copy: an immutable data is the same object in the copy, on both sides");
    NSMutableDictionary *eq = [NSMutableDictionary dictionary], *peq = [NSMutableDictionary dictionary];
    equalities(eq, @"copy", apple, appleCopy);
    equalities(peq, @"copy", mine, myCopy);
    equalities(eq, @"self", apple, apple);
    equalities(peq, @"self", mine, mine);
    equalities(eq, @"fresh", [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypeReLU],
               [MPSNNNeuronDescriptor cnnNeuronDescriptorWithType:MPSCNNNeuronTypeReLU]);
    equalities(peq, @"fresh", [port cnnNeuronDescriptorWithType:MPSCNNNeuronTypeReLU],
               [port cnnNeuronDescriptorWithType:MPSCNNNeuronTypeReLU]);
    compareSnapshots(eq, peq, @"equality: a copy, the object itself, and two fresh ones of one type");

    printf("  coding: the keys the release archives, round-tripped\n");
    check([MPSNNNeuronDescriptor supportsSecureCoding] == [port supportsSecureCoding],
          @"coding: both support secure coding");
    NSError *error = nil;
    NSData *appleArchive = [NSKeyedArchiver archivedDataWithRootObject:apple requiringSecureCoding:YES error:&error];
    MPSNNNeuronDescriptor *appleBack = [NSKeyedUnarchiver unarchivedObjectOfClass:[MPSNNNeuronDescriptor class] fromData:appleArchive error:&error];
    NSData *myArchive = [NSKeyedArchiver archivedDataWithRootObject:mine requiringSecureCoding:YES error:&error];
    MPSNNNeuronDescriptor *myBack = [NSKeyedUnarchiver unarchivedObjectOfClass:port fromData:myArchive error:&error];
    compareSnapshots(neuronSnapshot(appleBack), neuronSnapshot(myBack), @"coding: ELU round-trips its type and parameters, and drops data it does not read");

    MPSNNNeuronDescriptor *applePrelu = [MPSNNNeuronDescriptor cnnNeuronPReLUDescriptorWithData:preluData noCopy:NO];
    MPSNNNeuronDescriptor *myPrelu = [port cnnNeuronPReLUDescriptorWithData:preluData noCopy:NO];
    appleArchive = [NSKeyedArchiver archivedDataWithRootObject:applePrelu requiringSecureCoding:YES error:&error];
    appleBack = [NSKeyedUnarchiver unarchivedObjectOfClass:[MPSNNNeuronDescriptor class] fromData:appleArchive error:&error];
    myArchive = [NSKeyedArchiver archivedDataWithRootObject:myPrelu requiringSecureCoding:YES error:&error];
    myBack = [NSKeyedUnarchiver unarchivedObjectOfClass:port fromData:myArchive error:&error];
    compareSnapshots(neuronSnapshot(appleBack), neuronSnapshot(myBack), @"coding: PReLU round-trips its type and its data");
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        Class lossDataPort = NSClassFromString(@"CharonHostMPSCNNLossDataDescriptor");
        Class lossPort = NSClassFromString(@"CharonHostMPSCNNLossDescriptor");
        Class yoloPort = NSClassFromString(@"CharonHostMPSCNNYOLOLossDescriptor");
        Class neuronPort = NSClassFromString(@"CharonHostMPSNNNeuronDescriptor");
        check(lossDataPort != nil, @"the port's MPSCNNLossDataDescriptor is built in this process");
        check(lossPort != nil, @"the port's MPSCNNLossDescriptor is built in this process");
        check(yoloPort != nil, @"the port's MPSCNNYOLOLossDescriptor is built in this process");
        check(neuronPort != nil, @"the port's MPSNNNeuronDescriptor is built in this process");
        if (!lossDataPort || !lossPort || !yoloPort || !neuronPort)
            return 1;

        lossDataCases(lossDataPort);
        lossCases(lossPort);
        yoloCases(yoloPort, lossPort);
        neuronCases(neuronPort);
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}

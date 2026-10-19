#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>

static int failures;
static int checks;

static void check(BOOL ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", [line UTF8String]);
    else { printf("  FAIL %s\n", [line UTF8String]); failures++; }
}

static NSString *className(id object)
{
    NSString *name = NSStringFromClass([object class]);
    if ([name hasPrefix:@"CharonHost"])
        name = [name substringFromIndex:[@"CharonHost" length]];
    return name;
}

static NSString *num(NSUInteger value) { return [NSString stringWithFormat:@"%lu", (unsigned long)value]; }

static NSMutableDictionary *shape(id object)
{
    MPSCNNConvolutionDescriptor *c = (MPSCNNConvolutionDescriptor *)object;
    NSMutableDictionary *s = [NSMutableDictionary dictionary];
    s[@"class"] = className(object);
    s[@"kernelWidth"] = num(c.kernelWidth);
    s[@"kernelHeight"] = num(c.kernelHeight);
    s[@"inputFeatureChannels"] = num(c.inputFeatureChannels);
    s[@"outputFeatureChannels"] = num(c.outputFeatureChannels);
    s[@"strideInPixelsX"] = num(c.strideInPixelsX);
    s[@"strideInPixelsY"] = num(c.strideInPixelsY);
    s[@"groups"] = num(c.groups);
    s[@"dilationRateX"] = num(c.dilationRateX);
    s[@"dilationRateY"] = num(c.dilationRateY);
    s[@"neuronType"] = [NSString stringWithFormat:@"%ld", (long)c.neuronType];
    s[@"neuronParameterA"] = [NSString stringWithFormat:@"%g", c.neuronParameterA];
    s[@"neuronParameterB"] = [NSString stringWithFormat:@"%g", c.neuronParameterB];
    return s;
}

static NSMutableDictionary *depthwise(id object)
{
    NSMutableDictionary *s = shape(object);
    s[@"channelMultiplier"] = num(((MPSCNNDepthWiseConvolutionDescriptor *)object).channelMultiplier);
    return s;
}

static NSMutableDictionary *subpixel(id object)
{
    NSMutableDictionary *s = shape(object);
    s[@"subPixelScaleFactor"] = num(((MPSCNNSubPixelConvolutionDescriptor *)object).subPixelScaleFactor);
    return s;
}

static void compare(NSDictionary *apple, NSDictionary *port, NSString *moment)
{
    BOOL same = [apple isEqualToDictionary:port];
    check(same, ([NSString stringWithFormat:@"%@: the port's members read as Apple's", moment]));
    if (!same) {
        for (NSString *key in [[apple allKeys] sortedArrayUsingSelector:@selector(compare:)]) {
            if (![apple[key] isEqualToString:port[key]])
                printf("       %s: apple %s, port %s\n", [key UTF8String], [apple[key] UTF8String], [port[key] UTF8String]);
        }
    }
}

static void setShape(id object)
{
    MPSCNNConvolutionDescriptor *c = (MPSCNNConvolutionDescriptor *)object;
    c.kernelWidth = 3;
    c.kernelHeight = 5;
    c.inputFeatureChannels = 4;
    c.outputFeatureChannels = 8;
    c.strideInPixelsX = 2;
    c.strideInPixelsY = 3;
    c.groups = 1;
    c.dilationRateX = 2;
    c.dilationRateY = 4;
    [c setNeuronType:MPSCNNNeuronTypeReLU parameterA:0.5f parameterB:0.25f];
}

static void descriptorSection(NSString *title, Class apple, Class port, BOOL isSubpixel)
{
    printf("%s\n", [title UTF8String]);
    NSMutableDictionary *(*read)(id) = isSubpixel ? subpixel : depthwise;

    compare(read([[apple alloc] init]), read([[port alloc] init]), @"defaults");
    printf("  note %s: fusedNeuronDescriptor is not carried. Apple's fresh object has a non-nil MPSNNNeuronDescriptor,\n"
           "       an iOS 11.3 class the port does not have (MPSCNNElements10.m:278), so the port answers the base's nil. Not compared.\n",
           [className([apple new]) UTF8String]);

    id appleFactory = [apple cnnConvolutionDescriptorWithKernelWidth:3 kernelHeight:5 inputFeatureChannels:4 outputFeatureChannels:8];
    id portFactory = [port cnnConvolutionDescriptorWithKernelWidth:3 kernelHeight:5 inputFeatureChannels:4 outputFeatureChannels:8];
    check([portFactory isKindOfClass:port], @"factory: the port's four-argument factory answers an object of its own class");
    compare(read(appleFactory), read(portFactory), @"factory");

    id appleSet = [[apple alloc] init];
    id portSet = [[port alloc] init];
    setShape(appleSet);
    setShape(portSet);
    if (isSubpixel) {
        ((MPSCNNSubPixelConvolutionDescriptor *)appleSet).subPixelScaleFactor = 2;
        ((MPSCNNSubPixelConvolutionDescriptor *)portSet).subPixelScaleFactor = 2;
    }
    compare(read(appleSet), read(portSet), @"set");

    id appleCopy = [appleSet copy];
    id portCopy = [portSet copy];
    compare(read(appleCopy), read(portCopy), @"copy");
    check([className(portCopy) isEqualToString:className(portSet)], @"copy: the port's copy is of the port's class");
    check([appleCopy isEqual:appleSet] == NO && [portCopy isEqual:portSet] == NO,
          @"copy: a copy is not equal to its original on either side (both use object identity)");
    check([appleSet isEqual:appleSet] && [portSet isEqual:portSet], @"copy: an object is equal to itself on both sides");
    NSDictionary *appleBefore = read(appleCopy), *portBefore = read(portCopy);
    ((MPSCNNConvolutionDescriptor *)appleSet).kernelWidth = 9;
    ((MPSCNNConvolutionDescriptor *)portSet).kernelWidth = 9;
    if (isSubpixel) {
        ((MPSCNNSubPixelConvolutionDescriptor *)appleSet).subPixelScaleFactor = 1;
        ((MPSCNNSubPixelConvolutionDescriptor *)portSet).subPixelScaleFactor = 1;
    }
    compare(appleBefore, read(appleCopy), @"copy after the original changed (apple's copy)");
    compare(portBefore, read(portCopy), @"copy after the original changed (port's copy)");

    check([[apple new] isEqual:[apple new]] == NO && [[port new] isEqual:[port new]] == NO,
          @"equality: two fresh objects are not equal, on either side");
    check([[apple new] isEqual:appleSet] == NO && [[port new] isEqual:portSet] == NO,
          @"equality: a fresh object is not equal to a set one, on either side");

    if (!isSubpixel) {
        NSUInteger pairs[][2] = {{1, 1}, {4, 8}, {4, 4}, {4, 6}, {6, 4}, {3, 4}, {4, 12}, {0, 4}};
        NSUInteger expect[] = {1, 2, 1, 1, 0, 1, 3, 0};
        for (NSUInteger i = 0; i < sizeof(expect) / sizeof(expect[0]); i++) {
            id a = [[apple alloc] init];
            id p = [[port alloc] init];
            ((MPSCNNConvolutionDescriptor *)a).inputFeatureChannels = pairs[i][0];
            ((MPSCNNConvolutionDescriptor *)a).outputFeatureChannels = pairs[i][1];
            ((MPSCNNConvolutionDescriptor *)p).inputFeatureChannels = pairs[i][0];
            ((MPSCNNConvolutionDescriptor *)p).outputFeatureChannels = pairs[i][1];
            NSUInteger appleValue = ((MPSCNNDepthWiseConvolutionDescriptor *)a).channelMultiplier;
            NSUInteger portValue = ((MPSCNNDepthWiseConvolutionDescriptor *)p).channelMultiplier;
            check(appleValue == expect[i] && portValue == expect[i],
                  ([NSString stringWithFormat:@"channelMultiplier(in %lu, out %lu): apple %lu, port %lu, measured %lu",
                    (unsigned long)pairs[i][0], (unsigned long)pairs[i][1], (unsigned long)appleValue,
                    (unsigned long)portValue, (unsigned long)expect[i]]));
        }
    }

    NSError *error = nil;
    NSData *appleData = [NSKeyedArchiver archivedDataWithRootObject:appleCopy requiringSecureCoding:YES error:&error];
    NSError *appleError = error;
    error = nil;
    NSData *portData = [NSKeyedArchiver archivedDataWithRootObject:portCopy requiringSecureCoding:YES error:&error];
    NSError *portError = error;
    error = nil;
    id appleBack = appleData ? [NSKeyedUnarchiver unarchivedObjectOfClass:apple fromData:appleData error:&error] : nil;
    NSError *appleBackError = error;
    error = nil;
    id portBack = portData ? [NSKeyedUnarchiver unarchivedObjectOfClass:port fromData:portData error:&error] : nil;
    NSError *portBackError = error;
    check(appleBack != nil && portBack != nil, @"coding: both sides round-trip a secure archive");
    if (!appleBack || !portBack)
        printf("       apple: archive %s, unarchive %s\n       port:  archive %s, unarchive %s\n",
               appleError ? [[appleError description] UTF8String] : "ok",
               appleBackError ? [[appleBackError description] UTF8String] : "ok",
               portError ? [[portError description] UTF8String] : "ok",
               portBackError ? [[portBackError description] UTF8String] : "ok");
    if (appleBack && portBack) {
        NSMutableDictionary *a = read(appleBack), *p = read(portBack);
        for (NSString *key in @[@"neuronType", @"neuronParameterA", @"neuronParameterB"]) {
            [a removeObjectForKey:key];
            [p removeObjectForKey:key];
        }
        compare(a, p, @"coding (shape, factor and multiplier)");
    }
}

typedef id (*PaddingFactory)(Class);

static id averageFor(Class padding) { return [padding paddingForTensorflowAveragePooling]; }
static id validOnlyFor(Class padding) { return [padding paddingForTensorflowAveragePoolingValidOnly]; }

static BOOL sameObjectEachCall(Class padding, PaddingFactory make)
{
    return make(padding) == make(padding);
}

static NSString *policyLine(id policy)
{
    return [NSString stringWithFormat:@"paddingMethod 0x%lx, label %@", (unsigned long)[policy paddingMethod], [policy label]];
}

static NSString *destinationLine(id policy, id<MTLDevice> device, NSUInteger sourceW, NSUInteger sourceH,
                                 NSUInteger suggestedW, NSUInteger suggestedH, NSUInteger window, NSUInteger stride)
{
    MPSCNNPoolingAverage *pool = [[MPSCNNPoolingAverage alloc] initWithDevice:device kernelWidth:window kernelHeight:window
                                                              strideInPixelsX:stride strideInPixelsY:stride];
    MPSImageDescriptor *sourceDescriptor = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                          width:sourceW height:sourceH featureChannels:1];
    MPSImage *source = [[MPSImage alloc] initWithDevice:device imageDescriptor:sourceDescriptor];
    MPSImageDescriptor *suggested = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32
                                                                                   width:suggestedW height:suggestedH featureChannels:1];
    MPSOffset before = pool.offset;
    NSUInteger edgeBefore = pool.edgeMode;
    MPSImageDescriptor *returned = [policy destinationImageDescriptorForSourceImages:@[source] sourceStates:nil
                                                                           forKernel:pool suggestedDescriptor:suggested];
    MPSOffset after = pool.offset;
    return [NSString stringWithFormat:@"source %lux%lu, suggested %lux%lu, window %lu stride %lu: returns the suggested object %d, "
            @"size %lux%lu, edgeMode %lu->%lu, offset (%ld,%ld)->(%ld,%ld)",
            (unsigned long)sourceW, (unsigned long)sourceH, (unsigned long)suggestedW, (unsigned long)suggestedH,
            (unsigned long)window, (unsigned long)stride, returned == suggested,
            (unsigned long)returned.width, (unsigned long)returned.height,
            (unsigned long)edgeBefore, (unsigned long)pool.edgeMode,
            (long)before.x, (long)before.y, (long)after.x, (long)after.y];
}

static void baseSection(Class apple, Class port)
{
    printf("MPSCNNConvolutionDescriptor (base, plain init)\n");
    compare(shape([[apple alloc] init]), shape([[port alloc] init]), @"defaults");
    check(([[[apple alloc] init] fusedNeuronDescriptor] != nil) == ([[[port alloc] init] fusedNeuronDescriptor] != nil),
          @"fusedNeuronDescriptor is non-nil on both sides for a plain init");
}

static void paddingSection(NSString *title, PaddingFactory make, id<MTLDevice> device, Class port)
{
    printf("%s\n", [title UTF8String]);
    Class apple = [MPSNNDefaultPadding class];
    id applePolicy = make(apple);
    id portPolicy = make(port);
    check(applePolicy != nil && portPolicy != nil, @"factory: both sides answer an object");
    if (!applePolicy || !portPolicy) return;

    check([applePolicy isKindOfClass:apple] && [portPolicy isKindOfClass:port],
          @"factory: both answer an MPSNNDefaultPadding (the port's is a subclass of its own base)");
    NSString *a = policyLine(applePolicy), *p = policyLine(portPolicy);
    check([a isEqualToString:p], @"policy: the port's paddingMethod and label read as Apple's");
    if (![a isEqualToString:p])
        printf("       apple: %s\n       port:  %s\n", [a UTF8String], [p UTF8String]);
    else
        printf("       measured: %s\n", [a UTF8String]);
    check(sameObjectEachCall(apple, make) && sameObjectEachCall(port, make),
          @"sharing: each side answers the same object on every call");

    struct { NSUInteger sw, sh, gw, gh, window, stride; } cases[] = {
        {3, 3, 3, 3, 2, 2}, {3, 3, 2, 2, 2, 2}, {5, 5, 5, 5, 3, 1}, {5, 5, 4, 4, 3, 1}, {7, 7, 3, 3, 3, 2},
    };
    for (NSUInteger i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
        NSString *ap = destinationLine(applePolicy, device, cases[i].sw, cases[i].sh, cases[i].gw, cases[i].gh, cases[i].window, cases[i].stride);
        NSString *pp = destinationLine(portPolicy, device, cases[i].sw, cases[i].sh, cases[i].gw, cases[i].gh, cases[i].window, cases[i].stride);
        check([ap isEqualToString:pp], [NSString stringWithFormat:@"destination: %@", ap]);
        if (![ap isEqualToString:pp])
            printf("       apple: %s\n       port:  %s\n", [ap UTF8String], [pp UTF8String]);
    }
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        Class portDepthwise = NSClassFromString(@"CharonHostMPSCNNDepthWiseConvolutionDescriptor");
        Class portSubpixel = NSClassFromString(@"CharonHostMPSCNNSubPixelConvolutionDescriptor");
        Class portPadding = NSClassFromString(@"CharonHostMPSNNDefaultPadding");
        check(portDepthwise != nil, @"the port's depthwise class is built in this process");
        check(portSubpixel != nil, @"the port's sub-pixel class is built in this process");
        Class portBase = NSClassFromString(@"CharonHostMPSCNNConvolutionDescriptor");
        check(portBase != nil, @"the port's base convolution class is built in this process");
        if (!portBase)
            return 1;
        baseSection([MPSCNNConvolutionDescriptor class], portBase);
        check(portPadding != nil, @"the port's padding class is built in this process");
        if (!portDepthwise || !portSubpixel || !portPadding)
            return 1;

        descriptorSection(@"MPSCNNDepthWiseConvolutionDescriptor (iOS 11.0)", [MPSCNNDepthWiseConvolutionDescriptor class],
                          portDepthwise, NO);
        descriptorSection(@"MPSCNNSubPixelConvolutionDescriptor (iOS 11.0)", [MPSCNNSubPixelConvolutionDescriptor class],
                          portSubpixel, YES);

        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        check(device != nil, @"a Metal device answers on this host (the destinations need an MPSImage)");
        if (device) {
            paddingSection(@"MPSNNDefaultPadding +paddingForTensorflowAveragePooling (11.0 by the 11.0 cache, header ios(11.3))",
                           averageFor, device, portPadding);
            paddingSection(@"MPSNNDefaultPadding +paddingForTensorflowAveragePoolingValidOnly (11.3)",
                           validOnlyFor, device, portPadding);
        }
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}

/* descriptor.m - MTLTileRenderPipelineDescriptor (iOS 11.0), compared property by property with Apple's own object.
 *
 * Four moments are compared, each as a snapshot of the members both sides can be asked without harm: a fresh
 * descriptor, one with its settable members set away from their defaults, the same one after -reset, and a copy
 * of the set one. A disagreement names the member and both values.
 *
 * TILE BUFFERS ARE NOT IN THE SNAPSHOT, and Apple's are never touched by this case. Measured on the macOS host
 * (tests/backports/host/tile-render-pipeline-descriptor/run.sh, the "apple-tile-reset" child): once Apple's
 * tileBuffers has been read or set, its -reset crashes the process, so a differential that reset Apple's object
 * after touching its tile buffers would measure a crash, not a default. The port's tile buffers are checked by
 * their own expectations below instead, and the child proves the crash is Apple's.
 *
 * NO DEVICE IS CREATED. A descriptor asks a device nothing (facts/Metal/DeviceOnThisMachine.md). The tile function
 * is a device's object, so it is never set and reads as nil on both sides.
 */
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

static int failures;
static int checks;

static void check(int ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", [line UTF8String]);
    else { printf("  FAIL %s\n", [line UTF8String]); failures++; }
}

static NSString *describeBool(BOOL b) { return b ? @"YES" : @"NO"; }

static NSDictionary *snapshot(MTLTileRenderPipelineDescriptor *d)
{
    NSMutableDictionary *s = [NSMutableDictionary dictionary];
    s[@"label"] = d.label ?: @"(nil)";
    s[@"tileFunction"] = d.tileFunction ? @"set" : @"(nil)";
    s[@"rasterSampleCount"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.rasterSampleCount];
    s[@"colorAttachments[0].pixelFormat"] = [NSString stringWithFormat:@"%ld", (long)[d.colorAttachments objectAtIndexedSubscript:0].pixelFormat];
    s[@"colorAttachments[1].pixelFormat"] = [NSString stringWithFormat:@"%ld", (long)[d.colorAttachments objectAtIndexedSubscript:1].pixelFormat];
    s[@"threadgroupSizeMatchesTileSize"] = describeBool(d.threadgroupSizeMatchesTileSize);
    s[@"maxTotalThreadsPerThreadgroup"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxTotalThreadsPerThreadgroup];
    s[@"binaryArchives"] = d.binaryArchives ? @"set" : @"(nil)";
    s[@"preloadedLibraries"] = d.preloadedLibraries ? [NSString stringWithFormat:@"%lu", (unsigned long)d.preloadedLibraries.count] : @"(nil)";
    s[@"linkedFunctions"] = d.linkedFunctions ? @"set" : @"(nil)";
    s[@"supportAddingBinaryFunctions"] = describeBool(d.supportAddingBinaryFunctions);
    s[@"maxCallStackDepth"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxCallStackDepth];
    s[@"shaderValidation"] = [NSString stringWithFormat:@"%ld", (long)d.shaderValidation];
    MTLSize r = d.requiredThreadsPerThreadgroup;
    s[@"requiredThreadsPerThreadgroup"] = [NSString stringWithFormat:@"%ld,%ld,%ld", (long)r.width, (long)r.height, (long)r.depth];
    return s;
}

/* Sets every settable member away from its default, except the tile buffers (see the file's comment). */
static void setEverything(MTLTileRenderPipelineDescriptor *d)
{
    d.label = @"charon";
    d.rasterSampleCount = 4;
    [[d.colorAttachments objectAtIndexedSubscript:1] setPixelFormat:MTLPixelFormatRGBA8Unorm];
    d.threadgroupSizeMatchesTileSize = YES;
    d.maxTotalThreadsPerThreadgroup = 128;
    d.preloadedLibraries = @[];
    d.supportAddingBinaryFunctions = YES;
    d.maxCallStackDepth = 3;
    d.shaderValidation = MTLShaderValidationEnabled;
    d.requiredThreadsPerThreadgroup = MTLSizeMake(8, 8, 1);
}

static void compareSides(MTLTileRenderPipelineDescriptor *apple, MTLTileRenderPipelineDescriptor *port, NSString *moment)
{
    NSDictionary *a = snapshot(apple), *p = snapshot(port);
    int same = [a isEqualToDictionary:p];
    check(same, ([NSString stringWithFormat:@"%@: the port's members read as Apple's", moment]));
    if (!same) {
        for (NSString *key in [a.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
            if (![a[key] isEqualToString:p[key]])
                printf("       %s: apple %s, port %s\n", [key UTF8String], [a[key] UTF8String], [p[key] UTF8String]);
        }
    }
}

int main(int argc, char **argv)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "apple-tile-reset") == 0) {
            /* The child: Apple's tile buffers touched, then -reset. Apple's process is expected to die here. */
            MTLTileRenderPipelineDescriptor *apple = [[MTLTileRenderPipelineDescriptor alloc] init];
            MTLPipelineBufferDescriptor *slot = [[MTLPipelineBufferDescriptor alloc] init];
            [apple.tileBuffers setObject:slot atIndexedSubscript:2];
            [apple reset];
            printf("Apple's -reset returned\n");
            return 0;
        }

        Class portClass = NSClassFromString(@"CharonHostMTLTileRenderPipelineDescriptor");
        Class portBuffer = NSClassFromString(@"CharonHostMTLPipelineBufferDescriptor");
        check(portClass != nil && portBuffer != nil, @"the port's classes are built in this process");
        if (!portClass || !portBuffer)
            return 1;

        MTLTileRenderPipelineDescriptor *apple = [[MTLTileRenderPipelineDescriptor alloc] init];
        MTLTileRenderPipelineDescriptor *port = [[portClass alloc] init];
        printf("a fresh descriptor\n");
        compareSides(apple, port, @"fresh");

        printf("the settable members set away from their defaults\n");
        setEverything(apple);
        setEverything(port);
        compareSides(apple, port, @"set");

        printf("after -reset\n");
        [apple reset];
        [port reset];
        compareSides(apple, port, @"reset");

        printf("a copy of the set descriptor\n");
        setEverything(apple);
        setEverything(port);
        compareSides(
            [apple copy], [port copy], @"copy");

        printf("the port's tile buffers, against Apple's own answers where Apple can be asked\n");
        MTLPipelineBufferDescriptor *mine = [[MTLPipelineBufferDescriptor alloc] init];
        mine.mutability = MTLMutabilityMutable;
        MTLTileRenderPipelineDescriptor *tiles = [[portClass alloc] init];
        [tiles.tileBuffers setObject:mine atIndexedSubscript:2];
        check([tiles.tileBuffers objectAtIndexedSubscript:2].mutability == MTLMutabilityMutable,
              @"port: a tile buffer set at slot 2 reads back with its mutability");
        check([tiles.tileBuffers objectAtIndexedSubscript:0].mutability == MTLMutabilityDefault,
              @"port: an unset tile buffer slot answers a default descriptor");
        MTLTileRenderPipelineDescriptor *tilesCopy = [tiles copy];
        check([tilesCopy.tileBuffers objectAtIndexedSubscript:2].mutability == MTLMutabilityMutable &&
              [tilesCopy.tileBuffers objectAtIndexedSubscript:2] != [tiles.tileBuffers objectAtIndexedSubscript:2],
              @"port: the copy keeps the tile buffer's mutability and owns its own descriptor");
        [tiles reset];
        check([tiles.tileBuffers objectAtIndexedSubscript:2].mutability == MTLMutabilityDefault,
              @"port: -reset gives the tile buffer slot back its default mutability");
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}

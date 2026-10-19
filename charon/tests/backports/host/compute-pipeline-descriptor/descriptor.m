/* descriptor.m - MTLComputePipelineDescriptor, compared property by property against Apple's own object.
 *
 * Four moments are compared, each as a snapshot of every readable member on both sides: a fresh
 * descriptor, one with every settable member set away from its default, the same one after -reset, and a
 * copy of the set one. A snapshot is a dictionary of member name to its description, so a disagreement names
 * the member and both values.
 *
 * NO DEVICE IS CREATED. A descriptor asks a device nothing (facts/Metal/DeviceOnThisMachine.md), and the
 * compute function, which is a device's object, is never set, so its member is read as nil on both sides.
 *
 * The port's class is reached by the name run.sh gives it (CharonHost<Name>) because its object file is
 * built beside Apple's Metal in this process. The mutant in run.sh changes -reset and must turn the reset
 * snapshot red.
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

/* Every readable member of the descriptor, as a string, so the two sides can be compared whole. */
static NSDictionary *snapshot(MTLComputePipelineDescriptor *d)
{
    NSMutableDictionary *s = [NSMutableDictionary dictionary];
    s[@"label"] = d.label ?: @"(nil)";
    s[@"computeFunction"] = d.computeFunction ? @"set" : @"(nil)";
    s[@"threadGroupSizeIsMultipleOfThreadExecutionWidth"] = describeBool(d.threadGroupSizeIsMultipleOfThreadExecutionWidth);
    s[@"maxTotalThreadsPerThreadgroup"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxTotalThreadsPerThreadgroup];
    s[@"stageInputDescriptor"] = d.stageInputDescriptor ? @"set" : @"(nil)";
    s[@"buffers"] = d.buffers ? @"set" : @"(nil)";
    s[@"buffers[0].mutability"] = [NSString stringWithFormat:@"%ld", (long)[d.buffers objectAtIndexedSubscript:0].mutability];
    s[@"buffers[2].mutability"] = [NSString stringWithFormat:@"%ld", (long)[d.buffers objectAtIndexedSubscript:2].mutability];
    s[@"supportIndirectCommandBuffers"] = describeBool(d.supportIndirectCommandBuffers);
    s[@"insertLibraries"] = d.insertLibraries ? [NSString stringWithFormat:@"%lu", (unsigned long)d.insertLibraries.count] : @"(nil)";
    s[@"preloadedLibraries"] = d.preloadedLibraries ? [NSString stringWithFormat:@"%lu", (unsigned long)d.preloadedLibraries.count] : @"(nil)";
    s[@"binaryArchives"] = d.binaryArchives ? @"set" : @"(nil)";
    s[@"linkedFunctions"] = d.linkedFunctions ? @"set" : @"(nil)";
    s[@"supportAddingBinaryFunctions"] = describeBool(d.supportAddingBinaryFunctions);
    s[@"maxCallStackDepth"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxCallStackDepth];
    s[@"shaderValidation"] = [NSString stringWithFormat:@"%ld", (long)d.shaderValidation];
    MTLSize r = d.requiredThreadsPerThreadgroup;
    s[@"requiredThreadsPerThreadgroup"] = [NSString stringWithFormat:@"%ld,%ld,%ld", (long)r.width, (long)r.height, (long)r.depth];
    return s;
}

/* Sets every settable member away from its default, on whichever side it is given. */
static void setEverything(MTLComputePipelineDescriptor *d, Class slotClass)
{
    d.label = @"charon";
    d.threadGroupSizeIsMultipleOfThreadExecutionWidth = YES;
    d.maxTotalThreadsPerThreadgroup = 256;
    d.supportIndirectCommandBuffers = YES;
    d.supportAddingBinaryFunctions = YES;
    d.maxCallStackDepth = 4;
    d.shaderValidation = MTLShaderValidationEnabled;
    d.requiredThreadsPerThreadgroup = MTLSizeMake(4, 2, 1);
    MTLPipelineBufferDescriptor *slot = [[slotClass alloc] init];
    slot.mutability = MTLMutabilityMutable;
    [d.buffers setObject:slot atIndexedSubscript:2];
}

/* The four moments for one side, compared with the other side's. */
static void compareSides(MTLComputePipelineDescriptor *apple, MTLComputePipelineDescriptor *port, NSString *moment)
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

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        Class portClass = NSClassFromString(@"CharonHostMTLComputePipelineDescriptor");
        check(portClass != nil, @"the port's class is built in this process");
        if (!portClass)
            return 1;

        MTLComputePipelineDescriptor *apple = [[MTLComputePipelineDescriptor alloc] init];
        MTLComputePipelineDescriptor *port = [[portClass alloc] init];
        printf("a fresh descriptor\n");
        compareSides(apple, port, @"fresh");

        printf("every settable member set away from its default\n");
        setEverything(apple, [MTLPipelineBufferDescriptor class]);
        setEverything(port, NSClassFromString(@"CharonHostMTLPipelineBufferDescriptor"));
        compareSides(apple, port, @"set");

        printf("after -reset\n");
        [apple reset];
        [port reset];
        compareSides(apple, port, @"reset");

        printf("a copy of the set descriptor\n");
        setEverything(apple, [MTLPipelineBufferDescriptor class]);
        setEverything(port, NSClassFromString(@"CharonHostMTLPipelineBufferDescriptor"));
        MTLComputePipelineDescriptor *appleCopy = [apple copy];
        MTLComputePipelineDescriptor *portCopy = [port copy];
        compareSides(appleCopy, portCopy, @"copy");
        check(portCopy != port && [portCopy buffers] != [port buffers],
              @"the port's copy owns its nested buffers, so it is not the original");
        check([[portCopy buffers] objectAtIndexedSubscript:2] != [[port buffers] objectAtIndexedSubscript:2],
              @"the port's copy holds its own buffer descriptor, not the original's");
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}

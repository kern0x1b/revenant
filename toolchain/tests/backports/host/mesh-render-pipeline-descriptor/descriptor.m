#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <sys/wait.h>
#include <unistd.h>

static int failures;
static int checks;

static void check(int ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", [line UTF8String]);
    else { printf("  FAIL %s\n", [line UTF8String]); failures++; }
}

static NSString *describeBool(BOOL b) { return b ? @"YES" : @"NO"; }

static NSDictionary *snapshot(MTLMeshRenderPipelineDescriptor *d)
{
    NSMutableDictionary *s = [NSMutableDictionary dictionary];
    s[@"label"] = d.label ?: @"(nil)";
    s[@"objectFunction"] = d.objectFunction ? @"set" : @"(nil)";
    s[@"meshFunction"] = d.meshFunction ? @"set" : @"(nil)";
    s[@"fragmentFunction"] = d.fragmentFunction ? @"set" : @"(nil)";
    s[@"maxTotalThreadsPerObjectThreadgroup"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxTotalThreadsPerObjectThreadgroup];
    s[@"maxTotalThreadsPerMeshThreadgroup"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxTotalThreadsPerMeshThreadgroup];
    s[@"objectThreadgroupSizeIsMultipleOfThreadExecutionWidth"] = describeBool(d.objectThreadgroupSizeIsMultipleOfThreadExecutionWidth);
    s[@"meshThreadgroupSizeIsMultipleOfThreadExecutionWidth"] = describeBool(d.meshThreadgroupSizeIsMultipleOfThreadExecutionWidth);
    s[@"payloadMemoryLength"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.payloadMemoryLength];
    s[@"maxTotalThreadgroupsPerMeshGrid"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxTotalThreadgroupsPerMeshGrid];
    s[@"objectBuffers[2].mutability"] = [NSString stringWithFormat:@"%ld", (long)[d.objectBuffers objectAtIndexedSubscript:2].mutability];
    s[@"meshBuffers[30].mutability"] = [NSString stringWithFormat:@"%ld", (long)[d.meshBuffers objectAtIndexedSubscript:30].mutability];
    s[@"fragmentBuffers[0].mutability"] = [NSString stringWithFormat:@"%ld", (long)[d.fragmentBuffers objectAtIndexedSubscript:0].mutability];
    s[@"rasterSampleCount"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.rasterSampleCount];
    s[@"alphaToCoverageEnabled"] = describeBool(d.alphaToCoverageEnabled);
    s[@"alphaToOneEnabled"] = describeBool(d.alphaToOneEnabled);
    s[@"rasterizationEnabled"] = describeBool(d.rasterizationEnabled);
    s[@"maxVertexAmplificationCount"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxVertexAmplificationCount];
    s[@"colorAttachments[1].pixelFormat"] = [NSString stringWithFormat:@"%ld", (long)[d.colorAttachments objectAtIndexedSubscript:1].pixelFormat];
    s[@"colorAttachments[1].blendingEnabled"] = describeBool([d.colorAttachments objectAtIndexedSubscript:1].blendingEnabled);
    s[@"colorAttachments[0].pixelFormat"] = [NSString stringWithFormat:@"%ld", (long)[d.colorAttachments objectAtIndexedSubscript:0].pixelFormat];
    s[@"depthAttachmentPixelFormat"] = [NSString stringWithFormat:@"%ld", (long)d.depthAttachmentPixelFormat];
    s[@"stencilAttachmentPixelFormat"] = [NSString stringWithFormat:@"%ld", (long)d.stencilAttachmentPixelFormat];
    s[@"supportIndirectCommandBuffers"] = describeBool(d.supportIndirectCommandBuffers);
    s[@"binaryArchives"] = d.binaryArchives ? [NSString stringWithFormat:@"%lu", (unsigned long)d.binaryArchives.count] : @"(nil)";
    s[@"objectLinkedFunctions"] = d.objectLinkedFunctions ? @"set" : @"(nil)";
    s[@"meshLinkedFunctions"] = d.meshLinkedFunctions ? @"set" : @"(nil)";
    s[@"fragmentLinkedFunctions"] = d.fragmentLinkedFunctions ? @"set" : @"(nil)";
    s[@"shaderValidation"] = [NSString stringWithFormat:@"%ld", (long)d.shaderValidation];
    MTLSize a = d.requiredThreadsPerObjectThreadgroup, m = d.requiredThreadsPerMeshThreadgroup;
    s[@"requiredThreadsPerObjectThreadgroup"] = [NSString stringWithFormat:@"%lux%lux%lu", (unsigned long)a.width, (unsigned long)a.height, (unsigned long)a.depth];
    s[@"requiredThreadsPerMeshThreadgroup"] = [NSString stringWithFormat:@"%lux%lux%lu", (unsigned long)m.width, (unsigned long)m.height, (unsigned long)m.depth];
    return s;
}

static void setEverything(MTLMeshRenderPipelineDescriptor *d)
{
    d.label = @"revenant";
    d.maxTotalThreadsPerObjectThreadgroup = 32;
    d.maxTotalThreadsPerMeshThreadgroup = 48;
    d.objectThreadgroupSizeIsMultipleOfThreadExecutionWidth = YES;
    d.meshThreadgroupSizeIsMultipleOfThreadExecutionWidth = YES;
    d.payloadMemoryLength = 64;
    d.maxTotalThreadgroupsPerMeshGrid = 7;
    [d.objectBuffers objectAtIndexedSubscript:2].mutability = MTLMutabilityMutable;
    [d.meshBuffers objectAtIndexedSubscript:30].mutability = MTLMutabilityMutable;
    [d.fragmentBuffers objectAtIndexedSubscript:0].mutability = MTLMutabilityImmutable;
    d.rasterSampleCount = 4;
    d.alphaToCoverageEnabled = YES;
    d.alphaToOneEnabled = YES;
    d.rasterizationEnabled = NO;
    d.maxVertexAmplificationCount = 2;
    [d.colorAttachments objectAtIndexedSubscript:1].pixelFormat = MTLPixelFormatRGBA8Unorm;
    [d.colorAttachments objectAtIndexedSubscript:1].blendingEnabled = YES;
    d.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    d.stencilAttachmentPixelFormat = MTLPixelFormatStencil8;
    d.supportIndirectCommandBuffers = YES;
    d.binaryArchives = @[];
    d.objectLinkedFunctions = [[MTLLinkedFunctions alloc] init];
    d.shaderValidation = MTLShaderValidationEnabled;
    d.requiredThreadsPerObjectThreadgroup = MTLSizeMake(8, 4, 2);
    d.requiredThreadsPerMeshThreadgroup = MTLSizeMake(16, 1, 1);
}

static void compareSides(MTLMeshRenderPipelineDescriptor *apple, MTLMeshRenderPipelineDescriptor *port, NSString *moment)
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

typedef void (^Change)(MTLMeshRenderPipelineDescriptor *d);

static NSArray *equalityRow(Class cls)
{
    NSArray<Change> *changes = @[
        ^(MTLMeshRenderPipelineDescriptor *d) { d.label = @"x"; },
        ^(MTLMeshRenderPipelineDescriptor *d) { d.rasterSampleCount = 4; },
        ^(MTLMeshRenderPipelineDescriptor *d) { d.shaderValidation = MTLShaderValidationEnabled; },
        ^(MTLMeshRenderPipelineDescriptor *d) { d.requiredThreadsPerMeshThreadgroup = MTLSizeMake(1, 1, 1); },
        ^(MTLMeshRenderPipelineDescriptor *d) { [d.colorAttachments objectAtIndexedSubscript:1].pixelFormat = MTLPixelFormatRGBA8Unorm; },
        ^(MTLMeshRenderPipelineDescriptor *d) { [d.objectBuffers objectAtIndexedSubscript:2].mutability = MTLMutabilityMutable; },
        ^(MTLMeshRenderPipelineDescriptor *d) { d.supportIndirectCommandBuffers = YES; },
        ^(MTLMeshRenderPipelineDescriptor *d) { d.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float; },
        ^(MTLMeshRenderPipelineDescriptor *d) { d.objectLinkedFunctions = [[MTLLinkedFunctions alloc] init]; },
        ^(MTLMeshRenderPipelineDescriptor *d) { d.binaryArchives = @[]; },
    ];
    NSMutableArray *row = [NSMutableArray array];
    for (Change change in changes) {
        MTLMeshRenderPipelineDescriptor *a = [[cls alloc] init];
        MTLMeshRenderPipelineDescriptor *b = [[cls alloc] init];
        change(b);
        [row addObject:@([a isEqual:b])];
    }
    MTLMeshRenderPipelineDescriptor *fresh = [[cls alloc] init];
    [row addObject:@([fresh isEqual:[[cls alloc] init]])];
    return row;
}

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

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        Class portClass = NSClassFromString(@"RevenantHostMTLMeshRenderPipelineDescriptor");
        check(portClass != nil, @"the port's class is built in this process");
        if (!portClass)
            return 1;

        printf("a fresh descriptor\n");
        compareSides([[MTLMeshRenderPipelineDescriptor alloc] init], [[portClass alloc] init], @"fresh");

        printf("every member set away from its default\n");
        MTLMeshRenderPipelineDescriptor *apple = [[MTLMeshRenderPipelineDescriptor alloc] init];
        MTLMeshRenderPipelineDescriptor *port = [[portClass alloc] init];
        setEverything(apple);
        setEverything(port);
        compareSides(apple, port, @"set");

        printf("a copy of the set descriptor\n");
        MTLMeshRenderPipelineDescriptor *appleCopy = [apple copy];
        MTLMeshRenderPipelineDescriptor *portCopy = [port copy];
        compareSides(appleCopy, portCopy, @"copy");
        check([portCopy isEqual:port] && [port isEqual:portCopy] && [port hash] == [portCopy hash],
              @"port: a copy is equal to its original, and hashes the same");
        check([appleCopy isEqual:apple], @"apple: a copy is equal to its original");

        printf("after -reset\n");
        id appleBuffers = apple.objectBuffers, appleColours = apple.colorAttachments;
        id portBuffers = port.objectBuffers, portColours = port.colorAttachments;
        [apple reset];
        [port reset];
        compareSides(apple, port, @"reset");
        check((apple.objectBuffers != appleBuffers) == (port.objectBuffers != portBuffers),
              @"-reset gives the buffer array a new object on both sides, or keeps it on both");
        check((apple.colorAttachments != appleColours) == (port.colorAttachments != portColours),
              @"-reset gives the colour array a new object on both sides, or keeps it on both");
        check(appleCopy.objectBuffers != apple.objectBuffers && portCopy.objectBuffers != port.objectBuffers,
              @"a copy keeps its own buffer array after the original is reset");

        printf("equality, one change at a time from a fresh descriptor (Apple's answers are the expected ones)\n");
        NSArray *appleRow = equalityRow(MTLMeshRenderPipelineDescriptor.class);
        NSArray *portRow = equalityRow(portClass);
        check([appleRow isEqualToArray:portRow], @"the port's equality answers, row by row, as Apple's");
        if (![appleRow isEqualToArray:portRow])
            printf("       apple %s\n       port  %s\n", [[appleRow description] UTF8String], [[portRow description] UTF8String]);

        printf("the buffer slot past the last one, read in child processes (Apple's aborts)\n");
        int appleStatus = inChild(^{ MTLMeshRenderPipelineDescriptor *a = [[MTLMeshRenderPipelineDescriptor alloc] init]; (void)[a.objectBuffers objectAtIndexedSubscript:31]; });
        int portStatus = inChild(^{ MTLMeshRenderPipelineDescriptor *p = [[portClass alloc] init]; (void)[p.objectBuffers objectAtIndexedSubscript:31]; });
        check((appleStatus == 0) == (portStatus == 0), @"reading buffer slot 31 aborts on both sides, or on neither");
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}

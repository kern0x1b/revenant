/* descriptor.m - MTLIndirectCommandBufferDescriptor (iOS 12.0), compared member by member with Apple's own object.
 *
 * Four snapshots are compared, as in the other descriptor cases: a fresh descriptor, one with every member set away
 * from its default, a copy of that one, and the original after the copy was taken (the copy must not share).
 * Equality and the hash are compared the same way. A disagreement names the member and both values.
 *
 * NOTHING IS VALIDATED, measured on the host: a command type with bits Apple does not name, and a bind count far past
 * any device's, are read back as set on both sides. That is checked with the same values on both sides below.
 *
 * NO DEVICE IS CREATED. An indirect command buffer descriptor asks a device nothing.
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

static NSDictionary *snapshot(MTLIndirectCommandBufferDescriptor *d)
{
    NSMutableDictionary *s = [NSMutableDictionary dictionary];
    s[@"commandTypes"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.commandTypes];
    s[@"inheritPipelineState"] = describeBool(d.inheritPipelineState);
    s[@"inheritBuffers"] = describeBool(d.inheritBuffers);
    s[@"inheritDepthStencilState"] = describeBool(d.inheritDepthStencilState);
    s[@"inheritDepthBias"] = describeBool(d.inheritDepthBias);
    s[@"inheritDepthClipMode"] = describeBool(d.inheritDepthClipMode);
    s[@"inheritCullMode"] = describeBool(d.inheritCullMode);
    s[@"inheritFrontFacingWinding"] = describeBool(d.inheritFrontFacingWinding);
    s[@"inheritTriangleFillMode"] = describeBool(d.inheritTriangleFillMode);
    s[@"maxVertexBufferBindCount"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxVertexBufferBindCount];
    s[@"maxFragmentBufferBindCount"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxFragmentBufferBindCount];
    s[@"maxKernelBufferBindCount"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxKernelBufferBindCount];
    s[@"maxKernelThreadgroupMemoryBindCount"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxKernelThreadgroupMemoryBindCount];
    s[@"maxObjectBufferBindCount"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxObjectBufferBindCount];
    s[@"maxMeshBufferBindCount"] = [NSString stringWithFormat:@"%lu", (unsigned long)d.maxMeshBufferBindCount];
    return s;
}

/* Sets every member away from its default. */
static void setEverything(MTLIndirectCommandBufferDescriptor *d)
{
    d.commandTypes = MTLIndirectCommandTypeDraw | MTLIndirectCommandTypeDrawIndexed;
    d.inheritPipelineState = NO;
    d.inheritBuffers = NO;
    d.inheritDepthStencilState = NO;
    d.inheritDepthBias = NO;
    d.inheritDepthClipMode = NO;
    d.inheritCullMode = NO;
    d.inheritFrontFacingWinding = NO;
    d.inheritTriangleFillMode = NO;
    d.maxVertexBufferBindCount = 4;
    d.maxFragmentBufferBindCount = 5;
    d.maxKernelBufferBindCount = 6;
    d.maxKernelThreadgroupMemoryBindCount = 7;
    d.maxObjectBufferBindCount = 8;
    d.maxMeshBufferBindCount = 9;
}

static void compareSides(MTLIndirectCommandBufferDescriptor *apple, MTLIndirectCommandBufferDescriptor *port, NSString *moment)
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
        Class portClass = NSClassFromString(@"CharonHostMTLIndirectCommandBufferDescriptor");
        check(portClass != nil, @"the port's class is built in this process");
        if (!portClass)
            return 1;

        printf("a fresh descriptor (init and new)\n");
        compareSides([[MTLIndirectCommandBufferDescriptor alloc] init], [[portClass alloc] init], @"fresh");
        compareSides([MTLIndirectCommandBufferDescriptor new], [portClass new], @"new");

        printf("every member set away from its default\n");
        MTLIndirectCommandBufferDescriptor *apple = [[MTLIndirectCommandBufferDescriptor alloc] init];
        MTLIndirectCommandBufferDescriptor *port = [[portClass alloc] init];
        setEverything(apple);
        setEverything(port);
        compareSides(apple, port, @"set");

        printf("a copy of the set descriptor\n");
        MTLIndirectCommandBufferDescriptor *appleCopy = [apple copy];
        MTLIndirectCommandBufferDescriptor *portCopy = [port copy];
        compareSides(appleCopy, portCopy, @"copy");
        check([portCopy isEqual:port] && [port isEqual:portCopy] && [port hash] == [portCopy hash],
              @"port: a copy is equal to its original, and hashes the same");
        check(![port isEqual:[[portClass alloc] init]], @"port: a set descriptor is not equal to a fresh one");
        check(![apple isEqual:[[MTLIndirectCommandBufferDescriptor alloc] init]], @"apple: a set descriptor is not equal to a fresh one");

        printf("the copy does not share with the original\n");
        apple.maxVertexBufferBindCount = 40;
        port.maxVertexBufferBindCount = 40;
        compareSides(appleCopy, portCopy, @"copy after the original changed");
        check(![portCopy isEqual:port], @"port: the copy keeps its own bind count once the original changed");

        printf("values Apple does not validate read back as set on both sides\n");
        apple.commandTypes = (MTLIndirectCommandType)(1UL << 40);
        port.commandTypes = (MTLIndirectCommandType)(1UL << 40);
        apple.maxFragmentBufferBindCount = 99999;
        port.maxFragmentBufferBindCount = 99999;
        compareSides(apple, port, @"unnamed command bit and a large bind count");
    }
    printf("checks=%d failures=%d\n", checks, failures);
    return failures ? 1 : 0;
}

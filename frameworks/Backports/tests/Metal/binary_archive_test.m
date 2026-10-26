#import "../Foundation/check.h"
#import <Metal/Metal.h>
#import "RevenantMetalBinaryArchive.h"

static id revenant_archive(id<MTLDevice> device, NSURL *url, NSError **error)
{
    MTLBinaryArchiveDescriptor *descriptor = [[MTLBinaryArchiveDescriptor alloc] init];
    descriptor.url = url;
    return [[RevenantMetalBinaryArchive alloc] initWithDevice:device descriptor:descriptor error:error];
}

static id revenant_host_archive(id<MTLDevice> device, NSURL *url, NSError **error)
{
    MTLBinaryArchiveDescriptor *descriptor = [[MTLBinaryArchiveDescriptor alloc] init];
    descriptor.url = url;
    return [device newBinaryArchiveWithDescriptor:descriptor error:error];
}

static void revenant_compare_error(const char *name, NSError *host, NSError *backport)
{
    revenant_check(host.domain == backport.domain && host.code == backport.code, name,
                   [NSString stringWithFormat:@"%@/%ld != %@/%ld", host.domain, (long)host.code, backport.domain, (long)backport.code]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    revenant_check((NSClassFromString(@"RevenantMetalBinaryArchive") != Nil) != revenant_negative, "the archive class is present", @"RevenantMetalBinaryArchive");

    id<MTLDevice> device = MTLCreateSystemDefaultDevice();
    revenant_check(device != nil, "the host has a Metal device", @"no device");
    if (!device)
        return revenant_finish();

    NSString *source = @"#include <metal_stdlib>\nusing namespace metal;\n"
        "vertex float4 vmain(uint vid [[vertex_id]]) { return float4(0); }\n"
        "fragment float4 fmain() { return float4(1); }\n"
        "kernel void kmain(device float *x [[buffer(0)]], uint id [[thread_position_in_grid]]) { x[id] = 1; }\n";
    NSError *error = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:source options:nil error:&error];
    revenant_check(library != nil, "the test library compiles", error.localizedDescription ?: @"no library");
    if (!library)
        return revenant_finish();
    id<MTLFunction> vertex = [library newFunctionWithName:@"vmain"];
    id<MTLFunction> fragment = [library newFunctionWithName:@"fmain"];
    id<MTLFunction> kernel = [library newFunctionWithName:@"kmain"];

    error = nil;
    id hostEmpty = revenant_host_archive(device, nil, &error);
    id backportEmpty = revenant_archive(device, nil, &error);
    revenant_check(hostEmpty != nil && backportEmpty != nil, "an empty archive is created", [NSString stringWithFormat:@"%@ %@", hostEmpty, backportEmpty]);
    revenant_check([[backportEmpty device] isEqual:device], "the archive reports its device", NSStringFromClass([backportEmpty class]));
    revenant_check([backportEmpty label] == nil && [hostEmpty label] == nil, "the label starts empty as on the host", [NSString stringWithFormat:@"%@ %@", [hostEmpty label], [backportEmpty label]]);
    [backportEmpty setLabel:@"telegram"];
    revenant_expect_string("the label round trips", [backportEmpty label], @"telegram");

    NSURL *missing = [NSURL fileURLWithPath:@"/tmp/revenant-binary-archive-missing-does-not-exist.archive"];
    error = nil;
    id hostMissing = revenant_host_archive(device, missing, &error);
    NSError *hostMissingError = error;
    error = nil;
    id backportMissing = revenant_archive(device, missing, &error);
    revenant_check(hostMissing == nil && backportMissing == nil, "a missing file gives no archive", [NSString stringWithFormat:@"%@ %@", hostMissing, backportMissing]);
    revenant_compare_error("a missing file reports the host's error", hostMissingError, error);

    NSString *directory = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *garbagePath = [directory stringByAppendingPathComponent:@"revenant-binary-archive-garbage.bin"];
    [@"not an archive" writeToFile:garbagePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSURL *garbage = [NSURL fileURLWithPath:garbagePath];
    error = nil;
    id hostGarbage = revenant_host_archive(device, garbage, &error);
    NSError *hostGarbageError = error;
    error = nil;
    id backportGarbage = revenant_archive(device, garbage, &error);
    revenant_check(hostGarbage == nil && backportGarbage == nil, "a file that is not an archive gives no archive", [NSString stringWithFormat:@"%@ %@", hostGarbage, backportGarbage]);
    revenant_compare_error("a file that is not an archive reports the host's error", hostGarbageError, error);

    MTLRenderPipelineDescriptor *render = [[MTLRenderPipelineDescriptor alloc] init];
    render.vertexFunction = vertex;
    render.fragmentFunction = fragment;
    render.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    MTLComputePipelineDescriptor *compute = [[MTLComputePipelineDescriptor alloc] init];
    compute.computeFunction = kernel;

    id<MTLBinaryArchive> hostArchive = hostEmpty;
    id<MTLBinaryArchive> backportArchive = backportEmpty;
    error = nil;
    BOOL hostAdded = [hostArchive addRenderPipelineFunctionsWithDescriptor:render error:&error];
    NSError *hostAddError = error;
    error = nil;
    BOOL backportAdded = [backportArchive addRenderPipelineFunctionsWithDescriptor:render error:&error];
    revenant_check(hostAdded == backportAdded && backportAdded, "a render pipeline is added as on the host", error.localizedDescription ?: @"added");
    revenant_check(hostAddError == nil, "the host adds the render pipeline without error", hostAddError.localizedDescription ?: @"no error");
    error = nil;
    revenant_check([backportArchive addRenderPipelineFunctionsWithDescriptor:render error:&error] && error == nil, "a repeated render pipeline is accepted", error.localizedDescription ?: @"repeated");

    error = nil;
    BOOL hostCompute = [hostArchive addComputePipelineFunctionsWithDescriptor:compute error:&error];
    error = nil;
    BOOL backportCompute = [backportArchive addComputePipelineFunctionsWithDescriptor:compute error:&error];
    revenant_check(hostCompute == backportCompute && backportCompute, "a compute pipeline is added as on the host", error.localizedDescription ?: @"added");

    NSURL *hostOut = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"revenant-binary-archive-host.archive"]];
    NSURL *backportOut = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"revenant-binary-archive-backport.archive"]];
    [[NSFileManager defaultManager] removeItemAtURL:hostOut error:nil];
    [[NSFileManager defaultManager] removeItemAtURL:backportOut error:nil];
    error = nil;
    BOOL hostSerialized = [hostArchive serializeToURL:hostOut error:&error];
    error = nil;
    BOOL backportSerialized = [backportArchive serializeToURL:backportOut error:&error];
    NSError *backportSerializeError = error;
    revenant_check(hostSerialized && backportSerialized, "the archive is written", backportSerializeError.localizedDescription ?: @"written");
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:backportOut.path error:nil];
    revenant_check(attributes.fileSize > 0, "the written archive is not empty", [NSString stringWithFormat:@"%llu bytes", attributes.fileSize]);

    error = nil;
    id reopened = revenant_archive(device, backportOut, &error);
    revenant_check(reopened != nil && error == nil, "the written archive opens again", error.localizedDescription ?: @"no archive");
    error = nil;
    revenant_check([reopened addRenderPipelineFunctionsWithDescriptor:render error:&error] && error == nil, "the reopened archive accepts the pipeline it held", error.localizedDescription ?: @"rejected");
    revenant_check([reopened label] == nil, "a reopened archive has no label, as on the host", [NSString stringWithFormat:@"%@", [reopened label]]);

    NSURL *unwritable = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:@"revenant-no-such-directory/child.archive"]];
    error = nil;
    BOOL hostUnwritable = [hostArchive serializeToURL:unwritable error:&error];
    NSError *hostUnwritableError = error;
    error = nil;
    BOOL backportUnwritable = [backportArchive serializeToURL:unwritable error:&error];
    revenant_check(!hostUnwritable && !backportUnwritable, "writing into a missing directory fails as on the host", [NSString stringWithFormat:@"%d %d", hostUnwritable, backportUnwritable]);
    revenant_compare_error("writing into a missing directory reports the host's error", hostUnwritableError, error);

    NSString *zeroPath = [directory stringByAppendingPathComponent:@"revenant-binary-archive-zero.bin"];
    [[NSData data] writeToFile:zeroPath atomically:YES];
    error = nil;
    id backportZero = revenant_archive(device, [NSURL fileURLWithPath:zeroPath], &error);
    revenant_check(backportZero == nil && error != nil, "a zero-byte file gives no archive", [NSString stringWithFormat:@"%@", backportZero]);

    [[NSFileManager defaultManager] removeItemAtPath:directory error:NULL];
    return revenant_finish();
}

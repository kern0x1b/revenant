#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <Metal/MTLDynamicLibrary.h>

// link-probe.m - which of the fixture's kernels Apple's own compiler will LINK, one at a time.
//
// compare.sh asks for the whole fixture at once: one dynamic library, one serializeToURL:. When that
// fails, the message names the failure and not the kernel, and "the differential has nothing to
// compare" is all a reader gets -- which is what left the cause open. This program takes one Metal
// source per argument, compiles it the way oracle.m compiles the fixture (MTLLibraryTypeDynamic) and
// then asks for the dynamic library the oracle's step 3 asks for, and prints one line per file:
//
//     ok   <path> dynamic library
//     FAIL <path> <what Metal said>
//
// The two steps are separated because they fail differently and only the second one has: a kernel can
// compile and still not link, and a run that reports only the first would call that a compile error.
//
// Usage: link-probe.m one.metal [two.metal ...]

static void probe(id<MTLDevice> device, NSString *path)
{
    NSError *error = nil;
    NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (source == nil) {
        printf("FAIL %s cannot be read: %s\n", path.lastPathComponent.UTF8String,
               error.localizedDescription.UTF8String);
        fflush(stdout);
        return;
    }
    MTLCompileOptions *options = [MTLCompileOptions new];
    options.libraryType = MTLLibraryTypeDynamic;
    options.installName = @"charon.air2cpu.oracle";
    id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&error];
    if (library == nil) {
        printf("FAIL %s compile: %s\n", path.lastPathComponent.UTF8String,
               error.localizedDescription.UTF8String);
        fflush(stdout);
        return;
    }
    error = nil;
    id<MTLDynamicLibrary> dynamic = [device newDynamicLibrary:library error:&error];
    if (dynamic == nil) {
        printf("FAIL %s dynamic library: %s\n", path.lastPathComponent.UTF8String,
               error.localizedDescription.UTF8String);
        fflush(stdout);
        return;
    }
    printf("ok   %s dynamic library named %s\n", path.lastPathComponent.UTF8String,
           dynamic.installName.UTF8String);
    fflush(stdout);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (device == nil) {
            printf("FAIL no MTLDevice on this host, so no kernel can be probed\n");
            return 1;
        }
        printf("note device %s, %d kernel(s) from argv\n", [[device name] UTF8String], argc - 1);
        for (int index = 1; index < argc; index++)
            probe(device, [NSString stringWithUTF8String:argv[index]]);
    }
    return 0;
}
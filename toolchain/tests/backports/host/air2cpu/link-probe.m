#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <Metal/MTLDynamicLibrary.h>

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

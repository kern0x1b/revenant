#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <Metal/MTLDynamicLibrary.h>
#import <Metal/MTLBinaryArchive.h>
int main(void) {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        NSError *error = nil;
        NSString *source = [NSString stringWithContentsOfFile:@"orders.metal" encoding:NSUTF8StringEncoding error:&error];
        if (!source) { printf("no source: %s\n", error.localizedDescription.UTF8String); return 2; }
        MTLCompileOptions *options = [MTLCompileOptions new];
        options.libraryType = MTLLibraryTypeDynamic;
        options.installName = @"charon.orders";
        id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&error];
        if (!library) { printf("REFUSED: %s\n", error.localizedDescription.UTF8String); return 2; }
        id<MTLDynamicLibrary> dynamic = [device newDynamicLibrary:library error:&error];
        if (!dynamic) { printf("NO DYNAMIC: %s\n", error.localizedDescription.UTF8String); return 1; }
        if (![dynamic serializeToURL:[NSURL fileURLWithPath:@"orders.metallib"] error:&error]) {
            printf("NOT SERIALIZED: %s\n", error.localizedDescription.UTF8String); return 1;
        }
        printf("WROTE orders.metallib\n");
    }
    return 0;
}

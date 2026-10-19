// build.m — compile one Metal Shading Language file at run time and write the metallib.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <Metal/MTLDynamicLibrary.h>
int main(int argc, const char **argv) {
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        NSError *error = nil;
        NSString *source = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]
                                                encoding:NSUTF8StringEncoding error:&error];
        if (!source) { printf("no source: %s\n", error.localizedDescription.UTF8String); return 2; }
        MTLCompileOptions *options = [MTLCompileOptions new];
        options.libraryType = MTLLibraryTypeDynamic;
        options.installName = @"charon.orders";
        id<MTLLibrary> library = [device newLibraryWithSource:source options:options error:&error];
        if (!library) { printf("REFUSED %s: %s\n", argv[1], error.localizedDescription.UTF8String); return 2; }
        id<MTLDynamicLibrary> dynamic = [device newDynamicLibrary:library error:&error];
        if (!dynamic) { printf("NO DYNAMIC %s: %s\n", argv[1], error.localizedDescription.UTF8String); return 1; }
        NSString *out = [NSString stringWithUTF8String:argv[1]];
        out = [out stringByReplacingOccurrencesOfString:@".metal" withString:@".metallib"];
        if (![dynamic serializeToURL:[NSURL fileURLWithPath:out] error:&error]) {
            printf("NOT SERIALIZED %s: %s\n", argv[1], error.localizedDescription.UTF8String); return 1; }
        printf("WROTE %s\n", out.UTF8String);
    }
    return 0;
}

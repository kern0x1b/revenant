#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

int main(int argc, const char *argv[])
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        printf("device.present=%d\n", device != nil);
        if (!device)
            return 2;
        for (int i = 1; i < argc; i++) {
            NSString *path = [NSString stringWithUTF8String:argv[i]];
            NSError *error = nil;
            id<MTLLibrary> library = [device newLibraryWithURL:[NSURL fileURLWithPath:path] error:&error];
            printf("path=%s\n", argv[i]);
            printf("  library.present=%d\n", library != nil);
            if (!library) {
                printf("  error=%s\n", error ? [[error localizedDescription] UTF8String] : "(nil)");
                continue;
            }
            NSString *installName = library.installName;
            printf("  library.installName=%s\n", installName ? [installName UTF8String] : "(nil)");
            printf("  library.type=%ld\n", (long)library.type);
            printf("  library.functionNames=%s\n",
                   [[[library functionNames] componentsJoinedByString:@","] UTF8String]);
        }
    }
    return 0;
}

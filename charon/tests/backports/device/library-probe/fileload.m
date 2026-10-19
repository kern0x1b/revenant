/* fileload.m - what the host answers for a library LOADED FROM A FILE, the case the port serves. The port builds its
 * libraries from a metallib file (newLibraryWithURL: and newLibraryWithFile: read the translated LIB.metallib.es2
 * beside it), so the install name of a library from a file is the one the port must match. library.m asks the
 * same questions of a library built from source, which is the other kind.
 *
 *     host:  clang -fobjc-arc -framework Foundation -framework Metal fileload.m -o fileload
 *            ./fileload PATH [PATH ...]
 *
 * One line per answer per path: the path as given, then its install name (nil spelled out), its type, its
 * function names, and whether the load succeeded. The host's metallib is Apple's own, so the answer is Apple's.
 */
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

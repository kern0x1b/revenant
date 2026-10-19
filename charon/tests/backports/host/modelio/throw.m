#import <Foundation/Foundation.h>
#import <ModelIO/ModelIO.h>
#include <stdio.h>
/* What a reader did with each file: raised, or loaded and with how many meshes. The refusal test has to see
   WHICH, and the log line alone cannot tell them apart - a reader that logs loudly and returns nil and one
   that loads a mesh print the same thing to stderr unless the outcome is stated as well. */
int main(int argc, char **argv)
{
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            @try {
                MDLAsset *a = [[MDLAsset alloc] initWithURL:[NSURL fileURLWithPath:@(argv[i])]];
                printf("%s LOADED meshes=%lu\n", argv[i], (unsigned long)a.count);
            } @catch (NSException *e) {
                printf("%s THREW %s: %s\n", argv[i], e.name.UTF8String, e.reason.UTF8String);
            }
        }
    }
    return 0;
}

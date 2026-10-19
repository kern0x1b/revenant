#import <Foundation/Foundation.h>
#import <ModelIO/ModelIO.h>
#include <stdio.h>
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

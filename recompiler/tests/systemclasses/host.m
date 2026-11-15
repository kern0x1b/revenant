#import <Foundation/Foundation.h>
#include <stdio.h>
#include <unistd.h>

#include "xl_guest_image.h"
#include "xl_loader.h"

int main(int argc, char **argv)
{
    alarm(60);
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "usage: host LIBRARY\n");
            return 2;
        }
        if (xl_reserve(argv[1]) != XL_LOAD_OK || xl_load(argv[1]) != XL_LOAD_OK) {
            printf("FAIL load %s\n", xl_load_error());
            return 1;
        }
        Class cls = NSClassFromString(@"SCFixture");
        if (!cls) {
            printf("FAIL class\n");
            return 1;
        }
        for (NSString *line in [cls performSelector:@selector(run)])
            printf("%s\n", line.UTF8String);
        printf("done\n");
        fflush(stdout);
    }
    return 0;
}

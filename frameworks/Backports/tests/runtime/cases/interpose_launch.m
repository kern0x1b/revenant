#import "../app/revenant_check.h"
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <string.h>
#import <unistd.h>

#define REVENANT_INTERPOSED_PPID 4242

REVENANT_CASE(interpose_launch)
{
    const struct mach_header *probe = NULL;
    for (uint32_t index = 0; index < _dyld_image_count() && probe == NULL; index++) {
        const char *name = _dyld_get_image_name(index);
        if (name != NULL && strstr(name, "libRevenantInterposeProbe.dylib") != NULL) {
            probe = _dyld_get_image_header(index);
        }
    }
    unsigned long size = 0;
    const void *section = probe != NULL ? getsectiondata((const struct mach_header *)probe, "__DATA", "__interpose", &size) : NULL;
    revenant_expect_true(@"the interpose probe is loaded at launch with its __DATA,__interpose section",
                         probe != NULL && section != NULL, @"the probe image or its section is missing");
    int ppid = getppid();
    revenant_expect_true(@"a __DATA,__interpose tuple in an image linked at launch redirects the main executable's getppid call",
                         (ppid == REVENANT_INTERPOSED_PPID) != (BOOL)negative,
                         [NSString stringWithFormat:@"getppid returned %d, interposed value is %d", ppid, REVENANT_INTERPOSED_PPID]);
}

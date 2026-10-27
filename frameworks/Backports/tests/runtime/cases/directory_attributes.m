#import "../app/revenant_check.h"
#import <Foundation/Foundation.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <sys/attr.h>
#include <unistd.h>

REVENANT_CASE(directory_attributes)
{
    NSString *directory = negative ? @"/nonexistent-revenant-directory" : [NSBundle mainBundle].bundlePath;
    struct attrlist request = { ATTR_BIT_MAP_COUNT, 0, ATTR_CMN_NAME | ATTR_CMN_OBJTYPE, 0, 0, 0, 0 };
    char buffer[4096];
    unsigned long count = 16, base = 0, state = 0;
    int descriptor = open([directory fileSystemRepresentation], O_RDONLY);
    int openError = errno;
    revenant_expect_integer(@"the bundle directory opens", descriptor >= 0 ? 1 : -openError, 1);
    errno = 0;
    int listed = descriptor >= 0 ? getdirentriesattr(descriptor, &request, buffer, sizeof buffer, &count, &base, &state, 0) : -1;
    int listingError = errno;
    if (descriptor >= 0)
        close(descriptor);
    revenant_expect_integer(@"the bundle directory lists through getdirentriesattr", listed >= 0 ? 1 : -listingError, 1);
    BOOL found = NO;
    if (listed >= 0) {
        char *cursor = buffer;
        for (unsigned long index = 0; index < count; index++) {
            uint32_t length = 0;
            memcpy(&length, cursor, sizeof length);
            attrreference_t name;
            memcpy(&name, cursor + sizeof length, sizeof name);
            if (length == 0)
                break;
            if (strcmp(cursor + sizeof length + name.attr_dataoffset, "Info.plist") == 0)
                found = YES;
            cursor += length;
        }
    }
    revenant_expect_integer(@"the listing names the bundle's Info.plist", found ? 1 : 0, 1);
}

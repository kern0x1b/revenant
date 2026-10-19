#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

struct row {
    const char *name;
    NSString *const *value;
};

static const struct row table[] = {
#include "table.inc"
};

int main(void)
{
    @autoreleasepool {
        for (unsigned i = 0; i < sizeof(table) / sizeof(table[0]); i++) {
            NSString *value = *table[i].value;
            const char *utf8 = value ? [value UTF8String] : NULL;
            printf("%-72s = %s\n", table[i].name, utf8 ? utf8 : "(null)");
            printf("%-72s   bytes:", table[i].name);
            if (!utf8) {
                printf(" (no UTF-8: the value is not valid UTF-8)");
            } else {
                for (const unsigned char *p = (const unsigned char *)utf8; *p; p++) {
                    printf(" %02x", *p);
                }
            }
            printf("\n");
        }
        printf("rows: %u\n", (unsigned)(sizeof(table) / sizeof(table[0])));
    }
    return 0;
}

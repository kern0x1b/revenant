//
//  probe-constants.m
//  The 47 metadata key-space, coordinated-playback and player-rate constants, read out of whichever
//  build this binary is.
//
//  One program, linked twice by run.sh. Linked plain, every name below is Apple's own exported
//  symbol and the values are the host's. Linked with the rename list and the port's four sources,
//  the same names are the port's own definitions and the same table is read out of them. The two
//  tables are diffed, so a difference is a difference in the port's file and not in the question.
//
//  The names are reached through &symbol, not dlsym: the rename rewrites the reference, so this file
//  needs no knowledge of which build it is in, and a name the port does not define is a link error
//  rather than a row that quietly reads as absent.
//

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
            // The bytes are printed after the text, and that is the guard the commit claimed and did
            // not have. The text alone is not enough: -UTF8String answers NULL for a value that is
            // not valid UTF-8, so a value with one bad byte prints "(null)" - and if the host's own
            // value were non-UTF-8 too, both sides would print "(null)" and the row would agree with
            // the two values being the same. The byte line says what the bytes actually are, and
            // together with the text it is what makes "every one of these is pure printable ASCII and
            // decodes byte for byte to its printed text" a check rather than a claim.
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

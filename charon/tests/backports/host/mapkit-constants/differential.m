// The comparison probe for tests/backports/host/mapkit-constants/run.sh. The names themselves are
// generated into probe.h beside this file, one function per name, each holding the port's own value
// (renamed to charonHost_*) beside Apple's (the unrenamed symbol, which the host's own
// MapKit.framework answers for). This file is only the comparison and the report.
#import <Foundation/Foundation.h>
#import <stdio.h>
#include "probe.h"

static int failures = 0;
static int checked = 0;

void charonCompareString(NSString *symbol, NSString *ours, NSString *theirs)
{
    checked++;
    if (theirs == nil) {
        printf("FAIL %s: the host's own MapKit does not export the name, so the value the port carries is not Apple's\n",
               [symbol UTF8String]);
        failures++;
        return;
    }
    if (ours == nil) {
        printf("FAIL %s: the port carries nothing where the host's own MapKit carries \"%s\"\n",
               [symbol UTF8String], [theirs UTF8String]);
        failures++;
        return;
    }
    if (![ours isEqualToString:theirs]) {
        printf("FAIL %s: the port carries \"%s\", the host's own MapKit carries \"%s\"\n",
               [symbol UTF8String], [ours UTF8String], [theirs UTF8String]);
        failures++;
        return;
    }
    printf("ok %s = \"%s\"\n", [symbol UTF8String], [theirs UTF8String]);
}

void charonCompareNumber(NSString *symbol, double ours, double theirs)
{
    checked++;
    if (ours != theirs) {
        printf("FAIL %s: the port carries %.17g, the host's own MapKit carries %.17g\n",
               [symbol UTF8String], ours, theirs);
        failures++;
        return;
    }
    printf("ok %s = %.17g\n", [symbol UTF8String], theirs);
}

int main(void)
{
    for (unsigned index = 0; index < charonCount; index++) {
        charonChecks[index]();
    }
    fflush(stdout);
    printf("%d constants, %d failures\n", checked, failures);
    return failures == 0 ? 0 : 1;
}

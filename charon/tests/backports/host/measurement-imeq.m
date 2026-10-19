#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <stdio.h>
static void P(const char *f, ...) { va_list a; va_start(a, f); vprintf(f, a); va_end(a); }
int main(void) { @autoreleasepool {
    Class formatter = NSClassFromString(@"NSMeasurementFormatter");
    IMP objectIsEqual = class_getMethodImplementation([NSObject class], @selector(isEqual:));
    IMP objectHash = class_getMethodImplementation([NSObject class], @selector(hash));
    IMP oursIsEqual = class_getMethodImplementation(formatter, @selector(isEqual:));
    IMP oursHash = class_getMethodImplementation(formatter, @selector(hash));
    P("isEqual: NSObject %p  NSMeasurementFormatter %p  the same: %d\n", objectIsEqual, oursIsEqual, objectIsEqual == oursIsEqual);
    P("hash     NSObject %p  NSMeasurementFormatter %p  the same: %d\n", objectHash, oursHash, objectHash == oursHash);
    P("so -isEqual: and -hash are NSObject's: %d\n", (objectIsEqual == oursIsEqual) && (objectHash == oursHash));
} return 0; }

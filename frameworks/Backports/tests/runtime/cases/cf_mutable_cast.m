#import "../app/revenant_check.h"
#import <CoreFoundation/CoreFoundation.h>

static void revenant_cast_check(NSString *label, id value, const char *name, int negative)
{
    Class bound = revenant_backport_class("Foundation", name);
    Class system = NSClassFromString([NSString stringWithUTF8String:name]);
    BOOL cast = bound == system && [value isKindOfClass:bound] && ![NSStringFromClass([value class]) hasPrefix:@"Revenant"];
    revenant_expect_true(label, cast != (BOOL)negative,
                         [NSString stringWithFormat:@"bound %@ %p, system %p, value %@", bound, (__bridge void *)bound, (__bridge void *)system, [value class]]);
}

REVENANT_CASE(cf_mutable_cast)
{
    CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    revenant_cast_check(@"CFMutableDictionary is an NSMutableDictionary of the class the Backports library binds", (__bridge id)dictionary,
                        "NSMutableDictionary", negative);
    CFRelease(dictionary);

    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    revenant_cast_check(@"CFMutableArray is an NSMutableArray of the class the Backports library binds", (__bridge id)array,
                        "NSMutableArray", negative);
    CFRelease(array);

    CFMutableStringRef string = CFStringCreateMutable(kCFAllocatorDefault, 0);
    revenant_cast_check(@"CFMutableString is an NSMutableString of the class the Backports library binds", (__bridge id)string,
                        "NSMutableString", negative);
    CFRelease(string);

    CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, 0);
    revenant_cast_check(@"CFMutableData is an NSMutableData of the class the Backports library binds", (__bridge id)data,
                        "NSMutableData", negative);
    CFRelease(data);

    CFMutableSetRef set = CFSetCreateMutable(kCFAllocatorDefault, 0, &kCFTypeSetCallBacks);
    revenant_cast_check(@"CFMutableSet is an NSMutableSet of the class the Backports library binds", (__bridge id)set,
                        "NSMutableSet", negative);
    CFRelease(set);

    Class null = revenant_backport_class("Foundation", "NSNull");
    BOOL singleton = (id)kCFNull == [null null] && null == NSClassFromString(@"NSNull");
    revenant_expect_true(@"the NSNull the Backports library binds yields kCFNull", singleton != (BOOL)negative,
                         @"the null singleton comes from the device, not a proxy");
}

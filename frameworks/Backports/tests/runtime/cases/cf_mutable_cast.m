#import "../app/revenant_check.h"
#import <CoreFoundation/CoreFoundation.h>

static void revenant_cast_check(NSString *label, id value, Class expected, Class named, int negative)
{
    BOOL cast = [value isKindOfClass:expected] && named == expected && ![NSStringFromClass([value class]) hasPrefix:@"Revenant"];
    revenant_expect_true(label, cast != (BOOL)negative,
                         [NSString stringWithFormat:@"class %@, named %@, value %@", expected, named, [value class]]);
}

REVENANT_CASE(cf_mutable_cast)
{
    CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    revenant_cast_check(@"CFMutableDictionary is an NSMutableDictionary", (__bridge id)dictionary,
                        [NSMutableDictionary class], NSClassFromString(@"NSMutableDictionary"), negative);
    CFRelease(dictionary);

    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    revenant_cast_check(@"CFMutableArray is an NSMutableArray", (__bridge id)array,
                        [NSMutableArray class], NSClassFromString(@"NSMutableArray"), negative);
    CFRelease(array);

    CFMutableStringRef string = CFStringCreateMutable(kCFAllocatorDefault, 0);
    revenant_cast_check(@"CFMutableString is an NSMutableString", (__bridge id)string,
                        [NSMutableString class], NSClassFromString(@"NSMutableString"), negative);
    CFRelease(string);

    CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, 0);
    revenant_cast_check(@"CFMutableData is an NSMutableData", (__bridge id)data,
                        [NSMutableData class], NSClassFromString(@"NSMutableData"), negative);
    CFRelease(data);

    CFMutableSetRef set = CFSetCreateMutable(kCFAllocatorDefault, 0, &kCFTypeSetCallBacks);
    revenant_cast_check(@"CFMutableSet is an NSMutableSet", (__bridge id)set,
                        [NSMutableSet class], NSClassFromString(@"NSMutableSet"), negative);
    CFRelease(set);

    BOOL null = (id)kCFNull == [NSNull null] && [NSNull class] == NSClassFromString(@"NSNull");
    revenant_expect_true(@"[NSNull null] is kCFNull", null != (BOOL)negative,
                         @"the null singleton comes from the device, not a proxy");
}

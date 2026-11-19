#import "../app/revenant_check.h"
#import <CoreFoundation/CoreFoundation.h>

static void revenant_cast_check(NSString *label, id value, Class expected, Class named)
{
    revenant_expect_true(label, [value isKindOfClass:expected] && [value class] == named && named == expected,
                         [NSString stringWithFormat:@"class %@, named %@, value %@", expected, named, [value class]]);
}

REVENANT_CASE(cf_mutable_cast)
{
    CFMutableDictionaryRef dictionary = CFDictionaryCreateMutable(kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    revenant_cast_check(@"CFMutableDictionary is NSMutableDictionary", (__bridge id)dictionary,
                        [NSMutableDictionary class], NSClassFromString(@"NSMutableDictionary"));
    CFRelease(dictionary);

    CFMutableArrayRef array = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    revenant_cast_check(@"CFMutableArray is NSMutableArray", (__bridge id)array,
                        [NSMutableArray class], NSClassFromString(@"NSMutableArray"));
    CFRelease(array);

    CFMutableStringRef string = CFStringCreateMutable(kCFAllocatorDefault, 0);
    revenant_cast_check(@"CFMutableString is NSMutableString", (__bridge id)string,
                        [NSMutableString class], NSClassFromString(@"NSMutableString"));
    CFRelease(string);

    CFMutableDataRef data = CFDataCreateMutable(kCFAllocatorDefault, 0);
    revenant_cast_check(@"CFMutableData is NSMutableData", (__bridge id)data,
                        [NSMutableData class], NSClassFromString(@"NSMutableData"));
    CFRelease(data);

    CFMutableSetRef set = CFSetCreateMutable(kCFAllocatorDefault, 0, &kCFTypeSetCallBacks);
    revenant_cast_check(@"CFMutableSet is NSMutableSet", (__bridge id)set,
                        [NSMutableSet class], NSClassFromString(@"NSMutableSet"));
    CFRelease(set);

    revenant_expect_true(@"[NSNull null] is kCFNull", (id)kCFNull == [NSNull null] && [NSNull class] == NSClassFromString(@"NSNull"),
                         @"the null singleton comes from the device, not a proxy");
}

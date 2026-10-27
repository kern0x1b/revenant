#import <Foundation/Foundation.h>
#import <Security/Security.h>

void RevenantSecKeyFail(CFErrorRef *error, OSStatus status, NSString *description)
{
    if (!error) {
        return;
    }
    *error = CFErrorCreate(kCFAllocatorDefault, (__bridge CFStringRef)NSOSStatusErrorDomain, status,
                           (__bridge CFDictionaryRef)@{@"NSDescription": description});
}

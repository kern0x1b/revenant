#import <Foundation/Foundation.h>
#import <Security/Security.h>

static void charon_reply(void (^block)(void))
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

void SecAddSharedWebCredential(CFStringRef fqdn, CFStringRef username, CFStringRef password, void (^completionHandler)(CFErrorRef error))
{
    void (^handler)(CFErrorRef) = [completionHandler copy];
    if (!handler)
        return;
    charon_reply(^{
        NSDictionary *info = @{NSLocalizedDescriptionKey: @"Function or operation not implemented."};
        CFErrorRef error = (CFErrorRef)CFBridgingRetain([NSError errorWithDomain:NSOSStatusErrorDomain code:errSecUnimplemented userInfo:info]);
        handler(error);
        CFRelease(error);
    });
}

void SecRequestSharedWebCredential(CFStringRef fqdn, CFStringRef username, void (^completionHandler)(CFArrayRef credentials, CFErrorRef error))
{
    void (^handler)(CFArrayRef, CFErrorRef) = [completionHandler copy];
    if (!handler)
        return;
    charon_reply(^{
        CFArrayRef none = CFArrayCreate(kCFAllocatorDefault, NULL, 0, &kCFTypeArrayCallBacks);
        handler(none, NULL);
        CFRelease(none);
    });
}

CFStringRef SecCreateSharedWebCredentialPassword(void)
{
    static const char digits[] = "23456789";
    static const char upper[] = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    static const char lower[] = "abcdefghkmnopqrstuvwxyz";
    char all[sizeof(digits) + sizeof(upper) + sizeof(lower)];
    size_t total = 0;
    for (const char *set = digits; *set; set++)
        all[total++] = *set;
    for (const char *set = upper; *set; set++)
        all[total++] = *set;
    for (const char *set = lower; *set; set++)
        all[total++] = *set;
    char password[16];
    for (;;) {
        BOOL hasDigit = NO, hasUpper = NO, hasLower = NO;
        size_t at = 0;
        for (int i = 0; i < 12; i++) {
            if (i && i % 3 == 0)
                password[at++] = '-';
            char c = all[arc4random_uniform((uint32_t)total)];
            hasDigit = hasDigit || (c >= '2' && c <= '9');
            hasUpper = hasUpper || (c >= 'A' && c <= 'Z');
            hasLower = hasLower || (c >= 'a' && c <= 'z');
            password[at++] = c;
        }
        password[at] = 0;
        if (hasDigit && hasUpper && hasLower)
            break;
    }
    return CFStringCreateWithCString(kCFAllocatorDefault, password, kCFStringEncodingASCII);
}

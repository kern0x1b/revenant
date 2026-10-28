#import <Foundation/Foundation.h>
#import <Security/Security.h>

static void revenant_reply(void (^block)(void))
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), block);
}

static BOOL revenant_fqdn_is_usable(CFStringRef fqdn)
{
    return fqdn && CFGetTypeID(fqdn) == CFStringGetTypeID() && CFStringGetLength(fqdn) > 0;
}

static CFErrorRef revenant_shared_web_credential_error(OSStatus status)
{
    return (CFErrorRef)CFBridgingRetain([NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil]);
}

void SecAddSharedWebCredential(CFStringRef fqdn, CFStringRef username, CFStringRef password, void (^completionHandler)(CFErrorRef error))
{
    void (^handler)(CFErrorRef) = [completionHandler copy];
    if (!handler)
        return;
    OSStatus status = revenant_fqdn_is_usable(fqdn) ? errSecUnimplemented : errSecParam;
    revenant_reply(^{
        CFErrorRef error = revenant_shared_web_credential_error(status);
        handler(error);
        CFRelease(error);
    });
}

void SecRequestSharedWebCredential(CFStringRef fqdn, CFStringRef username, void (^completionHandler)(CFArrayRef credentials, CFErrorRef error))
{
    void (^handler)(CFArrayRef, CFErrorRef) = [completionHandler copy];
    if (!handler)
        return;
    OSStatus status = revenant_fqdn_is_usable(fqdn) ? errSecUnimplemented : errSecParam;
    revenant_reply(^{
        CFErrorRef error = revenant_shared_web_credential_error(status);
        handler(NULL, error);
        CFRelease(error);
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

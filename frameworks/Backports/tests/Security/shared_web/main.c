#include <stdio.h>
#include <Security/Security.h>
#include <CoreFoundation/CoreFoundation.h>
#include <dispatch/dispatch.h>

static void describe(CFErrorRef error)
{
    char domain[128];
    if (!error) {
        printf("error=none");
        return;
    }
    CFStringGetCString(CFErrorGetDomain(error), domain, sizeof domain, kCFStringEncodingUTF8);
    printf("error=%s/%ld", domain, (long)CFErrorGetCode(error));
}

static void add(const char *label, CFStringRef fqdn, CFStringRef account, CFStringRef password)
{
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    SecAddSharedWebCredential(fqdn, account, password, ^(CFErrorRef error) {
        printf("add %s: ", label);
        describe(error);
        printf("\n");
        dispatch_semaphore_signal(done);
    });
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) != 0)
        printf("add %s: no callback\n", label);
}

static void request(const char *label, CFStringRef fqdn, CFStringRef account)
{
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    SecRequestSharedWebCredential(fqdn, account, ^(CFArrayRef credentials, CFErrorRef error) {
        printf("request %s: credentials=%s ", label, credentials ? "array" : "NULL");
        describe(error);
        printf("\n");
        dispatch_semaphore_signal(done);
    });
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC)) != 0)
        printf("request %s: no callback\n", label);
}

static int shaped(CFStringRef password)
{
    if (CFStringGetLength(password) != 15)
        return 0;
    int digit = 0, upper = 0, lower = 0;
    for (CFIndex index = 0; index < 15; index++) {
        UniChar c = CFStringGetCharacterAtIndex(password, index);
        if (index == 3 || index == 7 || index == 11) {
            if (c != '-')
                return 0;
            continue;
        }
        if (c >= '2' && c <= '9')
            digit = 1;
        else if (c >= 'A' && c <= 'Z')
            upper = 1;
        else if (c >= 'a' && c <= 'z')
            lower = 1;
        else
            return 0;
    }
    return digit && upper && lower;
}

int main(void)
{
    add("nil-fqdn", NULL, NULL, NULL);
    add("empty-fqdn", CFSTR(""), CFSTR("account"), CFSTR("password"));
    add("nil-password", CFSTR("example.com"), CFSTR("account"), NULL);
    add("valid-fqdn", CFSTR("example.com"), CFSTR("account"), CFSTR("password"));
    request("nil-fqdn", NULL, NULL);
    request("empty-fqdn", CFSTR(""), NULL);

    int samples = 200, valid = 0;
    for (int index = 0; index < samples; index++) {
        CFStringRef password = SecCreateSharedWebCredentialPassword();
        valid += shaped(password);
        CFRelease(password);
    }
    printf("password samples=%d shaped=%d\n", samples, valid);
    return 0;
}

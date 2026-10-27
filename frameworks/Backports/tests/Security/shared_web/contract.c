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

int main(int argc, const char *argv[])
{
    if (argc != 2)
        return 2;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    SecRequestSharedWebCredential(CFSTR("revenant.invalid"), CFSTR("account"), ^(CFArrayRef credentials, CFErrorRef error) {
        printf("request %s: credentials=%s ", argv[1], credentials ? "array" : "NULL");
        describe(error);
        printf("\n");
        dispatch_semaphore_signal(done);
    });
    if (dispatch_semaphore_wait(done, dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC)) != 0)
        printf("request %s: no callback\n", argv[1]);
    return 0;
}

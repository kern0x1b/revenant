#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>
#include "port-store-rule.h"

static const char *const kWritingSelectors[] = {
    "saveCredentialIdentities:completion:",
    "removeCredentialIdentities:completion:",
    "removeAllCredentialIdentitiesWithCompletion:",
    "replaceCredentialIdentitiesWithIdentities:completion:",
    NULL
};

int main(int argc, char **argv)
{
    const char *framework = argc > 1
        ? argv[1]
        : "/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices";
    const char *prefix = argc > 2 ? argv[2] : "Port";
    if (!dlopen(framework, RTLD_LAZY)) { fprintf(stderr, "%s: %s\n", framework, dlerror()); return 1; }

    int failures = 0;
    Class host = objc_getClass("ASCredentialIdentityStore");
    if (!host) { fprintf(stderr, "no ASCredentialIdentityStore on the host\n"); return 1; }
    printf("  this machine's class is %s, the rule's prefix is \"%s\"\\n",
           class_getName(object_getClass(host)), prefix);
    for (int index = 0; kWritingSelectors[index]; ++index) {
        int allowed = port_store_receiver_is_the_ports((id)host, prefix);
        printf("  %-56s %s\n", kWritingSelectors[index], allowed ? "ALLOWED" : "refused");
        if (allowed)
            ++failures;
    }
    printf("  %d of the four would have been allowed against this machine's store\n", failures);
    return failures ? 1 : 0;
}

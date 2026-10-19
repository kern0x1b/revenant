/* port-store-selftest -- the host-write rule, exercised on class objects and selector strings.
 *
 * Nothing is sent. The check is the SAME predicate the probe's chokepoint uses, asked two questions:
 * may the port's own store class be written to, and may THIS MACHINE's?
 *
 * The second answer is the one that matters, and it is taken from the runtime's own class name --
 * `objc_getClass("ASCredentialIdentityStore")` is this Mac's class, out of the framework, right here --
 * and from the selector as a STRING, with no instance, no allocation and no call. So a regression in
 * the rule, and a chokepoint that stopped being the only way in, both show up here without anything
 * on this machine being written to.
 */
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#include <stdio.h>
#include <string.h>
#include "port-store-rule.h"

/* The four the release's own header names. They are passed as STRINGS and never sent. */
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
    /* This Mac's own class. Nothing is sent to it and nothing is allocated from it. */
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

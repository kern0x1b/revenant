#import "../Foundation/check.h"
#import <PassKit/PassKit.h>
#include <dlfcn.h>

static NSString *revenant_payment_network(void *handle, const char *name)
{
    NSString *__unsafe_unretained *value = (NSString *__unsafe_unretained *)dlsym(handle, name);
    return value ? *value : nil;
}

static void revenant_expect_payment_network(const char *name, BOOL enabled)
{
    static void *framework;
    if (framework == NULL)
        framework = dlopen("/System/Library/Frameworks/PassKit.framework/PassKit", RTLD_LAZY);
    NSString *expected = revenant_payment_network(framework, name);
    NSString *value = revenant_payment_network(RTLD_DEFAULT, name);
    revenant_expect_string(name, enabled ? value : nil, expected);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    revenant_expect_payment_network("PKPaymentNetworkAmex", !revenant_negative);
    revenant_expect_payment_network("PKPaymentNetworkDiscover", YES);
    revenant_expect_payment_network("PKPaymentNetworkMasterCard", YES);
    revenant_expect_payment_network("PKPaymentNetworkVisa", YES);
    return revenant_finish();
}

#import "../Foundation/check.h"
#import <dlfcn.h>
#import <DeviceCheck/DeviceCheck.h>

static BOOL revenant_wait(BOOL *finished)
{
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:30];
    while (!*finished && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return *finished;
}

static NSString *revenant_host_error_domain(void)
{
    void *framework = dlopen("/System/Library/Frameworks/DeviceCheck.framework/DeviceCheck", RTLD_LAZY);
    NSString *__unsafe_unretained *symbol = framework ? (NSString *__unsafe_unretained *)dlsym(framework, "DCErrorDomain") : NULL;
    return symbol ? *symbol : nil;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Class deviceClass = NSClassFromString(@"DCDeviceRevenant");
    Class attestClass = NSClassFromString(@"DCAppAttestServiceRevenant");
    revenant_check((deviceClass != Nil) != revenant_negative, "DCDevice implementation is present", NSStringFromClass(deviceClass));
    revenant_check((attestClass != Nil) != revenant_negative, "DCAppAttestService implementation is present", NSStringFromClass(attestClass));
    if (!deviceClass || !attestClass) {
        return revenant_finish();
    }

    id device = [deviceClass currentDevice];
    revenant_check(device != nil && [device isSupported] == NO, "current device reports isSupported NO", [NSString stringWithFormat:@"%d", [device isSupported]]);
    revenant_check([deviceClass currentDevice] == device, "currentDevice is one shared object", @"different objects");

    NSString *hostDomain = revenant_host_error_domain();
    revenant_check(hostDomain != nil, "host DeviceCheck exports DCErrorDomain", @"dlsym failed");

    __block NSData *token = nil;
    __block NSError *tokenError = nil;
    __block BOOL tokenFinished = NO;
    [device generateTokenWithCompletionHandler:^(NSData *data, NSError *error) {
        token = data;
        tokenError = error;
        tokenFinished = YES;
    }];
    revenant_wait(&tokenFinished);
    revenant_check(tokenFinished && token == nil, "generateToken completes without a token", @"no completion or a token");
    revenant_check(tokenError != nil && [tokenError.domain isEqualToString:hostDomain], "generateToken error domain matches host", tokenError.domain ?: @"no error");
    revenant_check(tokenError.code == DCErrorFeatureUnsupported, "generateToken error is DCErrorFeatureUnsupported", [NSString stringWithFormat:@"%ld", (long)tokenError.code]);

    id attest = [attestClass sharedService];
    revenant_check(attest != nil && [attest isSupported] == NO, "attestation service reports isSupported NO", @"supported");
    __block NSError *keyError = nil;
    __block BOOL keyFinished = NO;
    [attest generateKeyWithCompletionHandler:^(NSString *keyId, NSError *error) {
        keyError = error;
        keyFinished = YES;
    }];
    revenant_wait(&keyFinished);
    revenant_check(keyError != nil && [keyError.domain isEqualToString:hostDomain] && keyError.code == DCErrorFeatureUnsupported, "generateKey error is DCErrorFeatureUnsupported", keyError.description ?: @"no error");

    return revenant_finish();
}

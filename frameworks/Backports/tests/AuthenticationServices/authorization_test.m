#import "../Foundation/check.h"
#import <AuthenticationServices/AuthenticationServices.h>
#import <dlfcn.h>

@interface RevenantAuthorizationDelegate : NSObject <ASAuthorizationControllerDelegate>

@property (nonatomic) BOOL finished;
@property (nonatomic, strong) NSError *error;

@end

@implementation RevenantAuthorizationDelegate

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization
{
    self.finished = YES;
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error
{
    self.error = error;
    self.finished = YES;
}

@end

static NSString *revenant_host_authorization_domain(void)
{
    void *framework = dlopen("/System/Library/Frameworks/AuthenticationServices.framework/AuthenticationServices", RTLD_LAZY);
    NSString *__unsafe_unretained *symbol = framework ? (NSString *__unsafe_unretained *)dlsym(framework, "ASAuthorizationErrorDomain") : NULL;
    return symbol ? *symbol : nil;
}

static NSError *revenant_perform(Class controllerClass, id request)
{
    RevenantAuthorizationDelegate *delegate = [[RevenantAuthorizationDelegate alloc] init];
    id controller = [[controllerClass alloc] initWithAuthorizationRequests:@[request]];
    [controller setDelegate:delegate];
    [controller performRequests];
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
    while (!delegate.finished && [deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    return delegate.error;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    Class controllerClass = NSClassFromString(@"ASAuthorizationControllerRevenant");
    Class providerClass = NSClassFromString(@"ASAuthorizationPlatformPublicKeyCredentialProviderRevenant");
    revenant_check((controllerClass != Nil) != revenant_negative, "ASAuthorizationController implementation is present", NSStringFromClass(controllerClass));
    revenant_check((providerClass != Nil) != revenant_negative, "platform provider implementation is present", NSStringFromClass(providerClass));
    if (!controllerClass || !providerClass) {
        return revenant_finish();
    }

    NSString *hostDomain = revenant_host_authorization_domain();
    revenant_check(hostDomain != nil, "host AuthenticationServices exports ASAuthorizationErrorDomain", @"dlsym failed");

    NSError *appleIDError = revenant_perform(controllerClass, [[[ASAuthorizationAppleIDProvider alloc] init] createRequest]);
    revenant_check(appleIDError != nil && [appleIDError.domain isEqualToString:hostDomain], "Apple ID request reports the host error domain", appleIDError.domain ?: @"no error");
    revenant_check(appleIDError.code == ASAuthorizationErrorUnknown, "Apple ID request reports ASAuthorizationErrorUnknown as measured on the host", [NSString stringWithFormat:@"%ld", (long)appleIDError.code]);

    id provider = [[providerClass alloc] initWithRelyingPartyIdentifier:@"example.com"];
    NSData *challenge = [@"0123456789012345" dataUsingEncoding:NSUTF8StringEncoding];
    NSData *userID = [@"u" dataUsingEncoding:NSUTF8StringEncoding];
    id registration = [provider createCredentialRegistrationRequestWithChallenge:challenge name:@"user" userID:userID];
    revenant_check([[registration relyingPartyIdentifier] isEqualToString:@"example.com"], "registration request carries the relying party identifier", [registration relyingPartyIdentifier]);
    revenant_check([[registration challenge] isEqualToData:challenge], "registration request carries the challenge", @"differs");
    revenant_check([[registration name] isEqualToString:@"user"] && [[registration userID] isEqualToData:userID], "registration request carries the name and user id", @"differs");

    ASAuthorizationPlatformPublicKeyCredentialProvider *hostProvider = [[ASAuthorizationPlatformPublicKeyCredentialProvider alloc] initWithRelyingPartyIdentifier:@"example.com"];
    ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest *hostRegistration = [hostProvider createCredentialRegistrationRequestWithChallenge:challenge name:@"user" userID:userID];
    revenant_check([registration userVerificationPreference] == hostRegistration.userVerificationPreference, "default user verification preference matches host", [NSString stringWithFormat:@"%ld", (long)[registration userVerificationPreference]]);
    revenant_check([registration attestationPreference] == hostRegistration.attestationPreference, "default attestation preference matches host", [NSString stringWithFormat:@"%ld", (long)[registration attestationPreference]]);

    NSError *passkeyError = revenant_perform(controllerClass, registration);
    revenant_check(passkeyError != nil && [passkeyError.domain isEqualToString:hostDomain], "passkey registration reports the host error domain", passkeyError.domain ?: @"no error");
    revenant_check(passkeyError.code == ASAuthorizationErrorFailed, "passkey registration reports ASAuthorizationErrorFailed as measured on the host", [NSString stringWithFormat:@"%ld", (long)passkeyError.code]);

    id copy = [registration copy];
    revenant_check([[copy challenge] isEqualToData:challenge] && [[copy name] isEqualToString:@"user"], "copied registration request keeps its fields", @"differs");

    return revenant_finish();
}

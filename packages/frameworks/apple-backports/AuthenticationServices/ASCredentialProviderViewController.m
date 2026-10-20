#import <AuthenticationServices/AuthenticationServices.h>
#import <UIKit/UIKit.h>

@implementation ASCredentialProviderViewController

- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers
{
    (void)serviceIdentifiers;
}

- (void)provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity
{
    (void)credentialIdentity;
}

- (void)prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity
{
    (void)credentialIdentity;
}

- (void)prepareInterfaceForExtensionConfiguration
{
}

- (ASCredentialProviderExtensionContext *)extensionContext
{
    return nil;
}

@end

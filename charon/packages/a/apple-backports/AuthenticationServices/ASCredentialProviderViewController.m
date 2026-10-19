// ASCredentialProviderViewController, of iOS 12.0: the class a password-manager EXTENSION subclasses
// so the system can ask it for a credential.
//
// **What this class is for, and what the port does with it.** On a device the system instantiates an
// extension's provider controller, presents it, and calls the five methods below in the order the header
// documents: prepare the list of credentials for some services, prepare the interface for one identity,
// then ask for a credential without the user's interaction when the system already has a matching
// stored credential. An extension SUBCLASSES this class and overrides what it wants; the base class is
// where those calls land when it does not, and the header's contract for a base implementation is
// nothing happening.
//
// So every method here is a documented no-op default, and that is not a stub: it is the base class
// behaving as the base class behaves. An extension that overrides one gets its own behaviour; an
// extension that overrides none gets the release's own answer, which is also nothing.
//
// **What a device does that this port cannot.** The presentation itself is the system's: on a real
// device AutoFill shows this controller inside the system UI, and the identities it would offer come
// from the system's credential-identity store. The port has no such store to be presented from, and
// deliberately never touches this Mac's: the static scan and the runtime refusal in
// tests/backports/host/authservices/ are what stand between this machine's AutoFill state and a
// differential that asked the real store what it holds. The identities the port's own controller would
// offer are the ones the application's own store recorded, and facts/AuthenticationServices/records
//which that is.
#import <AuthenticationServices/AuthenticationServices.h>
#import <UIKit/UIKit.h>

@implementation ASCredentialProviderViewController

- (void)prepareCredentialListForServiceIdentifiers:(NSArray<ASCredentialServiceIdentifier *> *)serviceIdentifiers
{
    // The header: "Override this method to prepare a list of credentials to provide to the
    // system." With nothing overridden there is nothing to prepare, and a base implementation that
    // invented a list would be offering credentials the extension never said it had.
    (void)serviceIdentifiers;
}

- (void)provideCredentialWithoutUserInteractionForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity
{
    // The header asks the extension to provide a credential for an identity WITHOUT the user's
    // interaction, which the system only does when the store already holds a matching credential. The
    // base has no store, so it provides nothing, and saying so is what an extension that has not
    // overridden this is being told.
    (void)credentialIdentity;
}

- (void)prepareInterfaceToProvideCredentialForIdentity:(ASPasswordCredentialIdentity *)credentialIdentity
{
    // The header: "Override this method to prepare the user interface to provide a credential." The
    // presentation is the system's on a device; here the base prepares none.
    (void)credentialIdentity;
}

- (void)prepareInterfaceForExtensionConfiguration
{
    // The header: the system calls this when it displays the extension's settings. There is no
    // settings screen in the port -- that is the extension's own -- so the base prepares nothing.
}

- (ASCredentialProviderExtensionContext *)extensionContext
{
    // The header's getter for the context this controller completes requests into. On a device it is the
    // system-provided one; the port has none, and nil says so rather than standing in an object that
    // cannot complete anything.
    //
    // The header types this ASCredentialProviderExtensionContext *, and the port now declares it the
    // same way, because that class is carried: e51d793a6 recorded that the type was - (id) because
    // registry/AuthenticationServices/ios11.json held ASCredentialProviderExtensionContext absent, and
    // said at the declaration and in the facts that the type would follow the class when it arrived.
    // This is that following, and the reason the getter answers nil is now its own and narrower one:
    // the port has no SYSTEM-provided context to hand back, and its own context class is an object an
    // extension would be given, never one this controller should fabricate and return as if the system
    // had supplied it.
    return nil;
}

@end

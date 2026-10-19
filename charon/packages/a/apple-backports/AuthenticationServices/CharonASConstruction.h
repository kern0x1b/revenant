// The port's own construction of the AuthenticationServices classes whose -init and +new the release
// marks unavailable, and the coding key the base request uses.
//
// `ASAuthorizationRequest.h` marks both unavailable: an application is not meant to make a bare
// request, because nothing can service one without a provider. The port has to make these -- it is the
// thing that implements the class -- and calling `[[ASAuthorizationRequest alloc] init]` does not
// compile against those marks, so the construction is named, declared here, and defined in the file
// that implements the class. The header's unavailability still stands for every other caller, which is
// the point of it: `[ASAuthorizationRequest new]` in an application still does not compile.
//
// This is the same mechanism HomeKit's graph uses, for the same reason, and it is the shape every
// class in this family is written in.
#ifndef CHARON_AS_CONSTRUCTION_H
#define CHARON_AS_CONSTRUCTION_H

#import <Foundation/Foundation.h>
#import <AuthenticationServices/AuthenticationServices.h>

// The designated initialisers. A method may only assign `self` when it is in the init method family,
// and clang decides that from the attribute rather than from the spelling -- so a selector called
// `charon_init...` is not, and writing `self = [super init]` in one is rejected with "cannot assign to
// 'self' outside of a method in the init family". `objc_method_family(init)` is what makes a
// port's own name usable here.
#define CHARON_AS_CONSTRUCTION(cls, ...) \
    @interface cls (CharonASConstruction) \
    - (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider __VA_ARGS__ \
    __attribute__((objc_method_family(init))); \
    @end

@interface ASAuthorizationRequest (CharonASConstruction)
- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
    __attribute__((objc_method_family(init)));
@end

// Each class in the chain overrides this, so the most derived one runs: a subclass's own defaults are
// applied where the object is actually made. The port's provider builds its request through
// -charon_initWithProvider: and NOT through -init -- the base marks -init unavailable, and the compiler
// reads the base's mark for a subclass too -- so a default that lives in a subclass's -init is never
// reached, and a mutation of it changes nothing. That is not a property of the mutation; it was a
// default the port was not actually applying.
@interface ASAuthorizationOpenIDRequest (CharonASConstruction)
- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
    __attribute__((objc_method_family(init)));
@end
@interface ASAuthorizationAppleIDRequest (CharonASConstruction)
- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
    __attribute__((objc_method_family(init)));
@end

// A credential is a value object: the release marks -init and +new unavailable and hands the object
// back from a provider. The port's way in names the seven values the header declares, because there is
// no other way to make one and a credential with no user is not a credential.
@interface ASAuthorizationAppleIDCredential (CharonASConstruction)
- (instancetype)charon_initWithUser:(NSString *)user
                   authorizedScopes:(NSArray<ASAuthorizationScope> *)authorizedScopes
                     identityToken:(NSData *)identityToken
                  authorizationCode:(NSData *)authorizationCode
                             state:(NSString *)state
                             email:(NSString *)email
                          fullName:(NSPersonNameComponents *)fullName
                    realUserStatus:(ASUserDetectionStatus)realUserStatus
    __attribute__((objc_method_family(init)));
@end

// The result of a finished request: a provider and a credential held together. Neither can be made by
// an application -- the header marks both constructors unavailable -- and the controller makes the pair.
@interface ASAuthorization (CharonASConstruction)
- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
                              credential:(id<ASAuthorizationCredential>)credential
    __attribute__((objc_method_family(init)));
@end

// Whether the store can be written to and whether it takes changes or the whole set. This class does
// NOT mark -init unavailable, so the port's construction is the extra way in and the release's own -init
// is left alone.
// The store is a shared object on the release and +sharedStore here; the path is where its file goes
// and the class marks plain -init unavailable, so the port names its own way in.
@interface ASCredentialIdentityStore (CharonASConstruction)
- (instancetype)charon_initWithStorePath:(NSString *)path
    __attribute__((objc_method_family(init)));
@end

@interface ASCredentialIdentityStoreState (CharonASConstruction)
- (instancetype)charon_initWithEnabled:(BOOL)enabled
           supportsIncrementalUpdates:(BOOL)supportsIncrementalUpdates
    __attribute__((objc_method_family(init)));
@end

// A password credential is a value: the protocol it adopts declares the initialisers unavailable, so
// the port's own is the only way one is made.
@interface ASPasswordCredential (CharonASConstruction)
- (instancetype)charon_initWithUser:(NSString *)user password:(NSString *)password
    __attribute__((objc_method_family(init)));
@end

@interface ASAuthorizationAppleIDProvider (CharonASConstruction)
- (instancetype)charon_initWithCredentialState:(id)store
    __attribute__((objc_method_family(init)));
@end

#endif

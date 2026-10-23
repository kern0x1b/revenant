#ifndef REVENANT_AS_CONSTRUCTION_H
#define REVENANT_AS_CONSTRUCTION_H

#import <Foundation/Foundation.h>
#import <AuthenticationServices/AuthenticationServices.h>

#define REVENANT_AS_CONSTRUCTION(cls, ...) \
    @interface cls (RevenantASConstruction) \
    - (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider __VA_ARGS__ \
    __attribute__((objc_method_family(init))); \
    @end

@interface ASAuthorizationRequest (RevenantASConstruction)
- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider
    __attribute__((objc_method_family(init)));
@end

@interface ASAuthorizationOpenIDRequest (RevenantASConstruction)
- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider
    __attribute__((objc_method_family(init)));
@end
@interface ASAuthorizationAppleIDRequest (RevenantASConstruction)
- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider
    __attribute__((objc_method_family(init)));
@end

@interface ASAuthorizationAppleIDCredential (RevenantASConstruction)
- (instancetype)revenant_initWithUser:(NSString *)user
                   authorizedScopes:(NSArray<ASAuthorizationScope> *)authorizedScopes
                     identityToken:(NSData *)identityToken
                  authorizationCode:(NSData *)authorizationCode
                             state:(NSString *)state
                             email:(NSString *)email
                          fullName:(NSPersonNameComponents *)fullName
                    realUserStatus:(ASUserDetectionStatus)realUserStatus
    __attribute__((objc_method_family(init)));
@end

@interface ASAuthorization (RevenantASConstruction)
- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider
                              credential:(id<ASAuthorizationCredential>)credential
    __attribute__((objc_method_family(init)));
@end

@interface ASCredentialIdentityStore (RevenantASConstruction)
- (instancetype)revenant_initWithStorePath:(NSString *)path
    __attribute__((objc_method_family(init)));
@end

@interface ASCredentialIdentityStoreState (RevenantASConstruction)
- (instancetype)revenant_initWithEnabled:(BOOL)enabled
           supportsIncrementalUpdates:(BOOL)supportsIncrementalUpdates
    __attribute__((objc_method_family(init)));
@end

@interface ASPasswordCredential (RevenantASConstruction)
- (instancetype)revenant_initWithUser:(NSString *)user password:(NSString *)password
    __attribute__((objc_method_family(init)));
@end

@interface ASAuthorizationAppleIDProvider (RevenantASConstruction)
- (instancetype)revenant_initWithCredentialState:(id)store
    __attribute__((objc_method_family(init)));
@end

@interface ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest (RevenantASConstruction)
- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider
                                challenge:(NSData *)challenge
                                     name:(NSString *)name
                                   userID:(NSData *)userID
    __attribute__((objc_method_family(init)));
@end

@interface ASAuthorizationPlatformPublicKeyCredentialAssertionRequest (RevenantASConstruction)
- (instancetype)revenant_initWithProvider:(id<ASAuthorizationProvider>)provider
                                challenge:(NSData *)challenge
    __attribute__((objc_method_family(init)));
@end

#endif

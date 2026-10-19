#ifndef CHARON_AS_CONSTRUCTION_H
#define CHARON_AS_CONSTRUCTION_H

#import <Foundation/Foundation.h>
#import <AuthenticationServices/AuthenticationServices.h>

#define CHARON_AS_CONSTRUCTION(cls, ...) \
    @interface cls (CharonASConstruction) \
    - (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider __VA_ARGS__ \
    __attribute__((objc_method_family(init))); \
    @end

@interface ASAuthorizationRequest (CharonASConstruction)
- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
    __attribute__((objc_method_family(init)));
@end

@interface ASAuthorizationOpenIDRequest (CharonASConstruction)
- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
    __attribute__((objc_method_family(init)));
@end
@interface ASAuthorizationAppleIDRequest (CharonASConstruction)
- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
    __attribute__((objc_method_family(init)));
@end

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

@interface ASAuthorization (CharonASConstruction)
- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider
                              credential:(id<ASAuthorizationCredential>)credential
    __attribute__((objc_method_family(init)));
@end

@interface ASCredentialIdentityStore (CharonASConstruction)
- (instancetype)charon_initWithStorePath:(NSString *)path
    __attribute__((objc_method_family(init)));
@end

@interface ASCredentialIdentityStoreState (CharonASConstruction)
- (instancetype)charon_initWithEnabled:(BOOL)enabled
           supportsIncrementalUpdates:(BOOL)supportsIncrementalUpdates
    __attribute__((objc_method_family(init)));
@end

@interface ASPasswordCredential (CharonASConstruction)
- (instancetype)charon_initWithUser:(NSString *)user password:(NSString *)password
    __attribute__((objc_method_family(init)));
@end

@interface ASAuthorizationAppleIDProvider (CharonASConstruction)
- (instancetype)charon_initWithCredentialState:(id)store
    __attribute__((objc_method_family(init)));
@end

#endif

// The AuthenticationServices string constants of iOS 13.0. Every value here was read out of a real
// AuthenticationServices.framework: AuthenticationServices.framework of the 16.0, 18.0 shared caches, read with the project's own dyld cache reader: the symbol's pointer resolved through the cache's slide information, then the __CFConstantString's char* and its length, with the bytes agreeing with the length
// One release's API per object file, which is what the band machinery needs.
#import <Foundation/Foundation.h>

NSString *const ASAuthorizationAppleIDProviderCredentialRevokedNotification = @"ASAuthorizationAppleIDCredentialRevokedNotification";
NSString *const ASAuthorizationErrorDomain = @"com.apple.AuthenticationServices.AuthorizationError";
NSString *const ASAuthorizationOperationImplicit = @"implicit";
NSString *const ASAuthorizationOperationLogin = @"login";
NSString *const ASAuthorizationOperationLogout = @"logout";
NSString *const ASAuthorizationOperationRefresh = @"refresh";
NSString *const ASAuthorizationScopeEmail = @"email";
NSString *const ASAuthorizationScopeFullName = @"full_name";

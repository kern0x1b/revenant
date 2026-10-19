// ASAuthorizationAppleIDRequest, of iOS 13.0: the request Sign in with Apple is made with.
//
// **What it adds over its superclass is one property.** The measured class list -- macOS 27.0's own
// AuthenticationServices, asked with class_copyMethodList by tests/backports/host/authservices -- is
// four instance methods:
//
//     user  setUser:  init  .cxx_destruct
//
// so `user` and its setter, `init` (this header does not mark it unavailable and the host binds it, like
// its superclass), and the destructor the compiler emits. There is nothing else, which is the shape of
// a request whose whole content is the provider's own: the scopes, the state, the nonce and the
// operation are its superclass's, and everything Sign in with Apple adds is the user it is for.
//
// **What `user` is for.** If the application has been vended a `user` value through a previous
// ASAuthorization response, setting it gives the provider the context it needs to recognise the same
// person across a second sign-in -- the first sign-in returns the identifier, and the request that uses
// it asks for that person rather than a new one. Left nil, the provider treats the request as a first
// sign-in, which is what the header's `nullable` means and what the release does.
#import <AuthenticationServices/AuthenticationServices.h>
#import "CharonASConstruction.h"

@implementation ASAuthorizationAppleIDRequest

@synthesize user = _user;

- (instancetype)init
{
    // Bound for the same reason as on the superclass: this header does not mark -init unavailable, and
    // the host's own class list carries it.
    self = [super init];
    if (self)
        _user = nil;
    return self;
}

// The construction the provider uses, so the user is nil on the path a real request takes -- the same
// reason as in the class above, and the same fix.
- (instancetype)charon_initWithProvider:(id<ASAuthorizationProvider>)provider __attribute__((objc_method_family(init)))
{
    self = [super charon_initWithProvider:provider];
    if (self)
        _user = nil;
    return self;
}

- (NSString *)user
{
    return [_user copy];
}

- (void)setUser:(NSString *)user
{
    _user = [user copy];
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    // The superclass's copy carries the scopes, the state, the nonce and the operation; the user is
    // this class's own and is carried here, or a copy of a Sign in with Apple request would drop the
    // one thing that identifies which person it is for.
    ASAuthorizationAppleIDRequest *copy = [super copyWithZone:zone];
    if ([copy isKindOfClass:[ASAuthorizationAppleIDRequest class]])
        ((ASAuthorizationAppleIDRequest *)copy).user = _user;
    return copy;
}

@end

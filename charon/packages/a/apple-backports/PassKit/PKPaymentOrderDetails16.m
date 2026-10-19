// PKPaymentOrderDetails, 16.0: the order a merchant names to a payment request, carried as the caller's own data.
//
// The class is in the arm64e cache of iOS 16.0 with exactly these own selectors (tools/objc-class-surface.lua 16.0
// arm64e): -initWithOrderTypeIdentifier:orderIdentifier:webServiceURL:authenticationToken:, the four properties
// and their setters, -initWithCoder:, -encodeWithCoder:, and +supportsSecureCoding. Its own list has no -init, so a
// plain -init is NSObject's, and the host answers the same: the four members read back nil from it.
//
// Every member is a value the application sets and reads back, so nothing here is computed. The strings and the URL
// are copied as they are given, which is what the properties' copy attribute declares and what the host does: a
// mutable string the caller changes after it was set does not change the order. Nothing here calls the web service
// the URL names, and no authentication token is checked: the token is the caller's own string.
//
// The SDK header declares the class an NSObject with no protocol, and the host's class adopts NSSecureCoding (measured;
// the inventory does not list protocols), so the extension below adopts it for the coder, as PKPayment8.m does for its two classes.
#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>

@interface PKPaymentOrderDetails () <NSSecureCoding>
@end

@implementation PKPaymentOrderDetails {
    NSString *_orderTypeIdentifier;
    NSString *_orderIdentifier;
    NSURL *_webServiceURL;
    NSString *_authenticationToken;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithOrderTypeIdentifier:(NSString *)orderTypeIdentifier
                            orderIdentifier:(NSString *)orderIdentifier
                              webServiceURL:(NSURL *)webServiceURL
                        authenticationToken:(NSString *)authenticationToken
{
    self = [super init];
    if (self) {
        _orderTypeIdentifier = [orderTypeIdentifier copy];
        _orderIdentifier = [orderIdentifier copy];
        _webServiceURL = [webServiceURL copy];
        _authenticationToken = [authenticationToken copy];
    }
    return self;
}

- (NSString *)orderTypeIdentifier
{
    return _orderTypeIdentifier;
}

- (void)setOrderTypeIdentifier:(NSString *)orderTypeIdentifier
{
    _orderTypeIdentifier = [orderTypeIdentifier copy];
}

- (NSString *)orderIdentifier
{
    return _orderIdentifier;
}

- (void)setOrderIdentifier:(NSString *)orderIdentifier
{
    _orderIdentifier = [orderIdentifier copy];
}

- (NSURL *)webServiceURL
{
    return _webServiceURL;
}

- (void)setWebServiceURL:(NSURL *)webServiceURL
{
    _webServiceURL = [webServiceURL copy];
}

- (NSString *)authenticationToken
{
    return _authenticationToken;
}

- (void)setAuthenticationToken:(NSString *)authenticationToken
{
    _authenticationToken = [authenticationToken copy];
}

// The keys and value classes are the release's, measured on the host: an archive of an order written by PassKit holds the
// four members under these keys, the three strings as NSString and the URL as an NSURL object. The probe in
// tests/backports/host/payment-value compares this archive with the host's, and each side reads the other's back.
- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _orderTypeIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"orderTypeIdentifier"] copy];
        _orderIdentifier = [[coder decodeObjectOfClass:[NSString class] forKey:@"orderIdentifier"] copy];
        _webServiceURL = [[coder decodeObjectOfClass:[NSURL class] forKey:@"webServiceURL"] copy];
        _authenticationToken = [[coder decodeObjectOfClass:[NSString class] forKey:@"authenticationToken"] copy];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_orderTypeIdentifier forKey:@"orderTypeIdentifier"];
    [coder encodeObject:_orderIdentifier forKey:@"orderIdentifier"];
    [coder encodeObject:_webServiceURL forKey:@"webServiceURL"];
    [coder encodeObject:_authenticationToken forKey:@"authenticationToken"];
}

@end

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

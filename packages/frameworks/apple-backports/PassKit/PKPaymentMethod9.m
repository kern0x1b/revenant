#import <Foundation/Foundation.h>
#import <PassKit/PassKit.h>

@interface PKPaymentMethod () <NSSecureCoding, NSCopying>
@end

@implementation PKPaymentMethod {
    NSUInteger _type;
    NSString *_displayName;
    NSString *_network;
    id _paymentPass;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithPaymentPass:(id)paymentPass obfuscateNetworks:(BOOL)obfuscateNetworks
{
    (void)paymentPass;
    (void)obfuscateNetworks;
    return [super init];
}

- (NSUInteger)type
{
    return _type;
}

- (void)setType:(NSUInteger)type
{
    _type = type;
}

- (NSString *)displayName
{
    return _displayName;
}

- (void)setDisplayName:(NSString *)displayName
{
    _displayName = [displayName copy];
}

- (NSString *)network
{
    return _network;
}

- (void)setNetwork:(NSString *)network
{
    _network = [network copy];
}

- (id)paymentPass
{
    return _paymentPass;
}

- (void)setPaymentPass:(id)paymentPass
{
    _paymentPass = paymentPass;
}

- (id)copyWithZone:(NSZone *)zone
{
    PKPaymentMethod *copy = [[[self class] allocWithZone:zone] init];
    copy.type = _type;
    copy.displayName = _displayName;
    copy.network = _network;
    copy.paymentPass = _paymentPass;
    return copy;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _type = [[coder decodeObjectOfClass:[NSNumber class] forKey:@"type"] unsignedIntegerValue];
        _displayName = [[coder decodeObjectOfClass:[NSString class] forKey:@"displayName"] copy];
        _network = [[coder decodeObjectOfClass:[NSString class] forKey:@"network"] copy];
        _paymentPass = [coder decodeObjectOfClass:[NSObject class] forKey:@"paymentPass"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:@(_type) forKey:@"type"];
    [coder encodeObject:_displayName forKey:@"displayName"];
    [coder encodeObject:_network forKey:@"network"];
    [coder encodeObject:_paymentPass forKey:@"paymentPass"];
}

@end

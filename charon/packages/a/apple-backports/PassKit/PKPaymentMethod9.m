// PKPaymentMethod, 9.0: the instrument a payment was made with, as the application is told about it.
//
// The 9.0 release's surface (measured with tools/objc-class-surface.lua over the armv7 cache of iOS 9.0) is an NSObject
// with -type, -displayName, -network and -paymentPass, each with its setter, -initWithPaymentPass:obfuscateNetworks:,
// -copyWithZone:, -initWithCoder:, -encodeWithCoder: and +supportsSecureCoding. Nothing else is its own; the later
// members (-secureElementPass from 13.4, -billingAddress from 13.0) are not carried.
//
// A method is a description the caller can read back. A method built from nothing answers nil and 0 in every member,
// which the host answers for a fresh one. The strings are copied on the way in, as the release's copy attributes say
// for the strings. The payment pass is the one member this device cannot fill: a pass that carries payment data needs a
// Secure Element, which the device does not have, so -initWithPaymentPass:obfuscateNetworks: answers the empty method for
// any pass. The host answers the same for a fresh pass (measured on macOS PassKit with a fresh PKPaymentPass: type 0, nil
// network, nil paymentPass).
//
// The coder keys are the four members' own names. The host's archive of this class uses those names for the same four
// members (measured on macOS PassKit: type as a number, the others as strings or null); its other fields are later
// releases' members, which the 9.0 surface does not carry, so they are not written here.
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
    // The device has no Secure Element, so no pass it could be given carries payment data: the method is the empty one
    // whatever pass it is given, and the flag has nothing to obfuscate.
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

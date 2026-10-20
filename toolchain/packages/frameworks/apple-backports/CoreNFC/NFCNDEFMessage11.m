#import <CoreNFC/CoreNFC.h>
#import "RevenantNDEF.h"

@interface NFCNDEFPayload ()
@property (nonatomic, copy) NSData *chunkSize;
@end

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NFCNDEFPayload

@synthesize typeNameFormat = _typeNameFormat, type = _type, identifier = _identifier, payload = _payload, chunkSize = _chunkSize;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)self.typeNameFormat forKey:@"typeNameFormat"];
    [coder encodeObject:self.type forKey:@"type"];
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.payload forKey:@"payload"];
    if (self.chunkSize) {
        [coder encodeObject:self.chunkSize forKey:@"chunkSize"];
    }
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _typeNameFormat = (NFCTypeNameFormat)[coder decodeIntegerForKey:@"typeNameFormat"];
        _type = [[coder decodeObjectOfClass:[NSData class] forKey:@"type"] copy];
        _identifier = [[coder decodeObjectOfClass:[NSData class] forKey:@"identifier"] copy];
        _payload = [[coder decodeObjectOfClass:[NSData class] forKey:@"payload"] copy];
        _chunkSize = [[coder decodeObjectOfClass:[NSData class] forKey:@"chunkSize"] copy];
    }
    return self;
}

- (BOOL)isEqual:(id)other
{
    if (self == other) {
        return YES;
    }
    if (![other isKindOfClass:[NFCNDEFPayload class]]) {
        return NO;
    }
    NFCNDEFPayload *payload = other;
    return payload.typeNameFormat == self.typeNameFormat
        && ((payload.type == nil && self.type == nil) || [payload.type isEqualToData:self.type])
        && ((payload.identifier == nil && self.identifier == nil) || [payload.identifier isEqualToData:self.identifier])
        && ((payload.payload == nil && self.payload == nil) || [payload.payload isEqualToData:self.payload]);
}

- (NSUInteger)hash
{
    return self.payload.hash ^ self.type.hash ^ (NSUInteger)self.typeNameFormat;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, format %u, type %@, identifier %@, payload %lu bytes>",
                                      NSStringFromClass([self class]), (void *)self, (unsigned)self.typeNameFormat,
                                      self.type, self.identifier, (unsigned long)self.payload.length];
}

@end

@interface NFCNDEFMessage ()
@property (nonatomic, retain) NSMutableData *revenantEncoded;
@end

@implementation NFCNDEFMessage

@synthesize records = _records, revenantEncoded = _revenantEncoded;

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.records forKey:@"records"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _records = [[coder decodeObjectOfClasses:[[NSSet alloc] initWithObjects:[NSArray class], [NFCNDEFPayload class], nil]
                                           forKey:@"records"] copy];
    }
    return self;
}

- (BOOL)isEqual:(id)other
{
    if (self == other) {
        return YES;
    }
    if (![other isKindOfClass:[NFCNDEFMessage class]]) {
        return NO;
    }
    NFCNDEFMessage *message = other;
    return message.records == self.records || [message.records isEqualToArray:self.records];
}

- (NSUInteger)hash
{
    return self.records.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p, %lu records>", NSStringFromClass([self class]), (void *)self,
                                      (unsigned long)self.records.count];
}

@end

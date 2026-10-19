#import <CoreNFC/CoreNFC.h>
#import "CharonNDEF.h"

// NFCNDEFPayload and NFCNDEFMessage as iOS 11.0 has them: the records of a message and the message
// itself, with secure coding. A payload is a type, an identifier and bytes; a message is a list of
// payloads and knows how long it is once encoded.
//
// The record shape is CharonNDEF.h and CharonNDEF.m, the NFC Forum NDEF Technical Specification's and
// not a description of it. **The members iOS 13.0 added** - the two initialisers that take a record's
// fields, the chunked one, the well-known helpers, +ndefMessageWithData: and -length - are in
// NFCNDEFMessage13.m, because an object carries the API of one release.
//
// A 4S and an iPad 2 have no NFC radio, so nothing here is ever handed a tag. These two classes are
// values: a value is made, encoded and parsed without any radio at all, which is why they are carried
// whole while the sessions of the framework answer as a device without the service
// (facts/CoreNFC/NDEF.md).

@interface NFCNDEFPayload ()
// The chunking, kept as the bytes of a size_t so that only the chunked initialiser of 13.0 can set it:
// a payload with no chunk size is not chunked, which is not the same as chunked by zero.
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
// The bytes of the message, made once by the encoder of 13.0 and kept, so that -length is a length and
// not a second encoding.
@property (nonatomic, retain) NSMutableData *charonEncoded;
@end

@implementation NFCNDEFMessage

@synthesize records = _records, charonEncoded = _charonEncoded;

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

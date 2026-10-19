// CoreNFC/CoreNFC.h - the two classes of the port's NDEF family, transcribed from the declarations of
// the SDK 16.4 the port builds against (NFCNDEFPayload.h and NFCNDEFMessage.h), so the host
// differential can compile the port's own sources: **macOS has no CoreNFC** - every declaration of
// both headers is API_UNAVAILABLE(macos) - and there is nothing to link against here.
//
// The declarations are the SDK's, member for member and annotation for annotation. The port's sources
// include <CoreNFC/CoreNFC.h> as they do on the device, and this header is that include for the host:
// the test's include path comes first, so the sources see this and never the SDK's.

#ifndef CHARON_TEST_CORENFC_H
#define CHARON_TEST_CORENFC_H

#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, NFCTypeNameFormat) {
    NFCTypeNameFormatEmpty = 0x00,
    NFCTypeNameFormatNFCWellKnown = 0x01,
    NFCTypeNameFormatMedia = 0x02,
    NFCTypeNameFormatAbsoluteURI = 0x03,
    NFCTypeNameFormatNFCExternal = 0x04,
    NFCTypeNameFormatUnknown = 0x05,
    NFCTypeNameFormatUnchanged = 0x06
};

@interface NFCNDEFPayload : NSObject <NSSecureCoding>
@property (nonatomic, assign) NFCTypeNameFormat typeNameFormat;
@property (nonatomic, copy) NSData *type;
@property (nonatomic, copy) NSData *identifier;
@property (nonatomic, copy) NSData *payload;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFormat:(NFCTypeNameFormat)format type:(NSData *)type identifier:(NSData *)identifier payload:(NSData *)payload;
- (instancetype)initWithFormat:(NFCTypeNameFormat)format type:(NSData *)type identifier:(NSData *)identifier payload:(NSData *)payload chunkSize:(size_t)chunkSize;
+ (instancetype)wellKnownTypeURIPayloadWithString:(NSString *)uri;
+ (instancetype)wellKnownTypeURIPayloadWithURL:(NSURL *)url;
+ (instancetype)wellKnownTypeTextPayloadWithString:(NSString *)text locale:(NSLocale *)locale;
+ (instancetype)wellKnowTypeTextPayloadWithString:(NSString *)text locale:(NSLocale *)locale;
- (NSURL *)wellKnownTypeURIPayload;
- (NSString *)wellKnownTypeTextPayloadWithLocale:(NSLocale *__autoreleasing * _Nonnull)locale;
@end

@interface NFCNDEFMessage : NSObject <NSSecureCoding>
@property (nonatomic, copy) NSArray<NFCNDEFPayload *> *records;
@property (nonatomic, readonly) NSUInteger length;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithNDEFRecords:(NSArray<NFCNDEFPayload *> *)records;
+ (instancetype)ndefMessageWithData:(NSData *)data;
@end

#endif

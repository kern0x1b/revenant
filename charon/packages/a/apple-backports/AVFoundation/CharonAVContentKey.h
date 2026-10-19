#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

// The content key objects the session, its requests and its keys share (AVContentKeySession103.m, AVContentKey145.m,
// AVContentKeyResponse103.m). Internal: nothing here is an SDK declaration, and no application sees these names.

// The three kinds of response a request can take, from the factory that made it.
typedef NS_ENUM(NSInteger, CharonContentKeyResponseKind) {
    CharonContentKeyResponseKindFairPlay = 1,
    CharonContentKeyResponseKindClearKey,
    CharonContentKeyResponseKindAuthorizationToken,
};

@interface AVContentKeyResponse (CharonInternal)
- (CharonContentKeyResponseKind)charonKind;
- (NSData *)charonKeyData;
- (NSData *)charonInitializationVector;
- (NSData *)charonAuthorizationTokenData;
@end

// The 17.4 members of AVContentKey, for an SDK that predates them (the 16.4 SDK this port compiles against does not declare
// them). Transcribed from the 26.2 header: the status is NS_ENUM with Pending 0, Sufficient 1 and Insufficient 2. Where the
// SDK declares them (__IPHONE_17_4 is defined) nothing is added, so the declarations are never repeated.
#if !defined(__IPHONE_17_4)
typedef NS_ENUM(NSInteger, AVExternalContentProtectionStatus) {
    AVExternalContentProtectionStatusPending = 0,
    AVExternalContentProtectionStatusSufficient = 1,
    AVExternalContentProtectionStatusInsufficient = 2,
};

@interface AVContentKey (CharonIOS17_4)
@property (readonly) AVExternalContentProtectionStatus externalContentProtectionStatus;
- (void)revoke;
@end
#endif

// The key a clear key response carries, as a recipient receives it: the specifier it is for, the key and the vector.
@interface AVContentKey (CharonInternal)
+ (instancetype)charon_contentKeyWithSpecifier:(AVContentKeySpecifier *)specifier keyData:(NSData *)keyData
                          initializationVector:(NSData *)initializationVector;
// Decrypts a sample's bytes with this key: AES-128 in CBC with PKCS#7 padding for a 16-byte vector (the HLS AES-128
// form), AES-128 in CTR with the vector as the first 8 bytes of the counter block for an 8-byte vector. The key must be
// 16 bytes. The sample is decrypted whole, from counter zero. Returns nil and sets *error on a key or vector it cannot use.
- (NSData *)charon_decryptSampleData:(NSData *)sampleData error:(NSError **)error;
@end

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

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

@interface AVContentKey (CharonInternal)
+ (instancetype)charon_contentKeyWithSpecifier:(AVContentKeySpecifier *)specifier keyData:(NSData *)keyData
                          initializationVector:(NSData *)initializationVector;
- (NSData *)charon_decryptSampleData:(NSData *)sampleData error:(NSError **)error;
@end

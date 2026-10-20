#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, RevenantContentKeyResponseKind) {
    RevenantContentKeyResponseKindFairPlay = 1,
    RevenantContentKeyResponseKindClearKey,
    RevenantContentKeyResponseKindAuthorizationToken,
};

@interface AVContentKeyResponse (RevenantInternal)
- (RevenantContentKeyResponseKind)revenantKind;
- (NSData *)revenantKeyData;
- (NSData *)revenantInitializationVector;
- (NSData *)revenantAuthorizationTokenData;
@end

#if !defined(__IPHONE_17_4)
typedef NS_ENUM(NSInteger, AVExternalContentProtectionStatus) {
    AVExternalContentProtectionStatusPending = 0,
    AVExternalContentProtectionStatusSufficient = 1,
    AVExternalContentProtectionStatusInsufficient = 2,
};

@interface AVContentKey (RevenantIOS17_4)
@property (readonly) AVExternalContentProtectionStatus externalContentProtectionStatus;
- (void)revoke;
@end
#endif

@interface AVContentKey (RevenantInternal)
+ (instancetype)revenant_contentKeyWithSpecifier:(AVContentKeySpecifier *)specifier keyData:(NSData *)keyData
                          initializationVector:(NSData *)initializationVector;
- (NSData *)revenant_decryptSampleData:(NSData *)sampleData error:(NSError **)error;
@end

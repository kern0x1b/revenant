#import <Foundation/Foundation.h>
#ifndef CHARON_BRAILLE_ONLY
#import <Accessibility/Accessibility.h>
#endif

#ifndef AX_EXTERN
#define AX_EXTERN extern
#endif

NS_ASSUME_NONNULL_BEGIN

#pragma mark - AXTechnology (iOS 18.0)

API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
typedef NSString *const AXTechnology NS_TYPED_ENUM NS_SWIFT_NAME(AccessibilityTechnology);

API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyVoiceOver;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologySwitchControl;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyFullAccess;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyHearingDevicePaired;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyHearingDeviceActive;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyAutomaticActivation;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyHearingTest;
API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
AX_EXTERN AXTechnology AXTechnologyVoiceSwitch;

#pragma mark - AXRequest (iOS 18.0)

API_AVAILABLE(ios(18.0), macos(15.0), tvos(18.0), watchos(11.0))
@interface AXRequest : NSObject <NSCopying, NSSecureCoding>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@property (nullable, class, nonatomic, readonly) AXRequest *currentRequest;
@property (nonatomic, readonly) AXTechnology technology;

- (instancetype)charon_withTechnology:(AXTechnology)technology;

- (void)charon_setTechnology:(AXTechnology)technology;

@end

#pragma mark - AXFeatureOverrideSession (iOS 18.2)

API_AVAILABLE(ios(18.2))
typedef NS_OPTIONS(NSUInteger, AXFeatureOverrideSessionOptions) {
    AXFeatureOverrideSessionOptionsGrayscale = 1 << 0,
    AXFeatureOverrideSessionOptionsInvertColors = 1 << 1,
    AXFeatureOverrideSessionOptionsVoiceControl = 1 << 2,
    AXFeatureOverrideSessionOptionsVoiceOver = 1 << 3,
    AXFeatureOverrideSessionOptionsZoom = 1 << 4
};

API_AVAILABLE(ios(18.2))
AX_EXTERN NSErrorDomain const AXFeatureOverrideSessionErrorDomain;

API_AVAILABLE(ios(18.2))
typedef NS_ERROR_ENUM(AXFeatureOverrideSessionErrorDomain, AXFeatureOverrideSessionError) {
    AXFeatureOverrideSessionErrorUndefined = 0,
    AXFeatureOverrideSessionErrorAppNotEntitled,
    AXFeatureOverrideSessionErrorOverrideIsAlreadyActive,
    AXFeatureOverrideSessionErrorOverrideNotFoundForUUID,
};

API_AVAILABLE(ios(18.2))
@interface AXFeatureOverrideSession : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

API_AVAILABLE(ios(18.2))
@interface AXFeatureOverrideSessionManager : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@property (class, readonly) AXFeatureOverrideSessionManager *sharedInstance;

- (nullable AXFeatureOverrideSession *)beginOverrideSessionEnablingOptions:(AXFeatureOverrideSessionOptions)enableOptions
                                                         disablingOptions:(AXFeatureOverrideSessionOptions)disableOptions
                                                                      error:(NSError * _Nullable *)error;
- (BOOL)endOverrideSession:(AXFeatureOverrideSession *)session error:(NSError * _Nullable *)error;

@end

#pragma mark - AXBrailleTable, AXBrailleTranslationResult, AXBrailleTranslator (iOS 26.0)

API_AVAILABLE(ios(26.0))
@interface AXBrailleTable : NSObject <NSCopying, NSCoding>

@property (nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSString *providerIdentifier;
@property (nonatomic, readonly) NSString *localizedProviderName;
@property (nonatomic, readonly) NSString *language;
@property (nonatomic, readonly) NSSet<NSLocale *> *locales;
@property (nonatomic, readonly) BOOL isEightDot;

+ (NSSet<NSLocale *> *)supportedLocales;
+ (nullable AXBrailleTable *)defaultTableForLocale:(NSLocale *)locale;
+ (NSSet<AXBrailleTable *> *)tablesForLocale:(NSLocale *)locale;
+ (NSSet<AXBrailleTable *> *)languageAgnosticTables;

- (nullable instancetype)initWithIdentifier:(NSString *)identifier;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

API_AVAILABLE(ios(26.0))
@interface AXBrailleTranslationResult : NSObject <NSCopying, NSCoding>

@property (nonatomic, readonly) NSString *resultString;
@property (nonatomic, readonly) NSArray<NSNumber *> *locationMap;

- (instancetype)charon_withResultString:(NSString *)resultString
                                locations:(NSArray<NSNumber *> *)locations;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

API_AVAILABLE(ios(26.0))
@interface AXBrailleTranslator : NSObject

- (instancetype)initWithBrailleTable:(AXBrailleTable *)brailleTable;
- (AXBrailleTranslationResult *)translatePrintText:(NSString *)printText;
- (AXBrailleTranslationResult *)backTranslateBraille:(NSString *)braille;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

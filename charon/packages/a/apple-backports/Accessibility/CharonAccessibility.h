//
//  CharonAccessibility.h
//  Accessibility
//
//  The declarations the port's own SDK (iPhoneOS 16.4) does not have, transcribed from the
//  headers of iPhoneOS 26.2 word for word in their contract. Four of 26.2's twelve Accessibility
//  headers are new since 16.4 — AXRequest.h, AXMathExpression.h, AXBrailleTranslator.h and
//  AXFeatureOverrideSessionManager.h — and this is where the names in the first, the third and the
//  fourth are declared; the second, the sixteen AXMathExpression classes, is not declared here and
//  not carried, for the reason facts/Accessibility/Accessibility.md gives.
//
//  A backport writes the declaration itself for API newer than the SDK it compiles against. The
//  availability marks are not repeated: this header is read by the implementation files only, every
//  member it declares is carried from the port's own release, and what an application compiles
//  against is still the SDK's own header.
//

#import <Foundation/Foundation.h>
// A build that has no Accessibility framework - the host half of the braille differential, which
// compiles the three braille classes against nothing but Foundation - must not pull the system's
// header in: it declares the same three names this header transcribes, and two declarations of
// one class is a build that cannot be trusted.
#ifndef CHARON_BRAILLE_ONLY
#import <Accessibility/Accessibility.h>
#endif

// AX_EXTERN is the framework's own spelling of a symbol's visibility, defined in the framework's
// AXFoundation.h. A build without the framework - the port half of the braille differential -
// needs the same meaning, and `extern` is what the macro expands to there.
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

// A request is built here, with the technology that will serve it: the header marks -init
// unavailable, and this is the argument there is none of.
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

// The header marks -init unavailable, so the two results a translator builds are built here: the
// result string, and the map from a cell back to where the text put it. An empty map is what a
// translation that produced no cell has.
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

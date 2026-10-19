//
//  CharonIntents262.h
//  Intents
//
//  The thirteen declarations the port's own SDK (iPhoneOS 16.4) does not have, taken from the
//  headers of iPhoneOS 26.2 word for word in their contract:
//
//      7 classes    INMessageLinkMetadata, INUnsendMessagesIntent,
//                    INUnsendMessagesIntentResponse, INEditMessageIntent,
//                    INEditMessageIntentResponse, INMessageReaction, INSticker
//      4 enums      INUnsendMessagesIntentResponseCode, INEditMessageIntentResponseCode,
//                    INMessageReactionType, INStickerType
//      2 protocols  INUnsendMessagesIntentHandling, INEditMessageIntentHandling
//
//  Seven classes, four enumerations and two protocols: thirteen, counted because a count that
//  is wrong is a claim somebody relies on.
//
//  This is what a backport writes for API newer than the SDK it compiles against. The port
//  builds against iPhoneOS 16.4 (the toolchain's charon@iphoneos-sdk), and these names first
//  appear in the SDK of 17.0 and 18.0, so nothing here can come from a framework the compiler
//  already reads; the declaration is ours and the behaviour behind it is generated into the
//  object file of the group the release caches measure (IN12_0.m, IN16_0.m, IN18_0.m).
//
//  The availability marks are not repeated, and deliberately: this header is included by the
//  implementation files only, and every member it declares is carried from the port's own
//  release. What an application compiles against is still the SDK's own header, and this package
//  is what answers behind it.
//

#import <Foundation/Foundation.h>
#import <Intents/Intents.h>

// CHARON_HOST_BUILD is the host differential's build (tests/backports/host/intents-ride-driver and the
// rest of the Intents host harnesses). Its SDK is a newer one than iPhoneOS 16.4, and it already declares every
// name below, so a second declaration is a duplicate definition. The host build therefore takes the SDK's own
// declarations and declares nothing here; the device build is unchanged.
#ifndef CHARON_HOST_BUILD

NS_ASSUME_NONNULL_BEGIN

// The message-linking metadata of a message: what the link is (its Open Graph type and URL) and
// what it says (the site, the summary, the title). iOS 17.0.
API_AVAILABLE(ios(17.0), macos(14.0), watchos(10.0))
API_UNAVAILABLE(tvos)
@interface INMessageLinkMetadata : NSObject <NSCopying, NSSecureCoding>

- (instancetype)initWithSiteName:(nullable NSString *)siteName
                         summary:(nullable NSString *)summary
                           title:(nullable NSString *)title
                   openGraphType:(nullable NSString *)openGraphType
                         linkURL:(nullable NSURL *)linkURL NS_DESIGNATED_INITIALIZER;

@property (readwrite, copy, nullable, NS_NONATOMIC_IOSONLY) NSString *siteName;
@property (readwrite, copy, nullable, NS_NONATOMIC_IOSONLY) NSString *summary;
@property (readwrite, copy, nullable, NS_NONATOMIC_IOSONLY) NSString *title;
@property (readwrite, copy, nullable, NS_NONATOMIC_IOSONLY) NSString *openGraphType;
@property (readwrite, copy, nullable, NS_NONATOMIC_IOSONLY) NSURL *linkURL;

@end

// The code an unsend answers with. iOS 17.0.
typedef NS_ENUM(NSInteger, INUnsendMessagesIntentResponseCode) {
    INUnsendMessagesIntentResponseCodeUnspecified = 0,
    INUnsendMessagesIntentResponseCodeReady,
    INUnsendMessagesIntentResponseCodeInProgress,
    INUnsendMessagesIntentResponseCodeSuccess,
    INUnsendMessagesIntentResponseCodeFailure,
    INUnsendMessagesIntentResponseCodeFailureRequiringAppLaunch,
    INUnsendMessagesIntentResponseCodeFailureMessageNotFound,
    INUnsendMessagesIntentResponseCodeFailurePastUnsendTimeLimit,
    INUnsendMessagesIntentResponseCodeFailureMessageTypeUnsupported,
    INUnsendMessagesIntentResponseCodeFailureUnsupportedOnService,
    INUnsendMessagesIntentResponseCodeFailureMessageServiceNotAvailable,
    INUnsendMessagesIntentResponseCodeFailureRequiringInAppAuthentication,
};

// The messages to unsend, by identifier. iOS 17.0.
API_AVAILABLE(ios(17.0), macos(14.0), watchos(10.0))
API_UNAVAILABLE(tvos)
@interface INUnsendMessagesIntent : INIntent

- (instancetype)initWithMessageIdentifiers:(nullable NSArray<NSString *> *)messageIdentifiers NS_DESIGNATED_INITIALIZER;

@property (readonly, copy, nullable, NS_NONATOMIC_IOSONLY) NSArray<NSString *> *messageIdentifiers;

@end

@class INUnsendMessagesIntentResponse;

API_AVAILABLE(ios(17.0), macos(14.0), watchos(10.0))
API_UNAVAILABLE(tvos)
@protocol INUnsendMessagesIntentHandling <NSObject>

@required
- (void)handleUnsendMessages:(INUnsendMessagesIntent *)intent
                  completion:(void (^)(INUnsendMessagesIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));

@optional
- (void)confirmUnsendMessages:(INUnsendMessagesIntent *)intent
                   completion:(void (^)(INUnsendMessagesIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));

@end

// The answer to an unsend. iOS 17.0.
API_AVAILABLE(ios(17.0), macos(14.0), watchos(10.0))
API_UNAVAILABLE(tvos)
@interface INUnsendMessagesIntentResponse : INIntentResponse

- (id)init NS_UNAVAILABLE;

- (instancetype)initWithCode:(INUnsendMessagesIntentResponseCode)code
                 userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;

@property (readonly, NS_NONATOMIC_IOSONLY) INUnsendMessagesIntentResponseCode code;

@end

// The code an edit answers with. iOS 17.0.
typedef NS_ENUM(NSInteger, INEditMessageIntentResponseCode) {
    INEditMessageIntentResponseCodeUnspecified = 0,
    INEditMessageIntentResponseCodeReady,
    INEditMessageIntentResponseCodeInProgress,
    INEditMessageIntentResponseCodeSuccess,
    INEditMessageIntentResponseCodeFailure,
    INEditMessageIntentResponseCodeFailureRequiringAppLaunch,
    INEditMessageIntentResponseCodeFailureMessageNotFound,
    INEditMessageIntentResponseCodeFailurePastEditTimeLimit,
    INEditMessageIntentResponseCodeFailureMessageTypeUnsupported,
    INEditMessageIntentResponseCodeFailureUnsupportedOnService,
    INEditMessageIntentResponseCodeFailureMessageServiceNotAvailable,
    INEditMessageIntentResponseCodeFailureRequiringInAppAuthentication,
};

// The message to edit, by identifier, and what it is to say. iOS 17.0.
@class INStringResolutionResult;

API_AVAILABLE(ios(17.0), macos(14.0), watchos(10.0))
API_UNAVAILABLE(tvos)
@interface INEditMessageIntent : INIntent

- (instancetype)initWithMessageIdentifier:(nullable NSString *)messageIdentifier
                            editedContent:(nullable NSString *)editedContent NS_DESIGNATED_INITIALIZER;

@property (readonly, copy, nullable, NS_NONATOMIC_IOSONLY) NSString *messageIdentifier;
@property (readonly, copy, nullable, NS_NONATOMIC_IOSONLY) NSString *editedContent;

@end

@class INEditMessageIntentResponse;

API_AVAILABLE(ios(17.0), macos(14.0), watchos(10.0))
API_UNAVAILABLE(tvos)
@protocol INEditMessageIntentHandling <NSObject>

@required
- (void)handleEditMessage:(INEditMessageIntent *)intent
               completion:(void (^)(INEditMessageIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));

@optional
- (void)confirmEditMessage:(INEditMessageIntent *)intent
                completion:(void (^)(INEditMessageIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveEditedContentForEditMessage:(INEditMessageIntent *)intent
                            withCompletion:(void (^)(INStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveEditedContent(for:with:));

@end

// The answer to an edit. iOS 17.0.
API_AVAILABLE(ios(17.0), macos(14.0), watchos(10.0))
API_UNAVAILABLE(tvos)
@interface INEditMessageIntentResponse : INIntentResponse

- (id)init NS_UNAVAILABLE;

- (instancetype)initWithCode:(INEditMessageIntentResponseCode)code
                 userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;

@property (readonly, NS_NONATOMIC_IOSONLY) INEditMessageIntentResponseCode code;

@end

// What a reaction is: an emoji, or a generic one the service named. iOS 18.0.
typedef NS_ENUM(NSInteger, INMessageReactionType) {
    INMessageReactionTypeUnknown = 0,
    INMessageReactionTypeEmoji,
    INMessageReactionTypeGeneric,
};

// A reaction to a message. iOS 18.0.
API_AVAILABLE(ios(18.0), macos(15.0), watchos(11.0))
API_UNAVAILABLE(tvos)
@interface INMessageReaction : NSObject <NSCopying, NSSecureCoding>

- (instancetype)initWithReactionType:(INMessageReactionType)reactionType
                 reactionDescription:(nullable NSString *)reactionDescription
                               emoji:(nullable NSString *)emoji NS_DESIGNATED_INITIALIZER;

@property (readonly, assign, NS_NONATOMIC_IOSONLY) INMessageReactionType reactionType;
@property (readonly, copy, nullable, NS_NONATOMIC_IOSONLY) NSString *reactionDescription;
@property (readonly, copy, nullable, NS_NONATOMIC_IOSONLY) NSString *emoji;

@end

// What a sticker is: an emoji, or a generic one. iOS 18.0.
typedef NS_ENUM(NSInteger, INStickerType) {
    INStickerTypeUnknown = 0,
    INStickerTypeEmoji,
    INStickerTypeGeneric,
};

// A sticker on a message. iOS 18.0.
API_AVAILABLE(ios(18.0), macos(15.0), watchos(11.0))
API_UNAVAILABLE(tvos)
@interface INSticker : NSObject <NSCopying, NSSecureCoding>

- (instancetype)initWithType:(INStickerType)type
                       emoji:(nullable NSString *)emoji NS_DESIGNATED_INITIALIZER;

@property (readonly, assign, NS_NONATOMIC_IOSONLY) INStickerType type;
@property (readonly, copy, nullable, NS_NONATOMIC_IOSONLY) NSString *emoji;

@end

NS_ASSUME_NONNULL_END

#endif // CHARON_HOST_BUILD

#import <Foundation/Foundation.h>
#import <Intents/Intents.h>

#ifndef REVENANT_HOST_BUILD

NS_ASSUME_NONNULL_BEGIN

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

API_AVAILABLE(ios(17.0), macos(14.0), watchos(10.0))
API_UNAVAILABLE(tvos)
@interface INUnsendMessagesIntentResponse : INIntentResponse

- (id)init NS_UNAVAILABLE;

- (instancetype)initWithCode:(INUnsendMessagesIntentResponseCode)code
                 userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;

@property (readonly, NS_NONATOMIC_IOSONLY) INUnsendMessagesIntentResponseCode code;

@end

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

API_AVAILABLE(ios(17.0), macos(14.0), watchos(10.0))
API_UNAVAILABLE(tvos)
@interface INEditMessageIntentResponse : INIntentResponse

- (id)init NS_UNAVAILABLE;

- (instancetype)initWithCode:(INEditMessageIntentResponseCode)code
                 userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;

@property (readonly, NS_NONATOMIC_IOSONLY) INEditMessageIntentResponseCode code;

@end

typedef NS_ENUM(NSInteger, INMessageReactionType) {
    INMessageReactionTypeUnknown = 0,
    INMessageReactionTypeEmoji,
    INMessageReactionTypeGeneric,
};

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

typedef NS_ENUM(NSInteger, INStickerType) {
    INStickerTypeUnknown = 0,
    INStickerTypeEmoji,
    INStickerTypeGeneric,
};

API_AVAILABLE(ios(18.0), macos(15.0), watchos(11.0))
API_UNAVAILABLE(tvos)
@interface INSticker : NSObject <NSCopying, NSSecureCoding>

- (instancetype)initWithType:(INStickerType)type
                       emoji:(nullable NSString *)emoji NS_DESIGNATED_INITIALIZER;

@property (readonly, assign, NS_NONATOMIC_IOSONLY) INStickerType type;
@property (readonly, copy, nullable, NS_NONATOMIC_IOSONLY) NSString *emoji;

@end

NS_ASSUME_NONNULL_END

#endif

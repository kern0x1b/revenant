#import <Foundation/Foundation.h>
#import <Intents/Intents.h>

#ifndef REVENANT_HOST_BUILD

NS_ASSUME_NONNULL_BEGIN

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

@class INStringResolutionResult;

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


API_AVAILABLE(ios(18.0), macos(15.0), watchos(11.0))
API_UNAVAILABLE(tvos)


API_AVAILABLE(ios(18.0), macos(15.0), watchos(11.0))
API_UNAVAILABLE(tvos)

NS_ASSUME_NONNULL_END

#endif

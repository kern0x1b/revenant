#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>

// -[ENManager getExposureInfoFromSummary:userExplanation:completionHandler:], iOS 13.5.
//
// One member, and one release: ENManager's other members arrived in 12.5 and are in ENManager.m, whose
// file explains why this release has no exposure-notification service to ask. An object holds the API
// of exactly one release, so this member cannot share a file with those.
//
// It answers the same way they do, through the framework's own domain and its own documented code: the
// summary an application would pass is one it cannot have without a detection pass, so there is nothing
// to turn into exposure information, and the completion handler is called with nil and an error.

@implementation ENManager (CharonExposureInfo13)

- (void)getExposureInfoFromSummary:(ENExposureDetectionSummary *)summary
                  userExplanation:(NSString *)userExplanation
                  completionHandler:(void (^)(NSArray<ENExposureInfo *> *_Nullable exposureInfo, NSError *_Nullable error))completionHandler
{
    if (!completionHandler)
        return;
    completionHandler(nil, [NSError errorWithDomain:ENErrorDomain
                                                code:ENErrorCodeUnsupported
                                            userInfo:@{NSLocalizedDescriptionKey: @"Operation is not supported"}]);
}

@end

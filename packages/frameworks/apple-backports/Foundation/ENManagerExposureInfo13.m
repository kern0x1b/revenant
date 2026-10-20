#import <Foundation/Foundation.h>
#import <ExposureNotification/ExposureNotification.h>

@implementation ENManager (RevenantExposureInfo13)

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

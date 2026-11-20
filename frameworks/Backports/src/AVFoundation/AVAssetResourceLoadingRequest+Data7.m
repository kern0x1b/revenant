#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import "RevenantRangeHeader.h"

static char revenant_data_request_key;
static char revenant_response_key;
static char revenant_failure_key;
static char revenant_completion_key;
static NSString *const RevenantRangeErrorDomain = @"RevenantRangeErrorDomain";

@interface AVAssetResourceLoadingDataRequest (RevenantInit)
- (instancetype)initWithRevenantRequestedOffset:(long long)offset length:(NSInteger)length toEnd:(BOOL)toEnd;
- (NSData *)revenant_accumulatedData;
@end

@interface AVAssetResourceLoadingRequest (RevenantIOS6)
- (void)finishLoadingWithResponse:(NSURLResponse *)response data:(NSData *)data redirect:(NSURLRequest *)redirect;
- (BOOL)revenant_claimCompletion;
@end

@implementation AVAssetResourceLoadingRequest (RevenantData7)

- (BOOL)revenant_claimCompletion
{
    @synchronized (self) {
        if (objc_getAssociatedObject(self, &revenant_completion_key))
            return NO;
        objc_setAssociatedObject(self, &revenant_completion_key, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return YES;
    }
}

- (AVAssetResourceLoadingDataRequest *)dataRequest
{
    @synchronized (self) {
        AVAssetResourceLoadingDataRequest *data = objc_getAssociatedObject(self, &revenant_data_request_key);
        if (data)
            return data;
        if (objc_getAssociatedObject(self, &revenant_failure_key))
            return nil;
        long long offset = 0, length = 0;
        int toEnd = 0;
        RevenantRangeStatus status = revenant_range_header_parse(
            [[self.request valueForHTTPHeaderField:@"Range"] UTF8String], REVENANT_RANGE_TOTAL_UNKNOWN,
            &offset, &length, &toEnd);
        if (status != REVENANT_RANGE_OK) {
            objc_setAssociatedObject(self, &revenant_failure_key, @(status), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if ([self revenant_claimCompletion]) {
                NSDictionary *info = @{NSLocalizedDescriptionKey: @"The Range header cannot be served on iOS 6"};
                [self finishLoadingWithError:[NSError errorWithDomain:RevenantRangeErrorDomain code:status userInfo:info]];
            }
            return nil;
        }
        data = [[AVAssetResourceLoadingDataRequest alloc] initWithRevenantRequestedOffset:offset length:(NSInteger)length toEnd:(BOOL)toEnd];
        objc_setAssociatedObject(self, &revenant_data_request_key, data, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return data;
    }
}

- (AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest
{
    return nil;
}

- (NSURLResponse *)response
{
    return objc_getAssociatedObject(self, &revenant_response_key);
}

- (void)setResponse:(NSURLResponse *)response
{
    objc_setAssociatedObject(self, &revenant_response_key, response, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)finishLoading
{
    AVAssetResourceLoadingDataRequest *data = [self dataRequest];
    if (!data)
        return;
    if ([self revenant_claimCompletion])
        [self finishLoadingWithResponse:[self response] data:[data revenant_accumulatedData] redirect:nil];
}

@end

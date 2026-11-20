#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>
#import "RevenantRangeHeader.h"

static char revenant_data_request_key;
static char revenant_response_key;

@interface AVAssetResourceLoadingDataRequest (RevenantInit)
- (instancetype)initWithRevenantRequestedOffset:(long long)offset length:(NSInteger)length toEnd:(BOOL)toEnd;
- (NSData *)revenant_accumulatedData;
@end

@interface AVAssetResourceLoadingRequest (RevenantIOS6)
- (void)finishLoadingWithResponse:(NSURLResponse *)response data:(NSData *)data redirect:(NSURLRequest *)redirect;
@end

@implementation AVAssetResourceLoadingRequest (RevenantData7)

- (AVAssetResourceLoadingDataRequest *)dataRequest
{
    AVAssetResourceLoadingDataRequest *data = objc_getAssociatedObject(self, &revenant_data_request_key);
    if (data)
        return data;
    long long offset = 0, length = 0;
    int toEnd = 1;
    revenant_range_header_parse([[self.request valueForHTTPHeaderField:@"Range"] UTF8String], &offset, &length, &toEnd);
    data = [[AVAssetResourceLoadingDataRequest alloc] initWithRevenantRequestedOffset:offset length:(NSInteger)length toEnd:(BOOL)toEnd];
    objc_setAssociatedObject(self, &revenant_data_request_key, data, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return data;
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
    [self finishLoadingWithResponse:[self response] data:[data revenant_accumulatedData] redirect:nil];
}

@end

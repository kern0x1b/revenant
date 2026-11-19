#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static char revenant_data_request_key;

@interface AVAssetResourceLoadingDataRequest (RevenantInit)
- (instancetype)initWithRevenantRequestedOffset:(long long)offset length:(NSInteger)length toEnd:(BOOL)toEnd;
@end

@implementation AVAssetResourceLoadingRequest (RevenantData7)

- (AVAssetResourceLoadingDataRequest *)dataRequest
{
    AVAssetResourceLoadingDataRequest *data = objc_getAssociatedObject(self, &revenant_data_request_key);
    if (data)
        return data;
    NSString *range = [self.request valueForHTTPHeaderField:@"Range"];
    long long offset = 0;
    NSInteger length = 0;
    BOOL toEnd = YES;
    NSString *value = [range hasPrefix:@"bytes="] ? [range substringFromIndex:6] : range;
    NSArray *parts = [value componentsSeparatedByString:@"-"];
    if (parts.count == 2) {
        offset = [parts[0] longLongValue];
        if ([parts[1] length]) {
            length = [parts[1] integerValue] - (NSInteger)offset + 1;
            toEnd = NO;
        }
    }
    data = [[AVAssetResourceLoadingDataRequest alloc] initWithRevenantRequestedOffset:offset length:length toEnd:toEnd];
    objc_setAssociatedObject(self, &revenant_data_request_key, data, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return data;
}

- (AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest
{
    return nil;
}

@end

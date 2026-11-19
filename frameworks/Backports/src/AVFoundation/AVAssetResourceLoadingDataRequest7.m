#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static char revenant_data_accumulation_key;

@implementation AVAssetResourceLoadingDataRequest {
    long long _requestedOffset;
    long long _currentOffset;
    NSInteger _requestedLength;
    BOOL _requestsAllDataToEndOfResource;
}

- (instancetype)initWithRevenantRequestedOffset:(long long)offset length:(NSInteger)length toEnd:(BOOL)toEnd
{
    if ((self = [super init])) {
        _requestedOffset = offset;
        _currentOffset = offset;
        _requestedLength = length;
        _requestsAllDataToEndOfResource = toEnd;
    }
    return self;
}

- (long long)requestedOffset
{
    return _requestedOffset;
}

- (long long)currentOffset
{
    return _currentOffset;
}

- (NSInteger)requestedLength
{
    return _requestedLength;
}

- (BOOL)requestsAllDataToEndOfResource
{
    return _requestsAllDataToEndOfResource;
}

- (void)respondWithData:(NSData *)data
{
    NSMutableData *accumulated = objc_getAssociatedObject(self, &revenant_data_accumulation_key);
    if (!accumulated) {
        accumulated = [NSMutableData data];
        objc_setAssociatedObject(self, &revenant_data_accumulation_key, accumulated, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [accumulated appendData:data];
    _currentOffset += data.length;
}

- (NSData *)revenant_accumulatedData
{
    return objc_getAssociatedObject(self, &revenant_data_accumulation_key);
}

@end

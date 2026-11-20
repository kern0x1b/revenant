#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

static char revenant_data_accumulation_key;

@implementation AVAssetResourceLoadingDataRequest {
    long long _requestedOffset;
    long long _currentOffset;
    NSInteger _requestedLength;
    BOOL _requestsAllDataToEndOfResource;
    NSLock *_lock;
}

- (instancetype)initWithRevenantRequestedOffset:(long long)offset length:(NSInteger)length toEnd:(BOOL)toEnd
{
    if ((self = [super init])) {
        _requestedOffset = offset;
        _currentOffset = offset;
        _requestedLength = length;
        _requestsAllDataToEndOfResource = toEnd;
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (long long)requestedOffset
{
    return _requestedOffset;
}

- (long long)currentOffset
{
    [_lock lock];
    long long offset = _currentOffset;
    [_lock unlock];
    return offset;
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
    [_lock lock];
    NSMutableData *accumulated = objc_getAssociatedObject(self, &revenant_data_accumulation_key);
    if (!accumulated) {
        accumulated = [NSMutableData data];
        objc_setAssociatedObject(self, &revenant_data_accumulation_key, accumulated, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [accumulated appendData:data];
    _currentOffset += data.length;
    [_lock unlock];
}

- (NSData *)revenant_accumulatedData
{
    [_lock lock];
    NSData *data = [objc_getAssociatedObject(self, &revenant_data_accumulation_key) copy];
    [_lock unlock];
    return data;
}

@end

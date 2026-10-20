#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

@interface AVCaptureSynchronizedData ()
- (instancetype)initWithRevenantTimestamp:(CMTime)timestamp;
@end

@implementation AVCaptureSynchronizedData
{
    CMTime _revenantTimestamp;
}

- (instancetype)initWithRevenantTimestamp:(CMTime)timestamp
{
    if ((self = [super init]))
        _revenantTimestamp = timestamp;
    return self;
}

- (CMTime)timestamp
{
    return _revenantTimestamp;
}

@end

@interface AVCaptureSynchronizedSampleBufferData ()
- (instancetype)initWithRevenantSampleBuffer:(CMSampleBufferRef)sampleBuffer dropped:(BOOL)dropped reason:(AVCaptureOutputDataDroppedReason)reason;
@end

@implementation AVCaptureSynchronizedSampleBufferData
{
    CMSampleBufferRef _revenantSampleBuffer;
    BOOL _revenantSampleBufferWasDropped;
    AVCaptureOutputDataDroppedReason _revenantDroppedReason;
}

- (instancetype)initWithRevenantSampleBuffer:(CMSampleBufferRef)sampleBuffer dropped:(BOOL)dropped reason:(AVCaptureOutputDataDroppedReason)reason
{
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if ((self = [super initWithRevenantTimestamp:timestamp])) {
        _revenantSampleBuffer = sampleBuffer;
        CFRetain(_revenantSampleBuffer);
        _revenantSampleBufferWasDropped = dropped;
        _revenantDroppedReason = reason;
    }
    return self;
}

- (void)dealloc
{
    if (_revenantSampleBuffer)
        CFRelease(_revenantSampleBuffer);
}

- (CMSampleBufferRef)sampleBuffer
{
    return _revenantSampleBuffer;
}

- (BOOL)sampleBufferWasDropped
{
    return _revenantSampleBufferWasDropped;
}

- (AVCaptureOutputDataDroppedReason)droppedReason
{
    return _revenantDroppedReason;
}

@end

@implementation AVCaptureSynchronizedMetadataObjectData

- (NSArray<AVMetadataObject *> *)metadataObjects
{
    return @[];
}

@end

@implementation AVCaptureSynchronizedDepthData

- (AVDepthData *)depthData
{
    return nil;
}

- (BOOL)depthDataWasDropped
{
    return NO;
}

- (AVCaptureOutputDataDroppedReason)droppedReason
{
    return AVCaptureOutputDataDroppedReasonNone;
}

@end

@interface AVCaptureSynchronizedDataCollection () <NSFastEnumeration>
- (instancetype)initWithRevenantEntries:(NSMapTable<AVCaptureOutput *, AVCaptureSynchronizedData *> *)entries;
@end

@implementation AVCaptureSynchronizedDataCollection
{
    NSMapTable<AVCaptureOutput *, AVCaptureSynchronizedData *> *_revenantEntries;
}

- (instancetype)initWithRevenantEntries:(NSMapTable<AVCaptureOutput *, AVCaptureSynchronizedData *> *)entries
{
    if ((self = [super init]))
        _revenantEntries = entries;
    return self;
}

- (AVCaptureSynchronizedData *)synchronizedDataForCaptureOutput:(AVCaptureOutput *)captureOutput
{
    return [_revenantEntries objectForKey:captureOutput];
}

- (AVCaptureSynchronizedData *)objectForKeyedSubscript:(AVCaptureOutput *)key
{
    return [self synchronizedDataForCaptureOutput:key];
}

- (NSUInteger)count
{
    return _revenantEntries.count;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    return [[_revenantEntries.keyEnumerator allObjects] countByEnumeratingWithState:state objects:buffer count:len];
}

@end

@interface AVCaptureDataOutputSynchronizer () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
@end

@implementation AVCaptureDataOutputSynchronizer
{
    NSArray<AVCaptureOutput *> *_revenantDataOutputs;
    __weak id<AVCaptureDataOutputSynchronizerDelegate> _revenantDelegate;
    dispatch_queue_t _revenantQueue;
    NSMapTable<AVCaptureOutput *, AVCaptureSynchronizedData *> *_revenantLatest;
}

- (instancetype)initWithDataOutputs:(NSArray<AVCaptureOutput *> *)dataOutputs
{
    if ((self = [super init])) {
        _revenantDataOutputs = [dataOutputs copy];
        _revenantLatest = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}

- (NSArray<AVCaptureOutput *> *)dataOutputs
{
    return _revenantDataOutputs;
}

- (id<AVCaptureDataOutputSynchronizerDelegate>)delegate
{
    return _revenantDelegate;
}

- (dispatch_queue_t)delegateCallbackQueue
{
    return _revenantQueue;
}

- (void)setDelegate:(id<AVCaptureDataOutputSynchronizerDelegate>)delegate queue:(dispatch_queue_t)delegateCallbackQueue
{
    _revenantDelegate = delegate;
    _revenantQueue = delegate ? delegateCallbackQueue : nil;
    for (AVCaptureOutput *output in _revenantDataOutputs) {
        if ([output isKindOfClass:[AVCaptureVideoDataOutput class]])
            [(AVCaptureVideoDataOutput *)output setSampleBufferDelegate:delegate ? self : nil queue:delegate ? delegateCallbackQueue : nil];
        else if ([output isKindOfClass:[AVCaptureAudioDataOutput class]])
            [(AVCaptureAudioDataOutput *)output setSampleBufferDelegate:delegate ? self : nil queue:delegate ? delegateCallbackQueue : nil];
    }
}

- (void)revenant_recordSampleBuffer:(CMSampleBufferRef)sampleBuffer forOutput:(AVCaptureOutput *)output dropped:(BOOL)dropped reason:(AVCaptureOutputDataDroppedReason)reason
{
    AVCaptureSynchronizedSampleBufferData *data = [[AVCaptureSynchronizedSampleBufferData alloc] initWithRevenantSampleBuffer:sampleBuffer dropped:dropped reason:reason];
    @synchronized (_revenantLatest) {
        [_revenantLatest setObject:data forKey:output];
    }
    if (output != _revenantDataOutputs.firstObject)
        return;
    NSMapTable *snapshot = [NSMapTable strongToStrongObjectsMapTable];
    @synchronized (_revenantLatest) {
        for (AVCaptureOutput *held in _revenantDataOutputs) {
            AVCaptureSynchronizedData *latest = [_revenantLatest objectForKey:held];
            if (latest)
                [snapshot setObject:latest forKey:held];
        }
    }
    AVCaptureSynchronizedDataCollection *collection = [[AVCaptureSynchronizedDataCollection alloc] initWithRevenantEntries:snapshot];
    id<AVCaptureDataOutputSynchronizerDelegate> delegate = _revenantDelegate;
    if ([delegate respondsToSelector:@selector(dataOutputSynchronizer:didOutputSynchronizedDataCollection:)])
        [delegate dataOutputSynchronizer:self didOutputSynchronizedDataCollection:collection];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    [self revenant_recordSampleBuffer:sampleBuffer forOutput:output dropped:NO reason:AVCaptureOutputDataDroppedReasonNone];
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    [self revenant_recordSampleBuffer:sampleBuffer forOutput:output dropped:YES reason:AVCaptureOutputDataDroppedReasonLateData];
}

@end

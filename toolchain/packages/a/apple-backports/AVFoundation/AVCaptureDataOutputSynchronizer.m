#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

@interface AVCaptureSynchronizedData ()
- (instancetype)initWithCharonTimestamp:(CMTime)timestamp;
@end

@implementation AVCaptureSynchronizedData
{
    CMTime _charonTimestamp;
}

- (instancetype)initWithCharonTimestamp:(CMTime)timestamp
{
    if ((self = [super init]))
        _charonTimestamp = timestamp;
    return self;
}

- (CMTime)timestamp
{
    return _charonTimestamp;
}

@end

@interface AVCaptureSynchronizedSampleBufferData ()
- (instancetype)initWithCharonSampleBuffer:(CMSampleBufferRef)sampleBuffer dropped:(BOOL)dropped reason:(AVCaptureOutputDataDroppedReason)reason;
@end

@implementation AVCaptureSynchronizedSampleBufferData
{
    CMSampleBufferRef _charonSampleBuffer;
    BOOL _charonSampleBufferWasDropped;
    AVCaptureOutputDataDroppedReason _charonDroppedReason;
}

- (instancetype)initWithCharonSampleBuffer:(CMSampleBufferRef)sampleBuffer dropped:(BOOL)dropped reason:(AVCaptureOutputDataDroppedReason)reason
{
    CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if ((self = [super initWithCharonTimestamp:timestamp])) {
        _charonSampleBuffer = sampleBuffer;
        CFRetain(_charonSampleBuffer);
        _charonSampleBufferWasDropped = dropped;
        _charonDroppedReason = reason;
    }
    return self;
}

- (void)dealloc
{
    if (_charonSampleBuffer)
        CFRelease(_charonSampleBuffer);
}

- (CMSampleBufferRef)sampleBuffer
{
    return _charonSampleBuffer;
}

- (BOOL)sampleBufferWasDropped
{
    return _charonSampleBufferWasDropped;
}

- (AVCaptureOutputDataDroppedReason)droppedReason
{
    return _charonDroppedReason;
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
- (instancetype)initWithCharonEntries:(NSMapTable<AVCaptureOutput *, AVCaptureSynchronizedData *> *)entries;
@end

@implementation AVCaptureSynchronizedDataCollection
{
    NSMapTable<AVCaptureOutput *, AVCaptureSynchronizedData *> *_charonEntries;
}

- (instancetype)initWithCharonEntries:(NSMapTable<AVCaptureOutput *, AVCaptureSynchronizedData *> *)entries
{
    if ((self = [super init]))
        _charonEntries = entries;
    return self;
}

- (AVCaptureSynchronizedData *)synchronizedDataForCaptureOutput:(AVCaptureOutput *)captureOutput
{
    return [_charonEntries objectForKey:captureOutput];
}

- (AVCaptureSynchronizedData *)objectForKeyedSubscript:(AVCaptureOutput *)key
{
    return [self synchronizedDataForCaptureOutput:key];
}

- (NSUInteger)count
{
    return _charonEntries.count;
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained [])buffer count:(NSUInteger)len
{
    return [[_charonEntries.keyEnumerator allObjects] countByEnumeratingWithState:state objects:buffer count:len];
}

@end

@interface AVCaptureDataOutputSynchronizer () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
@end

@implementation AVCaptureDataOutputSynchronizer
{
    NSArray<AVCaptureOutput *> *_charonDataOutputs;
    __weak id<AVCaptureDataOutputSynchronizerDelegate> _charonDelegate;
    dispatch_queue_t _charonQueue;
    NSMapTable<AVCaptureOutput *, AVCaptureSynchronizedData *> *_charonLatest;
}

- (instancetype)initWithDataOutputs:(NSArray<AVCaptureOutput *> *)dataOutputs
{
    if ((self = [super init])) {
        _charonDataOutputs = [dataOutputs copy];
        _charonLatest = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}

- (NSArray<AVCaptureOutput *> *)dataOutputs
{
    return _charonDataOutputs;
}

- (id<AVCaptureDataOutputSynchronizerDelegate>)delegate
{
    return _charonDelegate;
}

- (dispatch_queue_t)delegateCallbackQueue
{
    return _charonQueue;
}

- (void)setDelegate:(id<AVCaptureDataOutputSynchronizerDelegate>)delegate queue:(dispatch_queue_t)delegateCallbackQueue
{
    _charonDelegate = delegate;
    _charonQueue = delegate ? delegateCallbackQueue : nil;
    for (AVCaptureOutput *output in _charonDataOutputs) {
        if ([output isKindOfClass:[AVCaptureVideoDataOutput class]])
            [(AVCaptureVideoDataOutput *)output setSampleBufferDelegate:delegate ? self : nil queue:delegate ? delegateCallbackQueue : nil];
        else if ([output isKindOfClass:[AVCaptureAudioDataOutput class]])
            [(AVCaptureAudioDataOutput *)output setSampleBufferDelegate:delegate ? self : nil queue:delegate ? delegateCallbackQueue : nil];
    }
}

- (void)charon_recordSampleBuffer:(CMSampleBufferRef)sampleBuffer forOutput:(AVCaptureOutput *)output dropped:(BOOL)dropped reason:(AVCaptureOutputDataDroppedReason)reason
{
    AVCaptureSynchronizedSampleBufferData *data = [[AVCaptureSynchronizedSampleBufferData alloc] initWithCharonSampleBuffer:sampleBuffer dropped:dropped reason:reason];
    @synchronized (_charonLatest) {
        [_charonLatest setObject:data forKey:output];
    }
    if (output != _charonDataOutputs.firstObject)
        return;
    NSMapTable *snapshot = [NSMapTable strongToStrongObjectsMapTable];
    @synchronized (_charonLatest) {
        for (AVCaptureOutput *held in _charonDataOutputs) {
            AVCaptureSynchronizedData *latest = [_charonLatest objectForKey:held];
            if (latest)
                [snapshot setObject:latest forKey:held];
        }
    }
    AVCaptureSynchronizedDataCollection *collection = [[AVCaptureSynchronizedDataCollection alloc] initWithCharonEntries:snapshot];
    id<AVCaptureDataOutputSynchronizerDelegate> delegate = _charonDelegate;
    if ([delegate respondsToSelector:@selector(dataOutputSynchronizer:didOutputSynchronizedDataCollection:)])
        [delegate dataOutputSynchronizer:self didOutputSynchronizedDataCollection:collection];
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    [self charon_recordSampleBuffer:sampleBuffer forOutput:output dropped:NO reason:AVCaptureOutputDataDroppedReasonNone];
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    [self charon_recordSampleBuffer:sampleBuffer forOutput:output dropped:YES reason:AVCaptureOutputDataDroppedReasonLateData];
}

@end

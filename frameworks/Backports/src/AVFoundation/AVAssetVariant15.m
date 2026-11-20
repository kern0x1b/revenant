#import <AVFoundation/AVAssetVariant.h>

@implementation AVAssetVariantVideoAttributes {
    CGSize _presentationSize;
    NSArray<NSNumber *> *_codecTypes;
    double _nominalFrameRate;
    AVVideoRange _videoRange;
}

- (CGSize)presentationSize
{
    return _presentationSize;
}

- (NSArray<NSNumber *> *)codecTypes
{
    return _codecTypes;
}

- (double)nominalFrameRate
{
    return _nominalFrameRate;
}

- (AVVideoRange)videoRange
{
    return _videoRange;
}

@end

@implementation AVAssetVariant {
    double _peakBitRate;
    double _averageBitRate;
    AVAssetVariantVideoAttributes *_videoAttributes;
}

- (double)peakBitRate
{
    return _peakBitRate;
}

- (double)averageBitRate
{
    return _averageBitRate;
}

- (AVAssetVariantVideoAttributes *)videoAttributes
{
    return _videoAttributes;
}

@end

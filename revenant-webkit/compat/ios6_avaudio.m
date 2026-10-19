#import <AVFoundation/AVFoundation.h>

@interface AVAudioSession (WebKitIOS6ChannelCounts)
@end

@implementation AVAudioSession (WebKitIOS6ChannelCounts)

- (NSInteger)maximumOutputNumberOfChannels
{
    NSInteger channels = [self outputNumberOfChannels];
    return channels > 0 ? channels : 2;
}

- (NSInteger)maximumInputNumberOfChannels
{
    NSInteger channels = [self inputNumberOfChannels];
    return channels > 0 ? channels : 1;
}

@end

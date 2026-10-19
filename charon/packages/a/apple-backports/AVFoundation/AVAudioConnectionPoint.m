#import "CharonAVAudioEngine.h"
#import <AVFAudio/AVAudioConnectionPoint.h>

@implementation AVAudioConnectionPoint

- (instancetype)initWithNode:(AVAudioNode *)node bus:(AVAudioNodeBus)bus
{
    if ((self = [super init])) {
        _node = node;
        _bus = bus;
    }
    return self;
}

- (AVAudioNode *)node
{
    return _node;
}

- (AVAudioNodeBus)bus
{
    return _bus;
}

@end

#import "RevenantSCNClock.h"

@implementation RevenantSCNClock
{
    NSTimeInterval _offset;
    NSTimeInterval _frozen;
    BOOL _playing;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _playing = YES;
    }
    return self;
}

- (NSTimeInterval)sceneTimeAtWallTime:(CFTimeInterval)wall
{
    return _playing ? wall + _offset : _frozen;
}

- (void)setSceneTime:(NSTimeInterval)time atWallTime:(CFTimeInterval)wall
{
    _offset = time - wall;
    _frozen = time;
}

- (BOOL)isPlaying
{
    return _playing;
}

- (void)setPlaying:(BOOL)playing atWallTime:(CFTimeInterval)wall
{
    if (playing == _playing) {
        return;
    }
    if (playing) {
        _offset = _frozen - wall;
    } else {
        _frozen = wall + _offset;
    }
    _playing = playing;
}

@end

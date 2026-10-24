#import <AVFoundation/AVFoundation.h>
#import "RevenantSCNAudio.h"

@interface RevenantSCNAudioPlayerDelegate : NSObject <AVAudioPlayerDelegate>
@property (nonatomic, weak) SCNAudioPlayer *owner;
@end

@implementation RevenantSCNAudioPlayerDelegate

@synthesize owner = _owner;

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    [self.owner revenantDidFinishPlayback];
}

@end

@implementation SCNAudioPlayer
{
    AVAudioPlayer *_player;
    RevenantSCNAudioPlayerDelegate *_delegate;
    __weak SCNNode *_node;
}

@synthesize audioSource = _audioSource;
@synthesize willStartPlayback = _willStartPlayback;
@synthesize didFinishPlayback = _didFinishPlayback;

- (instancetype)initWithSource:(SCNAudioSource *)source
{
    if (source == nil) {
        return nil;
    }
    if ((self = [super init])) {
        _audioSource = source;
    }
    return self;
}

+ (instancetype)audioPlayerWithSource:(SCNAudioSource *)source
{
    return [[self alloc] initWithSource:source];
}

- (AVAudioPlayer *)revenantAVPlayer
{
    if (_player) {
        return _player;
    }
    NSError *error = nil;
    AVAudioPlayer *player;
    if (_audioSource.shouldStream) {
        player = [[AVAudioPlayer alloc] initWithContentsOfURL:[_audioSource revenantURL] error:&error];
    } else {
        NSData *data = [_audioSource revenantData];
        player = data ? [[AVAudioPlayer alloc] initWithData:data error:&error] : nil;
    }
    if (player == nil) {
        return nil;
    }
    player.numberOfLoops = _audioSource.loops ? -1 : 0;
    player.volume = _audioSource.volume;
    player.enableRate = YES;
    player.rate = _audioSource.rate;
    _delegate = [[RevenantSCNAudioPlayerDelegate alloc] init];
    _delegate.owner = self;
    player.delegate = _delegate;
    [player prepareToPlay];
    _player = player;
    return _player;
}

- (void)revenantStartOnNode:(nullable SCNNode *)node
{
    _node = node;
    AVAudioPlayer *player = [self revenantAVPlayer];
    if (player == nil) {
        [node removeAudioPlayer:self];
        return;
    }
    if (_willStartPlayback) {
        _willStartPlayback();
    }
    if (![player play]) {
        [node removeAudioPlayer:self];
    }
}

- (void)revenantStop
{
    [_player stop];
}

- (void)revenantDidFinishPlayback
{
    [_node revenantRemoveFinishedAudioPlayer:self];
    if (_didFinishPlayback) {
        _didFinishPlayback();
    }
}

- (BOOL)revenantIsSpatial
{
    return _audioSource.positional && !_audioSource.shouldStream;
}

- (float)revenantSourceVolume
{
    return _audioSource.volume;
}

- (void)revenantApplyMix:(RevenantSCNAudioMix)mix
{
    _player.pan = mix.pan;
    _player.volume = mix.volume;
}

@end

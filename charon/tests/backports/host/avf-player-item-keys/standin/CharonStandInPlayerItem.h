//
//  CharonStandInPlayerItem.h
//  A stand-in for AVPlayerItem in the port build of tests/backports/host/avf-player-item-keys/probe.m. It holds one
//  real AVPlayerItem, made by Apple's own initializer, and the port's category (AVPlayerItemAutomaticKeys7.m, with
//  its class name changed by run.sh) is compiled onto this class instead of onto AVPlayerItem.
#import <AVFoundation/AVFoundation.h>

@interface CharonStandInPlayerItem : NSObject

- (instancetype)initWithAsset:(AVAsset *)asset;

@property (nonatomic, readonly) AVPlayerItem *item;

@end

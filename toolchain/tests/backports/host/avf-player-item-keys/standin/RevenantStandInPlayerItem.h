#import <AVFoundation/AVFoundation.h>

@interface CharonStandInPlayerItem : NSObject

- (instancetype)initWithAsset:(AVAsset *)asset;

@property (nonatomic, readonly) AVPlayerItem *item;

@end

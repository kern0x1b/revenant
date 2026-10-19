#import <AVFoundation/AVFoundation.h>

@interface RevenantStandInPlayerItem : NSObject

- (instancetype)initWithAsset:(AVAsset *)asset;

@property (nonatomic, readonly) AVPlayerItem *item;

@end

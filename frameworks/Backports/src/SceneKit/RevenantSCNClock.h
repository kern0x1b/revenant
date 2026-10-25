#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RevenantSCNClock : NSObject
- (NSTimeInterval)sceneTimeAtWallTime:(CFTimeInterval)wall;
- (void)setSceneTime:(NSTimeInterval)time atWallTime:(CFTimeInterval)wall;
- (BOOL)isPlaying;
- (void)setPlaying:(BOOL)playing atWallTime:(CFTimeInterval)wall;
@end

NS_ASSUME_NONNULL_END

#import <AVFoundation/AVFoundation.h>

@interface AVAsset (RevenantGroups5)
- (NSArray<AVMediaSelectionGroup *> *)mediaSelectionGroups;
@end

@interface AVMediaSelection (RevenantSelection5)
- (AVMediaSelectionOption *)selectedMediaOptionInMediaSelectionGroup:(AVMediaSelectionGroup *)group;
- (void)selectMediaOption:(AVMediaSelectionOption *)option inMediaSelectionGroup:(AVMediaSelectionGroup *)group;
@end

@implementation AVPlayerItem (RevenantCurrentMediaSelection5)

- (AVMediaSelection *)currentMediaSelection
{
    AVMediaSelection *selection = [[AVMediaSelection alloc] init];
    for (AVMediaSelectionGroup *group in [self.asset mediaSelectionGroups]) {
        AVMediaSelectionOption *option = [self selectedMediaOptionInMediaSelectionGroup:group];
        if (option)
            [selection selectMediaOption:option inMediaSelectionGroup:group];
    }
    return selection;
}

@end

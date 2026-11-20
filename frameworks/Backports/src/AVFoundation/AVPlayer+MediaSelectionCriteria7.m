#import <AVFoundation/AVFoundation.h>

@interface AVPlayerItem (RevenantSelection5)
- (void)selectMediaOption:(AVMediaSelectionOption *)option inMediaSelectionGroup:(AVMediaSelectionGroup *)group;
@end

@implementation AVPlayer (RevenantMediaSelectionCriteria7)

- (void)setMediaSelectionCriteria:(id)criteria forMediaCharacteristic:(AVMediaCharacteristic)characteristic
{
    AVMediaSelectionGroup *group = [self.currentItem.asset mediaSelectionGroupForMediaCharacteristic:characteristic];
    if (!group)
        return;
    NSArray<NSString *> *languages = [criteria respondsToSelector:@selector(preferredLanguages)] ? [criteria performSelector:@selector(preferredLanguages)] : nil;
    NSArray<AVMediaSelectionOption *> *options = languages.count
        ? [AVMediaSelectionGroup mediaSelectionOptionsFromArray:group.options filteredAndSortedAccordingToPreferredLanguages:languages]
        : group.options;
    AVMediaSelectionOption *option = options.firstObject ?: group.options.firstObject;
    if (option)
        [self.currentItem selectMediaOption:option inMediaSelectionGroup:group];
}

@end

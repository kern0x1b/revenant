#import <AVKit/AVKit.h>

@implementation AVPlayerViewController (CharonAutomaticPresentation)
- (UIModalPresentationStyle)charon_preferredModalPresentationStyle
{
    return UIModalPresentationFullScreen;
}
@end

#import <AVKit/AVKit.h>

@implementation AVPlayerViewController (RevenantAutomaticPresentation)
- (UIModalPresentationStyle)revenant_preferredModalPresentationStyle
{
    return UIModalPresentationFullScreen;
}
@end

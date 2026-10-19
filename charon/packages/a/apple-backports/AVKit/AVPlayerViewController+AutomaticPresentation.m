#import <AVKit/AVKit.h>

/* AVKit's player prefers full screen when it is presented with UIModalPresentationAutomatic
   (-[AVPlayerViewController _preferredModalPresentationStyle] of AVKit 16.0, 0x1aa12184c, answers 0).
   The port asks this where it resolves Automatic (UIKit/UIViewController+AutomaticPresentation.m); the
   file exports nothing, so it is in every band, for the port's own class and for the release's. */
@implementation AVPlayerViewController (CharonAutomaticPresentation)
- (UIModalPresentationStyle)charon_preferredModalPresentationStyle
{
    return UIModalPresentationFullScreen;
}
@end

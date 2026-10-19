#import <MediaPlayer/MediaPlayer.h>

/* MediaPlayer's media picker prefers the page sheet when it is presented with
   UIModalPresentationAutomatic (-[MPMediaPickerController _preferredModalPresentationStyle] of
   MediaPlayer 16.0, 0x196a554e4, answers 1). The port asks this where it resolves Automatic
   (UIKit/UIViewController+AutomaticPresentation.m). */
@implementation MPMediaPickerController (CharonAutomaticPresentation)
- (UIModalPresentationStyle)charon_preferredModalPresentationStyle
{
    return UIModalPresentationPageSheet;
}
@end

#import <MediaPlayer/MediaPlayer.h>

@implementation MPMediaPickerController (CharonAutomaticPresentation)
- (UIModalPresentationStyle)charon_preferredModalPresentationStyle
{
    return UIModalPresentationPageSheet;
}
@end

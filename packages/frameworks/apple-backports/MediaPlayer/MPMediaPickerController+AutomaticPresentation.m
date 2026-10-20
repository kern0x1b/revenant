#import <MediaPlayer/MediaPlayer.h>

@implementation MPMediaPickerController (RevenantAutomaticPresentation)
- (UIModalPresentationStyle)revenant_preferredModalPresentationStyle
{
    return UIModalPresentationPageSheet;
}
@end

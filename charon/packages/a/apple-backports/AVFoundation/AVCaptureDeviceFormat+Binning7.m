#import <AVFoundation/AVFoundation.h>

// AVCaptureDeviceFormat.videoBinned, iOS 7.
//
// The release answers this property under a different spelling of the same question, and both
// spellings read one thing: the format's own dictionary. 6.1.3's -[AVCaptureDeviceFormat isBinned]
// loads the ivar at offset 4 and sends -objectForKey: on it; 7.0's -[AVCaptureDeviceFormat
// isVideoBinned] loads the same ivar and sends -objectForKey: on it. Only the key differs, and the
// key is a string in the same image's __cstring on both sides: 6.1.3 holds "Binned" and holds no
// "videoBinned" at all, 7.0 holds "videoBinned" and its only other Binned key is the unrelated
// session-level "LiveSourceOptions.Binned" (facts/AVFoundation/AVFoundation70.md).
//
// So this is the release's own answer under the name the SDK gives the property, which is what
// @property(getter=isVideoBinned) BOOL videoBinned asks for - the getter is isVideoBinned, not
// videoBinned, and the port defines the getter the header declares.

@interface AVCaptureDeviceFormat (CharonBinnedDictionary)
- (BOOL)isBinned;
@end

@implementation AVCaptureDeviceFormat (CharonBinnedVideo)

- (BOOL)isVideoBinned
{
    return [self isBinned];
}

@end

// CharonAVKitSpeeds.h - the one thing AVPlayerViewController.m needs from the 16.0 speed object, and
// nothing else. A declaration, never a definition: the method is implemented in
// AVPlayerViewControllerSpeeds16.m, the object that owns the 16.0 API, so the 8.0 object's play path
// can call into it without defining a single 16.0 name of its own.
//
// The call is guarded by respondsToSelector: at the call site, because the 8.0 object must also link
// in the bands where the 16.0 object is not carried.
#import <AVKit/AVKit.h>

@interface AVPlayerViewController (CharonSpeeds16)
- (void)charon_applySelectedSpeed;
@end

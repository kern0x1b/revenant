// The stand-in for UIKit, for a host check. UIKit does not exist on macOS, so the port's source cannot be
// compiled against the real framework here; this declares what the port's own code names, so the port's
// code - and not a substitute for it - is what the check measures.
//
// Three classes and the two enums, added for MPRemoteCommandCenter71.m: the object's
// +sharedCommandCenter, the event it sends (UIEventTypeRemoteControl and the two properties it reads) and
// -[UIApplication sendEvent:], which is how a remote-control event reaches the port. Transcribed from
// UIKit's own headers; nothing here is behaviour, and the body of UIApplication is here for the same
// reason UIImage's is -- -[UIApplication sharedApplication] is sent, so the symbol must exist at link.
#import <Foundation/Foundation.h>

@interface UIImage : NSObject
@end

// The body as well as the declaration: the port's property is typed UIImage *, so _OBJC_CLASS_$_UIImage is
// referenced and an interface alone leaves it undefined at link time - measured, the same class of defect
// as MPSystemMusicPlayerController in QueueDescriptors.md.
@implementation UIImage
@end

typedef NS_ENUM(NSInteger, UIEventType) {
    UIEventTypeRemoteControl = 1,
};

typedef NS_OPTIONS(unsigned long, UIEventSubtype);

// UIEvent's own numbering of the remote-control subtypes; MPRemoteCommandCenter71.m switches on them and
// MPRemoteCommandCenter80.m/90.m spell the same names. They are declared here as well as in the
// MediaPlayer stand-in because UIEvent.h is where they live.
enum {
    UIEventSubtypeRemoteControlPlay = 1,
    UIEventSubtypeRemoteControlPause = 2,
    UIEventSubtypeRemoteControlStop = 3,
    UIEventSubtypeRemoteControlTogglePlayPause = 4,
    UIEventSubtypeRemoteControlNextTrack = 5,
    UIEventSubtypeRemoteControlPreviousTrack = 6,
    UIEventSubtypeRemoteControlBeginSeekingBackward = 7,
    UIEventSubtypeRemoteControlEndSeekingBackward = 8,
    UIEventSubtypeRemoteControlBeginSeekingForward = 9,
    UIEventSubtypeRemoteControlEndSeekingForward = 10,
    UIEventSubtypeRemoteControlRewind = 11,
    UIEventSubtypeRemoteControlFastForward = 12,
    UIEventSubtypeRemoteControlRating = 13,
};

@interface UIEvent : NSObject
@property (nonatomic, readonly) UIEventType type;
@property (nonatomic, readonly) UIEventSubtype subtype;
@end

@implementation UIEvent
@end

@interface UIApplication : NSObject
+ (UIApplication *)sharedApplication;
- (void)sendEvent:(UIEvent *)event;
@end

@implementation UIApplication
+ (UIApplication *)sharedApplication { static UIApplication *shared; return shared ?: (shared = [[UIApplication alloc] init]); }
- (void)sendEvent:(UIEvent *)event { (void)event; }
@end

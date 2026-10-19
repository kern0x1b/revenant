#import <Foundation/Foundation.h>

@interface UIImage : NSObject
@end

@implementation UIImage
@end

typedef NS_ENUM(NSInteger, UIEventType) {
    UIEventTypeRemoteControl = 1,
};

typedef NS_OPTIONS(unsigned long, UIEventSubtype);

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

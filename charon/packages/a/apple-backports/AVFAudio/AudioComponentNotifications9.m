#import <AudioToolbox/AudioComponent.h>
#import "CharonAudioToolboxNames.h"

// kAudioComponentInstanceInvalidationNotification, iOS 9 (the SDK's availability). Defined here for the same reason as
// AudioComponentNotifications7.m: the release does not have it, and an application that names it gets the host's name.
const CFStringRef kAudioComponentInstanceInvalidationNotification = (__bridge CFStringRef)CharonAudioComponentInstanceInvalidatedName;

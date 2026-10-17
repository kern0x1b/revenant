#import <AudioToolbox/AudioComponent.h>
#import "CharonAudioToolboxNames.h"

// kAudioComponentRegistrationsChangedNotification, iOS 7 (the SDK's availability). The release this port runs on has no
// such symbol, so the backport defines it: an application that names it gets the same notification name as on the host.
const CFStringRef kAudioComponentRegistrationsChangedNotification = (__bridge CFStringRef)CharonAudioComponentRegistrationsChangedName;

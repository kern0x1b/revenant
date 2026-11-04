#include "../revenant_impl.h"
#import <AudioToolbox/AudioComponent.h>
#import "RevenantAudioToolboxNames.h"

const CFStringRef BACKPORT_IMPL(kAudioComponentInstanceInvalidationNotification) = (__bridge CFStringRef)RevenantAudioComponentInstanceInvalidatedName;

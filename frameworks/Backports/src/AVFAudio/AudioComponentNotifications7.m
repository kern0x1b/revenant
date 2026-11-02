#include "../revenant_impl.h"
#import <AudioToolbox/AudioComponent.h>
#import "RevenantAudioToolboxNames.h"

const CFStringRef BACKPORT_IMPL(kAudioComponentRegistrationsChangedNotification) = (__bridge CFStringRef)RevenantAudioComponentRegistrationsChangedName;

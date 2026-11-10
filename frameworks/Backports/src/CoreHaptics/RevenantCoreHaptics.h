#ifndef REVENANT_COREHAPTICS_H
#define REVENANT_COREHAPTICS_H

#include "../revenant_impl.h"

#if defined(REVENANT_HOST_BUILD)
#define CHHapticEngine CHHapticEngineRevenant
#define CHHapticEvent CHHapticEventRevenant
#define CHHapticEventParameter CHHapticEventParameterRevenant
#define CHHapticDynamicParameter CHHapticDynamicParameterRevenant
#define CHHapticPattern CHHapticPatternRevenant
#endif

#import <Foundation/Foundation.h>
#import <CoreHaptics/CoreHaptics.h>

#endif

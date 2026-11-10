#ifndef REVENANT_VIBRATION_H
#define REVENANT_VIBRATION_H

#import <Foundation/Foundation.h>

BOOL RevenantVibratorIsAvailable(void);
void RevenantVibratorPlay(float intensity, const int *milliseconds, NSUInteger count);
void RevenantVibratorPulse(void);
void RevenantVibratorStop(void);

#endif

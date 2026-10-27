#import <Foundation/Foundation.h>

extern const NSTimeInterval RevenantAnimationDurationDefault;

NSTimeInterval RevenantAnimationDurationInherited(void);
void RevenantAnimationDurationPush(NSTimeInterval duration);
void RevenantAnimationDurationSetCurrent(NSTimeInterval duration);
void RevenantAnimationDurationPop(void);

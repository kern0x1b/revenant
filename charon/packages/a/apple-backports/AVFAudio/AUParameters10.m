#import "CharonAUAudioUnit.h"

// The two iOS 10.0 members of the parameter surface, in a category of their own: an object is
// carried from one release on (modules/apple/backports.lua, minimums()), so the automation observer
// and the automation event type cannot sit in the 9.0 file that carries the rest of the tree.

@implementation AUParameterNode (Charon10)

// The header's third observer (AUParameters.h:200-205) takes the series of value changes a UI gesture makes,
// with their timing, and - unlike AUParameterObserver - is not throttled.
// It is the same observer the 9.0 recording observer became, and the tree tells it in the same shape
// an automation event is defined with.
- (AUParameterObserverToken)tokenByAddingParameterAutomationObserver:(AUParameterAutomationObserver)observer
{
    [self charon_addAutomationObserver:observer];
    for (NSValue *held in [self charon_observerTokens]) {
        if (held.pointerValue == (__bridge const void *)observer) {
            return (AUParameterObserverToken)held.pointerValue;
        }
    }
    return (AUParameterObserverToken)(__bridge const void *)observer;
}

@end

@implementation AUParameter (Charon10)

// A value set with an event type is the automation form of the same change: the unit is given the
// value and told whether the change was the value itself, the touch that began a gesture, or the
// release that ended one - the three cases AUParameterAutomationEventType names.
- (void)setValue:(AUValue)value originator:(AUParameterObserverToken)originator atHostTime:(uint64_t)hostTime eventType:(AUParameterAutomationEventType)eventType
{
    [self charon_apply:value originator:originator atHostTime:hostTime eventType:eventType automate:hostTime != 0];
}

@end

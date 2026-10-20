#import "RevenantAUAudioUnit.h"

@implementation AUParameterNode (Revenant10)

- (AUParameterObserverToken)tokenByAddingParameterAutomationObserver:(AUParameterAutomationObserver)observer
{
    [self revenant_addAutomationObserver:observer];
    for (NSValue *held in [self revenant_observerTokens]) {
        if (held.pointerValue == (__bridge const void *)observer) {
            return (AUParameterObserverToken)held.pointerValue;
        }
    }
    return (AUParameterObserverToken)(__bridge const void *)observer;
}

@end

@implementation AUParameter (Revenant10)

- (void)setValue:(AUValue)value originator:(AUParameterObserverToken)originator atHostTime:(uint64_t)hostTime eventType:(AUParameterAutomationEventType)eventType
{
    [self revenant_apply:value originator:originator atHostTime:hostTime eventType:eventType automate:hostTime != 0];
}

@end

#import "CharonAUAudioUnit.h"

@implementation AUParameterNode (Charon10)

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

- (void)setValue:(AUValue)value originator:(AUParameterObserverToken)originator atHostTime:(uint64_t)hostTime eventType:(AUParameterAutomationEventType)eventType
{
    [self charon_apply:value originator:originator atHostTime:hostTime eventType:eventType automate:hostTime != 0];
}

@end

#if defined(REVENANT_HOST_BUILD)
#define INIntentResolutionResult INIntentResolutionResultRevenant
#endif

#import <Intents/Intents.h>
#import <objc/runtime.h>

#import "coding/RevenantCoding.h"
#import "RevenantIntentsResolution.h"

#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

#pragma mark - INIntentResolutionResult

@implementation INIntentResolutionResult {
    RevenantIntentsResolutionStatus _status;
    id _resolvedValue;
    NSArray *_valuesToDisambiguate;
    id _valueToConfirm;
    NSInteger _unsupportedReason;
    NSInteger _confirmationReason;
}

+ (instancetype)needsValue
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionNeedsValue
                             resolvedValue:nil
                       valuesToDisambiguate:nil
                              valueToConfirm:nil];
}

+ (instancetype)notRequired
{
    return [self revenant_answerWithStatus:RevenantIntentsResolutionNotRequired
                           resolvedValue:nil
                    valuesToDisambiguate:nil
                          valueToConfirm:nil
                       unsupportedReason:0];
}

+ (instancetype)unsupported
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionUnsupported
                             resolvedValue:nil
                       valuesToDisambiguate:nil
                              valueToConfirm:nil];
}

+ (instancetype)unsupportedWithReason:(NSInteger)reason
{
    return [self revenant_resolutionWithStatus:RevenantIntentsResolutionUnsupported
                             resolvedValue:nil
                       valuesToDisambiguate:nil
                              valueToConfirm:nil
                          unsupportedReason:reason];
}

+ (instancetype)confirmationRequiredWithItemToConfirm:(id)itemToConfirm forReason:(NSInteger)reason
{
    INIntentResolutionResult *result = [self revenant_resolutionWithStatus:RevenantIntentsResolutionConfirmationRequired
                                                           resolvedValue:nil
                                                     valuesToDisambiguate:nil
                                                            valueToConfirm:itemToConfirm];
    result->_confirmationReason = reason;
    return result;
}

+ (instancetype)revenant_resolutionWithStatus:(RevenantIntentsResolutionStatus)status
                            resolvedValue:(id)resolvedValue
                      valuesToDisambiguate:(NSArray *)valuesToDisambiguate
                             valueToConfirm:(id)valueToConfirm
{
    return [self revenant_resolutionWithStatus:status
                               resolvedValue:resolvedValue
                         valuesToDisambiguate:valuesToDisambiguate
                                valueToConfirm:valueToConfirm
                            unsupportedReason:0];
}

+ (instancetype)revenant_resolutionWithStatus:(RevenantIntentsResolutionStatus)status
                            resolvedValue:(id)resolvedValue
                      valuesToDisambiguate:(NSArray *)valuesToDisambiguate
                             valueToConfirm:(id)valueToConfirm
                         unsupportedReason:(NSInteger)unsupportedReason
{
    if (status == RevenantIntentsResolutionDisambiguation && valuesToDisambiguate.count == 0) {
        return nil;
    }
    if (resolvedValue == nil && (status == RevenantIntentsResolutionSuccess || status == RevenantIntentsResolutionNotRequired)) {
        return nil;
    }
    return [self revenant_answerWithStatus:status
                           resolvedValue:resolvedValue
                    valuesToDisambiguate:valuesToDisambiguate
                          valueToConfirm:valueToConfirm
                       unsupportedReason:unsupportedReason];
}

+ (instancetype)revenant_answerWithStatus:(RevenantIntentsResolutionStatus)status
                          resolvedValue:(id)resolvedValue
                   valuesToDisambiguate:(NSArray *)valuesToDisambiguate
                         valueToConfirm:(id)valueToConfirm
                      unsupportedReason:(NSInteger)unsupportedReason
{
    INIntentResolutionResult *result = [self revenant_adopted:NULL];
    result->_status = status;
    result->_resolvedValue = [resolvedValue copy];
    result->_valuesToDisambiguate = [valuesToDisambiguate copy];
    result->_valueToConfirm = [valueToConfirm copy];
    result->_unsupportedReason = unsupportedReason;
    return result;
}

+ (instancetype)revenant_adopted:(INIntentResolutionResult *)inner
{
    INIntentResolutionResult *result = [self alloc];
    result = revenant_intents_super_init(result, [INIntentResolutionResult class]);
    if (inner) {
        result->_status = inner->_status;
        result->_resolvedValue = [inner->_resolvedValue copy];
        result->_valuesToDisambiguate = [inner->_valuesToDisambiguate copy];
        result->_valueToConfirm = [inner->_valueToConfirm copy];
        result->_unsupportedReason = inner->_unsupportedReason;
        result->_confirmationReason = inner->_confirmationReason;
    } else {
        result->_status = RevenantIntentsResolutionNeedsValue;
    }
    return result;
}

- (void)revenant_adoptResolutionOf:(id)inner
{
    if (![inner isKindOfClass:[INIntentResolutionResult class]]) {
        return;
    }
    INIntentResolutionResult *wrapped = inner;
    _status = wrapped->_status;
    _resolvedValue = [wrapped->_resolvedValue copy];
    _valuesToDisambiguate = [wrapped->_valuesToDisambiguate copy];
    _valueToConfirm = [wrapped->_valueToConfirm copy];
    _unsupportedReason = wrapped->_unsupportedReason;
    _confirmationReason = wrapped->_confirmationReason;
}

- (NSInteger)revenant_unsupportedReason
{
    return _unsupportedReason;
}

- (NSInteger)resolutionResultCode
{
    switch (_status) {
        case RevenantIntentsResolutionSuccess:
            return 0;
        case RevenantIntentsResolutionUnsupported:
            return 1;
        case RevenantIntentsResolutionDisambiguation:
            return _valuesToDisambiguate.count == 1 ? 3 : 2;
        case RevenantIntentsResolutionConfirmationRequired:
            return 3;
        case RevenantIntentsResolutionNeedsValue:
            return 4;
        case RevenantIntentsResolutionNotRequired:
            return 5;
    }
    return 0;
}

- (id)itemToConfirm
{
    if (_status == RevenantIntentsResolutionConfirmationRequired) {
        return _valueToConfirm;
    }
    if (_status == RevenantIntentsResolutionDisambiguation && _valuesToDisambiguate.count == 1) {
        return _valuesToDisambiguate[0];
    }
    return nil;
}

- (NSInteger)unsupportedReason
{
    return _unsupportedReason;
}

- (NSInteger)confirmationReason
{
    return _confirmationReason;
}

- (NSArray *)disambiguationItems
{
    if (_status != RevenantIntentsResolutionDisambiguation || _valuesToDisambiguate.count == 1) {
        return nil;
    }
    return _valuesToDisambiguate;
}

- (id)resolvedValue
{
    return _resolvedValue;
}

- (NSArray *)valuesToDisambiguate
{
    return _valuesToDisambiguate;
}

- (id)valueToConfirm
{
    return _valueToConfirm;
}

- (RevenantIntentsResolutionStatus)resolutionStatus
{
    return _status;
}

- (NSString *)description
{
    static const char *names[] = {"needsValue", "notRequired", "unsupported", "success",
                                  "disambiguation", "confirmationRequired"};
    return [NSString stringWithFormat:@"<%@ %s%@%@>",
            [NSString stringWithCString:class_getName([self class]) encoding:NSUTF8StringEncoding],
            names[_status], _resolvedValue ? @" value" : @"",
            _valuesToDisambiguate ? @" choices" : (_valueToConfirm ? @" to confirm" : @"")];
}

@end

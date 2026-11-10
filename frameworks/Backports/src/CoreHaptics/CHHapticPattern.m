#import "RevenantCoreHapticsPrivate.h"

static NSString *revenant_haptic_event_type(NSString *text)
{
    if ([text isEqualToString:CHHapticEventTypeHapticTransient])
        return CHHapticEventTypeHapticTransient;
    if ([text isEqualToString:CHHapticEventTypeHapticContinuous])
        return CHHapticEventTypeHapticContinuous;
    return nil;
}

@implementation CHHapticPattern
{
    NSArray<CHHapticEvent *> *_events;
    NSArray<CHHapticDynamicParameter *> *_parameters;
    NSTimeInterval _duration;
}

- (instancetype)initWithEvents:(NSArray<CHHapticEvent *> *)events
                    parameters:(NSArray<CHHapticDynamicParameter *> *)parameters
                         error:(NSError **)outError
{
    NSTimeInterval duration = 0.0;
    for (CHHapticEvent *event in events) {
        NSTimeInterval end = event.relativeTime + event.duration;
        if (end > duration)
            duration = end;
    }
    for (CHHapticDynamicParameter *parameter in parameters) {
        NSTimeInterval time = parameter.relativeTime;
        if (time > duration)
            duration = time;
    }
    self = [super init];
    if (self) {
        _events = [events copy];
        _parameters = [parameters copy];
        _duration = duration;
    }
    if (outError)
        *outError = nil;
    return self;
}

- (instancetype)initWithEvents:(NSArray<CHHapticEvent *> *)events
               parameterCurves:(NSArray<CHHapticParameterCurve *> *)parameterCurves
                         error:(NSError **)outError
{
    if (outError)
        *outError = revenant_corehaptics_error(CHHapticErrorCodeOperationNotPermitted);
    return nil;
}

- (instancetype)initWithDictionary:(NSDictionary<CHHapticPatternKey, id> *)patternDict
                             error:(NSError **)outError
{
    id version = patternDict[CHHapticPatternKeyVersion];
    id listing = patternDict[CHHapticPatternKeyPattern];
    if (![version isKindOfClass:[NSNumber class]] || ![listing isKindOfClass:[NSArray class]]) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
        return nil;
    }
    if ([version unsignedIntegerValue] != 1) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
        return nil;
    }
    NSMutableArray<CHHapticEvent *> *events = [NSMutableArray array];
    NSMutableArray<CHHapticDynamicParameter *> *parameters = [NSMutableArray array];
    for (id entry in listing) {
        if (![entry isKindOfClass:[NSDictionary class]]) {
            if (outError)
                *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
            return nil;
        }
        NSDictionary *dictionary = entry;
        if (dictionary[CHHapticPatternKeyParameterCurve] != nil) {
            if (outError)
                *outError = revenant_corehaptics_error(CHHapticErrorCodeOperationNotPermitted);
            return nil;
        }
        NSDictionary *event = dictionary[CHHapticPatternKeyEvent];
        if (event != nil) {
            if (![event isKindOfClass:[NSDictionary class]]) {
                if (outError)
                    *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
                return nil;
            }
            NSString *type = revenant_haptic_event_type(event[CHHapticPatternKeyEventType]);
            id duration = event[CHHapticPatternKeyEventDuration];
            id time = event[CHHapticPatternKeyTime];
            if (!type || ![duration isKindOfClass:[NSNumber class]] || ![time isKindOfClass:[NSNumber class]]) {
                if (outError)
                    *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
                return nil;
            }
            NSMutableArray<CHHapticEventParameter *> *eventParameters = [NSMutableArray array];
            id listed = event[CHHapticPatternKeyEventParameters];
            if (listed != nil) {
                if (![listed isKindOfClass:[NSArray class]]) {
                    if (outError)
                        *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
                    return nil;
                }
                for (id parameter in listed) {
                    if (![parameter isKindOfClass:[NSDictionary class]]) {
                        if (outError)
                            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
                        return nil;
                    }
                    NSDictionary *fields = parameter;
                    id identifier = fields[CHHapticPatternKeyParameterID];
                    id value = fields[CHHapticPatternKeyParameterValue];
                    if (![identifier isKindOfClass:[NSString class]] || ![value isKindOfClass:[NSNumber class]]) {
                        if (outError)
                            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
                        return nil;
                    }
                    [eventParameters addObject:[[CHHapticEventParameter alloc] initWithParameterID:identifier
                                                                                            value:[value floatValue]]];
                }
            }
            [events addObject:[[CHHapticEvent alloc] initWithEventType:type
                                                                parameters:eventParameters
                                                              relativeTime:[time doubleValue]
                                                                  duration:[duration doubleValue]]];
            continue;
        }
        NSDictionary *parameter = dictionary[CHHapticPatternKeyParameter];
        if (parameter != nil) {
            if (![parameter isKindOfClass:[NSDictionary class]]) {
                if (outError)
                    *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
                return nil;
            }
            id identifier = parameter[CHHapticPatternKeyParameterID];
            id value = parameter[CHHapticPatternKeyParameterValue];
            id time = parameter[CHHapticPatternKeyTime];
            if (![identifier isKindOfClass:[NSString class]] || ![value isKindOfClass:[NSNumber class]] ||
                ![time isKindOfClass:[NSNumber class]]) {
                if (outError)
                    *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
                return nil;
            }
            [parameters addObject:[[CHHapticDynamicParameter alloc] initWithParameterID:identifier
                                                                                   value:[value floatValue]
                                                                            relativeTime:[time doubleValue]]];
            continue;
        }
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
        return nil;
    }
    return [self initWithEvents:events parameters:parameters error:outError];
}

- (instancetype)initWithContentsOfURL:(NSURL *)ahapURL error:(NSError **)outError
{
    NSError *readError = nil;
    NSData *data = [NSData dataWithContentsOfURL:ahapURL options:0 error:&readError];
    if (!data) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeFileNotFound);
        return nil;
    }
    NSDictionary *dictionary = [NSPropertyListSerialization propertyListWithData:data
                                                                          options:NSPropertyListImmutable
                                                                           format:NULL
                                                                            error:&readError];
    if (![dictionary isKindOfClass:[NSDictionary class]]) {
        if (outError)
            *outError = revenant_corehaptics_error(CHHapticErrorCodeInvalidPatternDictionary);
        return nil;
    }
    return [self initWithDictionary:dictionary error:outError];
}

- (NSDictionary<CHHapticPatternKey, id> *)exportDictionaryAndReturnError:(NSError **)outError
{
    NSMutableArray *listing = [NSMutableArray array];
    for (CHHapticEvent *event in _events) {
        NSMutableArray *eventParameters = [NSMutableArray array];
        for (CHHapticEventParameter *parameter in event.eventParameters) {
            [eventParameters addObject:@{CHHapticPatternKeyParameterID: parameter.parameterID,
                                        CHHapticPatternKeyParameterValue: @(parameter.value)}];
        }
        NSMutableDictionary *fields = [NSMutableDictionary dictionary];
        fields[CHHapticPatternKeyEventType] = event.type;
        if (event.duration > 0.0)
            fields[CHHapticPatternKeyEventDuration] = @(event.duration);
        if (eventParameters.count > 0)
            fields[CHHapticPatternKeyEventParameters] = eventParameters;
        fields[CHHapticPatternKeyTime] = @(event.relativeTime);
        [listing addObject:@{CHHapticPatternKeyEvent: fields}];
    }
    for (CHHapticDynamicParameter *parameter in _parameters) {
        [listing addObject:@{CHHapticPatternKeyParameter: @{CHHapticPatternKeyParameterID: parameter.parameterID,
                                                            CHHapticPatternKeyParameterValue: @(parameter.value),
                                                            CHHapticPatternKeyTime: @(parameter.relativeTime)}}];
    }
    if (outError)
        *outError = nil;
    return @{CHHapticPatternKeyVersion: @1, CHHapticPatternKeyPattern: listing};
}

- (NSTimeInterval)duration
{
    return _duration;
}

- (NSArray<CHHapticEvent *> *)revenant_events
{
    return _events;
}

- (NSArray<CHHapticDynamicParameter *> *)revenant_parameters
{
    return _parameters;
}

@end

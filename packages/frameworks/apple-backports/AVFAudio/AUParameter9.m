#import "RevenantAUAudioUnit.h"

@implementation AUParameter {
    RevenantAUParameterImpl *_revenant;
}

- (instancetype)initWithRevenantImpl:(RevenantAUParameterImpl *)impl
{
    if ((self = [super init])) {
        _revenant = impl;
        [self revenant_setIdentifier:impl.name];
        [self revenant_setDisplayName:impl.name];
    }
    return self;
}

- (AUValue)value
{
    if (_revenant.owner == nil || _revenant.owner.audioUnit == NULL) {
        return _revenant.minValue;
    }
    AudioUnitParameterValue value = 0;
    if (AudioUnitGetParameter(_revenant.owner.audioUnit, _revenant.identifier, _revenant.scope, _revenant.element, &value) != noErr) {
        return _revenant.minValue;
    }
    return (AUValue)value;
}

- (void)setValue:(AUValue)value
{
    [self setValue:value originator:NULL];
}

- (void)setValue:(AUValue)value originator:(AUParameterObserverToken)originator
{
    [self revenant_apply:value originator:originator atHostTime:0 eventType:AUParameterAutomationEventTypeValue automate:NO];
}

- (void)setValue:(AUValue)value originator:(AUParameterObserverToken)originator atHostTime:(uint64_t)hostTime
{
    [self revenant_apply:value originator:originator atHostTime:hostTime eventType:AUParameterAutomationEventTypeValue automate:hostTime != 0];
}

- (void)revenant_apply:(AUValue)value
           originator:(AUParameterObserverToken)originator
           atHostTime:(uint64_t)hostTime
            eventType:(AUParameterAutomationEventType)eventType
            automate:(BOOL)automate
{
    AUAudioUnit *owner = _revenant.owner;
    if (automate && owner != nil && owner.audioUnit != NULL) {
        AudioUnitParameterEvent event;
        memset(&event, 0, sizeof(event));
        event.scope = _revenant.scope;
        event.element = _revenant.element;
        event.parameter = _revenant.identifier;
        event.eventType = kParameterEvent_Immediate;
        event.eventValues.immediate.value = (AudioUnitParameterValue)value;
        AudioUnitScheduleParameters(owner.audioUnit, &event, 1);
        [self revenant_notifyValue:self.value atAddress:self.address];
        return;
    }
    if (owner != nil && owner.audioUnit != NULL) {
        AudioUnitParameterValue written = (AudioUnitParameterValue)value;
        AudioUnitSetParameter(owner.audioUnit, _revenant.identifier, _revenant.scope, _revenant.element, written, 0);
    }
    if (originator != NULL) {
        for (NSValue *token in [self revenant_observerTokens]) {
            if (token.pointerValue == (const void *)originator) {
                return;
            }
        }
    }
    [self revenant_notifyValue:value atAddress:self.address];
}

- (AUValue)minValue
{
    return _revenant.minValue;
}

- (AUValue)maxValue
{
    return _revenant.maxValue;
}

- (AudioUnitParameterUnit)unit
{
    return _revenant.unit;
}

- (NSString *)unitName
{
    return _revenant.unitName;
}

- (AudioUnitParameterOptions)flags
{
    return _revenant.flags;
}

- (AUParameterAddress)address
{
    return RevenantAddress(_revenant.identifier, _revenant.scope, _revenant.element);
}

- (NSArray<NSString *> *)valueStrings
{
    return _revenant.valueStrings;
}

- (NSArray<NSNumber *> *)dependentParameters
{
    return _revenant.dependentParameters;
}

- (NSString *)stringFromValue:(const AUValue *)value
{
    AUValue wanted = value != NULL ? *value : self.value;
    if (_revenant.valueStrings.count > 0) {
        NSInteger index = (NSInteger)llround(wanted);
        if (index >= 0 && index < (NSInteger)_revenant.valueStrings.count) {
            return _revenant.valueStrings[index];
        }
        return nil;
    }
    return [NSString stringWithFormat:@"%g", (double)wanted];
}

- (AudioUnitParameterID)revenant_identifier
{
    return _revenant.identifier;
}

- (AudioUnitScope)revenant_scope
{
    return _revenant.scope;
}

- (AudioUnitElement)revenant_element
{
    return _revenant.element;
}

- (AUValue)valueFromString:(NSString *)string
{
    if (_revenant.valueStrings.count > 0) {
        NSUInteger index = [_revenant.valueStrings indexOfObject:string];
        return index == NSNotFound ? _revenant.minValue : (AUValue)index;
    }
    return (AUValue)string.doubleValue;
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_revenant.identifier forKey:@"identifier"];
    [coder encodeInteger:(NSInteger)_revenant.scope forKey:@"scope"];
    [coder encodeInteger:(NSInteger)_revenant.element forKey:@"element"];
    [coder encodeFloat:_revenant.minValue forKey:@"minValue"];
    [coder encodeFloat:_revenant.maxValue forKey:@"maxValue"];
    [coder encodeObject:_revenant.unitName forKey:@"unitName"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _revenant = [RevenantAUParameterImpl new];
        _revenant.identifier = (AudioUnitParameterID)[coder decodeIntegerForKey:@"identifier"];
        _revenant.scope = (AudioUnitScope)[coder decodeIntegerForKey:@"scope"];
        _revenant.element = (AudioUnitElement)[coder decodeIntegerForKey:@"element"];
        _revenant.minValue = [coder decodeFloatForKey:@"minValue"];
        _revenant.maxValue = [coder decodeFloatForKey:@"maxValue"];
        _revenant.unitName = [coder decodeObjectForKey:@"unitName"];
    }
    return self;
}

@end

AUParameterTree *RevenantBuildParameterTree(AUAudioUnit *owner)
{
    AudioUnit unit = owner.audioUnit;
    if (unit == NULL) {
        return nil;
    }
    NSMutableArray<AUParameterNode *> *parameters = [NSMutableArray array];
    for (AudioUnitElement index = 0; index < 4096; index++) {
        AudioUnitParameterInfo info;
        memset(&info, 0, sizeof(info));
        UInt32 size = (UInt32)sizeof(info);
        if (AudioUnitGetProperty(unit, kAudioUnitProperty_ParameterInfo, kAudioUnitScope_Global, index, &info, &size) != noErr || size < sizeof(info)) {
            break;
        }
        RevenantAUParameterImpl *impl = [RevenantAUParameterImpl new];
        impl.name = [NSString stringWithUTF8String:info.name] ?: [NSString stringWithFormat:@"%u", (unsigned)index];
        impl.identifier = index;
        impl.scope = kAudioUnitScope_Global;
        impl.element = 0;
        impl.minValue = info.minValue;
        impl.maxValue = info.maxValue;
        impl.unit = info.unit;
        impl.flags = info.flags;
        impl.owner = owner;
        if (info.unitName != NULL) {
            impl.unitName = (__bridge_transfer NSString *)info.unitName;
        }
        NSString *display = [NSString stringWithUTF8String:info.name];
        if (info.cfNameString != NULL) {
            display = (__bridge_transfer NSString *)info.cfNameString;
            if (info.flags & kAudioUnitParameterFlag_CFNameRelease) {
                CFRelease(info.cfNameString);
            }
        }
        AUParameter *parameter = [[AUParameter alloc] initWithRevenantImpl:impl];
        [parameter revenant_setIdentifier:impl.name];
        [parameter revenant_setDisplayName:display];
        [parameters addObject:parameter];
    }
    if (parameters.count == 0) {
        return nil;
    }
    AUParameterTree *tree = [[AUParameterTree alloc] initWithRevenantChildren:parameters];
    [tree revenant_setIdentifier:@""];
    for (AUParameterNode *child in parameters) {
        [child revenant_setParent:tree keyPath:child.identifier];
    }
    return tree;
}

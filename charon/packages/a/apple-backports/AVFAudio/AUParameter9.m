#import "CharonAUAudioUnit.h"

@implementation AUParameter {
    CharonAUParameterImpl *_charon;
}

- (instancetype)initWithCharonImpl:(CharonAUParameterImpl *)impl
{
    if ((self = [super init])) {
        _charon = impl;
        [self charon_setIdentifier:impl.name];
        [self charon_setDisplayName:impl.name];
    }
    return self;
}

- (AUValue)value
{
    if (_charon.owner == nil || _charon.owner.audioUnit == NULL) {
        return _charon.minValue;
    }
    AudioUnitParameterValue value = 0;
    if (AudioUnitGetParameter(_charon.owner.audioUnit, _charon.identifier, _charon.scope, _charon.element, &value) != noErr) {
        return _charon.minValue;
    }
    return (AUValue)value;
}

- (void)setValue:(AUValue)value
{
    [self setValue:value originator:NULL];
}

- (void)setValue:(AUValue)value originator:(AUParameterObserverToken)originator
{
    [self charon_apply:value originator:originator atHostTime:0 eventType:AUParameterAutomationEventTypeValue automate:NO];
}

- (void)setValue:(AUValue)value originator:(AUParameterObserverToken)originator atHostTime:(uint64_t)hostTime
{
    [self charon_apply:value originator:originator atHostTime:hostTime eventType:AUParameterAutomationEventTypeValue automate:hostTime != 0];
}

- (void)charon_apply:(AUValue)value
           originator:(AUParameterObserverToken)originator
           atHostTime:(uint64_t)hostTime
            eventType:(AUParameterAutomationEventType)eventType
            automate:(BOOL)automate
{
    AUAudioUnit *owner = _charon.owner;
    if (automate && owner != nil && owner.audioUnit != NULL) {
        AudioUnitParameterEvent event;
        memset(&event, 0, sizeof(event));
        event.scope = _charon.scope;
        event.element = _charon.element;
        event.parameter = _charon.identifier;
        event.eventType = kParameterEvent_Immediate;
        event.eventValues.immediate.value = (AudioUnitParameterValue)value;
        AudioUnitScheduleParameters(owner.audioUnit, &event, 1);
        [self charon_notifyValue:self.value atAddress:self.address];
        return;
    }
    if (owner != nil && owner.audioUnit != NULL) {
        AudioUnitParameterValue written = (AudioUnitParameterValue)value;
        AudioUnitSetParameter(owner.audioUnit, _charon.identifier, _charon.scope, _charon.element, written, 0);
    }
    if (originator != NULL) {
        for (NSValue *token in [self charon_observerTokens]) {
            if (token.pointerValue == (const void *)originator) {
                return;
            }
        }
    }
    [self charon_notifyValue:value atAddress:self.address];
}

- (AUValue)minValue
{
    return _charon.minValue;
}

- (AUValue)maxValue
{
    return _charon.maxValue;
}

- (AudioUnitParameterUnit)unit
{
    return _charon.unit;
}

- (NSString *)unitName
{
    return _charon.unitName;
}

- (AudioUnitParameterOptions)flags
{
    return _charon.flags;
}

- (AUParameterAddress)address
{
    return CharonAddress(_charon.identifier, _charon.scope, _charon.element);
}

- (NSArray<NSString *> *)valueStrings
{
    return _charon.valueStrings;
}

- (NSArray<NSNumber *> *)dependentParameters
{
    return _charon.dependentParameters;
}

- (NSString *)stringFromValue:(const AUValue *)value
{
    AUValue wanted = value != NULL ? *value : self.value;
    if (_charon.valueStrings.count > 0) {
        NSInteger index = (NSInteger)llround(wanted);
        if (index >= 0 && index < (NSInteger)_charon.valueStrings.count) {
            return _charon.valueStrings[index];
        }
        return nil;
    }
    return [NSString stringWithFormat:@"%g", (double)wanted];
}

- (AudioUnitParameterID)charon_identifier
{
    return _charon.identifier;
}

- (AudioUnitScope)charon_scope
{
    return _charon.scope;
}

- (AudioUnitElement)charon_element
{
    return _charon.element;
}

- (AUValue)valueFromString:(NSString *)string
{
    if (_charon.valueStrings.count > 0) {
        NSUInteger index = [_charon.valueStrings indexOfObject:string];
        return index == NSNotFound ? _charon.minValue : (AUValue)index;
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
    [coder encodeInteger:(NSInteger)_charon.identifier forKey:@"identifier"];
    [coder encodeInteger:(NSInteger)_charon.scope forKey:@"scope"];
    [coder encodeInteger:(NSInteger)_charon.element forKey:@"element"];
    [coder encodeFloat:_charon.minValue forKey:@"minValue"];
    [coder encodeFloat:_charon.maxValue forKey:@"maxValue"];
    [coder encodeObject:_charon.unitName forKey:@"unitName"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _charon = [CharonAUParameterImpl new];
        _charon.identifier = (AudioUnitParameterID)[coder decodeIntegerForKey:@"identifier"];
        _charon.scope = (AudioUnitScope)[coder decodeIntegerForKey:@"scope"];
        _charon.element = (AudioUnitElement)[coder decodeIntegerForKey:@"element"];
        _charon.minValue = [coder decodeFloatForKey:@"minValue"];
        _charon.maxValue = [coder decodeFloatForKey:@"maxValue"];
        _charon.unitName = [coder decodeObjectForKey:@"unitName"];
    }
    return self;
}

@end

AUParameterTree *CharonBuildParameterTree(AUAudioUnit *owner)
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
        CharonAUParameterImpl *impl = [CharonAUParameterImpl new];
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
        AUParameter *parameter = [[AUParameter alloc] initWithCharonImpl:impl];
        [parameter charon_setIdentifier:impl.name];
        [parameter charon_setDisplayName:display];
        [parameters addObject:parameter];
    }
    if (parameters.count == 0) {
        return nil;
    }
    AUParameterTree *tree = [[AUParameterTree alloc] initWithCharonChildren:parameters];
    [tree charon_setIdentifier:@""];
    for (AUParameterNode *child in parameters) {
        [child charon_setParent:tree keyPath:child.identifier];
    }
    return tree;
}

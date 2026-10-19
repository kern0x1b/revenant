#import "CharonAUAudioUnit.h"

@implementation AUParameterNode {
@protected
    NSString *_charon_identifier;
    NSString *_charon_keyPath;
    NSString *_charon_displayName;
    NSMutableArray<NSValue *> *_charon_valueObservers;
    NSMutableArray<NSValue *> *_charon_recordingObservers;
    NSMutableArray<NSValue *> *_charon_automationObservers;
    NSMutableArray<NSValue *> *_charon_touchedTokens;
    __weak AUParameterNode *_charon_parent;
}

- (AUParameterObserverToken)charon_addObserver:(id)observer to:(NSMutableArray<NSValue *> *)table
{
    if (observer == nil) {
        return NULL;
    }
    NSValue *token = [NSValue valueWithPointer:(__bridge const void *)observer];
    [table addObject:token];
    return (__bridge AUParameterObserverToken)token;
}

- (void)charon_removeObserver:(AUParameterObserverToken)token
{
    if (token == NULL) {
        return;
    }
    NSValue *key = [NSValue valueWithPointer:(const void *)token];
    [_charon_valueObservers removeObject:key];
    [_charon_recordingObservers removeObject:key];
    [_charon_automationObservers removeObject:key];
    [_charon_touchedTokens removeObject:key];
}

- (void)charon_notifyValue:(AUValue)value atAddress:(AUParameterAddress)address
{
    for (NSValue *token in [_charon_valueObservers copy]) {
        AUParameterObserver observer = (AUParameterObserver)token.pointerValue;
        observer(address, value);
    }
    [_charon_parent charon_notifyValue:value atAddress:address];
}

- (void)charon_notifyRecording:(NSInteger)count events:(const AURecordedParameterEvent *)events
{
    for (NSValue *token in [_charon_recordingObservers copy]) {
        AUParameterRecordingObserver observer = (AUParameterRecordingObserver)token.pointerValue;
        observer(count, events);
    }
    [_charon_parent charon_notifyRecording:count events:events];
}

- (void)charon_notifyAutomation:(NSInteger)count events:(const AUParameterAutomationEvent *)events
{
    for (NSValue *token in [_charon_automationObservers copy]) {
        AUParameterAutomationObserver observer = (AUParameterAutomationObserver)token.pointerValue;
        observer(count, events);
    }
    [_charon_parent charon_notifyAutomation:count events:events];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _charon_identifier = @"";
        _charon_displayName = @"";
    }
    return self;
}

- (void)charon_setIdentifier:(NSString *)identifier
{
    _charon_identifier = [identifier copy];
}

- (NSString *)identifier
{
    return _charon_identifier;
}

- (NSString *)keyPath
{
    return _charon_keyPath;
}

- (NSString *)displayName
{
    return _charon_displayName;
}

- (NSString *)displayNameWithLength:(NSInteger)maximumLength
{
    return _charon_displayName;
}

- (AUParameterObserverToken)tokenByAddingParameterObserver:(AUParameterObserver)observer
{
    return [self charon_addObserver:observer to:_charon_valueObservers ?: (_charon_valueObservers = [NSMutableArray array])];
}

- (AUParameterObserverToken)tokenByAddingParameterRecordingObserver:(AUParameterRecordingObserver)observer
{
    return [self charon_addObserver:observer to:_charon_recordingObservers ?: (_charon_recordingObservers = [NSMutableArray array])];
}

- (void)removeParameterObserver:(AUParameterObserverToken)token
{
    [self charon_removeObserver:token];
}

- (void)charon_setParent:(AUParameterNode *)parent keyPath:(NSString *)keyPath
{
    _charon_parent = parent;
    _charon_keyPath = [keyPath copy];
}

- (NSArray<NSValue *> *)charon_observerTokens
{
    if (_charon_valueObservers == nil) {
        return @[];
    }
    return _charon_valueObservers;
}

- (void)charon_addAutomationObserver:(id)observer
{
    if (observer == nil) {
        return;
    }
    if (_charon_automationObservers == nil) {
        _charon_automationObservers = [NSMutableArray array];
    }
    [_charon_automationObservers addObject:[NSValue valueWithPointer:(__bridge const void *)observer]];
}

@end

@implementation AUParameterGroup {
    NSArray<AUParameterNode *> *_charon_children;
}

- (instancetype)initWithCharonChildren:(NSArray<AUParameterNode *> *)children
{
    if ((self = [super init])) {
        _charon_children = [children copy];
    }
    return self;
}

- (NSArray<AUParameterNode *> *)children
{
    return _charon_children;
}

- (id)valueForKey:(NSString *)key
{
    for (AUParameterNode *child in _charon_children) {
        if ([child.identifier isEqualToString:key]) {
            return child;
        }
    }
    return [super valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    for (AUParameterNode *child in _charon_children) {
        if ([child.identifier isEqualToString:key]) {
            [child setValue:value forKey:key];
            return;
        }
    }
    [super setValue:value forKey:key];
}

- (NSArray<AUParameter *> *)allParameters
{
    NSMutableArray<AUParameter *> *found = [NSMutableArray array];
    for (AUParameterNode *child in _charon_children) {
        if ([child isKindOfClass:[AUParameter class]]) {
            [found addObject:(AUParameter *)child];
        } else if ([child isKindOfClass:[AUParameterGroup class]]) {
            [found addObjectsFromArray:[(AUParameterGroup *)child allParameters]];
        }
    }
    return found;
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:(NSInteger)_charon_children.count forKey:@"children"];
    for (NSUInteger index = 0; index < _charon_children.count; index++) {
        [coder encodeObject:_charon_children[index] forKey:[NSString stringWithFormat:@"%lu", (unsigned long)index]];
    }
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        NSInteger count = [coder decodeIntegerForKey:@"children"];
        NSMutableArray<AUParameterNode *> *children = [NSMutableArray array];
        for (NSInteger index = 0; index < count; index++) {
            AUParameterNode *child = [coder decodeObjectForKey:[NSString stringWithFormat:@"%ld", (long)index]];
            if (child) {
                [children addObject:child];
            }
        }
        _charon_children = children;
    }
    return self;
}

@end

@implementation AUParameterTree

- (AUParameter *)parameterWithAddress:(AUParameterAddress)address
{
    for (AUParameter *parameter in [self allParameters]) {
        if (parameter.address == address) {
            return parameter;
        }
    }
    return nil;
}

- (AUParameter *)parameterWithID:(AudioUnitParameterID)paramID scope:(AudioUnitScope)scope element:(AudioUnitElement)element
{
    for (AUParameter *parameter in [self allParameters]) {
        if ([parameter charon_identifier] == paramID && [parameter charon_scope] == scope && [parameter charon_element] == element) {
            return parameter;
        }
    }
    return nil;
}

- (id)valueForKeyPath:(NSString *)keyPath
{
    AUParameterNode *node = self;
    for (NSString *part in [keyPath componentsSeparatedByString:@"."]) {
        if (![node isKindOfClass:[AUParameterGroup class]]) {
            return nil;
        }
        AUParameterNode *next = nil;
        for (AUParameterNode *child in [(AUParameterGroup *)node children]) {
            if ([child.identifier isEqualToString:part]) {
                next = child;
                break;
            }
        }
        if (next == nil) {
            return nil;
        }
        node = next;
    }
    return node;
}

@end

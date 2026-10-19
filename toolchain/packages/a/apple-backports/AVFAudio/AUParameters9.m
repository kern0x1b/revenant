#import "RevenantAUAudioUnit.h"

@implementation AUParameterNode {
@protected
    NSString *_revenant_identifier;
    NSString *_revenant_keyPath;
    NSString *_revenant_displayName;
    NSMutableArray<NSValue *> *_revenant_valueObservers;
    NSMutableArray<NSValue *> *_revenant_recordingObservers;
    NSMutableArray<NSValue *> *_revenant_automationObservers;
    NSMutableArray<NSValue *> *_revenant_touchedTokens;
    __weak AUParameterNode *_revenant_parent;
}

- (AUParameterObserverToken)revenant_addObserver:(id)observer to:(NSMutableArray<NSValue *> *)table
{
    if (observer == nil) {
        return NULL;
    }
    NSValue *token = [NSValue valueWithPointer:(__bridge const void *)observer];
    [table addObject:token];
    return (__bridge AUParameterObserverToken)token;
}

- (void)revenant_removeObserver:(AUParameterObserverToken)token
{
    if (token == NULL) {
        return;
    }
    NSValue *key = [NSValue valueWithPointer:(const void *)token];
    [_revenant_valueObservers removeObject:key];
    [_revenant_recordingObservers removeObject:key];
    [_revenant_automationObservers removeObject:key];
    [_revenant_touchedTokens removeObject:key];
}

- (void)revenant_notifyValue:(AUValue)value atAddress:(AUParameterAddress)address
{
    for (NSValue *token in [_revenant_valueObservers copy]) {
        AUParameterObserver observer = (AUParameterObserver)token.pointerValue;
        observer(address, value);
    }
    [_revenant_parent revenant_notifyValue:value atAddress:address];
}

- (void)revenant_notifyRecording:(NSInteger)count events:(const AURecordedParameterEvent *)events
{
    for (NSValue *token in [_revenant_recordingObservers copy]) {
        AUParameterRecordingObserver observer = (AUParameterRecordingObserver)token.pointerValue;
        observer(count, events);
    }
    [_revenant_parent revenant_notifyRecording:count events:events];
}

- (void)revenant_notifyAutomation:(NSInteger)count events:(const AUParameterAutomationEvent *)events
{
    for (NSValue *token in [_revenant_automationObservers copy]) {
        AUParameterAutomationObserver observer = (AUParameterAutomationObserver)token.pointerValue;
        observer(count, events);
    }
    [_revenant_parent revenant_notifyAutomation:count events:events];
}

- (instancetype)init
{
    if ((self = [super init])) {
        _revenant_identifier = @"";
        _revenant_displayName = @"";
    }
    return self;
}

- (void)revenant_setIdentifier:(NSString *)identifier
{
    _revenant_identifier = [identifier copy];
}

- (NSString *)identifier
{
    return _revenant_identifier;
}

- (NSString *)keyPath
{
    return _revenant_keyPath;
}

- (NSString *)displayName
{
    return _revenant_displayName;
}

- (NSString *)displayNameWithLength:(NSInteger)maximumLength
{
    return _revenant_displayName;
}

- (AUParameterObserverToken)tokenByAddingParameterObserver:(AUParameterObserver)observer
{
    return [self revenant_addObserver:observer to:_revenant_valueObservers ?: (_revenant_valueObservers = [NSMutableArray array])];
}

- (AUParameterObserverToken)tokenByAddingParameterRecordingObserver:(AUParameterRecordingObserver)observer
{
    return [self revenant_addObserver:observer to:_revenant_recordingObservers ?: (_revenant_recordingObservers = [NSMutableArray array])];
}

- (void)removeParameterObserver:(AUParameterObserverToken)token
{
    [self revenant_removeObserver:token];
}

- (void)revenant_setParent:(AUParameterNode *)parent keyPath:(NSString *)keyPath
{
    _revenant_parent = parent;
    _revenant_keyPath = [keyPath copy];
}

- (NSArray<NSValue *> *)revenant_observerTokens
{
    if (_revenant_valueObservers == nil) {
        return @[];
    }
    return _revenant_valueObservers;
}

- (void)revenant_addAutomationObserver:(id)observer
{
    if (observer == nil) {
        return;
    }
    if (_revenant_automationObservers == nil) {
        _revenant_automationObservers = [NSMutableArray array];
    }
    [_revenant_automationObservers addObject:[NSValue valueWithPointer:(__bridge const void *)observer]];
}

@end

@implementation AUParameterGroup {
    NSArray<AUParameterNode *> *_revenant_children;
}

- (instancetype)initWithRevenantChildren:(NSArray<AUParameterNode *> *)children
{
    if ((self = [super init])) {
        _revenant_children = [children copy];
    }
    return self;
}

- (NSArray<AUParameterNode *> *)children
{
    return _revenant_children;
}

- (id)valueForKey:(NSString *)key
{
    for (AUParameterNode *child in _revenant_children) {
        if ([child.identifier isEqualToString:key]) {
            return child;
        }
    }
    return [super valueForKey:key];
}

- (void)setValue:(id)value forKey:(NSString *)key
{
    for (AUParameterNode *child in _revenant_children) {
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
    for (AUParameterNode *child in _revenant_children) {
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
    [coder encodeInteger:(NSInteger)_revenant_children.count forKey:@"children"];
    for (NSUInteger index = 0; index < _revenant_children.count; index++) {
        [coder encodeObject:_revenant_children[index] forKey:[NSString stringWithFormat:@"%lu", (unsigned long)index]];
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
        _revenant_children = children;
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
        if ([parameter revenant_identifier] == paramID && [parameter revenant_scope] == scope && [parameter revenant_element] == element) {
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

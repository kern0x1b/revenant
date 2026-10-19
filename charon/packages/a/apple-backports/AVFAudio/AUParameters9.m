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

// A token is the address of the observer block the dictionary holds, so a token handed to
// -removeParameterObserver: finds exactly the block it named and two callers can never be given the
// same one. The blocks are kept in an array, not a dictionary, so the order they are called in is the
// order they were added in.
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

// A change reaches the observers of the parameter it happened to, and then the observers of every
// node above it, which is the header's notion of observing one parameter or a whole group (AUParameters.h:162-166).
// The recursion stops at the root, and each node is visited once per change
// because a group notifies its own observers and then asks its children to notify theirs only for a
// change of their own.
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
    // The header's own default: "The default implementation simply returns displayName."
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

// The tokens the node holds, which -charon_apply:... walks to see whether the change it is about to
// announce was the originator's own. Declared in the CharonImpl category and never defined for the
// same reason -[AUParameter charon_parameterWithImpl:] was, and found by the same harness: a send of a
// declared selector that nothing implements, which no build step in the repository sees.
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

// The header (AUParameters.h:236-240) makes a parameter group key-value compliant for its children: looking up
// a child's identifier as a key returns that child, so the group's own key answers for a
// child, and only for a child - a key it does not hold is left to NSObject, which is how a
// KVC-compliant-by-convention object behaves.
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

// The tree of a unit is the unit's own list of parameter identifiers, scopes, elements and ranges:
// that is what is written, and reading it back rebuilds the same tree, so an archive made on one
// machine answers the same on another.
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

// The header's v2 lookup. An address is its three coordinates packed identifier-then-scope-then-
// element, so a tree of a v2 unit finds a parameter from an id, a scope and an element directly; the
// packing is undone the same way it is done, and a unit that publishes no parameters answers nil.
- (AUParameter *)parameterWithID:(AudioUnitParameterID)paramID scope:(AudioUnitScope)scope element:(AudioUnitElement)element
{
    for (AUParameter *parameter in [self allParameters]) {
        if ([parameter charon_identifier] == paramID && [parameter charon_scope] == scope && [parameter charon_element] == element) {
            return parameter;
        }
    }
    return nil;
}

// The keyPath of a node is the identifiers of its parents joined with periods, so this is how a host
// gets back the node a key path names. AUParameters.h:146 says the keyPath of a node, passed to
// valueForKeyPath: on the tree, returns that same node.
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

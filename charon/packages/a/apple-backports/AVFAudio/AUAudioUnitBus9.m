#import "CharonAUAudioUnit.h"

@implementation AUAudioUnitBus {
    AUAudioUnit *_charon_owner;
    AUAudioUnitBusType _charon_type;
    NSUInteger _charon_index;
    BOOL _charon_shouldAllocateBuffer;
    NSString *_charon_name;
    AudioStreamBasicDescription _charon_format;
    BOOL _charon_enabled;
}

// The format of a bus is the unit's own kAudioUnitProperty_StreamFormat for that scope and element -
// the header says the property is "bridged to" it, which is exactly what this is. A unit that
// answers nothing for a bus has no format, which is nil rather than a default the port picked.
- (AVAudioFormat *)format
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioStreamBasicDescription described;
    if (_charon_owner == nil || _charon_owner.audioUnit == NULL) {
        return nil;
    }
    AudioUnitScope scope = _charon_type == AUAudioUnitBusTypeInput ? kAudioUnitScope_Input : kAudioUnitScope_Output;
    if (AudioUnitGetProperty(_charon_owner.audioUnit, kAudioUnitProperty_StreamFormat, scope, (AudioUnitElement)_charon_index,
                             &described, &size) != noErr) {
        return nil;
    }
    return [[AVAudioFormat alloc] initWithStreamDescription:&described];
}

// The private initializer the bus array builds its busses with. It is declared in the CharonImpl
// category in CharonAVFAudio.h and it was *sent* by -charon_allComponents and never defined: the
// object carried an undefined _objc_msgSend$initWithCharonOwner:type:index:, so every call raised.
// The gate cannot see that - a Charon-prefixed selector has no registry row, and the linker does not
// complain about an Objective-C message send - and the port-versus-host half of
// tests/backports/host/avfaudio found it the first time it instantiated a bus.
- (instancetype)initWithCharonOwner:(AUAudioUnit *)owner type:(AUAudioUnitBusType)type index:(NSUInteger)index
{
    if ((self = [super init])) {
        _charon_owner = owner;
        _charon_type = type;
        _charon_index = index;
    }
    return self;
}

- (BOOL)setFormat:(AVAudioFormat *)format error:(NSError **)outError
{
    if (format == nil || _charon_owner == nil || _charon_owner.audioUnit == NULL) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FormatNotSupported userInfo:nil];
        }
        return NO;
    }
    const AudioStreamBasicDescription *described = format.streamDescription;
    if (described == NULL) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FormatNotSupported userInfo:nil];
        }
        return NO;
    }
    AudioUnitScope scope = _charon_type == AUAudioUnitBusTypeInput ? kAudioUnitScope_Input : kAudioUnitScope_Output;
    OSStatus status = AudioUnitSetProperty(_charon_owner.audioUnit, kAudioUnitProperty_StreamFormat, scope,
                                           (AudioUnitElement)_charon_index, described, sizeof(AudioStreamBasicDescription));
    if (status != noErr) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
    _charon_format = *described;
    return YES;
}

- (AUAudioUnit *)ownerAudioUnit
{
    return _charon_owner;
}

- (AUAudioUnitBusType)busType
{
    return _charon_type;
}

- (NSUInteger)index
{
    return _charon_index;
}

- (NSString *)name
{
    return _charon_name;
}

- (void)setName:(NSString *)name
{
    _charon_name = [name copy];
}

- (NSArray<NSNumber *> *)supportedChannelLayoutTags
{
    // The tags the unit supports on this bus, through kAudioUnitProperty_SupportedChannelLayoutTags,
    // which the header documents as "AudioChannelLayoutTags[ variable number of elements ]", Access:
    // read only. The value is a CFArray whose entries are the *names* of tags, so each is read by
    // name and the four characters of the name are the tag. A unit that publishes none answers nil,
    // which the header allows - and nil is the answer, as opposed to the one-element array holding
    // the bus's own current layout, which is a different question and not the one asked.
    if (_charon_owner == nil || _charon_owner.audioUnit == NULL) {
        return nil;
    }
    AudioUnitScope scope = _charon_type == AUAudioUnitBusTypeInput ? kAudioUnitScope_Input : kAudioUnitScope_Output;
    UInt32 size = 0;
    if (AudioUnitGetPropertyInfo(_charon_owner.audioUnit, kAudioUnitProperty_SupportedChannelLayoutTags, scope,
                                 (AudioUnitElement)_charon_index, &size, NULL) != noErr || size < sizeof(CFArrayRef)) {
        return nil;
    }
    CFArrayRef tags = NULL;
    size = sizeof(tags);
    if (AudioUnitGetProperty(_charon_owner.audioUnit, kAudioUnitProperty_SupportedChannelLayoutTags, scope,
                             (AudioUnitElement)_charon_index, &tags, &size) != noErr || tags == NULL) {
        return nil;
    }
    NSMutableArray<NSNumber *> *found = [NSMutableArray array];
    CFIndex count = CFArrayGetCount(tags);
    for (CFIndex index = 0; index < count; index++) {
        CFStringRef name = CFArrayGetValueAtIndex(tags, index);
        if (name == NULL) {
            continue;
        }
        AudioChannelLayoutTag tag = CharonTagFromName((__bridge NSString *)name);
        if (tag != 0) {
            [found addObject:@(tag)];
        }
    }
    CFRelease(tags);
    return found;
}

// Float64 by the header's own Value Type, for the same reason the unit's own latency is: read narrow
// it is accepted and returns the low half of the double. See tests/backports/host/avfaudio/.
- (NSTimeInterval)latency
{
    if (_charon_owner == nil || _charon_owner.audioUnit == NULL) {
        return 0;
    }
    Float64 latency = 0;
    UInt32 size = sizeof(Float64);
    AudioUnitScope scope = _charon_type == AUAudioUnitBusTypeInput ? kAudioUnitScope_Input : kAudioUnitScope_Output;
    if (AudioUnitGetProperty(_charon_owner.audioUnit, kAudioUnitProperty_Latency, scope, (AudioUnitElement)_charon_index, &latency, &size) != noErr) {
        return 0;
    }
    return latency;
}

// Whether the bus is active, which on a v2 unit is the input render callback being installed or not -
// the header says the property is bridged to kAudioUnitProperty_MakeConnection and
// kAudioUnitProperty_SetRenderCallback together, and on a unit with no downstream node the render
// callback is the whole of it.
- (BOOL)isEnabled
{
    return _charon_enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    if (_charon_enabled == enabled || _charon_owner == nil || _charon_owner.audioUnit == NULL) {
        return;
    }
    _charon_enabled = enabled;
    AURenderCallbackStruct callback = {0};
    if (enabled) {
        callback.inputProc = CharonAURenderInput;
        callback.inputProcRefCon = (__bridge void *)_charon_owner;
    }
    AudioUnitSetProperty(_charon_owner.audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input,
                         (AudioUnitElement)_charon_index, enabled ? &callback : NULL, enabled ? sizeof(callback) : 0);
}

@end

@implementation AUAudioUnitBusArray {
    AUAudioUnit *_charon_owner;
    AUAudioUnitBusType _charon_type;
    NSArray<AUAudioUnitBus *> *_charon_busses;
}

// A bus array is built by asking the unit how many of that kind of bus it has: a v2 unit publishes
// the element count of a scope through kAudioUnitProperty_ElementCount, which is the release's own
// answer, so the number of busses is the unit's and not a number the port chose.
- (instancetype)initWithAudioUnit:(AUAudioUnit *)owner busType:(AUAudioUnitBusType)busType busses:(NSArray<AUAudioUnitBus *> *)busArray
{
    if ((self = [super init])) {
        _charon_owner = owner;
        _charon_type = busType;
        _charon_busses = [busArray copy];
    }
    return self;
}

// A bus array is built by asking the unit how many of that kind of bus it has: a v2 unit publishes
// the element count of a scope through kAudioUnitProperty_ElementCount, which is the release's own
// answer, so the number of busses is the unit's and not a number the port chose.
- (instancetype)initWithAudioUnit:(AUAudioUnit *)owner busType:(AUAudioUnitBusType)busType
{
    AudioUnitScope scope = busType == AUAudioUnitBusTypeInput ? kAudioUnitScope_Input : kAudioUnitScope_Output;
    UInt32 elements = 0;
    UInt32 size = sizeof(UInt32);
    NSMutableArray<AUAudioUnitBus *> *built = [NSMutableArray array];
    if (owner != nil && owner.audioUnit != NULL &&
        AudioUnitGetProperty(owner.audioUnit, kAudioUnitProperty_ElementCount, scope, 0, &elements, &size) == noErr) {
        for (UInt32 index = 0; index < elements; index++) {
            [built addObject:[[AUAudioUnitBus alloc] initWithCharonOwner:owner type:busType index:index]];
        }
    }
    return [self initWithAudioUnit:owner busType:busType busses:built];
}

- (NSUInteger)count
{
    return _charon_busses.count;
}

- (AUAudioUnitBus *)objectAtIndexedSubscript:(NSUInteger)index
{
    return index < _charon_busses.count ? _charon_busses[index] : nil;
}

- (AUAudioUnit *)ownerAudioUnit
{
    return _charon_owner;
}

- (AUAudioUnitBusType)busType
{
    return _charon_type;
}

// The header's own default: "The base implementation returns false." A bus array of a v2 unit has
// however many busses the unit says it has, and a v2 unit's element count is fixed once it is
// instantiated, so it cannot be changed from the host side.
- (BOOL)isCountChangeable
{
    return NO;
}

- (BOOL)setBusCount:(NSUInteger)count error:(NSError **)outError
{
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_InvalidPropertyValue userInfo:nil];
    }
    return NO;
}

- (void)addObserverToAllBusses:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
    for (AUAudioUnitBus *bus in _charon_busses) {
        [bus addObserver:observer forKeyPath:keyPath options:options context:context];
    }
}

- (void)removeObserverFromAllBusses:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context
{
    for (AUAudioUnitBus *bus in _charon_busses) {
        [bus removeObserver:observer forKeyPath:keyPath context:context];
    }
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained _Nonnull [_Nonnull])buffer count:(NSUInteger)len
{
    return [_charon_busses countByEnumeratingWithState:state objects:buffer count:len];
}

@end

@implementation AUAudioUnitPreset {
    NSInteger _charon_number;
    NSString *_charon_name;
}

- (instancetype)initWithNumber:(NSInteger)number name:(NSString *)name
{
    if ((self = [super init])) {
        _charon_number = number;
        _charon_name = [name copy];
    }
    return self;
}

- (NSInteger)number
{
    return _charon_number;
}

- (void)setNumber:(NSInteger)number
{
    _charon_number = number;
}

- (NSString *)name
{
    return _charon_name;
}

- (void)setName:(NSString *)name
{
    _charon_name = [name copy];
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_charon_number forKey:@"number"];
    [coder encodeObject:_charon_name forKey:@"name"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _charon_number = [coder decodeIntegerForKey:@"number"];
        _charon_name = [coder decodeObjectForKey:@"name"];
    }
    return self;
}

@end

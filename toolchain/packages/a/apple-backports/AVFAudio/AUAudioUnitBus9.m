#import "RevenantAUAudioUnit.h"

@implementation AUAudioUnitBus {
    AUAudioUnit *_revenant_owner;
    AUAudioUnitBusType _revenant_type;
    NSUInteger _revenant_index;
    BOOL _revenant_shouldAllocateBuffer;
    NSString *_revenant_name;
    AudioStreamBasicDescription _revenant_format;
    BOOL _revenant_enabled;
}

- (AVAudioFormat *)format
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioStreamBasicDescription described;
    if (_revenant_owner == nil || _revenant_owner.audioUnit == NULL) {
        return nil;
    }
    AudioUnitScope scope = _revenant_type == AUAudioUnitBusTypeInput ? kAudioUnitScope_Input : kAudioUnitScope_Output;
    if (AudioUnitGetProperty(_revenant_owner.audioUnit, kAudioUnitProperty_StreamFormat, scope, (AudioUnitElement)_revenant_index,
                             &described, &size) != noErr) {
        return nil;
    }
    return [[AVAudioFormat alloc] initWithStreamDescription:&described];
}

- (instancetype)initWithRevenantOwner:(AUAudioUnit *)owner type:(AUAudioUnitBusType)type index:(NSUInteger)index
{
    if ((self = [super init])) {
        _revenant_owner = owner;
        _revenant_type = type;
        _revenant_index = index;
    }
    return self;
}

- (BOOL)setFormat:(AVAudioFormat *)format error:(NSError **)outError
{
    if (format == nil || _revenant_owner == nil || _revenant_owner.audioUnit == NULL) {
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
    AudioUnitScope scope = _revenant_type == AUAudioUnitBusTypeInput ? kAudioUnitScope_Input : kAudioUnitScope_Output;
    OSStatus status = AudioUnitSetProperty(_revenant_owner.audioUnit, kAudioUnitProperty_StreamFormat, scope,
                                           (AudioUnitElement)_revenant_index, described, sizeof(AudioStreamBasicDescription));
    if (status != noErr) {
        if (outError) {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        return NO;
    }
    _revenant_format = *described;
    return YES;
}

- (AUAudioUnit *)ownerAudioUnit
{
    return _revenant_owner;
}

- (AUAudioUnitBusType)busType
{
    return _revenant_type;
}

- (NSUInteger)index
{
    return _revenant_index;
}

- (NSString *)name
{
    return _revenant_name;
}

- (void)setName:(NSString *)name
{
    _revenant_name = [name copy];
}

- (NSArray<NSNumber *> *)supportedChannelLayoutTags
{
    if (_revenant_owner == nil || _revenant_owner.audioUnit == NULL) {
        return nil;
    }
    AudioUnitScope scope = _revenant_type == AUAudioUnitBusTypeInput ? kAudioUnitScope_Input : kAudioUnitScope_Output;
    UInt32 size = 0;
    if (AudioUnitGetPropertyInfo(_revenant_owner.audioUnit, kAudioUnitProperty_SupportedChannelLayoutTags, scope,
                                 (AudioUnitElement)_revenant_index, &size, NULL) != noErr || size < sizeof(CFArrayRef)) {
        return nil;
    }
    CFArrayRef tags = NULL;
    size = sizeof(tags);
    if (AudioUnitGetProperty(_revenant_owner.audioUnit, kAudioUnitProperty_SupportedChannelLayoutTags, scope,
                             (AudioUnitElement)_revenant_index, &tags, &size) != noErr || tags == NULL) {
        return nil;
    }
    NSMutableArray<NSNumber *> *found = [NSMutableArray array];
    CFIndex count = CFArrayGetCount(tags);
    for (CFIndex index = 0; index < count; index++) {
        CFStringRef name = CFArrayGetValueAtIndex(tags, index);
        if (name == NULL) {
            continue;
        }
        AudioChannelLayoutTag tag = RevenantTagFromName((__bridge NSString *)name);
        if (tag != 0) {
            [found addObject:@(tag)];
        }
    }
    CFRelease(tags);
    return found;
}

- (NSTimeInterval)latency
{
    if (_revenant_owner == nil || _revenant_owner.audioUnit == NULL) {
        return 0;
    }
    Float64 latency = 0;
    UInt32 size = sizeof(Float64);
    AudioUnitScope scope = _revenant_type == AUAudioUnitBusTypeInput ? kAudioUnitScope_Input : kAudioUnitScope_Output;
    if (AudioUnitGetProperty(_revenant_owner.audioUnit, kAudioUnitProperty_Latency, scope, (AudioUnitElement)_revenant_index, &latency, &size) != noErr) {
        return 0;
    }
    return latency;
}

- (BOOL)isEnabled
{
    return _revenant_enabled;
}

- (void)setEnabled:(BOOL)enabled
{
    if (_revenant_enabled == enabled || _revenant_owner == nil || _revenant_owner.audioUnit == NULL) {
        return;
    }
    _revenant_enabled = enabled;
    AURenderCallbackStruct callback = {0};
    if (enabled) {
        callback.inputProc = RevenantAURenderInput;
        callback.inputProcRefCon = (__bridge void *)_revenant_owner;
    }
    AudioUnitSetProperty(_revenant_owner.audioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input,
                         (AudioUnitElement)_revenant_index, enabled ? &callback : NULL, enabled ? sizeof(callback) : 0);
}

@end

@implementation AUAudioUnitBusArray {
    AUAudioUnit *_revenant_owner;
    AUAudioUnitBusType _revenant_type;
    NSArray<AUAudioUnitBus *> *_revenant_busses;
}

- (instancetype)initWithAudioUnit:(AUAudioUnit *)owner busType:(AUAudioUnitBusType)busType busses:(NSArray<AUAudioUnitBus *> *)busArray
{
    if ((self = [super init])) {
        _revenant_owner = owner;
        _revenant_type = busType;
        _revenant_busses = [busArray copy];
    }
    return self;
}

- (instancetype)initWithAudioUnit:(AUAudioUnit *)owner busType:(AUAudioUnitBusType)busType
{
    AudioUnitScope scope = busType == AUAudioUnitBusTypeInput ? kAudioUnitScope_Input : kAudioUnitScope_Output;
    UInt32 elements = 0;
    UInt32 size = sizeof(UInt32);
    NSMutableArray<AUAudioUnitBus *> *built = [NSMutableArray array];
    if (owner != nil && owner.audioUnit != NULL &&
        AudioUnitGetProperty(owner.audioUnit, kAudioUnitProperty_ElementCount, scope, 0, &elements, &size) == noErr) {
        for (UInt32 index = 0; index < elements; index++) {
            [built addObject:[[AUAudioUnitBus alloc] initWithRevenantOwner:owner type:busType index:index]];
        }
    }
    return [self initWithAudioUnit:owner busType:busType busses:built];
}

- (NSUInteger)count
{
    return _revenant_busses.count;
}

- (AUAudioUnitBus *)objectAtIndexedSubscript:(NSUInteger)index
{
    return index < _revenant_busses.count ? _revenant_busses[index] : nil;
}

- (AUAudioUnit *)ownerAudioUnit
{
    return _revenant_owner;
}

- (AUAudioUnitBusType)busType
{
    return _revenant_type;
}

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
    for (AUAudioUnitBus *bus in _revenant_busses) {
        [bus addObserver:observer forKeyPath:keyPath options:options context:context];
    }
}

- (void)removeObserverFromAllBusses:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context
{
    for (AUAudioUnitBus *bus in _revenant_busses) {
        [bus removeObserver:observer forKeyPath:keyPath context:context];
    }
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id __unsafe_unretained _Nonnull [_Nonnull])buffer count:(NSUInteger)len
{
    return [_revenant_busses countByEnumeratingWithState:state objects:buffer count:len];
}

@end

@implementation AUAudioUnitPreset {
    NSInteger _revenant_number;
    NSString *_revenant_name;
}

- (instancetype)initWithNumber:(NSInteger)number name:(NSString *)name
{
    if ((self = [super init])) {
        _revenant_number = number;
        _revenant_name = [name copy];
    }
    return self;
}

- (NSInteger)number
{
    return _revenant_number;
}

- (void)setNumber:(NSInteger)number
{
    _revenant_number = number;
}

- (NSString *)name
{
    return _revenant_name;
}

- (void)setName:(NSString *)name
{
    _revenant_name = [name copy];
}

#pragma mark NSSecureCoding

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeInteger:_revenant_number forKey:@"number"];
    [coder encodeObject:_revenant_name forKey:@"name"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _revenant_number = [coder decodeIntegerForKey:@"number"];
        _revenant_name = [coder decodeObjectForKey:@"name"];
    }
    return self;
}

@end

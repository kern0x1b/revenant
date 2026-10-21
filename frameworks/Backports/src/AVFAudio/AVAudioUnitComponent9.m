#import "RevenantAVFAudio.h"

NSString * const AVAudioUnitTypeOutput = @"Output";
NSString * const AVAudioUnitTypeMusicDevice = @"Music Device";
NSString * const AVAudioUnitTypeMusicEffect = @"Music Effect";
NSString * const AVAudioUnitTypeFormatConverter = @"Format Converter";
NSString * const AVAudioUnitTypeEffect = @"Effect";
NSString * const AVAudioUnitTypeMixer = @"Mixer";
NSString * const AVAudioUnitTypePanner = @"Panner";
NSString * const AVAudioUnitTypeGenerator = @"Generator";
NSString * const AVAudioUnitTypeOfflineEffect = @"Offline Effect";
NSString * const AVAudioUnitTypeMIDIProcessor = @"MIDI Processor";
NSString * const AVAudioUnitManufacturerNameApple = @"Apple";
NSString * const AVAudioUnitComponentTagsDidChangeNotification = @"AVAudioUnitComponentTagsDidChangeNotification";

static NSString *RevenantTypeNameForType(OSType type)
{
    switch (type) {
        case kAudioUnitType_Output: return AVAudioUnitTypeOutput;
        case kAudioUnitType_MusicDevice: return AVAudioUnitTypeMusicDevice;
        case kAudioUnitType_MusicEffect: return AVAudioUnitTypeMusicEffect;
        case kAudioUnitType_Effect: return AVAudioUnitTypeEffect;
        case kAudioUnitType_Mixer: return AVAudioUnitTypeMixer;
        case kAudioUnitType_Panner: return AVAudioUnitTypePanner;
        case kAudioUnitType_FormatConverter: return AVAudioUnitTypeFormatConverter;
        case kAudioUnitType_Generator: return AVAudioUnitTypeGenerator;
        case kAudioUnitType_OfflineEffect: return AVAudioUnitTypeOfflineEffect;
        case kAudioUnitType_MIDIProcessor: return AVAudioUnitTypeMIDIProcessor;
        default: return nil;
    }
}

@implementation AVAudioUnitComponent {
    AudioComponent _revenant_component;
    AudioComponentDescription _revenant_description;
    NSString *_revenant_name;
    NSString *_revenant_typeName;
    NSString *_revenant_manufacturerName;
}

- (instancetype)initWithRevenantComponent:(AudioComponent)component
{
    if ((self = [super init])) {
        _revenant_component = component;
        if (AudioComponentGetDescription(component, &_revenant_description) != noErr) {
            memset(&_revenant_description, 0, sizeof(_revenant_description));
        }
        CFStringRef copied = NULL;
        if (AudioComponentCopyName(component, &copied) == noErr && copied != NULL) {
            _revenant_name = (__bridge_transfer NSString *)copied;
        }
        _revenant_typeName = RevenantTypeNameForType(_revenant_description.componentType);
        OSType manufacturer = CFSwapInt32HostToBig(_revenant_description.componentManufacturer);
        if (manufacturer == CFSwapInt32HostToBig(kAudioUnitManufacturer_Apple)) {
            _revenant_manufacturerName = AVAudioUnitManufacturerNameApple;
        } else {
            char code[5] = {0};
            memcpy(code, &manufacturer, 4);
            _revenant_manufacturerName = [NSString stringWithUTF8String:code] ?: @"";
        }
    }
    return self;
}

- (NSString *)name
{
    return _revenant_name;
}

- (NSString *)typeName
{
    return _revenant_typeName;
}

- (NSString *)localizedTypeName
{
    return _revenant_typeName;
}

- (NSString *)manufacturerName
{
    return _revenant_manufacturerName;
}

- (NSUInteger)version
{
    UInt32 version = 0;
    if (_revenant_component == NULL || AudioComponentGetVersion(_revenant_component, &version) != noErr) {
        return 0;
    }
    return (NSUInteger)version;
}

- (NSString *)versionString
{
    UInt32 version = (UInt32)[self version];
    return [NSString stringWithFormat:@"%u.%u.%u", (unsigned)((version >> 16) & 0xFFFF), (unsigned)((version >> 8) & 0xFF), (unsigned)(version & 0xFF)];
}

- (nullable NSURL *)componentURL
{
    return nil;
}

- (NSArray<NSNumber *> *)availableArchitectures
{
    return @[@(CPU_TYPE_ARM)];
}

- (BOOL)isSandboxSafe
{
    return YES;
}

- (BOOL)hasMIDIOutput
{
    AudioUnit unit = NULL;
    if (_revenant_component == NULL || AudioComponentInstanceNew(_revenant_component, &unit) != noErr || unit == NULL) {
        return NO;
    }
    UInt32 size = 0;
    BOOL has = AudioUnitGetPropertyInfo(unit, kAudioUnitProperty_MIDIOutputCallback, kAudioUnitScope_Global, 0, &size, NULL) == noErr;
    AudioComponentInstanceDispose(unit);
    return has;
}

- (BOOL)hasMIDIInput
{
    AudioUnit unit = NULL;
    if (_revenant_component == NULL || AudioComponentInstanceNew(_revenant_component, &unit) != noErr || unit == NULL) {
        return NO;
    }
    UInt32 size = 0;
    BOOL has = AudioUnitGetPropertyInfo(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &size, NULL) == noErr && size >= sizeof(AudioStreamBasicDescription);
    AudioComponentInstanceDispose(unit);
    return has;
}

- (AudioComponent)audioComponent
{
    return _revenant_component;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunguarded-availability"
- (void)setUserTagNames:(NSArray<NSString *> *)userTagNames
{
}

- (NSArray<NSString *> *)userTagNames
{
    return @[];
}

- (NSArray<NSString *> *)allTagNames
{
    return @[];
}
#pragma clang diagnostic pop

- (AudioComponentDescription)audioComponentDescription
{
    return _revenant_description;
}

- (nullable NSURL *)iconURL
{
    return nil;
}

- (BOOL)hasCustomView
{
    return NO;
}

- (BOOL)supportsNumberInputChannels:(NSInteger)numInputChannels outputChannels:(NSInteger)numOutputChannels
{
    if (numInputChannels < 0 || numOutputChannels < 0 || _revenant_component == NULL) {
        return NO;
    }
    AudioUnit unit = NULL;
    if (AudioComponentInstanceNew(_revenant_component, &unit) != noErr || unit == NULL) {
        return NO;
    }
    BOOL supported = YES;
    if (numInputChannels == 0 && numOutputChannels == 0) {
        supported = NO;
    }
    AudioStreamBasicDescription probe;
    memset(&probe, 0, sizeof(probe));
    probe.mFormatID = kAudioFormatLinearPCM;
    probe.mSampleRate = 44100.0;
    probe.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked;
    probe.mBitsPerChannel = 32;
    probe.mFramesPerPacket = 1;
    probe.mChannelsPerFrame = 1;
    if (supported && numInputChannels > 0) {
        probe.mChannelsPerFrame = (UInt32)numInputChannels;
        if (AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &probe, sizeof(probe)) != noErr) {
            supported = NO;
        }
    }
    if (supported && numOutputChannels > 0) {
        probe.mChannelsPerFrame = (UInt32)numOutputChannels;
        if (AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &probe, sizeof(probe)) != noErr) {
            supported = NO;
        }
    }
    AudioComponentInstanceDispose(unit);
    return supported;
}

@end

@implementation AVAudioUnitComponentManager

+ (instancetype)sharedAudioUnitComponentManager
{
    static AVAudioUnitComponentManager *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (NSArray<AVAudioUnitComponent *> *)revenant_allComponents
{
    NSMutableArray *found = [NSMutableArray array];
    AudioComponentDescription any = {0, 0, 0};
    UInt32 count = AudioComponentCount(&any);
    AudioComponent component = NULL;
    for (UInt32 index = 0; index < count; index++) {
        component = AudioComponentFindNext(component, &any);
        if (component == NULL) {
            break;
        }
        [found addObject:[[AVAudioUnitComponent alloc] initWithRevenantComponent:component]];
    }
    return found;
}

- (NSArray<NSString *> *)tagNames
{
    return @[];
}

- (NSArray<NSString *> *)standardLocalizedTagNames
{
    return @[];
}

- (NSArray<AVAudioUnitComponent *> *)componentsMatchingPredicate:(NSPredicate *)predicate
{
    NSArray<AVAudioUnitComponent *> *all = [self revenant_allComponents];
    if (predicate == nil) {
        return all;
    }
    NSMutableArray *matched = [NSMutableArray array];
    for (AVAudioUnitComponent *component in all) {
        if ([predicate evaluateWithObject:component]) {
            [matched addObject:component];
            continue;
        }
        NSDictionary *documented = @{
            @"name": component.name ?: @"",
            @"typeName": component.typeName ?: @"",
            @"localizedTypeName": component.localizedTypeName ?: @"",
            @"manufacturerName": component.manufacturerName ?: @"",
            @"version": @(component.version),
            @"versionString": component.versionString ?: @"",
            @"allTagNames": component.allTagNames,
            @"userTagNames": component.allTagNames,
            @"tags": component.allTagNames,
        };
        @try {
            if ([predicate evaluateWithObject:documented]) {
                [matched addObject:component];
            }
        } @catch (NSException *exception) {
        }
    }
    return matched;
}

- (NSArray<AVAudioUnitComponent *> *)componentsPassingTest:(BOOL (^)(AVAudioUnitComponent *comp, BOOL *stop))testHandler
{
    if (testHandler == nil) {
        return @[];
    }
    NSMutableArray *matched = [NSMutableArray array];
    BOOL finished = NO;
    for (AVAudioUnitComponent *component in [self revenant_allComponents]) {
        if ((testHandler(component, &finished))) {
            [matched addObject:component];
        }
        if (finished) {
            break;
        }
    }
    return matched;
}

- (NSArray<AVAudioUnitComponent *> *)componentsMatchingDescription:(AudioComponentDescription)desc
{
    NSMutableArray *matched = [NSMutableArray array];
    AudioComponentDescription wanted = desc;
    AudioComponent component = AudioComponentFindNext(NULL, &wanted);
    while (component != NULL) {
        [matched addObject:[[AVAudioUnitComponent alloc] initWithRevenantComponent:component]];
        component = AudioComponentFindNext(component, &wanted);
    }
    return matched;
}

@end

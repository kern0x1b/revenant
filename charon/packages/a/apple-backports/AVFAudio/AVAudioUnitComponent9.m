#import "CharonAVFAudio.h"

// AVAudioUnitComponent and AVAudioUnitComponentManager over the AudioComponent discovery C API,
// which iOS 6.1.3 exports in full: AudioComponentCount, AudioComponentFindNext,
// AudioComponentGetDescription, AudioComponentCopyName, AudioComponentGetVersion,
// AudioComponentInstanceNew, AudioComponentInstanceDispose, AudioComponentInstanceCanDo,
// AudioComponentInstanceGetComponent, AudioComponentRegister. Every answer below is one of those
// ten, or something the release holds itself - the one exception is written down where it happens.
//
// What this release does NOT have, measured, is the tag family: iOS 6.1.3 exports no
// AudioComponentCopyTags and no AudioComponentGetParameter, so no component of it carries a tag and
// the tag properties answer the empty array - the true answer for a release that defines no tag -
// with the notifications that would announce a change never posted. See
// facts/AVFAudio/AVAudioUnitComponent.md.

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

// The type name a component's kAudioUnitType says, in the strings the release itself exports: read
// through the symbol out of libAVFAudio.dylib in the arm64e cache of iOS 18.0, and from the host's
// own AVFAudio as a second independent source. The two agree on all eleven.
static NSString *CharonTypeNameForType(OSType type)
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
    AudioComponent _charon_component;
    AudioComponentDescription _charon_description;
    NSString *_charon_name;
    NSString *_charon_typeName;
    NSString *_charon_manufacturerName;
}

- (instancetype)initWithCharonComponent:(AudioComponent)component
{
    if ((self = [super init])) {
        _charon_component = component;
        if (AudioComponentGetDescription(component, &_charon_description) != noErr) {
            memset(&_charon_description, 0, sizeof(_charon_description));
        }
        CFStringRef copied = NULL;
        if (AudioComponentCopyName(component, &copied) == noErr && copied != NULL) {
            _charon_name = (__bridge_transfer NSString *)copied;
        }
        _charon_typeName = CharonTypeNameForType(_charon_description.componentType);
        // Apple's own manufacturer name comes out of the component bundle's Info.plist, which a
        // component inside the shared cache does not have. The four-character manufacturer code of
        // the description is what the release does hold, so that is what is answered: 'appl' reads
        // as the string the release itself exports for the Apple manufacturer, another code as
        // itself, which is the same four characters the release would name.
        OSType manufacturer = CFSwapInt32HostToBig(_charon_description.componentManufacturer);
        if (manufacturer == CFSwapInt32HostToBig(kAudioUnitManufacturer_Apple)) {
            _charon_manufacturerName = AVAudioUnitManufacturerNameApple;
        } else {
            char code[5] = {0};
            memcpy(code, &manufacturer, 4);
            _charon_manufacturerName = [NSString stringWithUTF8String:code] ?: @"";
        }
    }
    return self;
}

- (NSString *)name
{
    return _charon_name;
}

- (NSString *)typeName
{
    return _charon_typeName;
}

// The type name already carries the words and the spaces of the release's own type names ("Music
// Device", "Format Converter", "Offline Effect", all read out of the release), and this release has
// no component bundle to hold a localized string for them, so the type name is the display name.
- (NSString *)localizedTypeName
{
    return _charon_typeName;
}

- (NSString *)manufacturerName
{
    return _charon_manufacturerName;
}

- (NSUInteger)version
{
    UInt32 version = 0;
    if (_charon_component == NULL || AudioComponentGetVersion(_charon_component, &version) != noErr) {
        return 0;
    }
    return (NSUInteger)version;
}

// The version is the hexadecimal number 0xMMMMmmDD the header names, so its string is those three
// fields in that order: the major number, the minor number, the dot-release number.
- (NSString *)versionString
{
    UInt32 version = (UInt32)[self version];
    return [NSString stringWithFormat:@"%u.%u.%u", (unsigned)((version >> 16) & 0xFFFF), (unsigned)((version >> 8) & 0xFF), (unsigned)(version & 0xFF)];
}

// A component of this release lives in the shared cache, which has no path in the file system, so
// the location the header asks for is the one such a component can have: none.
- (nullable NSURL *)componentURL
{
    return nil;
}

// The header documents this as one Mach-O architecture constant per slice the component carries. The
// slice this library is built for is the one the release holds, and a component of the shared cache
// carries no other slice, so that is what is answered.
- (NSArray<NSNumber *> *)availableArchitectures
{
    return @[@(CPU_TYPE_ARM)];
}

// The header's own answer for iOS: "On iOS, this is always YES."
- (BOOL)isSandboxSafe
{
    return YES;
}

// Whether a component can emit or take MIDI is asked of the component itself, not inferred from its
// type: a real instance is made and asked for the property that says so. A unit without it answers
// an error, which is the answer NO.
- (BOOL)hasMIDIOutput
{
    AudioUnit unit = NULL;
    if (_charon_component == NULL || AudioComponentInstanceNew(_charon_component, &unit) != noErr || unit == NULL) {
        return NO;
    }
    UInt32 size = 0;
    BOOL has = AudioUnitGetPropertyInfo(unit, kAudioUnitProperty_MIDIOutputCallback, kAudioUnitScope_Global, 0, &size, NULL) == noErr;
    AudioComponentInstanceDispose(unit);
    return has;
}

// This release's property set has no per-unit "takes MIDI in" flag - kAudioUnitProperty_
// MIDIEventInputCallback is a macOS property, and no iOS property answers it - so what a component
// is asked is whether it has an input bus to take MIDI on, which is a real AudioUnit answer. A unit
// that reads MIDI through some other mechanism is not detected, which
// facts/AVFAudio/AVAudioUnitComponent.md records.
- (BOOL)hasMIDIInput
{
    AudioUnit unit = NULL;
    if (_charon_component == NULL || AudioComponentInstanceNew(_charon_component, &unit) != noErr || unit == NULL) {
        return NO;
    }
    UInt32 size = 0;
    BOOL has = AudioUnitGetPropertyInfo(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &size, NULL) == noErr && size >= sizeof(AudioStreamBasicDescription);
    AudioComponentInstanceDispose(unit);
    return has;
}

- (AudioComponent)audioComponent
{
    return _charon_component;
}

// This release exports no AudioComponentCopyTags and no AudioComponentGetParameter, so no component
// of it carries a tag: the array of the current user's tags is empty and setting one has nothing to
// change. Both are the header's own shapes over an empty set, not a stub.
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
    return _charon_description;
}

- (nullable NSURL *)iconURL
{
    return nil;
}

- (BOOL)hasCustomView
{
    return NO;
}

// The header (AVAudioUnitComponent.h:166-167) says YES means the component supports a given input/output channel setup.
// That is asked of a real instance of the component rather than read off its type: a stream format
// of the requested channel count is offered to the unit's input and output scope, and the unit's own
// answer decides. A unit that refuses the format does not support that configuration.
- (BOOL)supportsNumberInputChannels:(NSInteger)numInputChannels outputChannels:(NSInteger)numOutputChannels
{
    if (numInputChannels < 0 || numOutputChannels < 0 || _charon_component == NULL) {
        return NO;
    }
    AudioUnit unit = NULL;
    if (AudioComponentInstanceNew(_charon_component, &unit) != noErr || unit == NULL) {
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

// Every component the release has, as AVAudioUnitComponent objects over the release's own
// AudioComponentFindNext walk. Apple caches the list; the walk is cheap (AudioComponentCount is the
// number of iterations) and is done per search, so a component registered after this process started
// is found - which is what the registrations-changed notification would otherwise announce.
- (NSArray<AVAudioUnitComponent *> *)charon_allComponents
{
    NSMutableArray *found = [NSMutableArray array];
    // An all-zero description is the release's own "every component" query: AudioComponentCount and
    // AudioComponentFindNext both take it, and the loop stops where the release says it has no more.
    AudioComponentDescription any = {0, 0, 0};
    UInt32 count = AudioComponentCount(&any);
    AudioComponent component = NULL;
    for (UInt32 index = 0; index < count; index++) {
        component = AudioComponentFindNext(component, &any);
        if (component == NULL) {
            break;
        }
        [found addObject:[[AVAudioUnitComponent alloc] initWithCharonComponent:component]];
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
    NSArray<AVAudioUnitComponent *> *all = [self charon_allComponents];
    if (predicate == nil) {
        return all;
    }
    NSMutableArray *matched = [NSMutableArray array];
    for (AVAudioUnitComponent *component in all) {
        // The header's own example is "typeName CONTAINS 'Effect'", and the tag key the old
        // documentation names is 'tags'. Both are answered from the component itself, and a key this
        // release has no value for answers an empty array rather than raising.
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
            // A key the header does not name answers no match rather than taking the application
            // down through a predicate it wrote against Apple's own class.
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
    for (AVAudioUnitComponent *component in [self charon_allComponents]) {
        // Parenthesised on purpose: `[testHandler(component, &finished)]` is a message send whose
        // receiver clang parses as a *declarator* - the two arguments look like a parameter list -
        // and reports "expected identifier" on the ampersand. The parentheses make the receiver the
        // expression it is.
        if ((testHandler(component, &finished))) {
            [matched addObject:component];
        }
        if (finished) {
            break;
        }
    }
    return matched;
}

// The header (AVAudioUnitComponent.h:241-246) treats a zero in any of these fields as a wildcard, and the first match wins.
- (NSArray<AVAudioUnitComponent *> *)componentsMatchingDescription:(AudioComponentDescription)desc
{
    NSMutableArray *matched = [NSMutableArray array];
    AudioComponentDescription wanted = desc;
    AudioComponent component = AudioComponentFindNext(NULL, &wanted);
    while (component != NULL) {
        [matched addObject:[[AVAudioUnitComponent alloc] initWithCharonComponent:component]];
        component = AudioComponentFindNext(component, &wanted);
    }
    return matched;
}

@end

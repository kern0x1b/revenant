// The MIDI-CI 1.x classes of iOS 14: a profile made from its bytes alone, the profile state with enabled and disabled lists, a
// session's profile send, the discovered node, the discovery manager and the responder. Measured on macOS
// (oracle/micicapability.m, micicapability-macos.txt, 2026-10-09): a profile made from its bytes alone is named from them when
// the first byte is the standard profile's (0x7E); the discovery manager never answers, since its MIDI-CI client is refused
// (-10844), so its handler is never called; a responder with no profile delegate is not made. A discovered node is never
// produced by this port, since it has no MIDI-CI transport (facts/CoreMIDI/MIDICI.md).
#import "CharonMIDICI.h"

// The MIDI-CI actions have no transport: each does nothing, and says so once, the first time it is used (the registry's inert
// state). The names are the methods' own, as __PRETTY_FUNCTION__ gives them.
void charon_ci_inert(const char * _Nonnull action)
{
    static NSMutableSet *said;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        said = [NSMutableSet set];
    });
    NSString *name = [NSString stringWithUTF8String:action];
    @synchronized (said) {
        if ([said containsObject:name])
            return;
        [said addObject:name];
    }
    NSLog(@"charon: %s does nothing: this port has no MIDI-CI transport (facts/CoreMIDI/MIDICI.md)", action);
}

@implementation MIDICIProfile (CharonMIDI14)

- (instancetype)initWithData:(NSData *)data
{
    if (!data)
        return nil;
    NSString *name = nil;
    const UInt8 *bytes = data.bytes;
    if (data.length >= 5 && bytes[0] == 0x7E)
        name = [NSString stringWithFormat:@"Standard Profile Bank 0x%02X Number 0x%02X, Version: 0x%02X Level: 0x%02X",
                bytes[1], bytes[2], bytes[3], bytes[4]];
    return [self initWithData:data name:name];
}

@end

@implementation MIDICIProfileState (CharonMIDI14)

- (instancetype)initWithEnabledProfiles:(NSArray<MIDICIProfile *> *)enabled disabledProfiles:(NSArray<MIDICIProfile *> *)disabled
{
    return [self initWithChannel:0 enabledProfiles:enabled disabledProfiles:disabled];
}

@end

@implementation MIDICISession (CharonMIDI14)

// No MIDI-CI transport: the profile is not sent, so the answer is NO, as for enable and disable.
- (BOOL)sendProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData
{
    charon_ci_inert(__PRETTY_FUNCTION__);
    return NO;
}

@end

@implementation MIDICIDiscoveredNode {
    MIDIEntityRef _destination;
    MIDICIDeviceInfo *_deviceInfo;
    BOOL _supportsProfiles;
    BOOL _supportsProperties;
    NSNumber *_maximumSysExSize;
}

- (MIDIEntityRef)destination { return _destination; }
- (MIDICIDeviceInfo *)deviceInfo { return _deviceInfo; }
- (BOOL)supportsProfiles { return _supportsProfiles; }
- (BOOL)supportsProperties { return _supportsProperties; }
- (NSNumber *)maximumSysExSize { return _maximumSysExSize; }

@end

@implementation MIDICIDiscoveryManager

+ (MIDICIDiscoveryManager *)sharedInstance
{
    static MIDICIDiscoveryManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [[MIDICIDiscoveryManager alloc] init];
    });
    return manager;
}

// Measured: the handler is never called when the discovery's client is refused, which is the answer this port gives on
// every run, as it has no MIDI-CI transport to discover through.
- (void)discoverWithHandler:(MIDICIDiscoveryResponseBlock)completedHandler
{
    charon_ci_inert(__PRETTY_FUNCTION__);
}

@end

@implementation MIDICIResponder {
    NSArray<MIDICIInitiatiorMUID> *_initiators;
    id<MIDICIProfileResponderDelegate> _profileDelegate;
    MIDICIDeviceInfo *_deviceInfo;
}

- (instancetype)initWithDeviceInfo:(MIDICIDeviceInfo *)deviceInfo profileDelegate:(id<MIDICIProfileResponderDelegate>)delegate
                     profileStates:(MIDICIProfileStateList *)profileList supportProperties:(BOOL)propertiesSupported
{
    if (!delegate || !deviceInfo)
        return nil;
    self = [super init];
    if (self) {
        _deviceInfo = deviceInfo;
        _profileDelegate = delegate;
        _initiators = @[];
    }
    return self;
}

- (NSArray<MIDICIInitiatiorMUID> *)initiators { return _initiators; }
- (id<MIDICIProfileResponderDelegate>)profileDelegate { return _profileDelegate; }
- (MIDICIDeviceInfo *)deviceInfo { return _deviceInfo; }

// No MIDI-CI transport: no initiator connects to the responder, and no profile is notified or sent.
- (BOOL)notifyProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel isEnabled:(BOOL)enabledState { charon_ci_inert(__PRETTY_FUNCTION__); return NO; }
- (BOOL)sendProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData { charon_ci_inert(__PRETTY_FUNCTION__); return NO; }
- (BOOL)start { charon_ci_inert(__PRETTY_FUNCTION__); return NO; }
- (void)stop { }

@end

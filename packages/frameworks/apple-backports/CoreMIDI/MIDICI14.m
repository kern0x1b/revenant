#import "RevenantMIDICI.h"

void revenant_ci_inert(const char * _Nonnull action)
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
    NSLog(@"revenant: %s does nothing: this port has no MIDI-CI transport (facts/CoreMIDI/MIDICI.md)", action);
}

@implementation MIDICIProfile (RevenantMIDI14)

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

@implementation MIDICIProfileState (RevenantMIDI14)

- (instancetype)initWithEnabledProfiles:(NSArray<MIDICIProfile *> *)enabled disabledProfiles:(NSArray<MIDICIProfile *> *)disabled
{
    return [self initWithChannel:0 enabledProfiles:enabled disabledProfiles:disabled];
}

@end

@implementation MIDICISession (RevenantMIDI14)

- (BOOL)sendProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData
{
    revenant_ci_inert(__PRETTY_FUNCTION__);
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

- (void)discoverWithHandler:(MIDICIDiscoveryResponseBlock)completedHandler
{
    revenant_ci_inert(__PRETTY_FUNCTION__);
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

- (BOOL)notifyProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel isEnabled:(BOOL)enabledState { revenant_ci_inert(__PRETTY_FUNCTION__); return NO; }
- (BOOL)sendProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData { revenant_ci_inert(__PRETTY_FUNCTION__); return NO; }
- (BOOL)start { revenant_ci_inert(__PRETTY_FUNCTION__); return NO; }
- (void)stop { }

@end

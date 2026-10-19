#import "CharonMIDICI.h"

@implementation MIDICIProfile {
    NSString *_name;
    NSData *_profileID;
}

- (instancetype)initWithData:(NSData *)data name:(NSString *)inName
{
    if (!data)
        return nil;
    self = [super init];
    if (self) {
        _profileID = [data copy];
        _name = [inName copy];
    }
    return self;
}

- (NSString *)name { return _name; }
- (NSData *)profileID { return _profileID; }

@end

@implementation MIDICIProfileState {
    MIDIChannelNumber _midiChannel;
    NSArray<MIDICIProfile *> *_enabledProfiles;
    NSArray<MIDICIProfile *> *_disabledProfiles;
}

- (instancetype)initWithChannel:(MIDIChannelNumber)midiChannelNum enabledProfiles:(NSArray<MIDICIProfile *> *)enabled
               disabledProfiles:(NSArray<MIDICIProfile *> *)disabled
{
    self = [super init];
    if (self) {
        _midiChannel = midiChannelNum;
        _enabledProfiles = [enabled copy];
        _disabledProfiles = [disabled copy];
    }
    return self;
}

- (MIDIChannelNumber)midiChannel { return _midiChannel; }
- (NSArray<MIDICIProfile *> *)enabledProfiles { return _enabledProfiles; }
- (NSArray<MIDICIProfile *> *)disabledProfiles { return _disabledProfiles; }

@end

@implementation MIDICISession {
    MIDICIDiscoveredNode *_node;
    MIDICISessionDisconnectBlock _disconnectHandler;
    MIDICIProfileChangedBlock _profileChangedCallback;
    MIDICIProfileSpecificDataBlock _profileSpecificDataHandler;
}

@synthesize profileChangedCallback = _profileChangedCallback;
@synthesize profileSpecificDataHandler = _profileSpecificDataHandler;

- (instancetype)initWithDiscoveredNode:(MIDICIDiscoveredNode *)discoveredNode dataReadyHandler:(void (^)(void))handler
                     disconnectHandler:(MIDICISessionDisconnectBlock)disconnectHandler
{
    if (!discoveredNode)
        return nil;
    self = [super init];
    if (self) {
        _node = discoveredNode;
        _disconnectHandler = [disconnectHandler copy];
    }
    return self;
}

- (MIDIEntityRef)midiDestination { return _node.destination; }
- (BOOL)supportsProfileCapability { return _node.supportsProfiles; }
- (BOOL)supportsPropertyCapability { return _node.supportsProperties; }
- (MIDICIDeviceInfo *)deviceInfo { return _node.deviceInfo; }
- (NSNumber *)maxSysExSize { return _node.maximumSysExSize; }
- (NSNumber *)maxPropertyRequests { return @0; }

- (MIDICIProfileState *)profileStateForChannel:(MIDIChannelNumber)channel
{
    return [[MIDICIProfileState alloc] initWithChannel:channel enabledProfiles:@[] disabledProfiles:@[]];
}

- (BOOL)enableProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel error:(NSError **)outError { charon_ci_inert(__PRETTY_FUNCTION__); return NO; }
- (BOOL)disableProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel error:(NSError **)outError { charon_ci_inert(__PRETTY_FUNCTION__); return NO; }

@end

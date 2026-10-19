#import <Foundation/Foundation.h>
#import "CharonCoreMIDI.h"
#import "CharonMIDICI.h"
#import "CharonMIDIUMP18.h"

#include <pthread.h>

static MIDIClientRef charon_client(OSStatus *outStatus)
{
    static MIDIClientRef client = 0;
    static OSStatus lastRefusal = noErr;
    static pthread_mutex_t lock = PTHREAD_MUTEX_INITIALIZER;
    OSStatus status = noErr;
    pthread_mutex_lock(&lock);
    if (client == 0) {
        MIDIClientRef made = 0;
        status = MIDIClientCreate(CFSTR("charon-ump"), NULL, NULL, &made);
        if (status == noErr) {
            client = made;
        } else if (status != lastRefusal) {
            lastRefusal = status;
            NSLog(@"charon: the release would not make the MIDI client of the UMP endpoints (status %d); an endpoint cannot be made", (int)status);
        }
    }
    MIDIClientRef result = client;
    pthread_mutex_unlock(&lock);
    *outStatus = status;
    return result;
}

static NSMutableArray *charon_endpoints(void)
{
    static NSMutableArray *endpoints;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        endpoints = [NSMutableArray array];
    });
    return endpoints;
}

@implementation MIDI2DeviceInfo {
    MIDI2DeviceManufacturer _manufacturerID;
    MIDIUInteger14 _family;
    MIDIUInteger14 _modelNumber;
    MIDI2DeviceRevisionLevel _revisionLevel;
}

- (instancetype)initWithManufacturerID:(MIDI2DeviceManufacturer)manufacturerID family:(MIDIUInteger14)family
                           modelNumber:(MIDIUInteger14)modelNumber revisionLevel:(MIDI2DeviceRevisionLevel)revisionLevel
{
    self = [super init];
    if (self) {
        _manufacturerID = manufacturerID;
        _family = family;
        _modelNumber = modelNumber;
        _revisionLevel = revisionLevel;
    }
    return self;
}

- (MIDI2DeviceManufacturer)manufacturerID { return _manufacturerID; }
- (MIDIUInteger14)family { return _family; }
- (MIDIUInteger14)modelNumber { return _modelNumber; }
- (MIDI2DeviceRevisionLevel)revisionLevel { return _revisionLevel; }

@end

@interface MIDIUMPMutableFunctionBlock ()
- (void)charon_registeredWith:(MIDIUMPEndpoint *)endpoint;
- (void)charon_setFunctionBlockID:(MIDIUMPFunctionBlockID)identifier;
@end

@implementation MIDIUMPFunctionBlock {
@protected
    NSString *_name;
    MIDIUMPFunctionBlockID _functionBlockID;
    MIDIUMPFunctionBlockDirection _direction;
    MIDIUMPGroupNumber _firstGroup;
    MIDIUInteger7 _totalGroupsSpanned;
    UInt8 _maxSysEx8Streams;
    MIDIUMPFunctionBlockMIDI1Info _MIDI1Info;
    MIDIUMPFunctionBlockUIHint _UIHint;
    BOOL _isEnabled;
}

- (NSString *)name { return _name; }
- (MIDIUMPFunctionBlockID)functionBlockID { return _functionBlockID; }
- (MIDIUMPFunctionBlockDirection)direction { return _direction; }
- (MIDIUMPGroupNumber)firstGroup { return _firstGroup; }
- (MIDIUInteger7)totalGroupsSpanned { return _totalGroupsSpanned; }
- (UInt8)maxSysEx8Streams { return _maxSysEx8Streams; }
- (MIDIUMPFunctionBlockMIDI1Info)MIDI1Info { return _MIDI1Info; }
- (MIDIUMPFunctionBlockUIHint)UIHint { return _UIHint; }
- (BOOL)isEnabled { return _isEnabled; }
- (MIDIUMPEndpoint *)UMPEndpoint { return nil; }
- (MIDICIDevice *)midiCIDevice { return nil; }

@end

@implementation MIDIUMPMutableFunctionBlock {
    __weak MIDIUMPEndpoint *_endpoint;
}

- (instancetype)initWithName:(NSString *)name direction:(MIDIUMPFunctionBlockDirection)direction firstGroup:(MIDIUMPGroupNumber)firstGroup
          totalGroupsSpanned:(MIDIUInteger7)totalGroupsSpanned maxSysEx8Streams:(MIDIUInteger7)maxSysEx8Streams
                    MIDI1Info:(MIDIUMPFunctionBlockMIDI1Info)MIDI1Info UIHint:(MIDIUMPFunctionBlockUIHint)UIHint
                   isEnabled:(BOOL)isEnabled
{
    self = [super init];
    if (self) {
        _name = [name copy];
        _functionBlockID = 0;
        _direction = direction;
        _firstGroup = firstGroup;
        _totalGroupsSpanned = totalGroupsSpanned;
        _maxSysEx8Streams = maxSysEx8Streams;
        _MIDI1Info = MIDI1Info;
        _UIHint = UIHint;
        _isEnabled = isEnabled;
    }
    return self;
}

- (MIDIUMPEndpoint *)UMPEndpoint { return _endpoint; }

- (BOOL)setEnabled:(BOOL)isEnabled error:(NSError **)error
{
    if (!_endpoint)
        return NO;
    _isEnabled = isEnabled;
    return YES;
}

- (BOOL)setName:(NSString *)name error:(NSError **)error
{
    if (!_endpoint)
        return NO;
    _name = [name copy];
    return YES;
}

- (BOOL)reconfigureWithFirstGroup:(MIDIUMPGroupNumber)firstGroup direction:(MIDIUMPFunctionBlockDirection)direction
                        MIDI1Info:(MIDIUMPFunctionBlockMIDI1Info)MIDI1Info UIHint:(MIDIUMPFunctionBlockUIHint)UIHint error:(NSError **)error
{
    if (!_endpoint)
        return NO;
    _firstGroup = firstGroup;
    _direction = direction;
    _MIDI1Info = MIDI1Info;
    _UIHint = UIHint;
    return YES;
}

- (void)charon_registeredWith:(MIDIUMPEndpoint *)endpoint
{
    _endpoint = endpoint;
}

- (void)charon_setFunctionBlockID:(MIDIUMPFunctionBlockID)identifier
{
    _functionBlockID = identifier;
}

@end

@implementation MIDIUMPEndpoint {
@protected
    BOOL _hasStaticFunctionBlocks;
    NSString *_name;
    MIDIProtocolID _MIDIProtocol;
    MIDIEndpointRef _MIDIDestination;
    MIDIEndpointRef _MIDISource;
    MIDI2DeviceInfo *_deviceInfo;
    NSString *_productInstanceID;
    NSArray *_functionBlocks;
}

- (NSString *)name { return _name; }
- (MIDIProtocolID)MIDIProtocol { return _MIDIProtocol; }
- (MIDIUMPProtocolOptions)supportedMIDIProtocols
{
    return _MIDIProtocol == kMIDIProtocol_2_0 ? (kMIDIUMPProtocolOptionsMIDI1 | kMIDIUMPProtocolOptionsMIDI2) : kMIDIUMPProtocolOptionsMIDI1;
}
- (MIDIEndpointRef)MIDIDestination { return _MIDIDestination; }
- (MIDIEndpointRef)MIDISource { return _MIDISource; }
- (MIDI2DeviceInfo *)deviceInfo { return _deviceInfo; }
- (NSString *)productInstanceID { return _productInstanceID; }
- (BOOL)hasStaticFunctionBlocks { return _hasStaticFunctionBlocks; }
- (BOOL)hasJRTSReceiveCapability { return NO; }
- (BOOL)hasJRTSTransmitCapability { return NO; }
- (MIDIUMPCIObjectBackingType)endpointType { return kMIDIUMPCIObjectBackingTypeVirtual; }
- (NSArray<MIDIUMPFunctionBlock *> *)functionBlocks { return _functionBlocks; }
- (void)setFunctionBlocks:(NSArray<MIDIUMPFunctionBlock *> *)functionBlocks { _functionBlocks = [functionBlocks copy]; }

@end

@implementation MIDIUMPMutableEndpoint {
    BOOL _enabled;
    NSArray *_mutableBlocks;
    MIDIReceiveBlock _callback;
}

- (instancetype)initWithName:(NSString *)name deviceInfo:(MIDI2DeviceInfo *)deviceInfo productInstanceID:(NSString *)productInstanceID
                MIDIProtocol:(MIDIProtocolID)MIDIProtocol destinationCallback:(MIDIReceiveBlock)destinationCallback
{
    if (MIDIProtocol != kMIDIProtocol_1_0 && MIDIProtocol != kMIDIProtocol_2_0)
        return nil;
    self = [super init];
    if (!self)
        return nil;
    _name = [name copy];
    _deviceInfo = deviceInfo;
    _productInstanceID = [productInstanceID copy];
    _MIDIProtocol = MIDIProtocol;
    _callback = [destinationCallback copy];
    _enabled = NO;
    _mutableBlocks = @[];
    _functionBlocks = @[];
    MIDIEndpointRef destination = 0, source = 0;
    OSStatus status = noErr;
    MIDIClientRef client = charon_client(&status);
    if (status != noErr)
        return nil;
    status = CharonMIDIDestination(client, (__bridge CFStringRef)name, MIDIProtocol, &destination, _callback);
    if (status != noErr)
        return nil;
    status = CharonMIDISource(client, (__bridge CFStringRef)name, MIDIProtocol, &source);
    if (status != noErr) {
        if (MIDIEndpointDispose(destination) != noErr)
            NSLog(@"charon: the destination of a UMP endpoint whose source was refused could not be disposed");
        return nil;
    }
    _MIDIDestination = destination;
    _MIDISource = source;
    @synchronized (charon_endpoints()) {
        [charon_endpoints() addObject:self];
    }
    return self;
}

- (NSArray<MIDIUMPMutableFunctionBlock *> *)mutableFunctionBlocks { return _mutableBlocks; }
- (void)setMutableFunctionBlocks:(NSArray<MIDIUMPMutableFunctionBlock *> *)mutableFunctionBlocks { _mutableBlocks = [mutableFunctionBlocks copy]; }
- (BOOL)isEnabled { return _enabled; }

- (BOOL)setName:(NSString *)name error:(NSError **)error
{
    OSStatus status = MIDIObjectSetStringProperty(_MIDIDestination, kMIDIPropertyName, (__bridge CFStringRef)name);
    if (status == noErr)
        status = MIDIObjectSetStringProperty(_MIDISource, kMIDIPropertyName, (__bridge CFStringRef)name);
    if (status != noErr) {
        if (error)
            *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        return NO;
    }
    _name = [name copy];
    return YES;
}

- (BOOL)registerFunctionBlocks:(NSArray<MIDIUMPMutableFunctionBlock *> *)functionBlocks markAsStatic:(BOOL)markAsStatic error:(NSError **)error
{
    MIDIUMPFunctionBlockID identifier = 1;
    for (MIDIUMPMutableFunctionBlock *block in functionBlocks) {
        [block charon_registeredWith:self];
        [block charon_setFunctionBlockID:identifier++];
    }
    _mutableBlocks = [functionBlocks copy];
    _functionBlocks = [functionBlocks copy];
    _hasStaticFunctionBlocks = markAsStatic;
    return YES;
}

- (BOOL)setEnabled:(BOOL)isEnabled error:(NSError **)error
{
    _enabled = isEnabled;
    return YES;
}

@end

@implementation MIDIUMPEndpointManager

+ (MIDIUMPEndpointManager *)sharedInstance
{
    static MIDIUMPEndpointManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [[MIDIUMPEndpointManager alloc] init];
    });
    return manager;
}

- (NSArray<MIDIUMPEndpoint *> *)UMPEndpoints
{
    @synchronized (charon_endpoints()) {
        return [charon_endpoints() copy];
    }
}

@end

@implementation MIDICIDevice

- (MIDI2DeviceInfo *)deviceInfo { return nil; }
- (MIDICIMUID)MUID { return 0; }
- (BOOL)supportsProtocolNegotiation { return NO; }
- (BOOL)supportsProfileConfiguration { return NO; }
- (BOOL)supportsPropertyExchange { return NO; }
- (BOOL)supportsProcessInquiry { return NO; }
- (NSUInteger)maxSysExSize { return 0; }
- (NSUInteger)maxPropertyExchangeRequests { return 0; }
- (MIDICIDeviceType)deviceType { return kMIDICIDeviceTypeUnknown; }
- (NSArray<MIDIUMPCIProfile *> *)profiles { return @[]; }

@end

@implementation MIDIUMPCIProfile

- (NSString *)name { return nil; }
- (MIDICIProfileID)profileID { return (MIDICIProfileID){{0, 0, 0, 0, 0}}; }
- (MIDICIProfileType)profileType { return kMIDICIProfileTypeSingleChannel; }
- (MIDIUMPGroupNumber)groupOffset { return 0; }
- (MIDIChannelNumber)firstChannel { return 0; }
- (MIDIUInteger14)enabledChannelCount { return 0; }
- (MIDIUInteger14)totalChannelCount { return 0; }
- (BOOL)isEnabled { return NO; }

- (BOOL)setProfileState:(BOOL)isEnabled enabledChannelCount:(MIDIUInteger14)enabledChannelCount error:(NSError **)error
{
    charon_ci_inert(__PRETTY_FUNCTION__);
    return NO;
}

@end

@implementation MIDICIDeviceManager

+ (MIDICIDeviceManager *)sharedInstance
{
    static MIDICIDeviceManager *manager;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [[MIDICIDeviceManager alloc] init];
    });
    return manager;
}

- (NSArray<MIDICIDevice *> *)discoveredCIDevices { return @[]; }

@end

#ifndef CharonMIDIUMP18_h
#define CharonMIDIUMP18_h

#import <Foundation/Foundation.h>
#import <CoreMIDI/MIDIServices.h>
#import <CoreMIDI/MIDISetup.h>

typedef UInt8 MIDIUInteger4;
typedef UInt8 MIDIUInteger7;
typedef UInt16 MIDIUInteger14;
typedef UInt32 MIDIUInteger28;
typedef MIDIUInteger4 MIDIUMPGroupNumber;
typedef MIDIUInteger7 MIDIUMPFunctionBlockID;
typedef MIDIUInteger28 MIDICIMUID;
typedef uint8_t MIDIChannelNumber;

typedef struct {
    Byte sysExIDByte[3];
} MIDI2DeviceManufacturer;

typedef struct {
    Byte revisionLevel[4];
} MIDI2DeviceRevisionLevel;

typedef struct {
    Byte bytes[5];
} MIDICIProfileID;

typedef NS_ENUM(UInt8, MIDICIDeviceType) {
    kMIDICIDeviceTypeUnknown = 0,
    kMIDICIDeviceTypeLegacyMIDI1,
    kMIDICIDeviceTypeVirtual,
    kMIDICIDeviceTypeUSBMIDI
};

typedef NS_ENUM(UInt8, MIDICIProfileType) {
    kMIDICIProfileTypeSingleChannel = 1,
    kMIDICIProfileTypeGroup = 2,
    kMIDICIProfileTypeFunctionBlock = 3,
    kMIDICIProfileTypeMultichannel = 4
};

typedef NS_ENUM(UInt8, MIDIUMPCIObjectBackingType) {
    kMIDIUMPCIObjectBackingTypeUnknown = 0,
    kMIDIUMPCIObjectBackingTypeVirtual,
    kMIDIUMPCIObjectBackingTypeDriverDevice,
    kMIDIUMPCIObjectBackingTypeUSBMIDI
};

typedef NS_OPTIONS(MIDIUInteger4, MIDIUMPProtocolOptions) {
    kMIDIUMPProtocolOptionsMIDI1 = 1,
    kMIDIUMPProtocolOptionsMIDI2 = 1 << 1
};

typedef NS_ENUM(SInt32, MIDIUMPFunctionBlockMIDI1Info) {
    kMIDIUMPFunctionBlockMIDI1InfoNotMIDI1 = 0,
    kMIDIUMPFunctionBlockMIDI1InfoUnrestrictedBandwidth = 1,
    kMIDIUMPFunctionBlockMIDI1InfoRestrictedBandwidth = 2
};

typedef NS_ENUM(SInt32, MIDIUMPFunctionBlockUIHint) {
    kMIDIUMPFunctionBlockUIHintUnknown = 0,
    kMIDIUMPFunctionBlockUIHintReceiver = 1,
    kMIDIUMPFunctionBlockUIHintSender = 2,
    kMIDIUMPFunctionBlockUIHintSenderReceiver = 3
};

typedef NS_ENUM(SInt32, MIDIUMPFunctionBlockDirection) {
    kMIDIUMPFunctionBlockDirectionUnknown = 0,
    kMIDIUMPFunctionBlockDirectionInput = 1,
    kMIDIUMPFunctionBlockDirectionOutput = 2,
    kMIDIUMPFunctionBlockDirectionBidirectional = 3
};

@class MIDI2DeviceInfo, MIDIUMPEndpoint, MIDIUMPFunctionBlock, MIDICIDevice, MIDIUMPCIProfile;

NS_ASSUME_NONNULL_BEGIN

@interface MIDI2DeviceInfo : NSObject
@property (nonatomic, readonly) MIDI2DeviceManufacturer manufacturerID;
@property (nonatomic, readonly) MIDIUInteger14 family;
@property (nonatomic, readonly) MIDIUInteger14 modelNumber;
@property (nonatomic, readonly) MIDI2DeviceRevisionLevel revisionLevel;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithManufacturerID:(MIDI2DeviceManufacturer)manufacturerID
                                family:(MIDIUInteger14)family
                           modelNumber:(MIDIUInteger14)modelNumber
                         revisionLevel:(MIDI2DeviceRevisionLevel)revisionLevel;
@end

@interface MIDIUMPFunctionBlock : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) MIDIUMPFunctionBlockID functionBlockID;
@property (nonatomic, readonly) MIDIUMPFunctionBlockDirection direction;
@property (nonatomic, readonly) MIDIUMPGroupNumber firstGroup;
@property (nonatomic, readonly) MIDIUInteger7 totalGroupsSpanned;
@property (nonatomic, readonly) UInt8 maxSysEx8Streams;
@property (nonatomic, readonly) MIDIUMPFunctionBlockMIDI1Info MIDI1Info;
@property (nonatomic, readonly) MIDIUMPFunctionBlockUIHint UIHint;
@property (nonatomic, readonly, weak, nullable) MIDIUMPEndpoint *UMPEndpoint;
@property (nonatomic, readonly, weak, nullable) MIDICIDevice *midiCIDevice;
@property (nonatomic, readonly) BOOL isEnabled;
@end

@interface MIDIUMPMutableFunctionBlock : MIDIUMPFunctionBlock
@property (nonatomic, readonly, weak, nullable) MIDIUMPEndpoint *UMPEndpoint;
- (instancetype _Nullable)initWithName:(NSString *)name
                             direction:(MIDIUMPFunctionBlockDirection)direction
                            firstGroup:(MIDIUMPGroupNumber)firstGroup
                    totalGroupsSpanned:(MIDIUInteger7)totalGroupsSpanned
                      maxSysEx8Streams:(MIDIUInteger7)maxSysEx8Streams
                              MIDI1Info:(MIDIUMPFunctionBlockMIDI1Info)MIDI1Info
                                 UIHint:(MIDIUMPFunctionBlockUIHint)UIHint
                              isEnabled:(BOOL)isEnabled;
- (BOOL)setEnabled:(BOOL)isEnabled error:(NSError *_Nullable *_Nullable)error;
- (BOOL)setName:(NSString *)name error:(NSError *_Nullable *_Nullable)error;
- (BOOL)reconfigureWithFirstGroup:(MIDIUMPGroupNumber)firstGroup
                        direction:(MIDIUMPFunctionBlockDirection)direction
                        MIDI1Info:(MIDIUMPFunctionBlockMIDI1Info)MIDI1Info
                           UIHint:(MIDIUMPFunctionBlockUIHint)UIHint
                            error:(NSError *_Nullable *_Nullable)error;
@end

@interface MIDIUMPEndpoint : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) MIDIProtocolID MIDIProtocol;
@property (nonatomic, readonly) MIDIUMPProtocolOptions supportedMIDIProtocols;
@property (nonatomic, readonly) MIDIEndpointRef MIDIDestination;
@property (nonatomic, readonly) MIDIEndpointRef MIDISource;
@property (nonatomic, readonly) MIDI2DeviceInfo *deviceInfo;
@property (nonatomic, readonly) NSString *productInstanceID;
@property (nonatomic, readonly) BOOL hasStaticFunctionBlocks;
@property (nonatomic, readonly) BOOL hasJRTSReceiveCapability;
@property (nonatomic, readonly) BOOL hasJRTSTransmitCapability;
@property (nonatomic, readonly) MIDIUMPCIObjectBackingType endpointType;
@property (nonatomic, copy) NSArray<MIDIUMPFunctionBlock *> *functionBlocks;
@end

@interface MIDIUMPMutableEndpoint : MIDIUMPEndpoint
@property (nonatomic, copy) NSArray<MIDIUMPMutableFunctionBlock *> *mutableFunctionBlocks;
@property (nonatomic, readonly) BOOL isEnabled;
- (instancetype _Nullable)initWithName:(NSString *)name
                            deviceInfo:(MIDI2DeviceInfo *)deviceInfo
                     productInstanceID:(NSString *)productInstanceID
                          MIDIProtocol:(MIDIProtocolID)MIDIProtocol
                   destinationCallback:(MIDIReceiveBlock)destinationCallback;
- (BOOL)setName:(NSString *)name error:(NSError *_Nullable *_Nullable)error;
- (BOOL)registerFunctionBlocks:(NSArray<MIDIUMPMutableFunctionBlock *> *)functionBlocks
                  markAsStatic:(BOOL)markAsStatic
                         error:(NSError *_Nullable *_Nullable)error;
- (BOOL)setEnabled:(BOOL)isEnabled error:(NSError *_Nullable *_Nullable)error;
@end

@interface MIDIUMPEndpointManager : NSObject
@property (class, nonatomic, readonly) MIDIUMPEndpointManager *sharedInstance;
@property (nonatomic, readonly, copy) NSArray<MIDIUMPEndpoint *> *UMPEndpoints;
@end

@interface MIDICIDevice : NSObject
@property (nonatomic, readonly) MIDI2DeviceInfo *deviceInfo;
@property (nonatomic, readonly) MIDICIMUID MUID;
@property (nonatomic, readonly) BOOL supportsProtocolNegotiation;
@property (nonatomic, readonly) BOOL supportsProfileConfiguration;
@property (nonatomic, readonly) BOOL supportsPropertyExchange;
@property (nonatomic, readonly) BOOL supportsProcessInquiry;
@property (nonatomic, readonly) NSUInteger maxSysExSize;
@property (nonatomic, readonly) NSUInteger maxPropertyExchangeRequests;
@property (nonatomic, readonly) MIDICIDeviceType deviceType;
@property (nonatomic, readonly) NSArray<MIDIUMPCIProfile *> *profiles;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface MIDIUMPCIProfile : NSObject
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) MIDICIProfileID profileID;
@property (nonatomic, readonly) MIDICIProfileType profileType;
@property (nonatomic, readonly) MIDIUMPGroupNumber groupOffset;
@property (nonatomic, readonly) MIDIChannelNumber firstChannel;
@property (nonatomic, readonly) MIDIUInteger14 enabledChannelCount;
@property (nonatomic, readonly) MIDIUInteger14 totalChannelCount;
@property (nonatomic, readonly) BOOL isEnabled;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)setProfileState:(BOOL)isEnabled enabledChannelCount:(MIDIUInteger14)enabledChannelCount error:(NSError *_Nullable *_Nullable)error;
@end

@interface MIDICIDeviceManager : NSObject
@property (class, nonatomic, readonly) MIDICIDeviceManager *sharedInstance;
@property (nonatomic, readonly, copy) NSArray<MIDICIDevice *> *discoveredCIDevices;
@end

NS_ASSUME_NONNULL_END

#endif

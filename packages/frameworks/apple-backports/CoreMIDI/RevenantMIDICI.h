#ifndef RevenantMIDICI_h
#define RevenantMIDICI_h

#import <Foundation/Foundation.h>
#import <CoreMIDI/MIDIServices.h>

#import "RevenantMIDIUMP18.h"
#import "RevenantCoreMIDIProtocols.h"

@class MIDICIDeviceInfo, MIDICIProfile, MIDICIProfileState, MIDICISession, MIDICIDiscoveredNode;

NS_ASSUME_NONNULL_BEGIN

typedef NSArray<MIDICIProfileState *> MIDICIProfileStateList;

typedef void (^MIDICISessionDisconnectBlock)(MIDICISession *session, NSError *error);
typedef void (^MIDICIProfileChangedBlock)(MIDICISession *session, MIDIChannelNumber channel, MIDICIProfile *profile, BOOL enabled);
typedef void (^MIDICIProfileSpecificDataBlock)(MIDICISession *session, MIDIChannelNumber channel, MIDICIProfile *profile, NSData *profileSpecificData);
typedef void (^MIDICIDiscoveryResponseBlock)(NSArray<MIDICIDiscoveredNode *> *discoveredNodes);

@interface MIDICIDeviceInfo : NSObject
@property (nonatomic, readonly) NSData *manufacturerID;
@property (nonatomic, readonly) NSData *family;
@property (nonatomic, readonly) NSData *modelNumber;
@property (nonatomic, readonly) NSData *revisionLevel;
@property (nonatomic, readonly) MIDIEntityRef midiDestination;
- (instancetype _Nullable)initWithDestination:(MIDIEntityRef)midiDestination manufacturer:(NSData *)manufacturer
                                       family:(NSData *)family model:(NSData *)modelNumber revision:(NSData *)revisionLevel;
@end

@interface MIDICIProfile : NSObject
@property (nonatomic, readonly, nullable) NSString *name;
@property (nonatomic, readonly) NSData *profileID;
- (instancetype _Nullable)initWithData:(NSData *)data name:(NSString *)inName;
@end

@interface MIDICIProfile (RevenantMIDI14)
- (instancetype _Nullable)initWithData:(NSData *)data;
@end

@interface MIDICIProfileState : NSObject
@property (nonatomic, readonly) MIDIChannelNumber midiChannel;
@property (nonatomic, readonly) NSArray<MIDICIProfile *> *enabledProfiles;
@property (nonatomic, readonly) NSArray<MIDICIProfile *> *disabledProfiles;
- (instancetype _Nullable)initWithChannel:(MIDIChannelNumber)midiChannelNum enabledProfiles:(NSArray<MIDICIProfile *> *)enabled
                         disabledProfiles:(NSArray<MIDICIProfile *> *)disabled;
@end

@interface MIDICIProfileState (RevenantMIDI14)
- (instancetype _Nullable)initWithEnabledProfiles:(NSArray<MIDICIProfile *> *)enabled disabledProfiles:(NSArray<MIDICIProfile *> *)disabled;
@end

@interface MIDICIDiscoveredNode : NSObject
@property (nonatomic, readonly) MIDIEntityRef destination;
@property (nonatomic, readonly) MIDICIDeviceInfo *deviceInfo;
@property (nonatomic, readonly) BOOL supportsProfiles;
@property (nonatomic, readonly) BOOL supportsProperties;
@property (nonatomic, readonly) NSNumber *maximumSysExSize;
@end

@interface MIDICISession : NSObject
@property (nonatomic, readonly) MIDIEntityRef midiDestination;
@property (nonatomic, readonly) BOOL supportsProfileCapability;
@property (nonatomic, readonly) BOOL supportsPropertyCapability;
@property (nonatomic, readonly) MIDICIDeviceInfo *deviceInfo;
@property (nonatomic, readonly) NSNumber *maxSysExSize;
@property (nonatomic, readonly) NSNumber *maxPropertyRequests;
@property (nonatomic, copy, nullable) MIDICIProfileChangedBlock profileChangedCallback;
@property (nonatomic, copy, nullable) MIDICIProfileSpecificDataBlock profileSpecificDataHandler;
- (instancetype _Nullable)initWithDiscoveredNode:(MIDICIDiscoveredNode *)discoveredNode dataReadyHandler:(void (^)(void))handler
                               disconnectHandler:(MIDICISessionDisconnectBlock)disconnectHandler;
- (MIDICIProfileState *)profileStateForChannel:(MIDIChannelNumber)channel;
- (BOOL)enableProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel error:(NSError *_Nullable *_Nullable)outError;
- (BOOL)disableProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel error:(NSError *_Nullable *_Nullable)outError;
@end

@interface MIDICISession (RevenantMIDI14)
- (BOOL)sendProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData;
@end

@interface MIDICIDiscoveryManager : NSObject
+ (MIDICIDiscoveryManager *)sharedInstance;
- (void)discoverWithHandler:(MIDICIDiscoveryResponseBlock)completedHandler;
@end

@interface MIDICIResponder : NSObject
@property (nonatomic, readonly) NSArray<MIDICIInitiatiorMUID> *initiators;
@property (nonatomic, readonly, retain) id<MIDICIProfileResponderDelegate> profileDelegate;
@property (nonatomic, readonly) MIDICIDeviceInfo *deviceInfo;
- (instancetype _Nullable)initWithDeviceInfo:(MIDICIDeviceInfo *)deviceInfo profileDelegate:(id<MIDICIProfileResponderDelegate>)delegate
                               profileStates:(MIDICIProfileStateList *)profileList supportProperties:(BOOL)propertiesSupported;
- (BOOL)notifyProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel isEnabled:(BOOL)enabledState;
- (BOOL)sendProfile:(MIDICIProfile *)aProfile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData;
- (BOOL)start;
- (void)stop;
@end

NS_ASSUME_NONNULL_END

void revenant_ci_inert(const char * _Nonnull action);

#endif

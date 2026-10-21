#ifndef RevenantMIDICI_h
#define RevenantMIDICI_h

#import <Foundation/Foundation.h>
#import <CoreMIDI/MIDIServices.h>

#import "RevenantMIDIUMP18.h"
#import <CoreMIDI/MIDICapabilityInquiry.h>

@class MIDICIDeviceInfo, MIDICIProfile, MIDICIProfileState, MIDICISession, MIDICIDiscoveredNode;

NS_ASSUME_NONNULL_BEGIN

typedef NSArray<MIDICIProfileState *> MIDICIProfileStateList;

typedef void (^MIDICISessionDisconnectBlock)(MIDICISession *session, NSError *error);
typedef void (^MIDICIProfileChangedBlock)(MIDICISession *session, MIDIChannelNumber channel, MIDICIProfile *profile, BOOL enabled);
typedef void (^MIDICIProfileSpecificDataBlock)(MIDICISession *session, MIDIChannelNumber channel, MIDICIProfile *profile, NSData *profileSpecificData);
typedef void (^MIDICIDiscoveryResponseBlock)(NSArray<MIDICIDiscoveredNode *> *discoveredNodes);

@interface MIDICIProfile (RevenantMIDI14)
- (instancetype _Nullable)initWithData:(NSData *)data;
@end


@interface MIDICIProfileState (RevenantMIDI14)
- (instancetype _Nullable)initWithEnabledProfiles:(NSArray<MIDICIProfile *> *)enabled disabledProfiles:(NSArray<MIDICIProfile *> *)disabled;
@end

@interface MIDICISession (RevenantMIDI14)
- (BOOL)sendProfile:(MIDICIProfile *)profile onChannel:(MIDIChannelNumber)channel profileData:(NSData *)profileSpecificData;
@end

NS_ASSUME_NONNULL_END

void revenant_ci_inert(const char * _Nonnull action);

#endif

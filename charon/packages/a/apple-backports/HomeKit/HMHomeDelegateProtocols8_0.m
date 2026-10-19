#import <HomeKit/HomeKit.h>

@protocol HMHomeDelegate <NSObject>
@optional
- (void)homeDidUpdateName:(HMHome *)home;
- (void)homeDidUpdateAccessControlForCurrentUser:(HMHome *)home API_AVAILABLE(ios(11.0), watchos(4.0), tvos(11.0));
- (void)home:(HMHome *)home didAddAccessory:(HMAccessory *)accessory;
- (void)home:(HMHome *)home didRemoveAccessory:(HMAccessory *)accessory;
- (void)home:(HMHome *)home didAddUser:(HMUser *)user;
- (void)home:(HMHome *)home didRemoveUser:(HMUser *)user;
- (void)home:(HMHome *)home didUpdateRoom:(HMRoom *)room forAccessory:(HMAccessory *)accessory;
- (void)home:(HMHome *)home didAddRoom:(HMRoom *)room;
- (void)home:(HMHome *)home didRemoveRoom:(HMRoom *)room;
- (void)home:(HMHome *)home didUpdateNameForRoom:(HMRoom *)room;
- (void)home:(HMHome *)home didAddZone:(HMZone *)zone;
- (void)home:(HMHome *)home didRemoveZone:(HMZone *)zone;
- (void)home:(HMHome *)home didUpdateNameForZone:(HMZone *)zone;
- (void)home:(HMHome *)home didAddRoom:(HMRoom *)room toZone:(HMZone *)zone;
- (void)home:(HMHome *)home didRemoveRoom:(HMRoom *)room fromZone:(HMZone *)zone;
- (void)home:(HMHome *)home didAddServiceGroup:(HMServiceGroup *)group;
- (void)home:(HMHome *)home didRemoveServiceGroup:(HMServiceGroup *)group;
- (void)home:(HMHome *)home didUpdateNameForServiceGroup:(HMServiceGroup *)group;
- (void)home:(HMHome *)home didAddService:(HMService *)service toServiceGroup:(HMServiceGroup *)group;
- (void)home:(HMHome *)home didRemoveService:(HMService *)service fromServiceGroup:(HMServiceGroup *)group;
- (void)home:(HMHome *)home didAddActionSet:(HMActionSet *)actionSet;
- (void)home:(HMHome *)home didRemoveActionSet:(HMActionSet *)actionSet;
- (void)home:(HMHome *)home didUpdateNameForActionSet:(HMActionSet *)actionSet;
- (void)home:(HMHome *)home didUpdateActionsForActionSet:(HMActionSet *)actionSet;
- (void)home:(HMHome *)home didAddTrigger:(HMTrigger *)trigger;
- (void)home:(HMHome *)home didRemoveTrigger:(HMTrigger *)trigger;
- (void)home:(HMHome *)home didUpdateNameForTrigger:(HMTrigger *)trigger;
- (void)home:(HMHome *)home didUpdateTrigger:(HMTrigger *)trigger;
- (void)home:(HMHome *)home didUnblockAccessory:(HMAccessory *)accessory;
- (void)home:(HMHome *)home didEncounterError:(NSError *)error forAccessory:(HMAccessory *)accessory;
- (void)home:(HMHome *)home didUpdateHomeHubState:(HMHomeHubState)homeHubState API_AVAILABLE(ios(11.0), watchos(4.0), tvos(11.0));
- (void)homeDidUpdateSupportedFeatures:(HMHome *)home API_AVAILABLE(ios(13.2), watchos(6.1), tvos(13.2)) API_UNAVAILABLE(macos);
@end

@protocol HMHomeManagerDelegate <NSObject>
@optional
- (void)homeManager:(HMHomeManager *)manager didUpdateAuthorizationStatus:(HMHomeManagerAuthorizationStatus)status API_AVAILABLE(ios(13.0), watchos(6.0), tvos(13.0)) API_UNAVAILABLE(macos);
- (void)homeManagerDidUpdateHomes:(HMHomeManager *)manager;
- (void)homeManagerDidUpdatePrimaryHome:(HMHomeManager *)manager;
- (void)homeManager:(HMHomeManager *)manager didAddHome:(HMHome *)home;
- (void)homeManager:(HMHomeManager *)manager didRemoveHome:(HMHome *)home;
- (void)homeManager:(HMHomeManager *)manager didReceiveAddAccessoryRequest:(HMAddAccessoryRequest *)request API_DEPRECATED("No longer supported", ios(13.0, 15.0)) API_UNAVAILABLE(ios, macos, watchos, tvos, macCatalyst) NS_SWIFT_NAME(homeManager(_:didReceiveAddAccessoryRequest:));
@end

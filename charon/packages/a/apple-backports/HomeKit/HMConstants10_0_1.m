// The HomeKit string constants of iOS 10.0.1.
//
// **Where these values come from, and how to check them.** Every value below is a value a real
// HomeKit.framework holds, and the host's own HomeKit is on this machine, so each one is
// re-measurable today with three calls and no HomeKit source: `tools/corpus/host-probe.c` opens
// /System/Library/PrivateFrameworks/HomeKit.framework/Versions/A/HomeKit with dlopen, looks the
// symbol up with dlsym, and decodes the `NSString *const` it finds through CFStringGetCString,
// sized by the string's own CFStringGetLength so that a wrong address is a failed conversion
// rather than a plausible wrong answer. Measured for all 255 and recorded in
// coordination/corpus/ledger/constant-values-HomeKit.tsv: 255 asked, 255 exported by the host,
// 255 agreeing with the values below, 0 differing, 0 unreadable.
//
// The caches these were first read from (12.0, 16.0, 18.0) are named in facts/HomeKit/HMConstants.md.
//
// **The release in this file's name is a different measurement, by a different tool.** Which
// iOS release first exports a symbol is measured by `tools/release-split.lua`, which walks the
// real cache ladder, and the band machinery places an object by that measurement -- so the files
// are named for it and not for the release the 26.2 header annotates. For 63 of the framework's
// constants the two differ, the header is the later of the two, and facts/HomeKit/HMConstants.md
// lists every divergence.
//
// One release's API per object file, which is what the band machinery needs: nothing here
// arrived in any release but this one.

#import <Foundation/Foundation.h>

NSString *const HMAccessoryCategoryTypeIPCamera = @"C9EE63DB-2FF7-4514-826A-2FC2F0D4C9F0";
NSString *const HMAccessoryCategoryTypeVideoDoorbell = @"957A52E0-BE03-490C-8305-7B20C1CC17BA";
NSString *const HMActionSetTypeTriggerOwned = @"HMActionSetTypeTriggerOwned";
NSString *const HMCharacteristicMetadataUnitsMicrogramsPerCubicMeter = @"micrograms/m^3";
NSString *const HMCharacteristicMetadataUnitsPartsPerMillion = @"ppm";
NSString *const HMCharacteristicPropertyRequiresAuthorizationData = @"HMCharacteristicPropertyRequiresAuthorizationData";
NSString *const HMCharacteristicTypeDigitalZoom = @"0000011D-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeImageMirroring = @"0000011F-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeImageRotation = @"0000011E-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeMute = @"0000011A-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeNightVision = @"0000011B-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeOpticalZoom = @"0000011C-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSelectedStreamConfiguration = @"00000117-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSetupStreamEndpoint = @"00000118-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeStreamingStatus = @"00000120-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSupportedAudioStreamConfiguration = @"00000115-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSupportedRTPConfiguration = @"00000116-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSupportedVideoStreamConfiguration = @"00000114-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeVolume = @"00000119-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeCameraControl = @"00000111-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeCameraRTPStreamManagement = @"00000110-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeDoorbell = @"00000121-0000-1000-8000-0026BB765291";

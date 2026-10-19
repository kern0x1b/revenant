// The HomeKit string constants of iOS 12.0.
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

NSString *const HMAccessoryCategoryTypeFaucet = @"43CE6F7E-F7E8-44B4-80CE-5786F6E6CD47";
NSString *const HMAccessoryCategoryTypeShowerHead = @"39D2A5B4-F9A6-43F6-90E7-0019F0C0E99F";
NSString *const HMAccessoryCategoryTypeSprinkler = @"94D3FBD5-0A74-4EE4-BE1A-C97E82ADFA33";
NSString *const HMCharacteristicTypeActiveIdentifier = @"000000E7-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeInUse = @"000000D2-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeIsConfigured = @"000000D6-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeProgramMode = @"000000D1-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeRemainingDuration = @"000000D4-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSetDuration = @"000000D3-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeValveType = @"000000D5-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeFaucet = @"000000D7-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeIrrigationSystem = @"000000CF-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeValve = @"000000D0-0000-1000-8000-0026BB765291";

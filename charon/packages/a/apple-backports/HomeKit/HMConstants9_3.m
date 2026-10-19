// The HomeKit string constants of iOS 9.3.
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

NSString *const HMAccessoryCategoryTypeRangeExtender = @"8E33483E-2102-4BFE-9295-0A187D114188";
NSString *const HMCharacteristicMetadataUnitsLux = @"lux";
NSString *const HMCharacteristicPropertyHidden = @"HMCharacteristicPropertyHidden";

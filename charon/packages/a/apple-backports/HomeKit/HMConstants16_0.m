// The HomeKit string constants of iOS 16.0: the two television accessory categories the held iOS 16.0
// cache is the first to export. Their headers annotate iOS 18.0; the release that exports them is the
// one this file is named for, which is the measurement tools/release-split.lua makes. The other
// constants of the same header are in HMConstants13_4.m.
//
// **Where these values come from, and how to check them.** Every value below is a value a real
// HomeKit.framework holds, and the host's own HomeKit is on this machine, so each one is
// re-measurable today with three calls and no HomeKit source: `tools/corpus/host-probe.c` opens
// /System/Library/PrivateFrameworks/HomeKit.framework/Versions/A/HomeKit with dlopen, looks the
// symbol up with dlsym, and decodes the `NSString *const` it finds through CFStringGetCString,
// sized by the string's own CFStringGetLength so that a wrong address is a failed conversion
// rather than a plausible wrong answer. facts/HomeKit/HMConstants.md has the caches these were
// first read from and the divergences between the header and the measurement.
//
// One release's API per object file, which is what the band machinery needs: nothing here
// arrived in any release but this one.

#import <Foundation/Foundation.h>

NSString *const HMAccessoryCategoryTypeTelevisionSetTopBox = @"FB953A08-6CDD-44E0-B011-CFAC559A3CFB";
NSString *const HMAccessoryCategoryTypeTelevisionStreamingStick = @"B0C866C4-3E25-4F6A-8476-A8A3B579A86E";

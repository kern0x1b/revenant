// The HomeKit string constants of iOS 10.2.
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

NSString *const HMAccessoryCategoryTypeAirConditioner = @"18DDD63A-27F9-4341-B59B-759D3D114586";
NSString *const HMAccessoryCategoryTypeAirDehumidifier = @"1E15B639-DC98-41D4-A394-2E4A1D54AA3A";
NSString *const HMAccessoryCategoryTypeAirHeater = @"BF7036FD-93CF-49B5-954F-CD2B760D11DA";
NSString *const HMAccessoryCategoryTypeAirHumidifier = @"3FEB9075-C9AF-4629-ADBC-A853259C645A";
NSString *const HMAccessoryCategoryTypeAirPurifier = @"5510B997-D711-4636-870F-82BB61092B15";
NSString *const HMCharacteristicTypeActive = @"000000B0-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentAirPurifierState = @"000000A9-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentFanState = @"000000AF-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentHeaterCoolerState = @"000000B1-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentHumidifierDehumidifierState = @"000000B3-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentSlatState = @"000000AA-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentTilt = @"000000C1-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeDehumidifierThreshold = @"000000C9-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeFilterChangeIndication = @"000000AC-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeFilterLifeLevel = @"000000AB-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeFilterResetChangeIndication = @"000000AD-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeHumidifierThreshold = @"000000CA-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeLockPhysicalControls = @"000000A7-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeNitrogenDioxideDensity = @"000000C4-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeOzoneDensity = @"000000C3-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypePM10Density = @"000000C7-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypePM2_5Density = @"000000C6-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSlatType = @"000000C0-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSulphurDioxideDensity = @"000000C5-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSwingMode = @"000000B6-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetAirPurifierState = @"000000A8-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetFanState = @"000000BF-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetHeaterCoolerState = @"000000B2-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetHumidifierDehumidifierState = @"000000B4-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetTilt = @"000000C2-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeVolatileOrganicCompoundDensity = @"000000C8-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeWaterLevel = @"000000B5-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeAirPurifier = @"000000BB-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeFilterMaintenance = @"000000BA-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeHeaterCooler = @"000000BC-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeHumidifierDehumidifier = @"000000BD-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeSlats = @"000000B9-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeVentilationFan = @"000000B7-0000-1000-8000-0026BB765291";

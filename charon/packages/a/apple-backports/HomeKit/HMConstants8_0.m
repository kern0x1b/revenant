// The HomeKit string constants of iOS 8.0.
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

NSString *const HMCharacteristicMetadataFormatArray = @"array";
NSString *const HMCharacteristicMetadataFormatBool = @"bool";
NSString *const HMCharacteristicMetadataFormatData = @"data";
NSString *const HMCharacteristicMetadataFormatDictionary = @"dict";
NSString *const HMCharacteristicMetadataFormatFloat = @"float";
NSString *const HMCharacteristicMetadataFormatInt = @"int";
NSString *const HMCharacteristicMetadataFormatString = @"string";
NSString *const HMCharacteristicMetadataFormatTLV8 = @"tlv8";
NSString *const HMCharacteristicMetadataFormatUInt16 = @"uint16";
NSString *const HMCharacteristicMetadataFormatUInt32 = @"uint32";
NSString *const HMCharacteristicMetadataFormatUInt64 = @"uint64";
NSString *const HMCharacteristicMetadataFormatUInt8 = @"uint8";
NSString *const HMCharacteristicMetadataUnitsArcDegree = @"arcdegrees";
NSString *const HMCharacteristicMetadataUnitsCelsius = @"celsius";
NSString *const HMCharacteristicMetadataUnitsFahrenheit = @"fahrenheit";
NSString *const HMCharacteristicMetadataUnitsPercentage = @"percentage";
NSString *const HMCharacteristicPropertyReadable = @"HMCharacteristicPropertyReadable";
NSString *const HMCharacteristicPropertySupportsEventNotification = @"HMCharacteristicPropertySupportsEventNotification";
NSString *const HMCharacteristicPropertyWritable = @"HMCharacteristicPropertyWritable";
NSString *const HMCharacteristicTypeAdminOnlyAccess = @"00000001-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeAudioFeedback = @"00000005-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeBrightness = @"00000008-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCoolingThreshold = @"0000000D-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentDoorState = @"0000000E-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentHeatingCooling = @"0000000F-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentLockMechanismState = @"0000001D-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentRelativeHumidity = @"00000010-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentTemperature = @"00000011-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeHeatingThreshold = @"00000012-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeHue = @"00000013-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeIdentify = @"00000014-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeLockManagementAutoSecureTimeout = @"0000001A-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeLockManagementControlPoint = @"00000019-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeLockMechanismLastKnownAction = @"0000001C-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeLogs = @"0000001F-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeManufacturer = @"00000020-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeModel = @"00000021-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeMotionDetected = @"00000022-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeName = @"00000023-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeObstructionDetected = @"00000024-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeOutletInUse = @"00000026-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypePowerState = @"00000025-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeRotationDirection = @"00000028-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeRotationSpeed = @"00000029-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSaturation = @"0000002F-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSerialNumber = @"00000030-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetDoorState = @"00000032-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetHeatingCooling = @"00000033-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetLockMechanismState = @"0000001E-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetRelativeHumidity = @"00000034-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetTemperature = @"00000035-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTemperatureUnits = @"00000036-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeVersion = @"00000037-0000-1000-8000-0026BB765291";
NSString *const HMErrorDomain = @"HMErrorDomain";
NSString *const HMServiceTypeAccessoryInformation = @"0000003E-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeFan = @"00000040-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeGarageDoorOpener = @"00000041-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeLightbulb = @"00000043-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeLockManagement = @"00000044-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeLockMechanism = @"00000045-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeMicrophone = @"00000112-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeOutlet = @"00000047-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeSpeaker = @"00000113-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeSwitch = @"00000049-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeThermostat = @"0000004A-0000-1000-8000-0026BB765291";
NSString *const HMUserFailedAccessoriesKey = @"HMUserFailedAccessoriesKey";

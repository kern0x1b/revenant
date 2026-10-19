// The HomeKit string constants of iOS 9.0.
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

NSString *const HMAccessoryCategoryTypeBridge = @"61102194-9993-48BF-A1EF-6C7DC50F0C01";
NSString *const HMAccessoryCategoryTypeDoor = @"DD4DE411-8F01-44EE-866A-1F96144DC1B6";
NSString *const HMAccessoryCategoryTypeDoorLock = @"C25D5FCE-52EC-4599-A815-1192C5F08C7F";
NSString *const HMAccessoryCategoryTypeFan = @"151CB559-0DF9-40AA-8A67-12AF06C4449D";
NSString *const HMAccessoryCategoryTypeGarageDoorOpener = @"604B6E52-2C87-4596-B4C9-D15077C0C07F";
NSString *const HMAccessoryCategoryTypeLightbulb = @"57D56F4D-3302-41F7-AB34-5365AA180E81";
NSString *const HMAccessoryCategoryTypeOther = @"0FBA259B-05AC-46F2-875F-204ABB6D9FE7";
NSString *const HMAccessoryCategoryTypeOutlet = @"730F40D4-6D0E-4903-B09E-520A08AFB78C";
NSString *const HMAccessoryCategoryTypeProgrammableSwitch = @"3F9B944B-B8DF-4570-BAF5-CD31A8B321A7";
NSString *const HMAccessoryCategoryTypeSecuritySystem = @"14D8FE28-2998-49E3-AC95-E3969BE2957C";
NSString *const HMAccessoryCategoryTypeSensor = @"772AFB8E-8D2F-455E-90E5-9852E6C4DD31";
NSString *const HMAccessoryCategoryTypeSwitch = @"2F4C3164-8DE4-4A4F-93BA-DD1D5068DF0B";
NSString *const HMAccessoryCategoryTypeThermostat = @"79668DCF-89FB-450D-94B5-AEE70B7B09F1";
NSString *const HMAccessoryCategoryTypeWindow = @"1C501511-408E-4C1E-816B-3FC011FFD5B1";
NSString *const HMAccessoryCategoryTypeWindowCovering = @"2FB9EE1F-1C21-4D0B-9383-9B65F64DBF0E";
NSString *const HMActionSetTypeHomeArrival = @"HMActionSetTypeHomeArrival";
NSString *const HMActionSetTypeHomeDeparture = @"HMActionSetTypeHomeDeparture";
NSString *const HMActionSetTypeSleep = @"HMActionSetTypeSleep";
NSString *const HMActionSetTypeUserDefined = @"HMActionSetTypeUserDefined";
NSString *const HMActionSetTypeWakeUp = @"HMActionSetTypeWakeUp";
NSString *const HMCharacteristicKeyPath = @"characteristic";
NSString *const HMCharacteristicTypeAirParticulateDensity = @"00000064-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeAirParticulateSize = @"00000065-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeAirQuality = @"00000095-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeBatteryLevel = @"00000068-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCarbonDioxideDetected = @"00000092-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCarbonDioxideLevel = @"00000093-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCarbonDioxidePeakLevel = @"00000094-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCarbonMonoxideDetected = @"00000069-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCarbonMonoxideLevel = @"00000090-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCarbonMonoxidePeakLevel = @"00000091-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeChargingState = @"0000008F-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeContactState = @"0000006A-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentHorizontalTilt = @"0000006C-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentLightLevel = @"0000006B-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentPosition = @"0000006D-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentSecuritySystemState = @"00000066-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeCurrentVerticalTilt = @"0000006E-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeFirmwareVersion = @"00000052-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeHardwareVersion = @"00000053-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeHoldPosition = @"0000006F-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeInputEvent = @"00000073-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeLeakDetected = @"00000070-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeOccupancyDetected = @"00000071-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeOutputState = @"00000074-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypePositionState = @"00000072-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSecuritySystemAlarmType = @"0000008E-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSmokeDetected = @"00000076-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeSoftwareVersion = @"00000054-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeStatusActive = @"00000075-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeStatusFault = @"00000077-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeStatusJammed = @"00000078-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeStatusLowBattery = @"00000079-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeStatusTampered = @"0000007A-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetHorizontalTilt = @"0000007B-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetPosition = @"0000007C-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetSecuritySystemState = @"00000067-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicTypeTargetVerticalTilt = @"0000007D-0000-1000-8000-0026BB765291";
NSString *const HMCharacteristicValueKeyPath = @"characteristicValue";
NSString *const HMServiceTypeAirQualitySensor = @"0000008D-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeBattery = @"00000096-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeCarbonDioxideSensor = @"00000097-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeCarbonMonoxideSensor = @"0000007F-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeContactSensor = @"00000080-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeDoor = @"00000081-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeHumiditySensor = @"00000082-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeLeakSensor = @"00000083-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeLightSensor = @"00000084-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeMotionSensor = @"00000085-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeOccupancySensor = @"00000086-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeSecuritySystem = @"0000007E-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeSmokeSensor = @"00000087-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeStatefulProgrammableSwitch = @"00000088-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeStatelessProgrammableSwitch = @"00000089-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeTemperatureSensor = @"0000008A-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeWindow = @"0000008B-0000-1000-8000-0026BB765291";
NSString *const HMServiceTypeWindowCovering = @"0000008C-0000-1000-8000-0026BB765291";
NSString *const HMSignificantEventSunrise = @"sunrise";
NSString *const HMSignificantEventSunset = @"sunset";

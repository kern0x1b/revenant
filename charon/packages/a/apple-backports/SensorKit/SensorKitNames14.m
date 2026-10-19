// The names of SensorKit that arrived in iOS 14.0, with the values the host's own SensorKit holds.
//
// EVERY VALUE HERE IS READ OUT OF THE HOST'S SensorKit and not written down from memory, by the
// harness in tests/backports/host/sensorkit-names, which is three files and a runner and each does one
// thing:
//   read-host.m   opens the host's framework and dlsym's each name, DEREFERENCING ONCE - these are
//                 `const` object-pointer VARIABLES, so dlsym returns the address of the variable and
//                 the address of the variable is the string;
//   differential.m links THIS object's definitions into a process of its own and prints them, so the
//                 two sides are independent: an object wins at link time, and the host's values come
//                 from the other process;
//   compare.py    puts the two outputs side by side over the one name list both walk;
//   run.sh        builds and runs all of it, then breaks the comparison twice - every value wrong, and
//                 one value wrong, which must name exactly one row - and hands compare.py an empty host
//                 file, which must be red, so a run that compared nothing cannot look green.
//
// WHAT THE VALUES ARE, PLAINLY. The 29 usage-category keys each hold the string equal to the
// constant's own name, and the ten sensor constants hold identifiers of the form
// com.apple.SensorKit.motion.accelerometer. That is what the host's framework holds on this
// machine and it is what is carried; it is NOT a measurement of what an iOS 14 device's SensorKit
// holds, because no device has been asked. The facts file says so, and the device measurement is
// owed to a run on the guest.
//
// Open source checked: swift-corelibs-foundation 6.x: not used. What is carried is Apple's own
// SensorKit surface, which no permitted project implements; the values are Apple's and the only
// honest source for them is Apple's own framework.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

// The 29 device-usage category keys of iOS 14.0, SRDeviceUsageCategoryKey = NSString *
// (SRDeviceUsageCategories.h:13).
CFStringRef const SRDeviceUsageCategoryBooks = CFSTR("SRDeviceUsageCategoryBooks");
CFStringRef const SRDeviceUsageCategoryBusiness = CFSTR("SRDeviceUsageCategoryBusiness");
CFStringRef const SRDeviceUsageCategoryCatalogs = CFSTR("SRDeviceUsageCategoryCatalogs");
CFStringRef const SRDeviceUsageCategoryDeveloperTools = CFSTR("SRDeviceUsageCategoryDeveloperTools");
CFStringRef const SRDeviceUsageCategoryEducation = CFSTR("SRDeviceUsageCategoryEducation");
CFStringRef const SRDeviceUsageCategoryEntertainment = CFSTR("SRDeviceUsageCategoryEntertainment");
CFStringRef const SRDeviceUsageCategoryFinance = CFSTR("SRDeviceUsageCategoryFinance");
CFStringRef const SRDeviceUsageCategoryFoodAndDrink = CFSTR("SRDeviceUsageCategoryFoodAndDrink");
CFStringRef const SRDeviceUsageCategoryGames = CFSTR("SRDeviceUsageCategoryGames");
CFStringRef const SRDeviceUsageCategoryGraphicsAndDesign = CFSTR("SRDeviceUsageCategoryGraphicsAndDesign");
CFStringRef const SRDeviceUsageCategoryHealthAndFitness = CFSTR("SRDeviceUsageCategoryHealthAndFitness");
CFStringRef const SRDeviceUsageCategoryKids = CFSTR("SRDeviceUsageCategoryKids");
CFStringRef const SRDeviceUsageCategoryLifestyle = CFSTR("SRDeviceUsageCategoryLifestyle");
CFStringRef const SRDeviceUsageCategoryMedical = CFSTR("SRDeviceUsageCategoryMedical");
CFStringRef const SRDeviceUsageCategoryMiscellaneous = CFSTR("SRDeviceUsageCategoryMiscellaneous");
CFStringRef const SRDeviceUsageCategoryMusic = CFSTR("SRDeviceUsageCategoryMusic");
CFStringRef const SRDeviceUsageCategoryNavigation = CFSTR("SRDeviceUsageCategoryNavigation");
CFStringRef const SRDeviceUsageCategoryNews = CFSTR("SRDeviceUsageCategoryNews");
CFStringRef const SRDeviceUsageCategoryNewsstand = CFSTR("SRDeviceUsageCategoryNewsstand");
CFStringRef const SRDeviceUsageCategoryPhotoAndVideo = CFSTR("SRDeviceUsageCategoryPhotoAndVideo");
CFStringRef const SRDeviceUsageCategoryProductivity = CFSTR("SRDeviceUsageCategoryProductivity");
CFStringRef const SRDeviceUsageCategoryReference = CFSTR("SRDeviceUsageCategoryReference");
CFStringRef const SRDeviceUsageCategoryShopping = CFSTR("SRDeviceUsageCategoryShopping");
CFStringRef const SRDeviceUsageCategorySocialNetworking = CFSTR("SRDeviceUsageCategorySocialNetworking");
CFStringRef const SRDeviceUsageCategorySports = CFSTR("SRDeviceUsageCategorySports");
CFStringRef const SRDeviceUsageCategoryStickers = CFSTR("SRDeviceUsageCategoryStickers");
CFStringRef const SRDeviceUsageCategoryTravel = CFSTR("SRDeviceUsageCategoryTravel");
CFStringRef const SRDeviceUsageCategoryUtilities = CFSTR("SRDeviceUsageCategoryUtilities");
CFStringRef const SRDeviceUsageCategoryWeather = CFSTR("SRDeviceUsageCategoryWeather");

// The ten sensor constants of iOS 14.0, `extern SRSensor const`, which SRDefines.h typedefs to an
// NSString *.
CFStringRef const SRSensorAccelerometer = CFSTR("com.apple.SensorKit.motion.accelerometer");
CFStringRef const SRSensorAmbientLightSensor = CFSTR("com.apple.SensorKit.als");
CFStringRef const SRSensorDeviceUsageReport = CFSTR("com.apple.SensorKit.deviceUsageReport");
CFStringRef const SRSensorKeyboardMetrics = CFSTR("com.apple.SensorKit.keyboardMetrics");
CFStringRef const SRSensorMessagesUsageReport = CFSTR("com.apple.SensorKit.messagesUsageReport");
CFStringRef const SRSensorOnWristState = CFSTR("com.apple.SensorKit.onWristState");
CFStringRef const SRSensorPedometerData = CFSTR("com.apple.SensorKit.pedometer.data");
CFStringRef const SRSensorPhoneUsageReport = CFSTR("com.apple.SensorKit.phoneUsageReport");
CFStringRef const SRSensorRotationRate = CFSTR("com.apple.SensorKit.motion.gyroscope");
CFStringRef const SRSensorVisits = CFSTR("com.apple.SensorKit.visits");

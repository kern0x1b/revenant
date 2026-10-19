// The port's own values, printed from its own LINKED symbols.
//
// This object links TWO port-side sources, so every name below resolves to THIS PACKAGE'S definition
// and not to the host framework's - the port's object wins at link time, and the host's values come
// from the other process, which is what makes the two independent:
//
//   packages/a/apple-backports/SensorKit/SensorKitNames14.m   the 39 names of iOS 14.0
//   names-extra.m, which imports CharonSensorKitNames.h       the 18 names of 15.0 .. 26.0
//
// The second is a harness file rather than a release object because those eighteen constants are split
// across six objects, one release each, and their values live in one header behind one guard per
// release. Linking all six guards here walks that header whole; it is the same list the six objects
// carry between them, read through one definition rather than six copies.
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

extern CFStringRef SRDeviceUsageCategoryBooks;
extern CFStringRef SRDeviceUsageCategoryBusiness;
extern CFStringRef SRDeviceUsageCategoryCatalogs;
extern CFStringRef SRDeviceUsageCategoryDeveloperTools;
extern CFStringRef SRDeviceUsageCategoryEducation;
extern CFStringRef SRDeviceUsageCategoryEntertainment;
extern CFStringRef SRDeviceUsageCategoryFinance;
extern CFStringRef SRDeviceUsageCategoryFoodAndDrink;
extern CFStringRef SRDeviceUsageCategoryGames;
extern CFStringRef SRDeviceUsageCategoryGraphicsAndDesign;
extern CFStringRef SRDeviceUsageCategoryHealthAndFitness;
extern CFStringRef SRDeviceUsageCategoryKids;
extern CFStringRef SRDeviceUsageCategoryLifestyle;
extern CFStringRef SRDeviceUsageCategoryMedical;
extern CFStringRef SRDeviceUsageCategoryMiscellaneous;
extern CFStringRef SRDeviceUsageCategoryMusic;
extern CFStringRef SRDeviceUsageCategoryNavigation;
extern CFStringRef SRDeviceUsageCategoryNews;
extern CFStringRef SRDeviceUsageCategoryNewsstand;
extern CFStringRef SRDeviceUsageCategoryPhotoAndVideo;
extern CFStringRef SRDeviceUsageCategoryProductivity;
extern CFStringRef SRDeviceUsageCategoryReference;
extern CFStringRef SRDeviceUsageCategoryShopping;
extern CFStringRef SRDeviceUsageCategorySocialNetworking;
extern CFStringRef SRDeviceUsageCategorySports;
extern CFStringRef SRDeviceUsageCategoryStickers;
extern CFStringRef SRDeviceUsageCategoryTravel;
extern CFStringRef SRDeviceUsageCategoryUtilities;
extern CFStringRef SRDeviceUsageCategoryWeather;
extern CFStringRef SRSensorAccelerometer;
extern CFStringRef SRSensorAmbientLightSensor;
extern CFStringRef SRSensorDeviceUsageReport;
extern CFStringRef SRSensorKeyboardMetrics;
extern CFStringRef SRSensorMessagesUsageReport;
extern CFStringRef SRSensorOnWristState;
extern CFStringRef SRSensorPedometerData;
extern CFStringRef SRSensorPhoneUsageReport;
extern CFStringRef SRSensorRotationRate;
extern CFStringRef SRSensorVisits;
extern CFStringRef SRSensorSiriSpeechMetrics;
extern CFStringRef SRSensorTelephonySpeechMetrics;
extern CFStringRef SRSensorAmbientPressure;
extern CFStringRef SRSensorHeartRate;
extern CFStringRef SRSensorOdometer;
extern CFStringRef SRSensorMediaEvents;
extern CFStringRef SRPhotoplethysmogramOpticalSampleConditionSignalSaturation;
extern CFStringRef SRPhotoplethysmogramOpticalSampleConditionUnreliableNoise;
extern CFStringRef SRPhotoplethysmogramSampleUsageForegroundHeartRate;
extern CFStringRef SRPhotoplethysmogramSampleUsageDeepBreathing;
extern CFStringRef SRPhotoplethysmogramSampleUsageForegroundBloodOxygen;
extern CFStringRef SRPhotoplethysmogramSampleUsageBackgroundSystem;
extern CFStringRef SRSensorFaceMetrics;
extern CFStringRef SRSensorWristTemperature;
extern CFStringRef SRSensorElectrocardiogram;
extern CFStringRef SRSensorPhotoplethysmogram;
extern CFStringRef SRSensorAcousticSettings;
extern CFStringRef SRSensorSleepSessions;

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);

    CFStringRef all[] = {
        SRDeviceUsageCategoryBooks,
        SRDeviceUsageCategoryBusiness,
        SRDeviceUsageCategoryCatalogs,
        SRDeviceUsageCategoryDeveloperTools,
        SRDeviceUsageCategoryEducation,
        SRDeviceUsageCategoryEntertainment,
        SRDeviceUsageCategoryFinance,
        SRDeviceUsageCategoryFoodAndDrink,
        SRDeviceUsageCategoryGames,
        SRDeviceUsageCategoryGraphicsAndDesign,
        SRDeviceUsageCategoryHealthAndFitness,
        SRDeviceUsageCategoryKids,
        SRDeviceUsageCategoryLifestyle,
        SRDeviceUsageCategoryMedical,
        SRDeviceUsageCategoryMiscellaneous,
        SRDeviceUsageCategoryMusic,
        SRDeviceUsageCategoryNavigation,
        SRDeviceUsageCategoryNews,
        SRDeviceUsageCategoryNewsstand,
        SRDeviceUsageCategoryPhotoAndVideo,
        SRDeviceUsageCategoryProductivity,
        SRDeviceUsageCategoryReference,
        SRDeviceUsageCategoryShopping,
        SRDeviceUsageCategorySocialNetworking,
        SRDeviceUsageCategorySports,
        SRDeviceUsageCategoryStickers,
        SRDeviceUsageCategoryTravel,
        SRDeviceUsageCategoryUtilities,
        SRDeviceUsageCategoryWeather,
        SRSensorAccelerometer,
        SRSensorAmbientLightSensor,
        SRSensorDeviceUsageReport,
        SRSensorKeyboardMetrics,
        SRSensorMessagesUsageReport,
        SRSensorOnWristState,
        SRSensorPedometerData,
        SRSensorPhoneUsageReport,
        SRSensorRotationRate,
        SRSensorVisits,
        SRSensorSiriSpeechMetrics,
        SRSensorTelephonySpeechMetrics,
        SRSensorAmbientPressure,
        SRSensorHeartRate,
        SRSensorOdometer,
        SRSensorMediaEvents,
        SRPhotoplethysmogramOpticalSampleConditionSignalSaturation,
        SRPhotoplethysmogramOpticalSampleConditionUnreliableNoise,
        SRPhotoplethysmogramSampleUsageForegroundHeartRate,
        SRPhotoplethysmogramSampleUsageDeepBreathing,
        SRPhotoplethysmogramSampleUsageForegroundBloodOxygen,
        SRPhotoplethysmogramSampleUsageBackgroundSystem,
        SRSensorFaceMetrics,
        SRSensorWristTemperature,
        SRSensorElectrocardiogram,
        SRSensorPhotoplethysmogram,
        SRSensorAcousticSettings,
        SRSensorSleepSessions
    };
    const char *label[] = {
        "SRDeviceUsageCategoryBooks",
        "SRDeviceUsageCategoryBusiness",
        "SRDeviceUsageCategoryCatalogs",
        "SRDeviceUsageCategoryDeveloperTools",
        "SRDeviceUsageCategoryEducation",
        "SRDeviceUsageCategoryEntertainment",
        "SRDeviceUsageCategoryFinance",
        "SRDeviceUsageCategoryFoodAndDrink",
        "SRDeviceUsageCategoryGames",
        "SRDeviceUsageCategoryGraphicsAndDesign",
        "SRDeviceUsageCategoryHealthAndFitness",
        "SRDeviceUsageCategoryKids",
        "SRDeviceUsageCategoryLifestyle",
        "SRDeviceUsageCategoryMedical",
        "SRDeviceUsageCategoryMiscellaneous",
        "SRDeviceUsageCategoryMusic",
        "SRDeviceUsageCategoryNavigation",
        "SRDeviceUsageCategoryNews",
        "SRDeviceUsageCategoryNewsstand",
        "SRDeviceUsageCategoryPhotoAndVideo",
        "SRDeviceUsageCategoryProductivity",
        "SRDeviceUsageCategoryReference",
        "SRDeviceUsageCategoryShopping",
        "SRDeviceUsageCategorySocialNetworking",
        "SRDeviceUsageCategorySports",
        "SRDeviceUsageCategoryStickers",
        "SRDeviceUsageCategoryTravel",
        "SRDeviceUsageCategoryUtilities",
        "SRDeviceUsageCategoryWeather",
        "SRSensorAccelerometer",
        "SRSensorAmbientLightSensor",
        "SRSensorDeviceUsageReport",
        "SRSensorKeyboardMetrics",
        "SRSensorMessagesUsageReport",
        "SRSensorOnWristState",
        "SRSensorPedometerData",
        "SRSensorPhoneUsageReport",
        "SRSensorRotationRate",
        "SRSensorVisits",
        "SRSensorSiriSpeechMetrics",
        "SRSensorTelephonySpeechMetrics",
        "SRSensorAmbientPressure",
        "SRSensorHeartRate",
        "SRSensorOdometer",
        "SRSensorMediaEvents",
        "SRPhotoplethysmogramOpticalSampleConditionSignalSaturation",
        "SRPhotoplethysmogramOpticalSampleConditionUnreliableNoise",
        "SRPhotoplethysmogramSampleUsageForegroundHeartRate",
        "SRPhotoplethysmogramSampleUsageDeepBreathing",
        "SRPhotoplethysmogramSampleUsageForegroundBloodOxygen",
        "SRPhotoplethysmogramSampleUsageBackgroundSystem",
        "SRSensorFaceMetrics",
        "SRSensorWristTemperature",
        "SRSensorElectrocardiogram",
        "SRSensorPhotoplethysmogram",
        "SRSensorAcousticSettings",
        "SRSensorSleepSessions"
    };
    for (size_t i = 0; i < sizeof all / sizeof all[0]; i++) {
        char b[256] = {0};
        if (!all[i] || !CFStringGetCString(all[i], b, sizeof b, kCFStringEncodingUTF8)) {
            printf("PORT\t%s\t(UNREADABLE)\n", label[i]);
            continue;
        }
        printf("PORT\t%s\t%s\n", label[i], b);
    }
    return 0;
}

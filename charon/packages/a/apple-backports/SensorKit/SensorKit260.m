#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

// SensorKit of iOS 26.0, the properties that arrived then.
@implementation SRAcousticSettings
@dynamic environmentalSoundMeasurementsEnabled, audioExposureSampleLifetime, headphoneSafetyAudioLevel, musicEQSettings, accessibilitySettings;
CHARON_SCALAR_GETTER(BOOL, environmentalSoundMeasurementsEnabled, isEnvironmentalSoundMeasurementsEnabled)
CHARON_SCALAR_PROPERTY(SRAcousticSettingsSampleLifetime, audioExposureSampleLifetime)
CHARON_VALUE_PROPERTY(NSNumber *, headphoneSafetyAudioLevel)
CHARON_VALUE_PROPERTY(SRAcousticSettingsMusicEQ *, musicEQSettings)
CHARON_VALUE_PROPERTY(SRAcousticSettingsAccessibility *, accessibilitySettings)
@end
@implementation SRAcousticSettings (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRAcousticSettingsAccessibility
@dynamic leftRightBalance, monoAudioEnabled, backgroundSounds, headphoneAccommodations;
CHARON_SCALAR_PROPERTY(double, leftRightBalance)
CHARON_SCALAR_GETTER(BOOL, monoAudioEnabled, isMonoAudioEnabled)
CHARON_VALUE_PROPERTY(SRAcousticSettingsAccessibilityBackgroundSounds *, backgroundSounds)
CHARON_VALUE_PROPERTY(SRAcousticSettingsAccessibilityHeadphoneAccommodations *, headphoneAccommodations)
@end
@implementation SRAcousticSettingsAccessibility (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRAcousticSettingsAccessibilityBackgroundSounds
@dynamic enabled, soundName, relativeVolume, playWithMediaEnabled, relativeVolumeWithMedia, stopOnLockEnabled;
CHARON_SCALAR_GETTER(BOOL, enabled, isEnabled)
CHARON_SCALAR_PROPERTY(SRAcousticSettingsAccessibilityBackgroundSoundsName, soundName)
CHARON_SCALAR_PROPERTY(double, relativeVolume)
CHARON_SCALAR_GETTER(BOOL, playWithMediaEnabled, isPlayWithMediaEnabled)
CHARON_SCALAR_PROPERTY(double, relativeVolumeWithMedia)
CHARON_SCALAR_GETTER(BOOL, stopOnLockEnabled, isStopOnLockEnabled)
@end
@implementation SRAcousticSettingsAccessibilityBackgroundSounds (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRAcousticSettingsAccessibilityHeadphoneAccommodations
@dynamic enabled, mediaEnhanceTuning, mediaEnhanceBoosting, mediaEnhanceApplication;
CHARON_SCALAR_GETTER(BOOL, enabled, isEnabled)
CHARON_SCALAR_PROPERTY(SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceTuning, mediaEnhanceTuning)
CHARON_SCALAR_PROPERTY(SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceBoosting, mediaEnhanceBoosting)
CHARON_SCALAR_PROPERTY(SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceApplication, mediaEnhanceApplication)
@end
@implementation SRAcousticSettingsAccessibilityHeadphoneAccommodations (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRAcousticSettingsMusicEQ
@dynamic soundCheckEnabled, lateNightModeEnabled;
CHARON_SCALAR_GETTER(BOOL, soundCheckEnabled, isSoundCheckEnabled)
CHARON_SCALAR_GETTER(BOOL, lateNightModeEnabled, isLateNightModeEnabled)
@end
@implementation SRAcousticSettingsMusicEQ (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRSleepSession
@dynamic startDate, duration, identifier;
CHARON_VALUE_PROPERTY(NSDate *, startDate)
CHARON_SCALAR_PROPERTY(NSTimeInterval, duration)
CHARON_VALUE_PROPERTY(NSString *, identifier)
@end
@implementation SRSleepSession (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

// The two string constants of iOS 26.0,
// declared at SRSensors.h:345 and :357,
// named from CharonSensorKitNames.h rather than written here: an object carries the API of
// one release alone, while the values are one list that the host comparison in
// tests/backports/host/sensorkit-names walks whole.

#define CHARON_SENSORKIT_NAMES_26_0
#import "CharonSensorKitNames.h"

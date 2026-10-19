#ifndef CHARON_SENSORKIT_H
#define CHARON_SENSORKIT_H

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <SensorKit/SensorKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef CFTimeInterval SRAbsoluteTime;

typedef NSString *SRSensor;

typedef NSInteger SRAcousticSettingsSampleLifetime;
typedef NSInteger SRAcousticSettingsAccessibilityBackgroundSoundsName;
typedef NSInteger SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceApplication;
typedef NSInteger SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceBoosting;
typedef NSInteger SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceTuning;

typedef NSInteger SRElectrocardiogramLead;
typedef NSInteger SRElectrocardiogramSessionGuidance;
typedef NSInteger SRElectrocardiogramSessionState;

typedef NSInteger SRFaceMetricsContext;

typedef NSUInteger SRElectrocardiogramDataFlags;
typedef NSUInteger SRSpeechMetricsSessionFlags;
typedef NSUInteger SRWristTemperatureCondition;

@class SRAcousticSettingsAccessibility;
@class SRAcousticSettingsAccessibilityBackgroundSounds;
@class SRAcousticSettingsAccessibilityHeadphoneAccommodations;
@class SRAcousticSettingsMusicEQ;
@class SRAudioLevel;
@class SRElectrocardiogramSample;
@class SRElectrocardiogramSession;
@class SRFaceMetricsExpression;
@class SRPhotoplethysmogramAccelerometerSample;
@class SRPhotoplethysmogramOpticalSample;
@class SRPhotoplethysmogramSample;
@class SRSleepSession;
@class SRSpeechExpression;
@class SRWristTemperature;

@interface SRAcousticSettings : NSObject
@property (nonatomic, readonly, strong, nullable) SRAcousticSettingsAccessibility *accessibilitySettings;
@property (nonatomic, readonly, strong, nullable) SRAcousticSettingsMusicEQ *musicEQSettings;
@property (nonatomic, readonly, assign) SRAcousticSettingsSampleLifetime audioExposureSampleLifetime;
@property (nonatomic, readonly, assign, getter=isEnvironmentalSoundMeasurementsEnabled) BOOL environmentalSoundMeasurementsEnabled;
@property (nonatomic, readonly, strong, nullable) NSNumber *headphoneSafetyAudioLevel;
@end

@interface SRAcousticSettingsAccessibility : NSObject
@property (nonatomic, readonly, strong, nullable) SRAcousticSettingsAccessibilityBackgroundSounds *backgroundSounds;
@property (nonatomic, readonly, strong, nullable) SRAcousticSettingsAccessibilityHeadphoneAccommodations *headphoneAccommodations;
@property (nonatomic, readonly, assign) double leftRightBalance;
@property (nonatomic, readonly, assign, getter=isMonoAudioEnabled) BOOL monoAudioEnabled;
@end

@interface SRAcousticSettingsAccessibilityBackgroundSounds : NSObject
@property (nonatomic, readonly, assign) SRAcousticSettingsAccessibilityBackgroundSoundsName soundName;
@property (nonatomic, readonly, assign, getter=isEnabled) BOOL enabled;
@property (nonatomic, readonly, assign, getter=isPlayWithMediaEnabled) BOOL playWithMediaEnabled;
@property (nonatomic, readonly, assign, getter=isStopOnLockEnabled) BOOL stopOnLockEnabled;
@property (nonatomic, readonly, assign) double relativeVolume;
@property (nonatomic, readonly, assign) double relativeVolumeWithMedia;
@end

@interface SRAcousticSettingsAccessibilityHeadphoneAccommodations : NSObject
@property (nonatomic, readonly, assign) SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceApplication mediaEnhanceApplication;
@property (nonatomic, readonly, assign) SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceBoosting mediaEnhanceBoosting;
@property (nonatomic, readonly, assign) SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceTuning mediaEnhanceTuning;
@property (nonatomic, readonly, assign, getter=isEnabled) BOOL enabled;
@end

@interface SRAcousticSettingsMusicEQ : NSObject
@property (nonatomic, readonly, assign, getter=isLateNightModeEnabled) BOOL lateNightModeEnabled;
@property (nonatomic, readonly, assign, getter=isSoundCheckEnabled) BOOL soundCheckEnabled;
@end

@interface SRAudioLevel : NSObject
@property (nonatomic, readonly, assign) double loudness;
@property (nonatomic, readonly, assign) CMTimeRange timeRange;
@end

@interface SRElectrocardiogramData : NSObject
@property (nonatomic, readonly, assign) SRElectrocardiogramDataFlags flags;
@property (nonatomic, readonly, strong, nullable) NSMeasurement *value;
@end

@interface SRElectrocardiogramSample : NSObject
@property (nonatomic, readonly, strong, nullable) SRElectrocardiogramSession *session;
@property (nonatomic, readonly, strong, nullable) NSDate *date;
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitFrequency *> *frequency;
@property (nonatomic, readonly, strong, nullable) NSArray<NSNumber *> *data;
@property (nonatomic, readonly, assign) SRElectrocardiogramLead lead;
@end

@interface SRElectrocardiogramSession : NSObject
@property (nonatomic, readonly, copy, nullable) NSString *identifier;
@property (nonatomic, readonly, assign) SRElectrocardiogramSessionState state;
@property (nonatomic, readonly, assign) SRElectrocardiogramSessionGuidance sessionGuidance;
@end

@interface SRFaceMetrics : NSObject
@property (nonatomic, readonly, copy, nullable) NSString *version;
@property (nonatomic, readonly, copy, nullable) NSString *sessionIdentifier;
@property (nonatomic, readonly, assign) SRFaceMetricsContext context;
@property (nonatomic, readonly, strong, nullable) NSArray<SRFaceMetricsExpression *> *wholeFaceExpressions;
@property (nonatomic, readonly, strong, nullable) NSArray<SRFaceMetricsExpression *> *partialFaceExpressions;
@property (nonatomic, readonly, strong, nullable) id faceAnchor;
@end

@interface SRFaceMetricsExpression : NSObject
@property (nonatomic, readonly, copy, nullable) NSString *identifier;
@property (nonatomic, readonly, assign) double value;
@end

@interface SRPhotoplethysmogramSample : NSObject
@property (nonatomic, readonly, strong, nullable) NSDate *startDate;
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitTemperature *> *temperature;
@property (nonatomic, readonly, strong, nullable) NSArray<SRPhotoplethysmogramAccelerometerSample *> *accelerometerSamples;
@property (nonatomic, readonly, strong, nullable) NSArray<SRPhotoplethysmogramOpticalSample *> *opticalSamples;
@property (nonatomic, readonly, strong, nullable) NSArray<NSString *> *usage;
@property (nonatomic, readonly, assign) int64_t nanosecondsSinceStart;
@end

@interface SRPhotoplethysmogramAccelerometerSample : NSObject
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitAcceleration *> *x;
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitAcceleration *> *y;
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitAcceleration *> *z;
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitFrequency *> *samplingFrequency;
@property (nonatomic, readonly, assign) int64_t nanosecondsSinceStart;
@end

@interface SRPhotoplethysmogramOpticalSample : NSObject
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitLength *> *samplingFrequency;
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitLength *> *nominalWavelength;
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitLength *> *effectiveWavelength;
@property (nonatomic, readonly, strong, nullable) NSIndexSet *activePhotodiodeIndexes;
@property (nonatomic, readonly, strong, nullable) NSArray<NSString *> *conditions;
@property (nonatomic, readonly, strong, nullable) NSNumber *backgroundNoiseOffset;
@property (nonatomic, readonly, assign) NSInteger emitter;
@property (nonatomic, readonly, assign) NSInteger signalIdentifier;
@property (nonatomic, readonly, assign) int64_t nanosecondsSinceStart;
@end

@interface SRSleepSession : NSObject
@property (nonatomic, readonly, copy, nullable) NSString *identifier;
@property (nonatomic, readonly, strong, nullable) NSDate *startDate;
@property (nonatomic, readonly, assign) NSTimeInterval duration;
@end

@interface SRSpeechExpression : NSObject
@property (nonatomic, readonly, copy, nullable) NSString *version;
@property (nonatomic, readonly, assign) double activation;
@property (nonatomic, readonly, assign) double confidence;
@property (nonatomic, readonly, assign) double dominance;
@property (nonatomic, readonly, assign) double mood;
@property (nonatomic, readonly, assign) double valence;
@property (nonatomic, readonly, assign) CMTimeRange timeRange;
@end

@interface SRSpeechMetrics : NSObject
@property (nonatomic, readonly, copy, nullable) NSString *sessionIdentifier;
@property (nonatomic, readonly, strong, nullable) NSDate *timestamp;
@property (nonatomic, readonly, strong, nullable) SRAudioLevel *audioLevel;
@property (nonatomic, readonly, strong, nullable) SRSpeechExpression *speechExpression;
@property (nonatomic, readonly, assign) SRSpeechMetricsSessionFlags sessionFlags;
@property (nonatomic, readonly, strong, nullable) id speechRecognition;
@property (nonatomic, readonly, strong, nullable) id soundClassification;
@end

@interface SRSpeechMetrics (CharonSensorKit172)
@property (nonatomic, readonly, assign) NSTimeInterval timeSinceAudioStart;
@end

@interface SRWristTemperature : NSObject
@property (nonatomic, readonly, strong, nullable) NSDate *timestamp;
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitTemperature *> *value;
@property (nonatomic, readonly, strong, nullable) NSMeasurement<NSUnitTemperature *> *errorEstimate;
@property (nonatomic, readonly, assign) SRWristTemperatureCondition condition;
@end

@interface SRWristTemperatureSession : NSObject
@property (nonatomic, readonly, copy, nullable) NSString *version;
@property (nonatomic, readonly, strong, nullable) NSEnumerator<SRWristTemperature *> *temperatures;
@property (nonatomic, readonly, strong, nullable) NSDate *startDate;
@property (nonatomic, readonly, assign) NSTimeInterval duration;
@end

@interface SRApplicationUsage (CharonSensorKit150)
@property (nonatomic, readonly, strong, nullable) NSString *reportApplicationIdentifier;
@property (nonatomic, readonly, strong, nullable) NSArray<SRTextInputSession *> *textInputSessions;
@end

@interface SRApplicationUsage (CharonSensorKit164)
@property (nonatomic, readonly, assign) NSTimeInterval relativeStartTime;
@property (nonatomic, readonly, strong, nullable) NSArray<NSString *> *supplementalCategories;
@end


@interface SRDevice (CharonSensorKit170)
@property (nonatomic, readonly, copy, nullable) NSString *productType;
@end


@interface SRDeviceUsageReport (CharonSensorKit164)
@property (nonatomic, readonly, copy, nullable) NSString *version;
@end


@interface SRKeyboardMetrics (CharonSensorKit150)
@property (nonatomic, readonly, copy, nullable) NSArray<NSString *> *inputModes;
@end

@interface SRKeyboardMetrics (CharonSensorKit164)
@property (nonatomic, readonly, copy, nullable) NSArray<NSString *> *sessionIdentifiers;
@property (nonatomic, readonly, strong, nullable) NSArray<SRKeyboardProbabilityMetric *> *longWordTouchUpDown;
@property (nonatomic, readonly, strong, nullable) SRKeyboardProbabilityMetric *touchUpDown;
@end


@interface SRTextInputSession (CharonSensorKit164)
@property (nonatomic, readonly, copy, nullable) NSString *sessionIdentifier;
@end


@interface SRWristDetection (CharonSensorKit164)
@property (nonatomic, readonly, strong, nullable) NSDate *offWristDate;
@property (nonatomic, readonly, strong, nullable) NSDate *onWristDate;
@end


NS_ASSUME_NONNULL_END

#endif

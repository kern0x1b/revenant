#ifndef CHARON_SENSORKIT_H
#define CHARON_SENSORKIT_H

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <SensorKit/SensorKit.h>

// What the lowered 16.4 SDK this package builds against cannot name, written out here so that an
// application compiled against SDK 26.2 finds the classes and the types it expects.
//
// SensorKit arrived in iOS 14 and the build's SDK is four minor versions behind the one this package
// develops against, so nineteen of the framework's thirty-eight classes are absent from those headers
// and twenty-five of its property types are absent with them: the string enumerations SensorKit names
// its values with, the option masks, the one plain typedef, and the one struct. Each is spelled here as
// the SDK 26.2 header spells it - the same superclass, the same selector, the same property name and
// type, no ivars - and the availability annotations are left out, which is what the other three
// redeclarations in this package do (CharonMetricKit.h, CharonSecurityUI.h, CharonAVAudioBuffer.h):
// they would be refused against this deployment target and they mean nothing in a translation unit that
// is not an application's.
//
// No header text is copied here and no enumerator is invented. A value of one of the enumerations is
// produced by the system reading a sensor, and there is no system here that does that, so the port never
// has to name one; an application that receives a value from a payload and puts it in one of these
// properties carries the value with it, and the property's type is what the header promises.

NS_ASSUME_NONNULL_BEGIN

// MARK: - The types the build's SDK does not name, and the ones it does

// Ten of the twenty-five this header once carried are already in the 16.4 SDK and are left to it -
// SRAmbientLightSensorPlacement, SRAuthorizationStatus, SRCrownOrientation, SRDeletionReason,
// SRLocationCategory, SRMediaEventType, SRNotificationEvent, SRTextInputSessionType, SRWristLocation and
// the SRAmbientLightChromaticity struct - measured by compiling this header and reading which
// declarations it collided with. The fifteen below are the ones it does not have.
//
// A value of any of them is produced by the system reading a sensor, and there is no system here that
// does that, so the port never has to name one. That is why each of these is a typedef of its underlying
// type with no enumerator list: the ENUMERATORS are Apple's, and copying them would be copying a header
// to state a fact the port does not need. An application that receives a value in a payload and puts it
// in one of these properties carries the value with it, and the type is what the header promises.

// The one plain typedef: a time in seconds, the same type as the absolute time the four functions
// return.
typedef CFTimeInterval SRAbsoluteTime;

// The one string: the identifier of a stream in the store, which is a name and not a number.
typedef NSString *SRSensor;

// Five integer enumerations.
typedef NSInteger SRAcousticSettingsSampleLifetime;
typedef NSInteger SRAcousticSettingsAccessibilityBackgroundSoundsName;
typedef NSInteger SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceApplication;
typedef NSInteger SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceBoosting;
typedef NSInteger SRAcousticSettingsAccessibilityHeadphoneAccommodationsMediaEnhanceTuning;

// Two more integer enumerations, on the recording rather than the reading.
typedef NSInteger SRElectrocardiogramLead;
typedef NSInteger SRElectrocardiogramSessionGuidance;
typedef NSInteger SRElectrocardiogramSessionState;

// One more, on a face reading.
typedef NSInteger SRFaceMetricsContext;

// The three option masks, which are the type an application ORs into rather than a value it compares.
typedef NSUInteger SRElectrocardiogramDataFlags;
typedef NSUInteger SRSpeechMetricsSessionFlags;
typedef NSUInteger SRWristTemperatureCondition;

// MARK: - The nineteen classes the build's SDK does not declare

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

// The acoustic settings: what the application asked the system to measure, and what it was told. Every
// one of these is an application-written statement rather than a reading, which is why the class exists
// at all - a port that invented readings for it would be inventing the readings.
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

// A loudness reading over a stretch of audio, and the stretch it covers.
@interface SRAudioLevel : NSObject
@property (nonatomic, readonly, assign) double loudness;
@property (nonatomic, readonly, assign) CMTimeRange timeRange;
@end

// An electrocardiogram recording: the flags of the recording, and a channel of it. -value is a
// measurement, and the 16.4 SDK has no NSUnitVoltage, so the declaration is the bare measurement and a
// reading that carries its unit is still carried as one.
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

// The face metrics a TrueDepth camera reports. -faceAnchor is declared by ARKit, which this package does
// not carry, so the port has no such type to answer with: the property is registered absent
// (registry/SensorKit/ios14.json) and is not declared here, rather than carried as a name that could
// only ever read nil.
@interface SRFaceMetrics : NSObject
@property (nonatomic, readonly, copy, nullable) NSString *version;
@property (nonatomic, readonly, copy, nullable) NSString *sessionIdentifier;
@property (nonatomic, readonly, assign) SRFaceMetricsContext context;
@property (nonatomic, readonly, strong, nullable) NSArray<SRFaceMetricsExpression *> *wholeFaceExpressions;
@property (nonatomic, readonly, strong, nullable) NSArray<SRFaceMetricsExpression *> *partialFaceExpressions;
// faceAnchor is ARFaceAnchor * in the 26.2 header (SRFaceMetrics.h:72), and ARKit is not a framework this
// package carries, so there is no such type here to declare the property over. It is declared as id
// rather than left out, and that is the load-bearing part: the archiver walks the DECLARED property
// list, so a property that is not declared cannot be read back and an archived reading would silently
// lose the one field that ties a face reading to the camera frame it came from. SRFetchResult.sample
// is already declared this way for the same reason - its SampleType is a generic parameter rather than a
// class. The host's own SensorKit declares faceAnchor and does not implement it, so there is no oracle
// for the value; what the port answers is whatever an application archived under the name, and nil when
// nothing was, which is what the header's own nullable-for-everything-about-a-camera says.
@property (nonatomic, readonly, strong, nullable) id faceAnchor;
@end

@interface SRFaceMetricsExpression : NSObject
@property (nonatomic, readonly, copy, nullable) NSString *identifier;
@property (nonatomic, readonly, assign) double value;
@end

// The photoplethysmogram - a pulse reading from the watch's optical sensor - and its two channels.
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

// A night of sleep, and the speech the microphone heard in it. -soundClassification is declared by
// SoundAnalysis and -speechRecognition by Speech, neither of which this package carries, so those two
// are declared as id rather than left out: the archiver walks the DECLARED property list, so a property
// that is not declared cannot be read back, and an archived speech reading would lose the two fields
// that say what was said and what was heard. Both are nullable in the 26.2 header
// (SRSpeechMetrics.h:151 and :152) and both read nil from the port with nothing archived under them,
// which is what the host's own SensorKit answers for a metrics object with no session - measured, in the
// section of facts/SensorKit/SensorKit.md that names the harness.
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
// speechRecognition is SFSpeechRecognitionResult * in the 26.2 header and soundClassification is
// SNClassificationResult *, and Speech and SoundAnalysis are not frameworks this package carries - so
// they are id here, for the reason the class comment above gives: a property the archiver cannot see
// cannot be read back.
@property (nonatomic, readonly, strong, nullable) id speechRecognition;
@property (nonatomic, readonly, strong, nullable) id soundClassification;
@end

@interface SRSpeechMetrics (CharonSensorKit172)
@property (nonatomic, readonly, assign) NSTimeInterval timeSinceAudioStart;
@end

// A wrist-temperature reading, and the session of readings that share a state. -temperatures is an
// NSEnumerator that this release has no way to produce, so the property is carried and reads nil.
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

// MARK: - The six classes the SDK declares, and the properties only 26.2 gives them

// Thirteen properties arrived after 16.4 on six classes those headers do declare, and a class that is
// declared cannot be declared again - so each of these is a CATEGORY carrying the properties the older
// headers lack. That is the same shape CharonMetricKit.h uses for the five properties it declares, and
// it is where a property a category declares is implemented.
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

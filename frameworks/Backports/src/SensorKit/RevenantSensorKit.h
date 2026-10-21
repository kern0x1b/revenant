#ifndef REVENANT_SENSORKIT_H
#define REVENANT_SENSORKIT_H

#import <Foundation/Foundation.h>
#import <CoreMedia/CoreMedia.h>
#import <SensorKit/SensorKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef CFTimeInterval SRAbsoluteTime;

typedef NSString *SRSensor;

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

@interface SRSpeechMetrics (RevenantSensorKit172)
@property (nonatomic, readonly, assign) NSTimeInterval timeSinceAudioStart;
@end

@interface SRApplicationUsage (RevenantSensorKit150)
@property (nonatomic, readonly, strong, nullable) NSString *reportApplicationIdentifier;
@property (nonatomic, readonly, strong, nullable) NSArray<SRTextInputSession *> *textInputSessions;
@end

@interface SRApplicationUsage (RevenantSensorKit164)
@property (nonatomic, readonly, assign) NSTimeInterval relativeStartTime;
@property (nonatomic, readonly, strong, nullable) NSArray<NSString *> *supplementalCategories;
@end


@interface SRDevice (RevenantSensorKit170)
@property (nonatomic, readonly, copy, nullable) NSString *productType;
@end


@interface SRDeviceUsageReport (RevenantSensorKit164)
@property (nonatomic, readonly, copy, nullable) NSString *version;
@end


@interface SRKeyboardMetrics (RevenantSensorKit150)
@property (nonatomic, readonly, copy, nullable) NSArray<NSString *> *inputModes;
@end

@interface SRKeyboardMetrics (RevenantSensorKit164)
@property (nonatomic, readonly, copy, nullable) NSArray<NSString *> *sessionIdentifiers;
@property (nonatomic, readonly, strong, nullable) NSArray<SRKeyboardProbabilityMetric *> *longWordTouchUpDown;
@property (nonatomic, readonly, strong, nullable) SRKeyboardProbabilityMetric *touchUpDown;
@end


@interface SRTextInputSession (RevenantSensorKit164)
@property (nonatomic, readonly, copy, nullable) NSString *sessionIdentifier;
@end


@interface SRWristDetection (RevenantSensorKit164)
@property (nonatomic, readonly, strong, nullable) NSDate *offWristDate;
@property (nonatomic, readonly, strong, nullable) NSDate *onWristDate;
@end


NS_ASSUME_NONNULL_END

#endif

#ifndef CHARON_SENSORKIT_NAMES_H
#define CHARON_SENSORKIT_NAMES_H

// The string constants of SensorKit after iOS 14.0, in ONE place, and read by both sides of the
// comparison that measures them.
//
// WHY A HEADER AND NOT SIX FILES' WORTH OF DEFINITIONS. An object carries the API of exactly one
// release (tools/release-split.lua refuses a file whose symbols first appear in two), so these
// eighteen constants belong to six objects - 15.0, 15.4, 16.4, 17.0, 17.4 and 26.0 - and each of those
// objects names only its own. Their VALUES, though, are one list, and the harness that proves them
// has to walk that whole list from a single host-compilable source: it links the port's own
// definitions into one process and prints them, and it hands the host's values from another. Writing
// the values twice - once in each release object, once in the harness - is the defect this header
// exists to prevent. So each release object defines its own guard and imports this, and the harness
// defines every guard and imports this, and there is one definition of each string in the tree.
//
// WHAT THE VALUES ARE. Every one of them is a const object-pointer VARIABLE in Apple's own headers -
// `SR_EXTERN SRSensor const SRSensorHeartRate` at SRSensors.h:276, `SR_EXTERN
// SRPhotoplethysmogramSampleUsage const SRPhotoplethysmogramSampleUsageDeepBreathing` at
// SRPhotoplethysmogramSample.h:223 - and SRSensor, SRPhotoplethysmogramSampleUsage and
// SRPhotoplethysmogramOpticalSampleCondition are each a typedef of NSString * in those headers. A
// variable has no value in a header at all, so no SDK this package compiles against spells one, and
// the 26.0 SDK that declares two of these names not their values either. The values here are the
// HOST's own SensorKit's, read out of it by dlsym: tests/backports/host/sensorkit-names opens
// /System/Library/Frameworks/SensorKit.framework in a process of its own and dereferences each
// symbol ONCE, because dlsym on a const object-pointer variable returns the address of the variable
// and the address of the variable is the string. That is what the values below are, byte for byte,
// and compare.py holds the two sides against each other name by name over the one list both walk.
//
// This is what the HOST's framework holds, and it is NOT a measurement of what an iOS device's
// SensorKit holds: no device has been asked. Every registry row for one of these names says so in its
// own effect, because a row that claims a device measurement it does not have is the defect this
// file's values would otherwise invite.
//
// Open source checked: swift-corelibs-foundation 6.x - not used. What is carried is Apple's own
// SensorKit surface, which no permitted project implements; the values are Apple's and the only
// honest source for them is Apple's own framework.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

// MARK: - iOS 15.0 - SRSensors.h:194 and :213

#ifdef CHARON_SENSORKIT_NAMES_15_0

NSString * const SRSensorSiriSpeechMetrics = (NSString *)CFSTR("com.apple.SensorKit.speechMetrics.siri");
NSString * const SRSensorTelephonySpeechMetrics = (NSString *)CFSTR("com.apple.SensorKit.speechMetrics.telephony");

#endif

// MARK: - iOS 15.4 - SRSensors.h:230

#ifdef CHARON_SENSORKIT_NAMES_15_4

NSString * const SRSensorAmbientPressure = (NSString *)CFSTR("com.apple.SensorKit.ambientPressure");

#endif

// MARK: - iOS 16.4 - SRSensors.h:246

#ifdef CHARON_SENSORKIT_NAMES_16_4

NSString * const SRSensorMediaEvents = (NSString *)CFSTR("com.apple.SensorKit.mediaEvents");

#endif

// MARK: - iOS 16.0 by the held ladder - SRSensors.h:276 and :307
//
// THE FILE IS NAMED FOR THE LADDER'S ANSWER, NOT THE HEADER'S. SRSensors.h declares both of these
// API_AVAILABLE(ios(17.0)), and the registry says introduced 17.0, and sdk-26.2-surface.tsv agrees -
// but modules/apple/backports.lua's check_releases asks dyld.first_releases which HELD release first
// exports the symbol, and that is 16.0 for these two. Measured over SensorKit160.o:
//
//   iOS 16.0  _SRSensorHeartRate _SRSensorOdometer
//
// An object carries the API of one release as the LADDER measures it, so these live in a file named for
// 16.0. The header's own date stays what it says; nothing here claims the name arrived in 16.0.
#ifdef CHARON_SENSORKIT_NAMES_16_0

NSString * const SRSensorHeartRate = (NSString *)CFSTR("com.apple.SensorKit.heart.rate");
NSString * const SRSensorOdometer = (NSString *)CFSTR("com.apple.SensorKit.odometer");

#endif

// MARK: - iOS 17.4 - SRPhotoplethysmogramSample.h:14, :15, :213, :223, :232 and :242

// The six photoplethysmogram values are the case the "#define NAME @\"NAME\"" rule gets wrong, and
// the harness is why they are carried at all: their value is the SUFFIX of the constant's own name,
// not the name, so a guess here would have produced six strings the system would not recognise.
#ifdef CHARON_SENSORKIT_NAMES_17_4

NSString * const SRPhotoplethysmogramOpticalSampleConditionSignalSaturation = (NSString *)CFSTR("SignalSaturation");
NSString * const SRPhotoplethysmogramOpticalSampleConditionUnreliableNoise = (NSString *)CFSTR("UnreliableNoise");
NSString * const SRPhotoplethysmogramSampleUsageForegroundHeartRate = (NSString *)CFSTR("ForegroundHeartRate");
NSString * const SRPhotoplethysmogramSampleUsageDeepBreathing = (NSString *)CFSTR("DeepBreathing");
NSString * const SRPhotoplethysmogramSampleUsageForegroundBloodOxygen = (NSString *)CFSTR("ForegroundBloodOxygen");
NSString * const SRPhotoplethysmogramSampleUsageBackgroundSystem = (NSString *)CFSTR("BackgroundSystem");

#endif

// MARK: - iOS 18.0 by the held ladder - SRSensors.h:295, :265, :320 and :332
//
// Four more the LADDER places at 18.0 while SRSensors.h declares them API_AVAILABLE(ios(17.0)) or
// ios(17.4). Measured over SensorKit180.o:
//
//   iOS 18.0  _SRSensorFaceMetrics _SRSensorWristTemperature
//             _SRSensorElectrocardiogram _SRSensorPhotoplethysmogram
//
// Four of them therefore share one file named for 18.0, where the two at 16.0 above cannot share it
// with them: one object, one release.
#ifdef CHARON_SENSORKIT_NAMES_18_0

NSString * const SRSensorFaceMetrics = (NSString *)CFSTR("com.apple.SensorKit.faceMetrics");
NSString * const SRSensorWristTemperature = (NSString *)CFSTR("com.apple.SensorKit.wristTemperature");
NSString * const SRSensorElectrocardiogram = (NSString *)CFSTR("com.apple.SensorKit.ECG");
NSString * const SRSensorPhotoplethysmogram = (NSString *)CFSTR("com.apple.SensorKit.PPG");

#endif

// MARK: - iOS 26.0 - SRSensors.h:345 and :357

#ifdef CHARON_SENSORKIT_NAMES_26_0

NSString * const SRSensorAcousticSettings = (NSString *)CFSTR("com.apple.SensorKit.hearing.acousticSettings");
NSString * const SRSensorSleepSessions = (NSString *)CFSTR("com.apple.SensorKit.sleep.sessions");

#endif

#endif
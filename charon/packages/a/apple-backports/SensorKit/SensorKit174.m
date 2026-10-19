#import "CharonSensorKit.h"
#import "CharonSensorKitValue.h"
#import "../CharonValueStore.h"

// SensorKit of iOS 17.4, the properties that arrived then.
@implementation SRElectrocardiogramData
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic flags, value;
CHARON_SCALAR_PROPERTY(SRElectrocardiogramDataFlags, flags)
CHARON_VALUE_PROPERTY(NSMeasurement *, value)
@end
@implementation SRElectrocardiogramData (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRElectrocardiogramSample
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic date, frequency, session, lead, data;
CHARON_VALUE_PROPERTY(NSDate *, date)
CHARON_VALUE_PROPERTY(NSMeasurement *, frequency)
CHARON_VALUE_PROPERTY(SRElectrocardiogramSession *, session)
CHARON_SCALAR_PROPERTY(SRElectrocardiogramLead, lead)
CHARON_VALUE_PROPERTY(NSArray *, data)
@end
@implementation SRElectrocardiogramSample (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRElectrocardiogramSession
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic state, sessionGuidance, identifier;
CHARON_SCALAR_PROPERTY(SRElectrocardiogramSessionState, state)
CHARON_SCALAR_PROPERTY(SRElectrocardiogramSessionGuidance, sessionGuidance)
CHARON_VALUE_PROPERTY(NSString *, identifier)
@end
@implementation SRElectrocardiogramSession (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRPhotoplethysmogramAccelerometerSample
@dynamic nanosecondsSinceStart, samplingFrequency, x, y, z;
CHARON_SCALAR_PROPERTY(int64_t, nanosecondsSinceStart)
CHARON_VALUE_PROPERTY(NSMeasurement *, samplingFrequency)
CHARON_VALUE_PROPERTY(NSMeasurement *, x)
CHARON_VALUE_PROPERTY(NSMeasurement *, y)
CHARON_VALUE_PROPERTY(NSMeasurement *, z)
@end
@implementation SRPhotoplethysmogramAccelerometerSample (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRPhotoplethysmogramOpticalSample
@dynamic emitter, activePhotodiodeIndexes, signalIdentifier, nominalWavelength, effectiveWavelength, samplingFrequency, nanosecondsSinceStart, backgroundNoiseOffset, conditions;
CHARON_SCALAR_PROPERTY(NSInteger, emitter)
CHARON_VALUE_PROPERTY(NSIndexSet *, activePhotodiodeIndexes)
CHARON_SCALAR_PROPERTY(NSInteger, signalIdentifier)
CHARON_VALUE_PROPERTY(NSMeasurement *, nominalWavelength)
CHARON_VALUE_PROPERTY(NSMeasurement *, effectiveWavelength)
CHARON_VALUE_PROPERTY(NSMeasurement *, samplingFrequency)
CHARON_SCALAR_PROPERTY(int64_t, nanosecondsSinceStart)
CHARON_VALUE_PROPERTY(NSNumber *, backgroundNoiseOffset)
CHARON_VALUE_PROPERTY(NSArray *, conditions)
// One of four properties the SDK declares in a CATEGORY of this class, so they are written out
// rather than @dynamic: a property a category declares cannot be implemented in a class
// implementation, and a second declaration of the name would collide with the SDK's own.
-(NSNumber *)backgroundNoise { return (NSNumber *)[self charon_valueForKey:@"backgroundNoise"]; }
-(void)charon_setBackgroundNoise:(NSNumber *)value { [self charon_setValue:value forKey:@"backgroundNoise"]; }
// One of four properties the SDK declares in a CATEGORY of this class, so they are written out
// rather than @dynamic: a property a category declares cannot be implemented in a class
// implementation, and a second declaration of the name would collide with the SDK's own.
-(NSNumber *)normalizedReflectance { return (NSNumber *)[self charon_valueForKey:@"normalizedReflectance"]; }
-(void)charon_setNormalizedReflectance:(NSNumber *)value { [self charon_setValue:value forKey:@"normalizedReflectance"]; }
// One of four properties the SDK declares in a CATEGORY of this class, so they are written out
// rather than @dynamic: a property a category declares cannot be implemented in a class
// implementation, and a second declaration of the name would collide with the SDK's own.
-(NSNumber *)pinkNoise { return (NSNumber *)[self charon_valueForKey:@"pinkNoise"]; }
-(void)charon_setPinkNoise:(NSNumber *)value { [self charon_setValue:value forKey:@"pinkNoise"]; }
// One of four properties the SDK declares in a CATEGORY of this class, so they are written out
// rather than @dynamic: a property a category declares cannot be implemented in a class
// implementation, and a second declaration of the name would collide with the SDK's own.
-(NSNumber *)whiteNoise { return (NSNumber *)[self charon_valueForKey:@"whiteNoise"]; }
-(void)charon_setWhiteNoise:(NSNumber *)value { [self charon_setValue:value forKey:@"whiteNoise"]; }

@end
@implementation SRPhotoplethysmogramOpticalSample (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRPhotoplethysmogramSample
CHARON_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic startDate, nanosecondsSinceStart, usage, opticalSamples, accelerometerSamples, temperature;
CHARON_VALUE_PROPERTY(NSDate *, startDate)
CHARON_SCALAR_PROPERTY(int64_t, nanosecondsSinceStart)
CHARON_VALUE_PROPERTY(NSArray *, usage)
CHARON_VALUE_PROPERTY(NSArray *, opticalSamples)
CHARON_VALUE_PROPERTY(NSArray *, accelerometerSamples)
CHARON_VALUE_PROPERTY(NSMeasurement *, temperature)
@end
@implementation SRPhotoplethysmogramSample (CharonSensorKitValue)
CHARON_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

// The SIX photoplethysmogram strings of iOS 17.4 stay, and the two SENSOR identifiers that shared this
// guard do not: check_releases places SRSensorElectrocardiogram and SRSensorPhotoplethysmogram at 18.0
// while this file is the 17.4 object, so they are in SensorKit180.m with the two that arrived beside
// them. Eight constants were here; six remain.

#define CHARON_SENSORKIT_NAMES_17_4
#import "CharonSensorKitNames.h"

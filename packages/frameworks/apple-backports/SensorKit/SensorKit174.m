#import "RevenantSensorKit.h"
#import "RevenantSensorKitValue.h"
#import "../RevenantValueStore.h"

@implementation SRElectrocardiogramData
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic flags, value;
REVENANT_SCALAR_PROPERTY(SRElectrocardiogramDataFlags, flags)
REVENANT_VALUE_PROPERTY(NSMeasurement *, value)
@end
@implementation SRElectrocardiogramData (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRElectrocardiogramSample
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic date, frequency, session, lead, data;
REVENANT_VALUE_PROPERTY(NSDate *, date)
REVENANT_VALUE_PROPERTY(NSMeasurement *, frequency)
REVENANT_VALUE_PROPERTY(SRElectrocardiogramSession *, session)
REVENANT_SCALAR_PROPERTY(SRElectrocardiogramLead, lead)
REVENANT_VALUE_PROPERTY(NSArray *, data)
@end
@implementation SRElectrocardiogramSample (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRElectrocardiogramSession
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic state, sessionGuidance, identifier;
REVENANT_SCALAR_PROPERTY(SRElectrocardiogramSessionState, state)
REVENANT_SCALAR_PROPERTY(SRElectrocardiogramSessionGuidance, sessionGuidance)
REVENANT_VALUE_PROPERTY(NSString *, identifier)
@end
@implementation SRElectrocardiogramSession (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRPhotoplethysmogramAccelerometerSample
@dynamic nanosecondsSinceStart, samplingFrequency, x, y, z;
REVENANT_SCALAR_PROPERTY(int64_t, nanosecondsSinceStart)
REVENANT_VALUE_PROPERTY(NSMeasurement *, samplingFrequency)
REVENANT_VALUE_PROPERTY(NSMeasurement *, x)
REVENANT_VALUE_PROPERTY(NSMeasurement *, y)
REVENANT_VALUE_PROPERTY(NSMeasurement *, z)
@end
@implementation SRPhotoplethysmogramAccelerometerSample (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRPhotoplethysmogramOpticalSample
@dynamic emitter, activePhotodiodeIndexes, signalIdentifier, nominalWavelength, effectiveWavelength, samplingFrequency, nanosecondsSinceStart, backgroundNoiseOffset, conditions;
REVENANT_SCALAR_PROPERTY(NSInteger, emitter)
REVENANT_VALUE_PROPERTY(NSIndexSet *, activePhotodiodeIndexes)
REVENANT_SCALAR_PROPERTY(NSInteger, signalIdentifier)
REVENANT_VALUE_PROPERTY(NSMeasurement *, nominalWavelength)
REVENANT_VALUE_PROPERTY(NSMeasurement *, effectiveWavelength)
REVENANT_VALUE_PROPERTY(NSMeasurement *, samplingFrequency)
REVENANT_SCALAR_PROPERTY(int64_t, nanosecondsSinceStart)
REVENANT_VALUE_PROPERTY(NSNumber *, backgroundNoiseOffset)
REVENANT_VALUE_PROPERTY(NSArray *, conditions)
-(NSNumber *)backgroundNoise { return (NSNumber *)[self revenant_valueForKey:@"backgroundNoise"]; }
-(void)revenant_setBackgroundNoise:(NSNumber *)value { [self revenant_setValue:value forKey:@"backgroundNoise"]; }
-(NSNumber *)normalizedReflectance { return (NSNumber *)[self revenant_valueForKey:@"normalizedReflectance"]; }
-(void)revenant_setNormalizedReflectance:(NSNumber *)value { [self revenant_setValue:value forKey:@"normalizedReflectance"]; }
-(NSNumber *)pinkNoise { return (NSNumber *)[self revenant_valueForKey:@"pinkNoise"]; }
-(void)revenant_setPinkNoise:(NSNumber *)value { [self revenant_setValue:value forKey:@"pinkNoise"]; }
-(NSNumber *)whiteNoise { return (NSNumber *)[self revenant_valueForKey:@"whiteNoise"]; }
-(void)revenant_setWhiteNoise:(NSNumber *)value { [self revenant_setValue:value forKey:@"whiteNoise"]; }

@end
@implementation SRPhotoplethysmogramOpticalSample (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end
@implementation SRPhotoplethysmogramSample
REVENANT_SENSORKIT_UNCREATABLE_NEW_AND_INIT(@"")
@dynamic startDate, nanosecondsSinceStart, usage, opticalSamples, accelerometerSamples, temperature;
REVENANT_VALUE_PROPERTY(NSDate *, startDate)
REVENANT_SCALAR_PROPERTY(int64_t, nanosecondsSinceStart)
REVENANT_VALUE_PROPERTY(NSArray *, usage)
REVENANT_VALUE_PROPERTY(NSArray *, opticalSamples)
REVENANT_VALUE_PROPERTY(NSArray *, accelerometerSamples)
REVENANT_VALUE_PROPERTY(NSMeasurement *, temperature)
@end
@implementation SRPhotoplethysmogramSample (RevenantSensorKitValue)
REVENANT_SENSORKIT_VALUE_STORE_IMPLEMENTATION
@end

#define REVENANT_SENSORKIT_NAMES_17_4
#import "RevenantSensorKitNames.h"

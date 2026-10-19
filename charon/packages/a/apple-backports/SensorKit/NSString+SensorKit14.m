// Nothing of the port's own is imported here, for the same reason SRAbsoluteTime.m imports nothing of
// the port's: this file needs no class, no typedef and no store, so importing CharonSensorKit.h would
// only drag its fifteen redeclared enumerations into a translation unit that has no use for them - and
// into the differential in tests/backports/host/sensorkit-tombstones, where the host's newer SensorKit
// spells those enumerations NS_ENUM and clang refuses the pair as "typedef redefinition with different
// types". SRSensor is NSString * (SRDefines.h), so spelling the return type here is the same type the
// SDK declares and no redeclaration is involved.
#import <Foundation/Foundation.h>

// -[NSString sr_sensorForDeletionRecordsFromSensor], of SRSensors+SRDeletionRecord.h, iOS 14.0.
//
// WHY THIS IS A CATEGORY ON A FOUNDATION CLASS HERE, when the row said it could not be. The row's reason
// was "the port adds no category to a Foundation class", and this framework contradicts that twice over
// already: NSDate+SensorKit14.m is a category on NSDate in this same folder, and that is the row for
// +[NSDate dateWithSRAbsoluteTime:]. What is true, and what the row should have said, is that the method
// has to name a deletion record's sensor - and that needs no sensor, no store and no device.
//
// WHAT IT ANSWERS, measured rather than guessed. The host's own SensorKit.framework carries this
// category and answers it, and the answers are over fifty inputs in
// tests/backports/host/sensorkit-tombstones: two processes, the port's category linked into one and the
// host's framework opened in the other, compared input by input. The rule the host holds is:
//
//   - a string that does NOT already end in ".tombstones"  ->  the string with ".tombstones" appended
//   - a string that DOES already end in ".tombstones"     ->  nil
//
// and it holds for inputs that are not sensor names at all: "" answers ".tombstones", "hello" answers
// "hello.tombstones", and "tombstones" - which has no leading dot - answers "tombstones.tombstones".
// Case and whitespace are preserved verbatim, so the rule is a suffix test and not a lookup table, and
// the method is idempotent in the way that matters: asking twice for the same record's sensor gives nil
// the second time instead of a name no store would recognise.
//
// The nil half is not decoration. The header declares the return `nullable`
// (SRSensors+SRDeletionRecord.h:15), and this is the only reading under which the nullable exists: a
// deletion record's sensor is a sensor name with the tombstone suffix already on it, and handing that
// back would be handing an application a sensor that collects nothing and never will.

static NSString *const CharonSensorKitTombstoneSuffix = @".tombstones";

@implementation NSString (SRDeletionRecord)

- (NSString *)sr_sensorForDeletionRecordsFromSensor
{
    if ([self hasSuffix:CharonSensorKitTombstoneSuffix])
        return nil;
    return [self stringByAppendingString:CharonSensorKitTombstoneSuffix];
}

@end
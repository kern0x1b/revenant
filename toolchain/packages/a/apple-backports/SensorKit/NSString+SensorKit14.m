#import <Foundation/Foundation.h>

static NSString *const CharonSensorKitTombstoneSuffix = @".tombstones";

@implementation NSString (SRDeletionRecord)

- (NSString *)sr_sensorForDeletionRecordsFromSensor
{
    if ([self hasSuffix:CharonSensorKitTombstoneSuffix])
        return nil;
    return [self stringByAppendingString:CharonSensorKitTombstoneSuffix];
}

@end

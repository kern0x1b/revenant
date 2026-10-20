#import <Foundation/Foundation.h>

static NSString *const RevenantSensorKitTombstoneSuffix = @".tombstones";

@implementation NSString (SRDeletionRecord)

- (NSString *)sr_sensorForDeletionRecordsFromSensor
{
    if ([self hasSuffix:RevenantSensorKitTombstoneSuffix])
        return nil;
    return [self stringByAppendingString:RevenantSensorKitTombstoneSuffix];
}

@end

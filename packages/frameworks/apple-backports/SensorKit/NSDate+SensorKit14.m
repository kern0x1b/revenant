#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

#import <SensorKit/SRAbsoluteTime.h>

extern SRAbsoluteTime SRAbsoluteTimeGetCurrent(void);
extern CFAbsoluteTime SRAbsoluteTimeToCFAbsoluteTime(SRAbsoluteTime sr);
extern SRAbsoluteTime SRAbsoluteTimeFromCFAbsoluteTime(CFAbsoluteTime cf);

@interface NSDate (RevenantSensorKit)

+ (instancetype)dateWithSRAbsoluteTime:(SRAbsoluteTime)time;
- (instancetype)initWithSRAbsoluteTime:(SRAbsoluteTime)time;
- (SRAbsoluteTime)srAbsoluteTime;

@end

@implementation NSDate (RevenantSensorKit)

+ (instancetype)dateWithSRAbsoluteTime:(SRAbsoluteTime)time
{
    return [[self alloc] initWithSRAbsoluteTime:time];
}

- (instancetype)initWithSRAbsoluteTime:(SRAbsoluteTime)time
{
    return [self initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)SRAbsoluteTimeToCFAbsoluteTime(time)];
}

- (SRAbsoluteTime)srAbsoluteTime
{
    return SRAbsoluteTimeFromCFAbsoluteTime((CFAbsoluteTime)self.timeIntervalSinceReferenceDate);
}

@end

// The NSDate side of SensorKit's absolute time, which arrived in iOS 14.0.
//
// The category is three thin wrappers over the conversions this package already has: an SRAbsoluteTime
// and a CFAbsoluteTime are the same instant read on two clocks, joined by the one anchor in
// SensorKit/SRAbsoluteTime.m, and SRAbsoluteTimeToCFAbsoluteTime and SRAbsoluteTimeFromCFAbsoluteTime
// are each other's inverse through it. So nothing here computes anything of its own, and the numbers
// the header's three relations are about are the ones the existing time functions already answer.
//
//   +[NSDate dateWithSRAbsoluteTime:]  the date an SRAbsoluteTime names
//   -[NSDate initWithSRAbsoluteTime:]  the same, as an initializer
//   -[NSDate srAbsoluteTime]           the SRAbsoluteTime a date names
//
// The header's own declaration, in SensorKit.framework/Headers/NSDate+SensorKit.h of the SDK 16.4 this
// package compiles against:
//
//   @interface NSDate (CharonSensorKit)
//   + (instancetype)dateWithSRAbsoluteTime:(SRAbsoluteTime)time;
//   - (instancetype)initWithSRAbsoluteTime:(SRAbsoluteTime)time;
//   @property (readonly) SRAbsoluteTime srAbsoluteTime;
//   @end
//
// SRAbsoluteTime is CFTimeInterval (SRAbsoluteTime.h:14) and the category is marked
// API_UNAVAILABLE(macOS). That marking is why the host differential asks for these three through a
// SELECTOR rather than a typed call: a host translation unit may write @selector(...) - a selector
// expression needs no declaration - but it may not declare or call the method, which is why the port's
// half is built with rename.h and the host's is not. The host's own build has all three, so the two
// sides are held to the same three relations. See facts/SensorKit/SensorKit.md and
// tests/backports/host/sensorkit.
//
// Open source checked: swift-corelibs-foundation 6.x - not used. The arithmetic is Foundation's own
// NSTimeInterval read through this package's existing conversion pair, and nothing here reimplements
// either; the surface is Apple's, and no permitted project implements SensorKit.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>

// The typedef, from SensorKit's own header - the same one SRAbsoluteTime.m imports for it. NOT
// CharonSensorKit.h: that header redeclares the framework's classes for the SDK 16.4 this package
// compiles against, and a host build - the macOS SDK has all of them - would see every one twice.
//
// The three functions are the port's own, from SRAbsoluteTime.m, which carries them because the SDK
// 16.4 headers do not name them. They are the clock pair this category is three wrappers over, and they
// are each other's inverse through the one anchor that file reads.
#import <SensorKit/SRAbsoluteTime.h>

extern SRAbsoluteTime SRAbsoluteTimeGetCurrent(void);
extern CFAbsoluteTime SRAbsoluteTimeToCFAbsoluteTime(SRAbsoluteTime sr);
extern SRAbsoluteTime SRAbsoluteTimeFromCFAbsoluteTime(CFAbsoluteTime cf);

// THE SDK'S OWN NAMES, and that is the whole of what was wrong with the first version of this
// category. A program compiled against the 14.0 SDK sends `dateWithSRAbsoluteTime:` and the runtime
// looks the selector up on NSDate: a method spelled `charon_dateWithSRAbsoluteTime:` is a DIFFERENT
// selector, so nothing sent by such a program would ever reach this code, and the 6.1.3 gate said so in
// the only way it could - "listed as implemented, but nothing of that name is built". The harness renames
// them for the PORT'S half only, exactly as it renames the four time functions, because one binary
// carries this category and the host's own SensorKit and the two must not shadow each other.
@interface NSDate (CharonSensorKit)

+ (instancetype)dateWithSRAbsoluteTime:(SRAbsoluteTime)time;
- (instancetype)initWithSRAbsoluteTime:(SRAbsoluteTime)time;
- (SRAbsoluteTime)srAbsoluteTime;

@end

@implementation NSDate (CharonSensorKit)

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

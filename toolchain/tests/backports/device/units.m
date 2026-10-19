#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/message.h>
#import "check.h"

static NSString *image_of(Class cls)
{
    Dl_info info;
    return dladdr((__bridge const void *)cls, &info) ? @(info.dli_fname).lastPathComponent : @"?";
}

static BOOL close_enough(double actual, double expected)
{
    return fabs(actual - expected) <= fabs(expected) * 1e-12;
}

static NSString *raised(void (^block)(void))
{
    @try {
        block();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing";
}

@interface CharonPartialArchive : NSObject <NSCoding>
@property (nonatomic, copy) NSDictionary *keys;
@end

@implementation CharonPartialArchive

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return nil;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    for (NSString *key in self.keys) {
        id value = self.keys[key];
        if ([value isKindOfClass:[NSNumber class]])
            [coder encodeDouble:[value doubleValue] forKey:key];
        else
            [coder encodeObject:value forKey:key];
    }
}

@end

static id decode_as(NSString *className, NSDictionary *keys, NSError **error)
{
    NSMutableData *data = [NSMutableData data];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    [archiver setClassName:className forClass:[CharonPartialArchive class]];
    CharonPartialArchive *partial = [[CharonPartialArchive alloc] init];
    partial.keys = keys;
    [archiver encodeObject:partial forKey:@"root"];
    [archiver finishEncoding];
    NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
    unarchiver.decodingFailurePolicy = NSDecodingFailurePolicySetErrorAndReturn;
    id object = [unarchiver decodeObjectForKey:@"root"];
    if (error)
        *error = unarchiver.error;
    [unarchiver finishDecoding];
    return object;
}

int main(void)
{
    @autoreleasepool {
        for (NSString *name in @[@"NSUnit", @"NSDimension", @"NSUnitConverterLinear", @"NSUnitLength",
                                 @"NSMeasurement", @"NSDateInterval"])
            CHECK_EQUAL(image_of(NSClassFromString(name)), @"libFoundationBackports.dylib",
                        [name stringByAppendingString:@" comes from the backports library"].UTF8String);

        CHECK_EQUAL([NSUnitLength baseUnit].symbol, @"m", "the base unit of length is the metre");
        CHECK_EQUAL([NSUnitMass baseUnit].symbol, @"kg", "the base unit of mass is the kilogramme");
        CHECK_EQUAL([NSUnitTemperature baseUnit].symbol, @"K", "the base unit of temperature is the kelvin");
        CHECK([NSUnitLength meters] == [NSUnitLength meters], "a unit is a singleton");
        CHECK_EQUAL([NSUnitLength micrometers].symbol, @"\u00b5m", "a symbol outside ASCII survives");
        CHECK_EQUAL([NSUnitElectricResistance ohms].symbol, @"\u2126",
                    "the ohm keeps the sign Apple uses, U+2126, not the Greek omega it is drawn like");
        CHECK_EQUAL([NSUnitArea squareKilometers].symbol, @"km\u00b2", "a squared symbol keeps its exponent");

        CHECK(close_enough([[NSUnitLength miles].converter baseUnitValueFromValue:1], 1609.344),
              "a mile is 1609.344 metres");
        CHECK(close_enough([[NSUnitMass stones].converter baseUnitValueFromValue:1], 6.35029),
              "a stone is 6.35029 kilogrammes, not the reciprocal iOS 10 used");
        CHECK(close_enough([[NSUnitTemperature celsius].converter baseUnitValueFromValue:0], 273.15),
              "zero celsius is 273.15 kelvin");
        CHECK(close_enough([[NSUnitTemperature fahrenheit].converter valueFromBaseUnitValue:273.15], 32),
              "zero celsius is 32 fahrenheit");
        CHECK(close_enough([[NSUnitFuelEfficiency milesPerGallon].converter baseUnitValueFromValue:30], 7.8405),
              "thirty miles per gallon is 7.8405 litres per 100 km");

        NSMeasurement *twoKilometres = [[NSMeasurement alloc] initWithDoubleValue:2 unit:[NSUnitLength kilometers]];
        NSMeasurement *fiveHundredMetres = [[NSMeasurement alloc] initWithDoubleValue:500 unit:[NSUnitLength meters]];
        CHECK([twoKilometres measurementByConvertingToUnit:[NSUnitLength meters]].doubleValue == 2000,
              "two kilometres are two thousand metres");
        NSMeasurement *sum = [twoKilometres measurementByAddingMeasurement:fiveHundredMetres];
        CHECK(sum.doubleValue == 2500 && [sum.unit isEqual:[NSUnitLength meters]],
              "differing units are added in the base unit");
        NSMeasurement *plain = [twoKilometres measurementByAddingMeasurement:
                                   [[NSMeasurement alloc] initWithDoubleValue:3 unit:[NSUnitLength kilometers]]];
        CHECK(plain.doubleValue == 5 && [plain.unit isEqual:[NSUnitLength kilometers]],
              "equal units are added in that unit");
        CHECK(![twoKilometres isEqual:[[NSMeasurement alloc] initWithDoubleValue:2000 unit:[NSUnitLength meters]]],
              "a measurement is not equal to the same length in another unit");
        CHECK(![twoKilometres canBeConvertedToUnit:[NSUnitTemperature celsius]],
              "a length cannot be converted to a temperature");

        @try {
            [twoKilometres measurementByAddingMeasurement:
                [[NSMeasurement alloc] initWithDoubleValue:1 unit:[NSUnitTemperature celsius]]];
            CHECK(NO, "adding differing unit types raises");
        } @catch (NSException *exception) {
            CHECK([exception.name isEqual:NSInvalidArgumentException]
                  && [exception.reason hasPrefix:@"Cannot add measurements of differing unit types!"],
                  "adding differing unit types raises");
        }

        NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:twoKilometres];
        NSMeasurement *back = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
        CHECK_EQUAL(back, twoKilometres, "a measurement survives an archive");
        CHECK_EQUAL(back.unit.symbol, @"km", "the unit survives an archive");

        NSDate *epoch = [NSDate dateWithTimeIntervalSinceReferenceDate:0];
        NSDateInterval *ten = [[NSDateInterval alloc] initWithStartDate:epoch duration:10];
        NSDateInterval *overlapping = [[NSDateInterval alloc] initWithStartDate:[epoch dateByAddingTimeInterval:5]
                                                                      duration:10];
        CHECK(ten.endDate.timeIntervalSinceReferenceDate == 10, "the end date is the start plus the duration");
        CHECK([ten containsDate:epoch] && [ten containsDate:[epoch dateByAddingTimeInterval:10]],
              "the interval is closed at both ends");
        CHECK(![ten containsDate:[epoch dateByAddingTimeInterval:10.5]], "a date past the end is not contained");
        CHECK([ten intersectsDateInterval:overlapping], "overlapping intervals intersect");
        NSDateInterval *cut = [ten intersectionWithDateInterval:overlapping];
        CHECK(cut.startDate.timeIntervalSinceReferenceDate == 5 && cut.duration == 5,
              "the intersection is the later start to the earlier end");
        CHECK([ten intersectionWithDateInterval:
                  [[NSDateInterval alloc] initWithStartDate:[epoch dateByAddingTimeInterval:20] duration:1]] == nil,
              "intervals that do not meet intersect in nil");
        CHECK([ten compare:overlapping] == NSOrderedAscending, "an earlier interval orders first");
        NSDateInterval *backAgain = [NSKeyedUnarchiver unarchiveObjectWithData:
                                        [NSKeyedArchiver archivedDataWithRootObject:ten]];
        CHECK_EQUAL(backAgain, ten, "an interval survives an archive");

        NSDate *start = [NSDate dateWithTimeIntervalSinceReferenceDate:10], *end = [NSDate dateWithTimeIntervalSinceReferenceDate:15];
        NSDate *none = nil;
        CHECK_EQUAL(raised(^{ (void)[[NSDateInterval alloc] initWithStartDate:none duration:1]; }),
                    @"NSInvalidArgumentException: Start date is nil!", "an interval with no start raises");
        CHECK_EQUAL(raised(^{ (void)[[NSDateInterval alloc] initWithStartDate:start duration:-1]; }),
                    @"NSInvalidArgumentException: Duration is less than 0!", "a negative duration raises");
        CHECK_EQUAL(raised(^{ (void)[[NSDateInterval alloc] initWithStartDate:start duration:NAN]; }), @"nothing",
                    "a duration that is not a number passes, as on every release");
        CHECK_EQUAL(raised(^{ (void)[[NSDateInterval alloc] initWithStartDate:start endDate:none]; }),
                    @"NSInvalidArgumentException: End date is nil!", "an interval with no end raises");
        CHECK_EQUAL(raised(^{ (void)[[NSDateInterval alloc] initWithStartDate:end endDate:start]; }),
                    @"NSGenericException: Start date cannot be later in time than end date!",
                    "an interval that ends before it starts raises");
        CHECK(![ten containsDate:none] && ![ten intersectsDateInterval:(id)none]
              && [ten intersectionWithDateInterval:(id)none] == nil, "no date and no interval meet nothing");

        NSError *error = nil;
        NSDateInterval *byDuration = decode_as(@"NSDateInterval", @{@"NS.startDate": start, @"NS.duration": @5}, &error);
        CHECK(byDuration.duration == 5 && !error, "an archive with a duration decodes by it");
        NSDateInterval *startOnly = decode_as(@"NSDateInterval", @{@"NS.startDate": start}, &error);
        CHECK(startOnly != nil && startOnly.duration == 0 && !error, "an archive with a start alone decodes to no duration");
        NSDateInterval *endOnly = decode_as(@"NSDateInterval", @{@"NS.endDate": end}, &error);
        CHECK(endOnly == nil && [error.domain isEqual:NSCocoaErrorDomain] && error.code == 4865,
              "an archive with no start fails the coder with 4865");
        NSData *intervalArchive = [NSKeyedArchiver archivedDataWithRootObject:ten];
        NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:intervalArchive options:0 format:NULL error:NULL];
        BOOL hasDuration = NO;
        for (id object in plist[@"$objects"])
            if ([object isKindOfClass:[NSDictionary class]] && object[@"NS.duration"])
                hasDuration = YES;
        CHECK(hasDuration, "an interval is archived with its duration beside its dates");

        CHECK_EQUAL(raised(^{ (void)((id (*)(id, SEL))objc_msgSend)([NSUnit alloc], @selector(init)); }),
                    @"NSGenericException: -init should never be called on NSUnit!", "a unit made with -init raises");
        CHECK(![[[NSUnit alloc] initWithSymbol:@"m"] isEqual:[NSUnitLength meters]],
              "a plain unit of m is not metres: the classes differ");
        id noSymbol = decode_as(@"NSUnit", @{}, &error);
        CHECK(noSymbol == nil && error.code == 4865, "a unit archived with no symbol fails the coder with 4865");

        printf("%d checks, %d failures\n", charon_checks, charon_failures);
        return charon_failures;
    }
}

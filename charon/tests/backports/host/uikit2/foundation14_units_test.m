#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

static uint64_t state = 0xB17B17E5ull;

static uint32_t next(void)
{
    state = state * 6364136223846793005ull + 1442695040888963407ull;
    return (uint32_t)(state >> 33);
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        Class ours = NSClassFromString(@"CharonHostNSUnitInformationStorage");
        Class ourMeasurement = NSClassFromString(@"CharonHostNSMeasurement");
        CHECK(ours != Nil && ourMeasurement != Nil, "the port defines the unit and the measurement");
        NSArray *names = @[@"bits", @"nibbles", @"bytes", @"kilobits", @"kilobytes", @"kibibits", @"kibibytes", @"megabits", @"megabytes", @"mebibits", @"mebibytes", @"gigabits", @"gigabytes",
                           @"gibibits", @"gibibytes", @"terabits", @"terabytes", @"tebibits", @"tebibytes", @"petabits", @"petabytes", @"pebibits", @"pebibytes", @"exabits", @"exabytes",
                           @"exbibits", @"exbibytes", @"zettabits", @"zettabytes", @"zebibits", @"zebibytes", @"yottabits", @"yottabytes", @"yobibits", @"yobibytes"];
        CHECK(names.count == 35, "there are 35 units");
        NSUInteger wrong = 0;
        for (NSString *name in names) {
            NSUnitInformationStorage *port = ((id (*)(id, SEL))objc_msgSend)(ours, NSSelectorFromString(name));
            NSUnitInformationStorage *system = ((id (*)(id, SEL))objc_msgSend)([NSUnitInformationStorage class], NSSelectorFromString(name));
            NSUnitConverterLinear *a = (id)port.converter, *b = (id)system.converter;
            BOOL same = [port.symbol isEqualToString:system.symbol] && a.coefficient == b.coefficient && a.constant == b.constant &&
                        [[port valueForKey:@"specifier"] isEqual:[system valueForKey:@"specifier"]] &&
                        port == ((id (*)(id, SEL))objc_msgSend)(ours, NSSelectorFromString(name)) && [NSStringFromClass([port class]) isEqualToString:@"CharonHostNSUnitInformationStorage"];
            if (!same) {
                wrong++;
                printf("  %s: port %s %a %a %@ | system %s %a %a %@\n", name.UTF8String, port.symbol.UTF8String, a.coefficient, a.constant, [port valueForKey:@"specifier"], system.symbol.UTF8String, b.coefficient, b.constant, [system valueForKey:@"specifier"]);
            }
        }
        CHECK(wrong == 0, "every unit has the symbol, the converter and the specifier the system's has");
        CHECK([((NSUnit *)[ours baseUnit]).symbol isEqualToString:[NSUnitInformationStorage baseUnit].symbol], "the base unit is bytes");

        NSUInteger cases = argc > 1 ? (NSUInteger)atoi(argv[1]) : 60000, differing = 0;
        for (NSUInteger index = 0; index < cases; index++) {
            NSString *from = names[next() % names.count], *to = names[next() % names.count];
            double value = next() % 5 == 0 ? (double)(int32_t)next() : ((double)next() / 65536.0) * pow(10.0, (double)(int)(next() % 20) - 6.0) * (next() % 2 ? 1 : -1);
            id portFrom = ((id (*)(id, SEL))objc_msgSend)(ours, NSSelectorFromString(from)), portTo = ((id (*)(id, SEL))objc_msgSend)(ours, NSSelectorFromString(to));
            NSMeasurement *system = [[NSMeasurement alloc] initWithDoubleValue:value unit:((id (*)(id, SEL))objc_msgSend)([NSUnitInformationStorage class], NSSelectorFromString(from))];
            id port = ((id (*)(id, SEL, double, id))objc_msgSend)([ourMeasurement alloc], @selector(initWithDoubleValue:unit:), value, portFrom);
            double theirs = [[system measurementByConvertingToUnit:((id (*)(id, SEL))objc_msgSend)([NSUnitInformationStorage class], NSSelectorFromString(to))] doubleValue];
            double mine = [[port measurementByConvertingToUnit:portTo] doubleValue];
            if (!(mine == theirs || (isnan(mine) && isnan(theirs)))) {
                differing++;
                if (differing < 6)
                    printf("  %g %s -> %s: port %.17g system %.17g\n", value, from.UTF8String, to.UTF8String, mine, theirs);
            }
        }
        CHECK(differing == 0, "random measurements convert between units to the last bit as the system's do");

        id custom = [[ours alloc] initWithSymbol:@"q" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3]];
        NSUnitInformationStorage *systemCustom = [[NSUnitInformationStorage alloc] initWithSymbol:@"q" converter:[[NSUnitConverterLinear alloc] initWithCoefficient:3]];
        CHECK([[custom valueForKey:@"specifier"] isEqual:[systemCustom valueForKey:@"specifier"]] && [[custom symbol] isEqual:@"q"], "a unit made by hand has no specifier, as the system's has none");
        id k1 = ((id (*)(id, SEL))objc_msgSend)(ours, @selector(kibibytes)), k2 = ((id (*)(id, SEL))objc_msgSend)(ours, @selector(kibibytes));
        CHECK([k1 isEqual:k2] && ![k1 isEqual:((id (*)(id, SEL))objc_msgSend)(ours, @selector(kilobytes))], "units are equal to themselves and not to their neighbours");
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:k1 requiringSecureCoding:YES error:NULL];
        NSError *error = nil;
        NSUnit *decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:ours, [NSUnit class], nil] fromData:archive error:&error];
        CHECK(decoded != nil && [decoded.symbol isEqualToString:@"KiB"] && [decoded isKindOfClass:ours], "a unit survives its own archive");
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}

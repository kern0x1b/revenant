#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "check.h"

static Class base, image;

@interface CharonGamutlessTraits : NSObject
@end

@implementation CharonGamutlessTraits

- (CGFloat)displayScale
{
    return 3;
}

@end

static NSString *caught(id (^work)(void), id *made)
{
    @try {
        *made = work();
    } @catch (NSException *exception) {
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
    return @"nothing raised";
}

static NSString *described(id format)
{
    if (!format)
        return @"nil";
    NSString *kind = [format isKindOfClass:image] ? @"image format" : [format isKindOfClass:base] ? @"format" : NSStringFromClass([format class]);
    UIGraphicsImageRendererFormat *held = format;
    NSMutableString *text = [NSMutableString stringWithFormat:@"%@, bounds %@", kind, NSStringFromCGRect(held.bounds)];
    if ([format isKindOfClass:image])
        [text appendFormat:@", scale %g, opaque %d, extended %d", held.scale, held.opaque, held.prefersExtendedRange];
    return text;
}

static void record(NSMutableArray *into, const char *step, NSString *value)
{
    [into addObject:@[@(step), value ?: @"nothing"]];
}

static NSString *for_traits(UITraitCollection *traits)
{
    id made = nil;
    NSString *raised = caught(^id { return ((id (*)(id, SEL, id))objc_msgSend)(image, @selector(formatForTraitCollection:), traits); }, &made);
    return [NSString stringWithFormat:@"%@; %@", raised, described(made)];
}

static UITraitCollection *traits(NSArray *parts)
{
    return [UITraitCollection traitCollectionWithTraitsFromCollections:parts];
}

static void script(NSMutableArray *into)
{
    id made = nil;
    caught(^id { return ((id (*)(id, SEL))objc_msgSend)(base, @selector(preferredFormat)); }, &made);
    record(into, "the preferred format of the base class", described(made));
    record(into, "is a new one each time", ((id (*)(id, SEL))objc_msgSend)(base, @selector(preferredFormat)) != ((id (*)(id, SEL))objc_msgSend)(base, @selector(preferredFormat)) ? @"yes" : @"no");
    caught(^id { return ((id (*)(id, SEL))objc_msgSend)(image, @selector(preferredFormat)); }, &made);
    record(into, "the preferred format of the image class", described(made));
    record(into, "and its default format", described(((id (*)(id, SEL))objc_msgSend)(image, @selector(defaultFormat))));

    record(into, "for no traits at all", for_traits(nil));
    record(into, "for an empty collection", for_traits(traits(@[])));
    record(into, "for scale 3", for_traits([UITraitCollection traitCollectionWithDisplayScale:3]));
    record(into, "for scale 1", for_traits([UITraitCollection traitCollectionWithDisplayScale:1]));
    record(into, "for scale 0", for_traits([UITraitCollection traitCollectionWithDisplayScale:0]));
    record(into, "for a scale below the float epsilon but above the double one", for_traits([UITraitCollection traitCollectionWithDisplayScale:1e-9]));
    record(into, "for a scale below the double epsilon", for_traits([UITraitCollection traitCollectionWithDisplayScale:1e-17]));
    record(into, "for a negative scale", for_traits([UITraitCollection traitCollectionWithDisplayScale:-2]));
    record(into, "for the sRGB gamut", for_traits([UITraitCollection traitCollectionWithDisplayGamut:UIDisplayGamutSRGB]));
    record(into, "for the P3 gamut", for_traits([UITraitCollection traitCollectionWithDisplayGamut:UIDisplayGamutP3]));
    record(into, "for an unspecified gamut", for_traits([UITraitCollection traitCollectionWithDisplayGamut:UIDisplayGamutUnspecified]));
    record(into, "for scale 2 and the P3 gamut", for_traits(traits(@[[UITraitCollection traitCollectionWithDisplayScale:2],
                                                                   [UITraitCollection traitCollectionWithDisplayGamut:UIDisplayGamutP3]])));
    record(into, "for traits that say nothing about the display", for_traits([UITraitCollection traitCollectionWithHorizontalSizeClass:UIUserInterfaceSizeClassCompact]));
}

int main(void)
{
    @autoreleasepool {
        NSMutableArray *system = [NSMutableArray array], *port = [NSMutableArray array];
        base = [UIGraphicsRendererFormat class];
        image = [UIGraphicsImageRendererFormat class];
        script(system);

        base = NSClassFromString(@"CharonHostUIGraphicsRendererFormat");
        image = NSClassFromString(@"CharonHostUIGraphicsImageRendererFormat");
        BOOL carried = base != Nil && image != Nil;
        CHECK(carried, "the port carries the formats to ask");
        if (carried)
            script(port);
        for (NSUInteger index = 0; index < system.count; index++) {
            NSArray *mine = index < port.count ? port[index] : nil;
            NSString *expected = system[index][1], *actual = mine ? mine[1] : @"nothing";
            printf("  %s: %s\n", [system[index][0] UTF8String], expected.UTF8String);
            charon_check([expected isEqual:actual], [system[index][0] UTF8String],
                         [NSString stringWithFormat:@"%@ != %@", actual, expected]);
        }
        if (carried) {
            NSString *gamutless = for_traits((UITraitCollection *)[[CharonGamutlessTraits alloc] init]);
            NSString *wanted = system[6][1];
            printf("  for traits of a release that has no gamut: %s\n", gamutless.UTF8String);
            charon_check([gamutless isEqual:wanted], "for traits of a release that has no gamut",
                         [NSString stringWithFormat:@"%@ != %@", gamutless, wanted]);
        }
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}

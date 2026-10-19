#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

static Class flavor;

static UITraitCollection *with_style(UIUserInterfaceStyle style)
{
    return ((id (*)(Class, SEL, UIUserInterfaceStyle))objc_msgSend)(flavor, @selector(traitCollectionWithUserInterfaceStyle:), style);
}

static UITraitCollection *with_scale(CGFloat scale)
{
    return ((id (*)(Class, SEL, CGFloat))objc_msgSend)(flavor, @selector(traitCollectionWithDisplayScale:), scale);
}

static UITraitCollection *empty(void)
{
    return [[flavor alloc] init];
}

static UITraitCollection *merged(NSArray *collections)
{
    return ((id (*)(Class, SEL, NSArray *))objc_msgSend)(flavor, @selector(traitCollectionWithTraitsFromCollections:), collections);
}

static NSString *style_of(UITraitCollection *collection)
{
    UIUserInterfaceStyle style = ((UIUserInterfaceStyle (*)(id, SEL))objc_msgSend)(collection, @selector(userInterfaceStyle));
    switch (style) {
        case UIUserInterfaceStyleUnspecified: return @"unspecified";
        case UIUserInterfaceStyleLight: return @"light";
        case UIUserInterfaceStyleDark: return @"dark";
    }
    return [NSString stringWithFormat:@"%ld", (long)style];
}

static void record(NSMutableArray *into, const char *step, NSString *value)
{
    [into addObject:@[@(step), value ?: @"nil"]];
}

static NSString *yes_no(BOOL held)
{
    return held ? @"yes" : @"no";
}

static void script(NSMutableArray *into)
{
    UITraitCollection *light = with_style(UIUserInterfaceStyleLight);
    UITraitCollection *dark = with_style(UIUserInterfaceStyleDark);
    UITraitCollection *none = with_style(UIUserInterfaceStyleUnspecified);
    UITraitCollection *scale = with_scale(2);
    UITraitCollection *nothing = empty();

    record(into, "a collection built light", style_of(light));
    record(into, "a collection built dark", style_of(dark));
    record(into, "a collection built unspecified", style_of(none));
    record(into, "a collection of a scale alone", style_of(scale));
    record(into, "a collection of nothing at all", style_of(nothing));

    record(into, "light merged over nothing", style_of(merged(@[light, none])));
    record(into, "nothing merged over light", style_of(merged(@[none, light])));
    record(into, "light merged over a scale", style_of(merged(@[light, scale])));
    record(into, "a scale merged over light", style_of(merged(@[scale, light])));
    record(into, "dark merged over light", style_of(merged(@[light, dark])));

    record(into, "unspecified is the same as empty", yes_no([none isEqual:nothing]));
    record(into, "and hashes the same", yes_no(none.hash == nothing.hash));
    record(into, "light is not the same as empty", yes_no(![light isEqual:nothing]));
    record(into, "and hashes differently", yes_no(light.hash != nothing.hash));

    UITraitCollection *both = merged(@[scale, light]);
    record(into, "a collection with the style contains light", yes_no([both containsTraitsInCollection:light]));
    record(into, "light contains a collection that also has a scale", yes_no([light containsTraitsInCollection:both]));
    record(into, "light contains unspecified, which asks for nothing", yes_no([light containsTraitsInCollection:none]));
    record(into, "empty contains light", yes_no([nothing containsTraitsInCollection:light]));

    record(into, "the description names the style", yes_no([light.description containsString:@"UserInterfaceStyle"]));
    record(into, "and says nothing of it when it is unset", yes_no(![nothing.description containsString:@"UserInterfaceStyle"]));

    record(into, "a copy is the collection itself", yes_no([light copy] == light));

    NSData *archived = [NSKeyedArchiver archivedDataWithRootObject:light];
    UITraitCollection *read = archived ? [NSKeyedUnarchiver unarchiveObjectWithData:archived] : nil;
    record(into, "the style survives an archive", read ? style_of(read) : @"nothing came back");
}

static NSString *environment_style(void)
{
    if (flavor == [UITraitCollection class])
        return style_of([UIScreen mainScreen].traitCollection);
    SEL built = @selector(charon_traitCollectionForScreen:);
    if (![flavor respondsToSelector:built])
        return @"the port builds no collection for a screen";
    UITraitCollection *screen = ((id (*)(Class, SEL, UIScreen *))objc_msgSend)(flavor, built, [UIScreen mainScreen]);
    return style_of(screen);
}

int main(void)
{
    @autoreleasepool {
        NSMutableArray *system = [NSMutableArray array], *ours = [NSMutableArray array];
        flavor = [UITraitCollection class];
        script(system);
        NSString *systemScreen = environment_style();

        Class ported = NSClassFromString(@"CharonHostUITraitCollection");
        BOOL carried = ported != Nil
            && [ported respondsToSelector:@selector(traitCollectionWithUserInterfaceStyle:)]
            && [ported instancesRespondToSelector:@selector(userInterfaceStyle)];
        CHECK(carried, "the port carries the user interface style of a trait collection");
        if (carried) {
            flavor = ported;
            script(ours);
            NSString *ourScreen = environment_style();
            charon_check([ourScreen isEqual:systemScreen], "the collection a screen is given carries the style",
                         [NSString stringWithFormat:@"%@ != %@", ourScreen, systemScreen]);
        }
        for (NSUInteger index = 0; index < system.count; index++) {
            NSArray *mine = index < ours.count ? ours[index] : nil;
            NSString *expected = system[index][1], *actual = mine ? mine[1] : @"nothing";
            printf("  %s: %s\n", [system[index][0] UTF8String], expected.UTF8String);
            charon_check([expected isEqual:actual], [system[index][0] UTF8String],
                         [NSString stringWithFormat:@"%@ != %@", actual, expected]);
        }
        printf("  a screen: %s\n", systemScreen.UTF8String);
    }
    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    return charon_failures;
}

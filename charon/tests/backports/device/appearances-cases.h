#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

static NSMutableArray *charon_images;
static BOOL charon_font_names;

static UIImage *charon_test_image(int side)
{
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, side, side, 8, 0, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 1, 0, 0, 1);
    CGContextFillRect(context, CGRectMake(0, 0, side, side));
    CGImageRef pixels = CGBitmapContextCreateImage(context);
    UIImage *image = [UIImage imageWithCGImage:pixels scale:1 orientation:UIImageOrientationUp];
    CGImageRelease(pixels);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return image;
}

static void charon_prepare_images(void)
{
    charon_images = [NSMutableArray arrayWithObjects:charon_test_image(4), charon_test_image(6), nil];
}

static NSString *charon_token(id value);

static NSString *charon_rgba(UIColor *colour)
{
    UIColor *resolved = colour;
    if ([colour respondsToSelector:@selector(resolvedColorWithTraitCollection:)])
        resolved = [colour resolvedColorWithTraitCollection:[UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight]];
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if (![resolved getRed:&red green:&green blue:&blue alpha:&alpha]) {
        [resolved getWhite:&red alpha:&alpha];
        green = blue = red;
    }
    return [NSString stringWithFormat:@"rgba(%.2f %.2f %.2f %.2f)", red, green, blue, alpha];
}

static NSString *charon_attributes_token(NSDictionary *attributes)
{
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *key in [attributes.allKeys sortedArrayUsingSelector:@selector(compare:)])
        [items addObject:[NSString stringWithFormat:@"%@=%@", key, charon_token(attributes[key])]];
    return [NSString stringWithFormat:@"{%@}", [items componentsJoinedByString:@","]];
}

static NSString *charon_token(id value)
{
    if (!value)
        return @"nil";
    if ([value isKindOfClass:[UIColor class]])
        return charon_rgba(value);
    if ([value isKindOfClass:[UIFont class]])
        return charon_font_names ? [NSString stringWithFormat:@"font(%.0f %@)", [value pointSize], [value fontName]] : [NSString stringWithFormat:@"font(%.0f)", [value pointSize]];
    if ([value isKindOfClass:[UIImage class]]) {
        NSUInteger index = [charon_images indexOfObjectIdenticalTo:value];
        return index == NSNotFound ? @"img?" : [NSString stringWithFormat:@"img%lu", (unsigned long)index];
    }
    if ([value isKindOfClass:[NSDictionary class]])
        return charon_attributes_token(value);
    if ([value isKindOfClass:[UIBlurEffect class]]) {
        for (NSInteger style = 0; style < 40; style++) {
            UIBlurEffect *candidate = [UIBlurEffect effectWithStyle:(UIBlurEffectStyle)style];
            if (candidate && [candidate isEqual:value])
                return [NSString stringWithFormat:@"effect%ld", (long)style];
        }
        return @"effect?";
    }
    return [value description];
}

static BOOL charon_is_kind(id object, NSString *name)
{
    for (Class kind = [object class]; kind; kind = class_getSuperclass(kind))
        if ([NSStringFromClass(kind) hasSuffix:name])
            return YES;
    return NO;
}

static NSString *charon_button_state_token(id state)
{
    return [NSString stringWithFormat:@"[%@ %@ %@ %@]", charon_token([state titleTextAttributes]), NSStringFromUIOffset([state titlePositionAdjustment]), charon_token([state backgroundImage]),
            NSStringFromUIOffset([state backgroundImagePositionAdjustment])];
}

static NSString *charon_button_token(id appearance)
{
    return [NSString stringWithFormat:@"%@%@%@%@", charon_button_state_token([appearance normal]), charon_button_state_token([appearance highlighted]), charon_button_state_token([appearance disabled]),
            charon_button_state_token([appearance focused])];
}

static NSString *charon_item_state_token(id state)
{
    return [NSString stringWithFormat:@"[%@ %@ %@ %@ %@ %@ %@]", charon_token([state titleTextAttributes]), NSStringFromUIOffset([state titlePositionAdjustment]), charon_token([state iconColor]),
            NSStringFromUIOffset([state badgePositionAdjustment]), charon_token([state badgeBackgroundColor]), charon_token([state badgeTextAttributes]), NSStringFromUIOffset([state badgeTitlePositionAdjustment])];
}

static NSString *charon_item_token(id appearance)
{
    return [NSString stringWithFormat:@"%@%@%@%@", charon_item_state_token([appearance normal]), charon_item_state_token([appearance selected]), charon_item_state_token([appearance disabled]),
            charon_item_state_token([appearance focused])];
}

static NSString *charon_indicator_token(UIImage *image)
{
    NSString *text = charon_token(image);
    return [text isEqual:@"nil"] || [text isEqual:@"img?"] ? @"default" : text;
}

static NSString *charon_snapshot(id object)
{
    if (charon_is_kind(object, @"UIBarButtonItemAppearance"))
        return charon_button_token(object);
    if (charon_is_kind(object, @"UITabBarItemAppearance"))
        return charon_item_token(object);
    UIBarAppearance *base = object;
    NSInteger idiom = [base idiom];
    NSMutableString *text = [NSMutableString stringWithFormat:@"idiom%@ %@ %@ %@ %ld %@ %@", idiom == (NSInteger)[UIDevice currentDevice].userInterfaceIdiom ? @"D" : [NSString stringWithFormat:@"%ld", (long)idiom], charon_token([base backgroundEffect]), charon_token([base backgroundColor]),
                             charon_token([base backgroundImage]), (long)[base backgroundImageContentMode], charon_token([base shadowColor]), charon_token([base shadowImage])];
    if (charon_is_kind(object, @"UINavigationBarAppearance"))
        [text appendFormat:@" %@ %@ %@ %@ %@ %@ %@ %@ %@", charon_token([object titleTextAttributes]), NSStringFromUIOffset([object titlePositionAdjustment]), charon_token([object largeTitleTextAttributes]),
         charon_button_token([object buttonAppearance]), charon_button_token([object doneButtonAppearance]), charon_button_token([object backButtonAppearance]),
         charon_indicator_token([object backIndicatorImage]), charon_indicator_token([object backIndicatorTransitionMaskImage]),
         [object respondsToSelector:NSSelectorFromString(@"prominentButtonAppearance")] ? ([object valueForKey:@"prominentButtonAppearance"] == [object doneButtonAppearance] ? @"same" : @"apart") : @"same"];
    if (charon_is_kind(object, @"UIToolbarAppearance"))
        [text appendFormat:@" %@ %@", charon_button_token([object buttonAppearance]), charon_button_token([object doneButtonAppearance])];
    if (charon_is_kind(object, @"UITabBarAppearance"))
        [text appendFormat:@" %@ %@ %@ %@ %@ %ld %g %g", charon_item_token([object stackedLayoutAppearance]), charon_item_token([object inlineLayoutAppearance]),
         charon_item_token([object compactInlineLayoutAppearance]), charon_token([object selectionIndicatorTintColor]), charon_token([object selectionIndicatorImage]),
         (long)[object stackedItemPositioning], (double)[object stackedItemWidth], (double)[object stackedItemSpacing]];
    return text;
}

static id charon_state(id appearance, NSString *name)
{
    return [appearance valueForKey:name];
}

typedef id (^CharonAppearanceMaker)(NSString *kind);
typedef id (^CharonAppearanceCase)(CharonAppearanceMaker make);

static NSDictionary *charon_case(NSString *name, CharonAppearanceCase body)
{
    return @{@"name": name, @"body": [body copy]};
}

static NSArray *charon_appearance_cases(void)
{
    UIColor *red = [UIColor colorWithRed:1 green:0 blue:0 alpha:1], *blue = [UIColor colorWithRed:0 green:0 blue:1 alpha:1], *green = [UIColor colorWithRed:0 green:1 blue:0 alpha:1];
    UIColor *tint = [UIColor colorWithRed:0.2 green:0.4 blue:0.6 alpha:0.8];
    UIImage *first = charon_images[0], *second = charon_images[1];
    NSMutableArray *cases = [NSMutableArray array];
    for (NSString *kind in @[@"UIBarAppearance", @"UINavigationBarAppearance", @"UIToolbarAppearance", @"UITabBarAppearance", @"UIBarButtonItemAppearance", @"UITabBarItemAppearance"])
        [cases addObject:charon_case([@"a new " stringByAppendingString:kind], ^id(CharonAppearanceMaker make) { return make(kind); })];
    for (NSString *kind in @[@"UIBarAppearance", @"UINavigationBarAppearance", @"UIToolbarAppearance", @"UITabBarAppearance"]) {
        [cases addObject:charon_case([kind stringByAppendingString:@" opaque"], ^id(CharonAppearanceMaker make) { id a = make(kind); [a configureWithOpaqueBackground]; return a; })];
        [cases addObject:charon_case([kind stringByAppendingString:@" transparent"], ^id(CharonAppearanceMaker make) { id a = make(kind); [a configureWithTransparentBackground]; return a; })];
        [cases addObject:charon_case([kind stringByAppendingString:@" default"], ^id(CharonAppearanceMaker make) { id a = make(kind); [a configureWithDefaultBackground]; return a; })];
        [cases addObject:charon_case([kind stringByAppendingString:@" with every background value"], ^id(CharonAppearanceMaker make) {
            id a = make(kind);
            [a setBackgroundEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
            [a setBackgroundColor:tint];
            [a setBackgroundImage:first];
            [a setBackgroundImageContentMode:UIViewContentModeScaleAspectFill];
            [a setShadowColor:red];
            [a setShadowImage:second];
            return a;
        })];
        [cases addObject:charon_case([kind stringByAppendingString:@" with no effect and no shadow"], ^id(CharonAppearanceMaker make) {
            id a = make(kind);
            [a setBackgroundEffect:nil];
            [a setShadowColor:nil];
            return a;
        })];
        [cases addObject:charon_case([kind stringByAppendingString:@" copied"], ^id(CharonAppearanceMaker make) { id a = make(kind); [a setBackgroundColor:blue]; return [a copy]; })];
        [cases addObject:charon_case([kind stringByAppendingString:@" made from another"], ^id(CharonAppearanceMaker make) {
            id source = make(@"UIBarAppearance");
            [source configureWithOpaqueBackground];
            [source setBackgroundColor:green];
            return [(UIBarAppearance *)[[make(kind) class] alloc] initWithBarAppearance:source];
        })];
    }
    [cases addObject:charon_case(@"navigation titles", ^id(CharonAppearanceMaker make) {
        id a = make(@"UINavigationBarAppearance");
        [a setTitleTextAttributes:@{NSForegroundColorAttributeName: red}];
        [a setLargeTitleTextAttributes:@{NSFontAttributeName: [UIFont systemFontOfSize:30], NSKernAttributeName: @2}];
        [a setTitlePositionAdjustment:UIOffsetMake(2, 3)];
        return a;
    })];
    [cases addObject:charon_case(@"navigation titles set to empty and to nothing", ^id(CharonAppearanceMaker make) {
        id a = make(@"UINavigationBarAppearance");
        [a setTitleTextAttributes:@{}];
        [a setLargeTitleTextAttributes:@{NSKernAttributeName: @2}];
        [a setLargeTitleTextAttributes:nil];
        return a;
    })];
    [cases addObject:charon_case(@"the back button follows the plain button", ^id(CharonAppearanceMaker make) {
        id a = make(@"UINavigationBarAppearance");
        [charon_state([a buttonAppearance], @"normal") setTitleTextAttributes:@{NSForegroundColorAttributeName: red, NSFontAttributeName: [UIFont systemFontOfSize:22], NSKernAttributeName: @1}];
        [charon_state([a buttonAppearance], @"normal") setTitlePositionAdjustment:UIOffsetMake(4, 4)];
        [charon_state([a buttonAppearance], @"normal") setBackgroundImage:first];
        [charon_state([a buttonAppearance], @"highlighted") setTitleTextAttributes:@{NSForegroundColorAttributeName: blue}];
        return a;
    })];
    [cases addObject:charon_case(@"the back button set on its own", ^id(CharonAppearanceMaker make) {
        id a = make(@"UINavigationBarAppearance");
        id back = [[[a buttonAppearance] class] new];
        [charon_state(back, @"normal") setTitlePositionAdjustment:UIOffsetMake(8, 8)];
        [charon_state(back, @"disabled") setBackgroundImage:second];
        [a setBackButtonAppearance:back];
        [charon_state([a buttonAppearance], @"normal") setTitlePositionAdjustment:UIOffsetMake(1, 2)];
        return a;
    })];
    [cases addObject:charon_case(@"the done button is the prominent button", ^id(CharonAppearanceMaker make) {
        id a = make(@"UINavigationBarAppearance");
        id done = [[[a buttonAppearance] class] new];
        [done configureWithDefaultForStyle:UIBarButtonItemStyleDone];
        [charon_state(done, @"highlighted") setBackgroundImage:first];
        [a setValue:done forKey:@"prominentButtonAppearance"];
        return a;
    })];
    [cases addObject:charon_case(@"the back indicator is a pair", ^id(CharonAppearanceMaker make) {
        id a = make(@"UINavigationBarAppearance");
        [a setBackIndicatorImage:first transitionMaskImage:nil];
        return a;
    })];
    [cases addObject:charon_case(@"the back indicator pair set", ^id(CharonAppearanceMaker make) {
        id a = make(@"UINavigationBarAppearance");
        [a setBackIndicatorImage:first transitionMaskImage:second];
        return [a copy];
    })];
    [cases addObject:charon_case(@"a plain button appearance with every state set", ^id(CharonAppearanceMaker make) {
        id a = make(@"UIBarButtonItemAppearance");
        [charon_state(a, @"normal") setTitleTextAttributes:@{NSForegroundColorAttributeName: red, NSKernAttributeName: @2}];
        [charon_state(a, @"normal") setTitlePositionAdjustment:UIOffsetMake(1, 2)];
        [charon_state(a, @"highlighted") setBackgroundImage:first];
        [charon_state(a, @"highlighted") setBackgroundImagePositionAdjustment:UIOffsetMake(3, 4)];
        [charon_state(a, @"disabled") setTitleTextAttributes:@{NSForegroundColorAttributeName: blue}];
        [charon_state(a, @"focused") setTitlePositionAdjustment:UIOffsetMake(5, 6)];
        return a;
    })];
    [cases addObject:charon_case(@"the disabled button colour is derived", ^id(CharonAppearanceMaker make) {
        id a = make(@"UIBarButtonItemAppearance");
        [charon_state(a, @"normal") setTitleTextAttributes:@{NSForegroundColorAttributeName: tint, NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}];
        return a;
    })];
    [cases addObject:charon_case(@"a done button appearance", ^id(CharonAppearanceMaker make) {
        id a = [(UIBarButtonItemAppearance *)[[make(@"UIBarButtonItemAppearance") class] alloc] initWithStyle:UIBarButtonItemStyleDone];
        [charon_state(a, @"normal") setTitleTextAttributes:@{NSKernAttributeName: @3}];
        return a;
    })];
    [cases addObject:charon_case(@"a button appearance configured for a style", ^id(CharonAppearanceMaker make) {
        id a = make(@"UIBarButtonItemAppearance");
        [charon_state(a, @"normal") setTitlePositionAdjustment:UIOffsetMake(1, 1)];
        [a configureWithDefaultForStyle:UIBarButtonItemStyleDone];
        return a;
    })];
    [cases addObject:charon_case(@"a button appearance copied", ^id(CharonAppearanceMaker make) {
        id a = make(@"UIBarButtonItemAppearance");
        [charon_state(a, @"disabled") setBackgroundImage:second];
        return [a copy];
    })];
    [cases addObject:charon_case(@"a toolbar appearance with buttons", ^id(CharonAppearanceMaker make) {
        id a = make(@"UIToolbarAppearance");
        [charon_state([a buttonAppearance], @"normal") setTitleTextAttributes:@{NSForegroundColorAttributeName: green}];
        [charon_state([a doneButtonAppearance], @"normal") setBackgroundImage:first];
        return [a copy];
    })];
    [cases addObject:charon_case(@"a tab item appearance with every state set", ^id(CharonAppearanceMaker make) {
        id a = make(@"UITabBarItemAppearance");
        [charon_state(a, @"normal") setTitleTextAttributes:@{NSForegroundColorAttributeName: red, NSFontAttributeName: [UIFont systemFontOfSize:22], NSKernAttributeName: @2}];
        [charon_state(a, @"normal") setTitlePositionAdjustment:UIOffsetMake(1, 1)];
        [charon_state(a, @"normal") setIconColor:red];
        [charon_state(a, @"normal") setBadgePositionAdjustment:UIOffsetMake(2, 2)];
        [charon_state(a, @"normal") setBadgeBackgroundColor:green];
        [charon_state(a, @"normal") setBadgeTextAttributes:@{NSKernAttributeName: @1}];
        [charon_state(a, @"normal") setBadgeTitlePositionAdjustment:UIOffsetMake(3, 3)];
        [charon_state(a, @"selected") setIconColor:blue];
        [charon_state(a, @"selected") setTitleTextAttributes:@{NSForegroundColorAttributeName: blue}];
        [charon_state(a, @"disabled") setBadgeBackgroundColor:tint];
        return a;
    })];
    for (NSInteger style = 0; style < 5; style++)
        [cases addObject:charon_case([NSString stringWithFormat:@"a tab item appearance of style %ld", (long)style], ^id(CharonAppearanceMaker make) {
            return [(UITabBarItemAppearance *)[[make(@"UITabBarItemAppearance") class] alloc] initWithStyle:(UITabBarItemAppearanceStyle)style];
        })];
    [cases addObject:charon_case(@"a tab bar appearance with layout values", ^id(CharonAppearanceMaker make) {
        id a = make(@"UITabBarAppearance");
        [a setSelectionIndicatorTintColor:red];
        [a setSelectionIndicatorImage:first];
        [a setStackedItemPositioning:UITabBarItemPositioningCentered];
        [a setStackedItemWidth:10.5];
        [a setStackedItemSpacing:4];
        return [a copy];
    })];
    [cases addObject:charon_case(@"a tab bar appearance with item appearances", ^id(CharonAppearanceMaker make) {
        id a = make(@"UITabBarAppearance");
        [charon_state([a stackedLayoutAppearance], @"normal") setIconColor:red];
        [charon_state([a inlineLayoutAppearance], @"selected") setTitlePositionAdjustment:UIOffsetMake(1, 2)];
        id compact = [(UITabBarItemAppearance *)[[[a compactInlineLayoutAppearance] class] alloc] initWithStyle:UITabBarItemAppearanceStyleStacked];
        [charon_state(compact, @"disabled") setBadgeBackgroundColor:blue];
        [a setCompactInlineLayoutAppearance:compact];
        return a;
    })];
    [cases addObject:charon_case(@"an appearance read back from a secure archive", ^id(CharonAppearanceMaker make) {
        id a = make(@"UINavigationBarAppearance");
        [a configureWithOpaqueBackground];
        [a setBackgroundColor:tint];
        [a setShadowColor:nil];
        [a setTitleTextAttributes:@{NSForegroundColorAttributeName: red, NSKernAttributeName: @2}];
        [a setTitlePositionAdjustment:UIOffsetMake(2, 3)];
        [charon_state([a buttonAppearance], @"normal") setTitleTextAttributes:@{NSForegroundColorAttributeName: blue}];
        [a setBackIndicatorImage:first transitionMaskImage:second];
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:a requiringSecureCoding:YES error:NULL];
        return [NSKeyedUnarchiver unarchivedObjectOfClass:[a class] fromData:data error:NULL];
    })];
    return cases;
}

#import <UIKit/UIKit.h>
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
#import <objc/message.h>
#import <objc/runtime.h>
#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)


@interface UINavigationBar (CharonAppearanceRefresh)
- (void)charonHostCharon_refreshForced:(BOOL)force;
@end

@interface UITabBar (CharonAppearanceRefresh)
- (void)charonHostCharon_refreshForced:(BOOL)force;
@end

@interface UINavigationBar (CharonHostAppearances)
- (id)charonHostStandardAppearance;
- (void)charonHostSetStandardAppearance:(id)appearance;
- (id)charonHostCompactAppearance;
- (void)charonHostSetCompactAppearance:(id)appearance;
- (id)charonHostScrollEdgeAppearance;
- (void)charonHostSetScrollEdgeAppearance:(id)appearance;
- (id)charonHostCompactScrollEdgeAppearance;
- (void)charonHostSetCompactScrollEdgeAppearance:(id)appearance;
@end

@interface UIToolbar (CharonHostAppearances)
- (id)charonHostStandardAppearance;
- (void)charonHostSetStandardAppearance:(id)appearance;
- (id)charonHostCompactAppearance;
- (void)charonHostSetCompactAppearance:(id)appearance;
- (id)charonHostScrollEdgeAppearance;
- (void)charonHostSetScrollEdgeAppearance:(id)appearance;
- (id)charonHostCompactScrollEdgeAppearance;
- (void)charonHostSetCompactScrollEdgeAppearance:(id)appearance;
@end

@interface UITabBar (CharonHostAppearances)
- (id)charonHostStandardAppearance;
- (void)charonHostSetStandardAppearance:(id)appearance;
- (id)charonHostScrollEdgeAppearance;
- (void)charonHostSetScrollEdgeAppearance:(id)appearance;
@end

@interface UINavigationItem (CharonHostAppearances)
- (id)charonHostStandardAppearance;
- (void)charonHostSetStandardAppearance:(id)appearance;
- (id)charonHostCompactAppearance;
- (void)charonHostSetCompactAppearance:(id)appearance;
- (id)charonHostScrollEdgeAppearance;
- (void)charonHostSetScrollEdgeAppearance:(id)appearance;
- (id)charonHostCompactScrollEdgeAppearance;
- (void)charonHostSetCompactScrollEdgeAppearance:(id)appearance;
@end

@interface UITabBarItem (CharonHostAppearances)
- (id)charonHostStandardAppearance;
- (void)charonHostSetStandardAppearance:(id)appearance;
- (id)charonHostScrollEdgeAppearance;
- (void)charonHostSetScrollEdgeAppearance:(id)appearance;
@end

#import "appearances-cases.h"

#define images charon_images

static Class port_class(NSString *name)
{
    return NSClassFromString([@"CharonHost" stringByAppendingString:name]);
}

#define snap charon_snapshot
#define tok charon_token

static NSMutableArray *masks;

static NSString *normalised(id object)
{
    NSMutableString *text = [[object description] mutableCopy];
    [text replaceOccurrencesOfString:@"CharonHost" withString:@"" options:0 range:NSMakeRange(0, text.length)];
    for (NSArray *pair in masks)
        [text replaceOccurrencesOfString:pair[0] withString:pair[1] options:0 range:NSMakeRange(0, text.length)];
    NSRegularExpression *pointer = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL];
    [pointer replaceMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"0x"];
    NSRegularExpression *group = [NSRegularExpression regularExpressionWithPattern:@"\\{\\(.*?\\)\\}" options:0 error:NULL];
    NSArray *matches = [group matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        NSString *inner = [text substringWithRange:NSMakeRange(match.range.location + 2, match.range.length - 4)];
        NSArray *items = [[inner componentsSeparatedByString:@"), ("] sortedArrayUsingSelector:@selector(compare:)];
        [text replaceCharactersInRange:match.range withString:[NSString stringWithFormat:@"{(%@)}", [items componentsJoinedByString:@"), ("]]];
    }
    return text;
}

static void add_mask(UIColor *system, UIColor *port, NSString *token)
{
    if (system)
        [masks addObject:@[[system description], token]];
    if (port && ![[port description] isEqual:[system description]])
        [masks addObject:@[[port description], token]];
}

typedef id (^Operation)(id root, unsigned pick);

static unsigned state_random = 1;

static unsigned next_random(void)
{
    state_random ^= state_random << 13;
    state_random ^= state_random >> 17;
    state_random ^= state_random << 5;
    return state_random;
}

static NSString *attempt(id root, Operation operation, unsigned pick, id *result)
{
    @try {
        *result = operation(root, pick);
        return @"ok";
    } @catch (NSException *exception) {
        *result = root;
        return [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
    }
}

static NSDictionary *named(NSString *name, Operation operation)
{
    return @{@"name": name, @"operation": [operation copy]};
}

static NSData *archive(id object)
{
    return [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:NULL];
}

static id unarchive(id object)
{
    return [NSKeyedUnarchiver unarchivedObjectOfClass:[object class] fromData:archive(object) error:NULL];
}

static NSArray *tta_variants(void)
{
    return @[[NSNull null], @{}, @{NSForegroundColorAttributeName: [UIColor redColor]}, @{NSFontAttributeName: [UIFont systemFontOfSize:22]},
             @{NSForegroundColorAttributeName: [UIColor blueColor], NSKernAttributeName: @2}, @{NSKernAttributeName: @3},
             @{NSForegroundColorAttributeName: [UIColor colorWithRed:0 green:0.5 blue:1 alpha:0.5], NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}];
}

static UIOffset offset_variant(unsigned pick, BOOL nonzero)
{
    UIOffset offsets[] = {{0, 0}, {1, 2}, {3, 4}, {-2, 5}};
    return offsets[nonzero ? 1 + pick % 3 : pick % 4];
}

static id nullable(id value)
{
    return value == [NSNull null] ? nil : value;
}

static NSArray *button_state_operations(id (^state)(id root, unsigned pick), NSString *prefix, BOOL nonzero)
{
    NSMutableArray *operations = [NSMutableArray array];
    [operations addObject:named([prefix stringByAppendingString:@"tta"], ^id(id root, unsigned pick) {
        [state(root, pick) setTitleTextAttributes:nullable(tta_variants()[(pick >> 2) % tta_variants().count])];
        return root;
    })];
    [operations addObject:named([prefix stringByAppendingString:@"pos"], ^id(id root, unsigned pick) {
        [state(root, pick) setTitlePositionAdjustment:offset_variant(pick >> 2, nonzero)];
        return root;
    })];
    [operations addObject:named([prefix stringByAppendingString:@"bg"], ^id(id root, unsigned pick) {
        [state(root, pick) setBackgroundImage:(pick >> 2) % 3 ? images[((pick >> 2) % 3) - 1] : nil];
        return root;
    })];
    [operations addObject:named([prefix stringByAppendingString:@"bgpos"], ^id(id root, unsigned pick) {
        [state(root, pick) setBackgroundImagePositionAdjustment:offset_variant(pick >> 2, nonzero)];
        return root;
    })];
    return operations;
}

static NSArray *item_state_operations(id (^state)(id root, unsigned pick), NSString *prefix, BOOL nonzero)
{
    NSMutableArray *operations = [NSMutableArray array];
    [operations addObject:named([prefix stringByAppendingString:@"tta"], ^id(id root, unsigned pick) {
        [state(root, pick) setTitleTextAttributes:nullable(tta_variants()[(pick >> 2) % tta_variants().count])];
        return root;
    })];
    [operations addObject:named([prefix stringByAppendingString:@"badgetta"], ^id(id root, unsigned pick) {
        [state(root, pick) setBadgeTextAttributes:nullable(tta_variants()[(pick >> 2) % tta_variants().count])];
        return root;
    })];
    [operations addObject:named([prefix stringByAppendingString:@"pos"], ^id(id root, unsigned pick) {
        [state(root, pick) setTitlePositionAdjustment:offset_variant(pick >> 2, nonzero)];
        return root;
    })];
    [operations addObject:named([prefix stringByAppendingString:@"badgepos"], ^id(id root, unsigned pick) {
        [state(root, pick) setBadgePositionAdjustment:offset_variant(pick >> 2, nonzero)];
        return root;
    })];
    [operations addObject:named([prefix stringByAppendingString:@"badgetitlepos"], ^id(id root, unsigned pick) {
        [state(root, pick) setBadgeTitlePositionAdjustment:offset_variant(pick >> 2, nonzero)];
        return root;
    })];
    [operations addObject:named([prefix stringByAppendingString:@"icon"], ^id(id root, unsigned pick) {
        UIColor *colours[] = {nil, [UIColor redColor], [UIColor blueColor]};
        [state(root, pick) setIconColor:colours[(pick >> 2) % 3]];
        return root;
    })];
    [operations addObject:named([prefix stringByAppendingString:@"badgebg"], ^id(id root, unsigned pick) {
        UIColor *colours[] = {nil, [UIColor greenColor], [UIColor redColor]};
        [state(root, pick) setBadgeBackgroundColor:colours[(pick >> 2) % 3]];
        return root;
    })];
    return operations;
}

static NSArray *bar_operations(void)
{
    NSMutableArray *operations = [NSMutableArray array];
    [operations addObject:named(@"effect", ^id(id root, unsigned pick) {
        UIBlurEffect *effects[] = {nil, [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight], [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark],
                                   [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]};
        [root setBackgroundEffect:effects[pick % 4]];
        return root;
    })];
    [operations addObject:named(@"colour", ^id(id root, unsigned pick) {
        UIColor *colours[] = {nil, [UIColor redColor], [UIColor colorWithRed:0.2 green:0.4 blue:0.6 alpha:0.8]};
        [root setBackgroundColor:colours[pick % 3]];
        return root;
    })];
    [operations addObject:named(@"image", ^id(id root, unsigned pick) {
        [root setBackgroundImage:pick % 3 ? images[(pick % 3) - 1] : nil];
        return root;
    })];
    [operations addObject:named(@"mode", ^id(id root, unsigned pick) {
        UIViewContentMode modes[] = {UIViewContentModeScaleToFill, UIViewContentModeScaleAspectFit, UIViewContentModeScaleAspectFill, UIViewContentModeCenter, UIViewContentModeTopLeft};
        [root setBackgroundImageContentMode:modes[pick % 5]];
        return root;
    })];
    [operations addObject:named(@"shadowcolour", ^id(id root, unsigned pick) {
        UIColor *colours[] = {nil, [UIColor redColor], [UIColor blueColor]};
        [root setShadowColor:colours[pick % 3]];
        return root;
    })];
    [operations addObject:named(@"shadowimage", ^id(id root, unsigned pick) {
        [root setShadowImage:pick % 3 ? images[(pick % 3) - 1] : nil];
        return root;
    })];
    [operations addObject:named(@"default", ^id(id root, unsigned pick) { [root configureWithDefaultBackground]; return root; })];
    [operations addObject:named(@"opaque", ^id(id root, unsigned pick) { [root configureWithOpaqueBackground]; return root; })];
    [operations addObject:named(@"transparent", ^id(id root, unsigned pick) { [root configureWithTransparentBackground]; return root; })];
    [operations addObject:named(@"copy", ^id(id root, unsigned pick) { return [root copy]; })];
    [operations addObject:named(@"copyWithZone", ^id(id root, unsigned pick) { return [root copyWithZone:nil]; })];
    [operations addObject:named(@"archive", ^id(id root, unsigned pick) { return unarchive(root); })];
    return operations;
}

static NSArray *state_names(void)
{
    return @[@"normal", @"highlighted", @"disabled", @"focused"];
}

static NSArray *item_names(void)
{
    return @[@"normal", @"selected", @"disabled", @"focused"];
}

static NSArray *button_operations(id (^appearance)(id root), NSString *prefix, BOOL nonzero)
{
    NSMutableArray *operations = [NSMutableArray array];
    [operations addObjectsFromArray:button_state_operations(^id(id root, unsigned pick) { return [appearance(root) valueForKey:state_names()[pick % 4]]; }, prefix, nonzero)];
    return operations;
}

static NSArray *root_button_operations(void)
{
    NSMutableArray *operations = [NSMutableArray arrayWithArray:button_operations(^id(id root) { return root; }, @"", NO)];
    [operations addObject:named(@"configure", ^id(id root, unsigned pick) {
        UIBarButtonItemStyle styles[] = {UIBarButtonItemStylePlain, UIBarButtonItemStyleDone, (UIBarButtonItemStyle)7, (UIBarButtonItemStyle)1, (UIBarButtonItemStyle)3, (UIBarButtonItemStyle)5};
        [root configureWithDefaultForStyle:styles[pick % 6]];
        return root;
    })];
    [operations addObject:named(@"copy", ^id(id root, unsigned pick) { return [root copy]; })];
    [operations addObject:named(@"archive", ^id(id root, unsigned pick) { return unarchive(root); })];
    return operations;
}

static NSArray *root_item_operations(void)
{
    NSMutableArray *operations = [NSMutableArray arrayWithArray:item_state_operations(^id(id root, unsigned pick) { return [root valueForKey:item_names()[pick % 4]]; }, @"", NO)];
    [operations addObject:named(@"configure", ^id(id root, unsigned pick) {
        [root configureWithDefaultForStyle:(UITabBarItemAppearanceStyle)((NSInteger)(pick % 8) - 1)];
        return root;
    })];
    [operations addObject:named(@"copy", ^id(id root, unsigned pick) { return [root copy]; })];
    return operations;
}

static id make_kind(NSString *kind, BOOL port)
{
    Class kindClass = port ? port_class(kind) : NSClassFromString(kind);
    return [[kindClass alloc] init];
}

static id fresh_button(id root, NSString *getter, unsigned pick)
{
    Class kindClass = [[root valueForKey:getter] class];
    UIBarButtonItemStyle styles[] = {UIBarButtonItemStylePlain, UIBarButtonItemStyleDone, (UIBarButtonItemStyle)7};
    id appearance = [[kindClass alloc] initWithStyle:styles[pick % 3]];
    NSArray *operations = button_operations(^id(id item) { return item; }, @"", YES);
    for (int index = 0; index < (int)((pick >> 2) % 4); index++) {
        NSDictionary *chosen = operations[(pick >> (4 + index)) % operations.count];
        ((Operation)chosen[@"operation"])(appearance, pick >> (6 + index));
    }
    return appearance;
}

static id fresh_item(id root, NSString *getter, unsigned pick)
{
    Class kindClass = [[root valueForKey:getter] class];
    id appearance = [[kindClass alloc] initWithStyle:(UITabBarItemAppearanceStyle)(pick % 5)];
    NSArray *operations = item_state_operations(^id(id item, unsigned inner) { return [item valueForKey:item_names()[inner % 4]]; }, @"", YES);
    for (int index = 0; index < (int)((pick >> 3) % 4); index++) {
        NSDictionary *chosen = operations[(pick >> (5 + index)) % operations.count];
        ((Operation)chosen[@"operation"])(appearance, pick >> (7 + index));
        if (getenv("FUZZ_FRESH"))
            printf("FRESH %s(%u) -> %s\n", [chosen[@"name"] UTF8String], pick >> (7 + index), [[[appearance description] stringByReplacingOccurrencesOfString:@"\n" withString:@"|"] UTF8String]);
    }
    return appearance;
}

static NSArray *nested_button_operations(NSString *getter, NSString *label)
{
    return button_operations(^id(id root) { return [root valueForKey:getter]; }, label, YES);
}

static NSArray *nested_item_operations(NSString *getter, NSString *label)
{
    return item_state_operations(^id(id root, unsigned pick) { return [[root valueForKey:getter] valueForKey:item_names()[pick % 4]]; }, label, YES);
}

static NSArray *shared_bar_operations(NSString *kind)
{
    NSMutableArray *operations = [NSMutableArray arrayWithArray:bar_operations()];
    [operations addObject:named(@"idiom", ^id(id root, unsigned pick) {
        UIUserInterfaceIdiom idioms[] = {UIUserInterfaceIdiomPhone, UIUserInterfaceIdiomPad, (UIUserInterfaceIdiom)5, (UIUserInterfaceIdiom)-1};
        return [[[root class] alloc] initWithIdiom:idioms[pick % 4]];
    })];
    [operations addObject:named(@"fromself", ^id(id root, unsigned pick) { return [[[root class] alloc] initWithBarAppearance:root]; })];
    [operations addObject:named(@"fromother", ^id(id root, unsigned pick) {
        NSArray *kinds = @[@"UIBarAppearance", @"UINavigationBarAppearance", @"UIToolbarAppearance", @"UITabBarAppearance"];
        NSString *other = kinds[(pick >> 3) % 4];
        BOOL port = [NSStringFromClass([root class]) hasPrefix:@"CharonHost"];
        id source = make_kind(other, port);
        if (pick & 1)
            [source configureWithOpaqueBackground];
        if (pick & 2)
            [source setBackgroundColor:[UIColor blueColor]];
        return [[[root class] alloc] initWithBarAppearance:source];
    })];
    return operations;
}

static NSArray *navigation_operations(void)
{
    NSMutableArray *operations = [NSMutableArray arrayWithArray:shared_bar_operations(@"UINavigationBarAppearance")];
    [operations addObject:named(@"title", ^id(id root, unsigned pick) { [root setTitleTextAttributes:nullable(tta_variants()[pick % tta_variants().count])]; return root; })];
    [operations addObject:named(@"largetitle", ^id(id root, unsigned pick) { [root setLargeTitleTextAttributes:nullable(tta_variants()[pick % tta_variants().count])]; return root; })];
    [operations addObject:named(@"titlepos", ^id(id root, unsigned pick) { [root setTitlePositionAdjustment:offset_variant(pick, NO)]; return root; })];
    [operations addObject:named(@"indicator", ^id(id root, unsigned pick) {
        [root setBackIndicatorImage:pick & 1 ? images[0] : nil transitionMaskImage:pick & 2 ? images[1] : nil];
        return root;
    })];
    for (NSString *getter in @[@"buttonAppearance", @"doneButtonAppearance", @"backButtonAppearance"]) {
        [operations addObjectsFromArray:nested_button_operations(getter, [getter stringByAppendingString:@"."])];
        [operations addObject:named([@"set." stringByAppendingString:getter], ^id(id root, unsigned pick) {
            id appearance = fresh_button(root, getter, pick);
            [root setValue:appearance forKey:getter];
            return root;
        })];
        [operations addObject:named([@"setback." stringByAppendingString:getter], ^id(id root, unsigned pick) {
            id appearance = fresh_button(root, getter, pick);
            [root setValue:[root valueForKey:getter] forKey:getter];
            return root;
        })];
        [operations addObject:named([@"nil." stringByAppendingString:getter], ^id(id root, unsigned pick) { [root setValue:nil forKey:getter]; return root; })];
    }
    [operations addObject:named(@"prominent", ^id(id root, unsigned pick) {
        id appearance = fresh_button(root, @"doneButtonAppearance", pick);
        [root setProminentButtonAppearance:appearance];
        return root;
    })];
    return operations;
}

static NSArray *toolbar_operations(void)
{
    NSMutableArray *operations = [NSMutableArray arrayWithArray:shared_bar_operations(@"UIToolbarAppearance")];
    for (NSString *getter in @[@"buttonAppearance", @"doneButtonAppearance"]) {
        [operations addObjectsFromArray:nested_button_operations(getter, [getter stringByAppendingString:@"."])];
        [operations addObject:named([@"set." stringByAppendingString:getter], ^id(id root, unsigned pick) {
            [root setValue:fresh_button(root, getter, pick) forKey:getter];
            return root;
        })];
        [operations addObject:named([@"nil." stringByAppendingString:getter], ^id(id root, unsigned pick) { [root setValue:nil forKey:getter]; return root; })];
    }
    return operations;
}

static NSArray *tab_operations(void)
{
    NSMutableArray *operations = [NSMutableArray arrayWithArray:shared_bar_operations(@"UITabBarAppearance")];
    for (NSDictionary *one in [operations copy])
        if ([one[@"name"] isEqual:@"archive"])
            [operations removeObject:one];
    for (NSString *getter in @[@"stackedLayoutAppearance", @"inlineLayoutAppearance", @"compactInlineLayoutAppearance"]) {
        [operations addObjectsFromArray:nested_item_operations(getter, [getter stringByAppendingString:@"."])];
        [operations addObject:named([@"set." stringByAppendingString:getter], ^id(id root, unsigned pick) {
            [root setValue:fresh_item(root, getter, pick) forKey:getter];
            return root;
        })];
        [operations addObject:named([@"nil." stringByAppendingString:getter], ^id(id root, unsigned pick) { [root setValue:nil forKey:getter]; return root; })];
    }
    [operations addObject:named(@"tint", ^id(id root, unsigned pick) { [root setSelectionIndicatorTintColor:pick % 3 ? (pick % 3 == 1 ? [UIColor redColor] : [UIColor greenColor]) : nil]; return root; })];
    [operations addObject:named(@"indicatorimage", ^id(id root, unsigned pick) { [root setSelectionIndicatorImage:pick % 3 ? images[(pick % 3) - 1] : nil]; return root; })];
    [operations addObject:named(@"positioning", ^id(id root, unsigned pick) { [root setStackedItemPositioning:(UITabBarItemPositioning)(pick % 4)]; return root; })];
    [operations addObject:named(@"width", ^id(id root, unsigned pick) { CGFloat widths[] = {0, 5, -3, 10.5}; [root setStackedItemWidth:widths[pick % 4]]; return root; })];
    [operations addObject:named(@"spacing", ^id(id root, unsigned pick) { CGFloat spacings[] = {0, 2, -1, 7.25}; [root setStackedItemSpacing:spacings[pick % 4]]; return root; })];
    return operations;
}

static NSString *difference(NSString *ours, NSString *system)
{
    NSUInteger index = 0, limit = MIN(ours.length, system.length);
    while (index < limit && [ours characterAtIndex:index] == [system characterAtIndex:index])
        index++;
    NSUInteger from = index > 80 ? index - 80 : 0;
    NSString *ourTail = [ours substringWithRange:NSMakeRange(from, MIN((NSUInteger)500, ours.length - from))];
    NSString *systemTail = [system substringWithRange:NSMakeRange(from, MIN((NSUInteger)500, system.length - from))];
    return [NSString stringWithFormat:@"\n  ours   ...%@\n  system ...%@", [ourTail stringByReplacingOccurrencesOfString:@"\n" withString:@"|"],
            [systemTail stringByReplacingOccurrencesOfString:@"\n" withString:@"|"]];
}


@interface RecordingTabBar : UITabBar
@property (nonatomic, strong) UIColor *recordedTint;
@end

@implementation RecordingTabBar
@synthesize recordedTint = _recordedTint;

- (void)setSelectedImageTintColor:(UIColor *)color
{
    _recordedTint = color;
    [super setSelectedImageTintColor:color];
}
@end

static NSString *pixel(UIImage *image)
{
    if (!image)
        return @"nil";
    unsigned char data[4] = {0, 0, 0, 0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(data, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, 1, 1), image.CGImage);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return [NSString stringWithFormat:@"%d %d %d %d %.0fx%.0f", data[0], data[1], data[2], data[3], image.size.width, image.size.height * image.scale];
}

static void settle(void)
{
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
}

static void check_accessors(NSString *name, id ourBar, id systemBar, NSArray *slots, NSString *kind)
{
    for (NSString *slot in slots) {
        NSString *capital = [[slot substringToIndex:1].uppercaseString stringByAppendingString:[slot substringFromIndex:1]];
        SEL ourGetter = NSSelectorFromString([@"charonHost" stringByAppendingString:capital]);
        SEL ourSetter = NSSelectorFromString([NSString stringWithFormat:@"charonHostSet%@:", capital]);
        SEL systemGetter = NSSelectorFromString(slot);
        SEL systemSetter = NSSelectorFromString([NSString stringWithFormat:@"set%@:", capital]);
        charon_check([ourBar respondsToSelector:ourGetter] && [ourBar respondsToSelector:ourSetter], NAMED(@"%@ answers %@", name, slot), @"the accessors are missing");
        id ourDefault = ((id (*)(id, SEL))objc_msgSend)(ourBar, ourGetter), systemDefault = ((id (*)(id, SEL))objc_msgSend)(systemBar, systemGetter);
        charon_check((ourDefault == nil) == (systemDefault == nil), NAMED(@"%@.%@ starts %@ as the system's does", name, slot, systemDefault ? @"with a default" : @"nil"), @"the default differs");
        if (ourDefault)
            charon_check([normalised(ourDefault) isEqual:normalised(systemDefault)] && ((id (*)(id, SEL))objc_msgSend)(ourBar, ourGetter) == ourDefault, NAMED(@"%@.%@ starts with the default appearance and answers the one object", name, slot),
                         [NSString stringWithFormat:@"%@", difference(normalised(ourDefault), normalised(systemDefault))]);
        id ourValue = make_kind(kind, YES), systemValue = make_kind(kind, NO);
        [ourValue configureWithOpaqueBackground];
        [systemValue configureWithOpaqueBackground];
        [ourValue setBackgroundColor:[UIColor redColor]];
        [systemValue setBackgroundColor:[UIColor redColor]];
        ((void (*)(id, SEL, id))objc_msgSend)(ourBar, ourSetter, ourValue);
        ((void (*)(id, SEL, id))objc_msgSend)(systemBar, systemSetter, systemValue);
        id ourStored = ((id (*)(id, SEL))objc_msgSend)(ourBar, ourGetter), systemStored = ((id (*)(id, SEL))objc_msgSend)(systemBar, systemGetter);
        charon_check((ourStored != ourValue) == (systemStored != systemValue) && ourStored == ((id (*)(id, SEL))objc_msgSend)(ourBar, ourGetter) && [ourStored isEqual:ourValue] && [systemStored isEqual:systemValue],
                     NAMED(@"%@.%@ keeps a copy of what it is given", name, slot), @"the copy differs");
        [ourStored setBackgroundColor:[UIColor blueColor]];
        [systemStored setBackgroundColor:[UIColor blueColor]];
        charon_check([[((id (*)(id, SEL))objc_msgSend)(ourBar, ourGetter) backgroundColor] isEqual:[UIColor blueColor]] == [[((id (*)(id, SEL))objc_msgSend)(systemBar, systemGetter) backgroundColor] isEqual:[UIColor blueColor]],
                     NAMED(@"%@.%@ hands back the object it keeps", name, slot), @"a change to the answer does not reach the bar");
        ((void (*)(id, SEL, id))objc_msgSend)(ourBar, ourSetter, nil);
        ((void (*)(id, SEL, id))objc_msgSend)(systemBar, systemSetter, nil);
        id ourCleared = ((id (*)(id, SEL))objc_msgSend)(ourBar, ourGetter), systemCleared = ((id (*)(id, SEL))objc_msgSend)(systemBar, systemGetter);
        charon_check((ourCleared == nil) == (systemCleared == nil) && (!ourCleared || [normalised(ourCleared) isEqual:normalised(systemCleared)]), NAMED(@"%@.%@ goes back to its default when cleared", name, slot), @"the cleared value differs");
    }
}

static void check_application(void)
{
    UINavigationBarAppearance *systemShape = nil;
    (void)systemShape;
    UIColor *red = [UIColor colorWithRed:1 green:0 blue:0 alpha:1];

    UINavigationBar *navigation = [[UINavigationBar alloc] init];
    id navigationAppearance = make_kind(@"UINavigationBarAppearance", YES);
    [navigationAppearance configureWithOpaqueBackground];
    [navigationAppearance setBackgroundColor:red];
    [navigationAppearance setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blueColor], NSFontAttributeName: [UIFont systemFontOfSize:19]}];
    [navigationAppearance setTitlePositionAdjustment:UIOffsetMake(3, 2)];
    [[navigationAppearance buttonAppearance].normal setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor greenColor]}];
    [[navigationAppearance buttonAppearance].normal setBackgroundImage:images[0]];
    [[navigationAppearance doneButtonAppearance].normal setBackgroundImage:images[1]];
    [[navigationAppearance backButtonAppearance].normal setBackgroundImage:images[1]];
    [navigation charonHostSetStandardAppearance:navigationAppearance];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"255 0 0 255"], "a background colour becomes a solid background image of the bar", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));
    charon_check([navigation backgroundImageForBarMetrics:UIBarMetricsLandscapePhone] == nil, "without a compact appearance the landscape metrics keep no image of their own", @"an image is set");
    NSDictionary *legacy = navigation.titleTextAttributes;
    charon_check([legacy[UITextAttributeTextColor] isEqual:[UIColor blueColor]] && [[legacy[UITextAttributeFont] fontName] length] && [legacy[UITextAttributeFont] pointSize] == 19, "the title attributes are handed on as the bar's own", [NSString stringWithFormat:@"%@", legacy]);
    charon_check([navigation titleVerticalPositionAdjustmentForBarMetrics:UIBarMetricsDefault] == 2, "the vertical title offset is applied", [NSString stringWithFormat:@"%g", [navigation titleVerticalPositionAdjustmentForBarMetrics:UIBarMetricsDefault]]);
    UIBarButtonItem *proxy = [UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil];
    charon_check([[proxy titleTextAttributesForState:UIControlStateNormal][UITextAttributeTextColor] isEqual:[UIColor greenColor]], "the plain button title attributes reach the buttons of navigation bars", @"the colour is missing");
    charon_check([proxy backgroundImageForState:UIControlStateNormal style:UIBarButtonItemStylePlain barMetrics:UIBarMetricsDefault] == images[0] &&
                 [proxy backgroundImageForState:UIControlStateNormal style:UIBarButtonItemStyleDone barMetrics:UIBarMetricsDefault] == images[1] &&
                 [proxy backButtonBackgroundImageForState:UIControlStateNormal barMetrics:UIBarMetricsDefault] == images[1], "the button background images reach the plain, done and back buttons", @"an image is missing");
    charon_check([navigation.shadowImage isKindOfClass:[UIImage class]] && navigation.shadowImage.size.width == 1, "the default shadow of an opaque bar is a hairline", @"no hairline");

    [navigationAppearance setBackgroundColor:[UIColor blueColor]];
    settle();
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"255 0 0 255"], "changing the appearance that was set later does not reach the bar", @"the bar changed");
    [[navigation charonHostStandardAppearance] setBackgroundColor:[UIColor blueColor]];
    settle();
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"0 0 255 255"], "a change to the appearance the bar keeps reaches the bar", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));

    id compact = make_kind(@"UINavigationBarAppearance", YES);
    [compact configureWithOpaqueBackground];
    [compact setBackgroundColor:[UIColor greenColor]];
    [navigation charonHostSetCompactAppearance:compact];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsLandscapePhone]) hasPrefix:@"0 255 0 255"], "the compact appearance is applied to the landscape metrics", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsLandscapePhone]));
    [navigation charonHostSetCompactAppearance:nil];
    charon_check([navigation backgroundImageForBarMetrics:UIBarMetricsLandscapePhone] == nil, "clearing the compact appearance clears the landscape image", @"the image stays");

    id scroll = make_kind(@"UINavigationBarAppearance", YES);
    [scroll configureWithOpaqueBackground];
    [scroll setBackgroundColor:[UIColor yellowColor]];
    [navigation charonHostSetScrollEdgeAppearance:scroll];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"255 255 0 255"] && [navigation charonHostScrollEdgeAppearance] != nil,
                 "a bar with no scroll view is at its edge and takes the scroll edge appearance", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));
    id compactEdge = make_kind(@"UINavigationBarAppearance", YES);
    [compactEdge configureWithOpaqueBackground];
    [compactEdge setBackgroundColor:[UIColor purpleColor]];
    [navigation charonHostSetCompactScrollEdgeAppearance:compactEdge];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsLandscapePhone]) hasPrefix:@"128 0 128 255"], "the compact scroll edge appearance goes to the landscape metrics at the edge", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsLandscapePhone]));
    [navigation charonHostSetCompactScrollEdgeAppearance:nil];
    [navigation charonHostSetScrollEdgeAppearance:nil];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"0 0 255 255"] && [navigation backgroundImageForBarMetrics:UIBarMetricsLandscapePhone] == nil, "without a scroll edge appearance the standard one is used at the edge", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));

    UINavigationItem *first = [[UINavigationItem alloc] initWithTitle:@"one"], *second = [[UINavigationItem alloc] initWithTitle:@"two"];
    [navigation pushNavigationItem:first animated:NO];
    [navigation pushNavigationItem:second animated:NO];
    id itemGreen = make_kind(@"UINavigationBarAppearance", YES);
    [itemGreen configureWithOpaqueBackground];
    [itemGreen setBackgroundColor:[UIColor greenColor]];
    [second charonHostSetStandardAppearance:itemGreen];
    [navigation charonHostCharon_refreshForced:NO];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"0 255 0 255"], "the appearance of the top item is the bar's", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));
    [[second charonHostStandardAppearance] setBackgroundColor:[UIColor purpleColor]];
    settle();
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"128 0 128 255"], "a change to the appearance of the top item is applied", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));
    id itemEdge = make_kind(@"UINavigationBarAppearance", YES);
    [itemEdge configureWithOpaqueBackground];
    [itemEdge setBackgroundColor:[UIColor orangeColor]];
    [second charonHostSetScrollEdgeAppearance:itemEdge];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"255 128 0 255"], "the scroll edge appearance of the top item comes before its standard one at the edge", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));
    [second charonHostSetScrollEdgeAppearance:nil];
    [navigation popNavigationItemAnimated:NO];
    [navigation charonHostCharon_refreshForced:NO];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"0 0 255 255"], "popping the item returns the bar to its own appearance", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));
    [first charonHostSetStandardAppearance:itemGreen];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"0 255 0 255"], "setting the appearance of the top item applies it at once", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));
    [first charonHostSetStandardAppearance:nil];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"0 0 255 255"], "clearing it returns the bar to its own", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));

    UITabBar *itemTabs = [[UITabBar alloc] init];
    UITabBarItem *tabOne = [[UITabBarItem alloc] initWithTitle:@"a" image:nil tag:0], *tabTwo = [[UITabBarItem alloc] initWithTitle:@"b" image:nil tag:1];
    itemTabs.items = @[tabOne, tabTwo];
    id tabOwn = make_kind(@"UITabBarAppearance", YES), tabItemApp = make_kind(@"UITabBarAppearance", YES);
    [tabOwn configureWithOpaqueBackground];
    [tabOwn setBackgroundColor:[UIColor redColor]];
    [tabItemApp configureWithOpaqueBackground];
    [tabItemApp setBackgroundColor:[UIColor greenColor]];
    [itemTabs charonHostSetStandardAppearance:tabOwn];
    [tabTwo charonHostSetStandardAppearance:tabItemApp];
    itemTabs.selectedItem = tabOne;
    [itemTabs charonHostCharon_refreshForced:NO];
    charon_check([pixel(itemTabs.backgroundImage) hasPrefix:@"255 0 0 255"], "a tab bar with an item that has no appearance keeps its own", pixel(itemTabs.backgroundImage));
    itemTabs.selectedItem = tabTwo;
    [itemTabs charonHostCharon_refreshForced:NO];
    charon_check([pixel(itemTabs.backgroundImage) hasPrefix:@"0 255 0 255"], "the appearance of the selected tab item is the bar's", pixel(itemTabs.backgroundImage));

    id transparent = make_kind(@"UINavigationBarAppearance", YES);
    [navigation charonHostSetStandardAppearance:transparent];
    charon_check([pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]) hasPrefix:@"0 0 0 0"] && navigation.shadowImage.size.width == 0, "a transparent appearance clears the bar and its shadow", pixel([navigation backgroundImageForBarMetrics:UIBarMetricsDefault]));
    id blur = make_kind(@"UINavigationBarAppearance", YES);
    [blur setBackgroundEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleLight]];
    [navigation charonHostSetStandardAppearance:blur];
    charon_check([navigation backgroundImageForBarMetrics:UIBarMetricsDefault] == nil, "a blur effect leaves the bar its own look", @"an image is set");
    id image = make_kind(@"UINavigationBarAppearance", YES);
    [image setBackgroundImage:images[1]];
    [image setShadowImage:images[0]];
    [navigation charonHostSetStandardAppearance:image];
    charon_check(CGSizeEqualToSize([navigation backgroundImageForBarMetrics:UIBarMetricsDefault].size, ((UIImage *)images[1]).size) && CGSizeEqualToSize(navigation.shadowImage.size, ((UIImage *)images[0]).size), "a background image and a shadow image are handed on as they are", [NSString stringWithFormat:@"%@ %@", [navigation backgroundImageForBarMetrics:UIBarMetricsDefault], navigation.shadowImage]);
    [navigation charonHostSetStandardAppearance:nil];
    settle();
    charon_check([navigation backgroundImageForBarMetrics:UIBarMetricsDefault] == nil && navigation.shadowImage == nil && navigation.titleTextAttributes == nil, "clearing the standard appearance takes the look back", @"something stays");
    charon_check([proxy titleTextAttributesForState:UIControlStateNormal][UITextAttributeTextColor] == nil && [proxy backgroundImageForState:UIControlStateNormal style:UIBarButtonItemStylePlain barMetrics:UIBarMetricsDefault] == nil, "the buttons are cleared as well", @"they stay");

    UINavigationBar *untouched = [[UINavigationBar alloc] init];
    id defaultAppearance = [untouched charonHostStandardAppearance];
    (void)defaultAppearance;
    [untouched charonHostSetCompactAppearance:nil];
    settle();
    charon_check([untouched backgroundImageForBarMetrics:UIBarMetricsDefault] == nil && untouched.titleTextAttributes == nil, "reading the default appearance changes nothing", @"the bar changed");
    [[untouched charonHostStandardAppearance] setTitleTextAttributes:@{NSForegroundColorAttributeName: red}];
    settle();
    charon_check([untouched.titleTextAttributes[UITextAttributeTextColor] isEqual:red], "changing the default appearance in place applies it", @"the title colour is missing");

    UIToolbar *toolbar = [[UIToolbar alloc] init];
    id toolbarAppearance = make_kind(@"UIToolbarAppearance", YES);
    [toolbarAppearance configureWithOpaqueBackground];
    [toolbarAppearance setBackgroundColor:red];
    [[toolbarAppearance doneButtonAppearance].normal setBackgroundImage:images[1]];
    [toolbar charonHostSetStandardAppearance:toolbarAppearance];
    charon_check([pixel([toolbar backgroundImageForToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault]) hasPrefix:@"255 0 0 255"], "a toolbar takes the background colour as a solid image", pixel([toolbar backgroundImageForToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault]));
    charon_check([toolbar shadowImageForToolbarPosition:UIBarPositionAny].size.width == 1, "a toolbar takes the shadow as a hairline", @"no hairline");
    UIBarButtonItem *toolbarProxy = [UIBarButtonItem appearanceWhenContainedIn:[UIToolbar class], nil];
    charon_check([toolbarProxy backgroundImageForState:UIControlStateNormal style:UIBarButtonItemStyleDone barMetrics:UIBarMetricsDefault] == images[1], "the done button image reaches the buttons of toolbars", @"the image is missing");
    [toolbar charonHostSetStandardAppearance:nil];
    settle();
    charon_check([toolbar backgroundImageForToolbarPosition:UIBarPositionAny barMetrics:UIBarMetricsDefault] == nil, "clearing the toolbar appearance takes the look back", @"an image stays");

    RecordingTabBar *tabs = [[RecordingTabBar alloc] init];
    id tabAppearance = make_kind(@"UITabBarAppearance", YES);
    [tabAppearance configureWithOpaqueBackground];
    [tabAppearance setBackgroundColor:red];
    [tabAppearance setSelectionIndicatorImage:images[0]];
    [[tabAppearance stackedLayoutAppearance].selected setIconColor:[UIColor greenColor]];
    [[tabAppearance stackedLayoutAppearance].normal setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blueColor]}];
    [[tabAppearance stackedLayoutAppearance].selected setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor yellowColor]}];
    [tabs charonHostSetStandardAppearance:tabAppearance];
    charon_check([pixel(tabs.backgroundImage) hasPrefix:@"255 0 0 255"] && tabs.shadowImage.size.width == 1, "a tab bar takes the background colour and the shadow", pixel(tabs.backgroundImage));
    charon_check(CGSizeEqualToSize(tabs.selectionIndicatorImage.size, ((UIImage *)images[0]).size) && [tabs.recordedTint isEqual:[UIColor greenColor]], "the selection indicator image and the selected icon colour are applied", [NSString stringWithFormat:@"%@ %@", tabs.selectionIndicatorImage, tabs.recordedTint]);
    UITabBarItem *itemProxy = [UITabBarItem appearanceWhenContainedIn:[UITabBar class], nil];
    charon_check([[itemProxy titleTextAttributesForState:UIControlStateNormal][UITextAttributeTextColor] isEqual:[UIColor blueColor]] && [[itemProxy titleTextAttributesForState:UIControlStateSelected][UITextAttributeTextColor] isEqual:[UIColor yellowColor]],
                 "the normal and selected tab titles reach the tab items", @"a colour is missing");
    [tabs charonHostSetStandardAppearance:nil];
    settle();
    charon_check(tabs.backgroundImage == nil && tabs.selectionIndicatorImage == nil && tabs.recordedTint == nil, "clearing the tab bar appearance takes the look back", @"something stays");
}


static void check_equality(void)
{
    NSArray *kinds = @[@"UIBarAppearance", @"UINavigationBarAppearance", @"UIToolbarAppearance", @"UITabBarAppearance", @"UIBarButtonItemAppearance", @"UITabBarItemAppearance"];
    for (NSString *kind in kinds) {
        id ours = make_kind(kind, YES), system = make_kind(kind, NO), oursAgain = make_kind(kind, YES), systemAgain = make_kind(kind, NO);
        charon_check([ours isEqual:oursAgain] == [system isEqual:systemAgain] && [ours hash] == [oursAgain hash] && [ours isEqual:ours] && ![ours isEqual:nil] && ![ours isEqual:@"text"] && ![system isEqual:@"text"],
                     NAMED(@"two new %@ are equal with equal hashes", kind), @"the equality differs");
        for (NSString *other in kinds)
            if (![other isEqual:kind])
                charon_check([ours isEqual:make_kind(other, YES)] == [system isEqual:make_kind(other, NO)], NAMED(@"a new %@ is not equal to a new %@", kind, other), @"the equality differs");
    }
    id ours = make_kind(@"UIBarAppearance", YES), system = make_kind(@"UIBarAppearance", NO), oursAgain = make_kind(@"UIBarAppearance", YES), systemAgain = make_kind(@"UIBarAppearance", NO);
    [ours setBackgroundColor:[UIColor redColor]];
    [system setBackgroundColor:[UIColor redColor]];
    charon_check([ours isEqual:oursAgain] == [system isEqual:systemAgain] && ![ours isEqual:oursAgain], "a different colour is a different appearance", @"the equality differs");
    [oursAgain setBackgroundColor:[UIColor redColor]];
    [systemAgain setBackgroundColor:[UIColor redColor]];
    charon_check([ours isEqual:oursAgain] == [system isEqual:systemAgain] && [ours hash] == [oursAgain hash], "the same colour is the same appearance", @"the equality differs");
    id ourTab = make_kind(@"UITabBarAppearance", YES), systemTab = make_kind(@"UITabBarAppearance", NO);
    [[ourTab stackedLayoutAppearance].normal setIconColor:[UIColor redColor]];
    [[systemTab stackedLayoutAppearance].normal setIconColor:[UIColor redColor]];
    charon_check([ourTab isEqual:make_kind(@"UITabBarAppearance", YES)] == [systemTab isEqual:make_kind(@"UITabBarAppearance", NO)] && ![ourTab isEqual:make_kind(@"UITabBarAppearance", YES)], "an icon colour makes a tab bar appearance different", @"the equality differs");

    for (NSString *kind in kinds) {
        id ourObject = make_kind(kind, YES), systemObject = make_kind(kind, NO);
        NSData *data = archive(ourObject);
        id decoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[ourObject class] fromData:data error:NULL];
        id systemDecoded = [NSKeyedUnarchiver unarchivedObjectOfClass:[systemObject class] fromData:archive(systemObject) error:NULL];
        charon_check(decoded && systemDecoded && [decoded isKindOfClass:[ourObject class]] && [decoded isEqual:ourObject] && [systemDecoded isEqual:systemObject] && [[decoded copy] isEqual:decoded],
                     NAMED(@"%@ makes a secure archive and reads it back equal", kind), @"the round trip differs");
        charon_check([normalised(decoded) isEqual:normalised(ourObject)], NAMED(@"%@ reads back with the description it was archived with", kind), @"the description differs");
    }
    id ourNavigation = make_kind(@"UINavigationBarAppearance", YES);
    [ourNavigation configureWithOpaqueBackground];
    [ourNavigation setBackgroundColor:[UIColor colorWithRed:0.2 green:0.4 blue:0.6 alpha:0.8]];
    [ourNavigation setBackgroundImage:images[0]];
    [ourNavigation setShadowColor:nil];
    [ourNavigation setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor redColor], NSFontAttributeName: [UIFont boldSystemFontOfSize:20], NSKernAttributeName: @2}];
    [ourNavigation setTitlePositionAdjustment:UIOffsetMake(2, 3)];
    [[ourNavigation buttonAppearance].normal setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor blueColor]}];
    [[ourNavigation buttonAppearance].highlighted setBackgroundImage:images[1]];
    [ourNavigation setBackIndicatorImage:images[0] transitionMaskImage:images[1]];
    id round = unarchive(ourNavigation);
    charon_check([snap(round) hasPrefix:@"idiom"] && [[round backgroundColor] isEqual:[ourNavigation backgroundColor]] && [round shadowColor] == nil && [round backgroundEffect] == nil && CGSizeEqualToSize([round backgroundImage].size, ((UIImage *)images[0]).size) &&
                 [[round titleTextAttributes][NSKernAttributeName] isEqual:@2] && UIOffsetEqualToOffset([round titlePositionAdjustment], UIOffsetMake(2, 3)) && [[[round buttonAppearance].normal titleTextAttributes][NSForegroundColorAttributeName] isEqual:[UIColor blueColor]] &&
                 CGSizeEqualToSize([[round buttonAppearance].highlighted backgroundImage].size, ((UIImage *)images[1]).size) && CGSizeEqualToSize([round backIndicatorImage].size, ((UIImage *)images[0]).size) &&
                 CGSizeEqualToSize([round backIndicatorTransitionMaskImage].size, ((UIImage *)images[1]).size) && [round isEqual:ourNavigation] == NO,
                 "a navigation bar appearance keeps every value through a secure archive, the images as pictures", @"a value differs");
    id tab = make_kind(@"UITabBarAppearance", YES);
    [[tab stackedLayoutAppearance].normal setIconColor:[UIColor redColor]];
    [[tab stackedLayoutAppearance].selected setBadgeBackgroundColor:[UIColor greenColor]];
    [tab setStackedItemWidth:9];
    [tab setSelectionIndicatorTintColor:[UIColor blueColor]];
    id tabRound = unarchive(tab);
    charon_check([tabRound isEqual:tab] && [[tabRound stackedLayoutAppearance].selected iconColor] == nil && [[[tabRound stackedLayoutAppearance].normal iconColor] isEqual:[UIColor redColor]] && [tabRound stackedItemWidth] == 9,
                 "a tab bar appearance keeps its icon colour on the state it was set on through an archive", @"a value differs");
}


static void check_selectors(void)
{
    NSDictionary *selectors = @{
        @"UIBarAppearance": @[@"idiom", @"backgroundEffect", @"setBackgroundEffect:", @"backgroundColor", @"setBackgroundColor:", @"backgroundImage", @"setBackgroundImage:", @"backgroundImageContentMode",
                              @"setBackgroundImageContentMode:", @"shadowColor", @"setShadowColor:", @"shadowImage", @"setShadowImage:", @"configureWithDefaultBackground", @"configureWithOpaqueBackground",
                              @"configureWithTransparentBackground", @"initWithIdiom:", @"initWithBarAppearance:", @"initWithCoder:", @"encodeWithCoder:", @"copy", @"copyWithZone:", @"isEqual:", @"hash", @"init"],
        @"UINavigationBarAppearance": @[@"titleTextAttributes", @"setTitleTextAttributes:", @"largeTitleTextAttributes", @"setLargeTitleTextAttributes:", @"titlePositionAdjustment", @"setTitlePositionAdjustment:",
                                        @"buttonAppearance", @"setButtonAppearance:", @"doneButtonAppearance", @"setDoneButtonAppearance:", @"backButtonAppearance", @"setBackButtonAppearance:", @"backIndicatorImage",
                                        @"backIndicatorTransitionMaskImage", @"setBackIndicatorImage:transitionMaskImage:", @"prominentButtonAppearance", @"setProminentButtonAppearance:"],
        @"UIToolbarAppearance": @[@"buttonAppearance", @"setButtonAppearance:", @"doneButtonAppearance", @"setDoneButtonAppearance:", @"prominentButtonAppearance", @"setProminentButtonAppearance:"],
        @"UITabBarAppearance": @[@"stackedLayoutAppearance", @"setStackedLayoutAppearance:", @"inlineLayoutAppearance", @"setInlineLayoutAppearance:", @"compactInlineLayoutAppearance",
                                 @"setCompactInlineLayoutAppearance:", @"selectionIndicatorTintColor", @"setSelectionIndicatorTintColor:", @"selectionIndicatorImage", @"setSelectionIndicatorImage:",
                                 @"stackedItemPositioning", @"setStackedItemPositioning:", @"stackedItemWidth", @"setStackedItemWidth:", @"stackedItemSpacing", @"setStackedItemSpacing:"],
        @"UIBarButtonItemAppearance": @[@"init", @"initWithStyle:", @"initWithCoder:", @"encodeWithCoder:", @"copy", @"copyWithZone:", @"configureWithDefaultForStyle:", @"normal", @"highlighted", @"disabled", @"focused", @"isEqual:", @"hash"],
        @"UITabBarItemAppearance": @[@"init", @"initWithStyle:", @"initWithCoder:", @"encodeWithCoder:", @"copy", @"copyWithZone:", @"configureWithDefaultForStyle:", @"normal", @"selected", @"disabled", @"focused", @"isEqual:", @"hash"],
        @"UIBarButtonItemStateAppearance": @[@"titleTextAttributes", @"setTitleTextAttributes:", @"titlePositionAdjustment", @"setTitlePositionAdjustment:", @"backgroundImage", @"setBackgroundImage:",
                                             @"backgroundImagePositionAdjustment", @"setBackgroundImagePositionAdjustment:"],
        @"UITabBarItemStateAppearance": @[@"titleTextAttributes", @"setTitleTextAttributes:", @"titlePositionAdjustment", @"setTitlePositionAdjustment:", @"iconColor", @"setIconColor:", @"badgePositionAdjustment",
                                          @"setBadgePositionAdjustment:", @"badgeBackgroundColor", @"setBadgeBackgroundColor:", @"badgeTextAttributes", @"setBadgeTextAttributes:", @"badgeTitlePositionAdjustment",
                                          @"setBadgeTitlePositionAdjustment:"]};
    for (NSString *name in selectors) {
        Class ours = port_class(name), system = NSClassFromString(name);
        NSMutableArray *missing = [NSMutableArray array];
        for (NSString *selector in selectors[name]) {
            BOOL ourAnswer = [ours instancesRespondToSelector:NSSelectorFromString(selector)], systemAnswer = [system instancesRespondToSelector:NSSelectorFromString(selector)];
            if (ourAnswer != systemAnswer)
                [missing addObject:selector];
        }
        charon_check(!missing.count, NAMED(@"%@ answers the selectors the system's answers", name), [missing componentsJoinedByString:@" "]);
    }
}


static void check_cases(void)
{
    NSArray *cases = charon_appearance_cases();
    CharonAppearanceMaker portMaker = ^id(NSString *kind) { return make_kind(kind, YES); };
    CharonAppearanceMaker systemMaker = ^id(NSString *kind) { return make_kind(kind, NO); };
    int before = charon_failures;
    NSMutableArray *expectations = [NSMutableArray array];
    for (NSDictionary *one in cases) {
        id ours = ((CharonAppearanceCase)one[@"body"])(portMaker), system = ((CharonAppearanceCase)one[@"body"])(systemMaker);
        charon_check(ours && system && [snap(ours) isEqual:snap(system)] && [normalised(ours) isEqual:normalised(system)], NAMED(@"scripted case: %@", one[@"name"]),
                     [NSString stringWithFormat:@"%@", difference([snap(ours) stringByAppendingString:normalised(ours)], [snap(system) stringByAppendingString:normalised(system)])]);
    }
    charon_font_names = NO;
    for (NSDictionary *one in cases)
        [expectations addObject:snap(((CharonAppearanceCase)one[@"body"])(systemMaker))];
    charon_font_names = YES;
    const char *path = getenv("APPEARANCES_EXPECTATIONS");
    if (path && charon_failures == before) {
        NSMutableString *text = [NSMutableString stringWithString:@"static NSString *const charon_appearance_expectations[] = {\n"];
        for (NSString *expected in expectations) {
            NSString *escaped = [[expected stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
            [text appendFormat:@"    @\"%@\",\n", escaped];
        }
        [text appendString:@"};\n"];
        [text writeToFile:@(path) atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    }
}

static void run_fuzz(const char *name, id (^make)(BOOL port), NSArray *operations, int runs, int length)
{
    int failures = 0;
    for (int run = 0; run < runs && failures < 3; run++) {
        id ours = make(YES), system = make(NO);
        NSMutableString *trace = [NSMutableString string];
        NSString *problem = nil;
        for (int step = 0; step < length && !problem; step++) {
            NSDictionary *chosen = operations[next_random() % operations.count];
            unsigned pick = next_random();
            [trace appendFormat:@"%@(%u) ", chosen[@"name"], pick & 0xffff];
            id ourResult = nil, systemResult = nil;
            NSString *ourOutcome = attempt(ours, chosen[@"operation"], pick, &ourResult);
            NSString *systemOutcome = attempt(system, chosen[@"operation"], pick, &systemResult);
            ours = ourResult;
            system = systemResult;
            if (getenv("FUZZ_TRACE") && !strcmp(getenv("FUZZ_TRACE"), name) && run == atoi(getenv("FUZZ_RUN"))) {
                printf("STEP %s\n  ours   %s\n  system %s\n", [trace UTF8String], [[normalised(ours) stringByReplacingOccurrencesOfString:@"\n" withString:@"|"] UTF8String],
                       [[normalised(system) stringByReplacingOccurrencesOfString:@"\n" withString:@"|"] UTF8String]);
            }
            if (![ourOutcome isEqual:systemOutcome])
                problem = [NSString stringWithFormat:@"outcome %@ != %@", ourOutcome, systemOutcome];
            else if (![snap(ours) isEqual:snap(system)])
                problem = [NSString stringWithFormat:@"state%@", difference(snap(ours), snap(system))];
            else if ([ours isEqual:[ours copy]] != [system isEqual:[system copy]] || [ours hash] != [[ours copy] hash] || [system hash] != [[system copy] hash])
                problem = @"equality of a copy";
            else if (![normalised(ours) isEqual:normalised(system)])
                problem = [NSString stringWithFormat:@"description%@", difference(normalised(ours), normalised(system))];
        }
        if (problem) {
            failures++;
            charon_check(NO, NAMED(@"%s run %d", name, run), [NSString stringWithFormat:@"after %@: %@", trace, problem]);
        }
    }
    if (!failures)
        charon_check(YES, NAMED(@"%s matches the system over %d random sequences of %d changes", name, runs, length), @"");
}

int main(void)
{
    @autoreleasepool {
        charon_font_names = YES;
        charon_prepare_images();
        if (getenv("FUZZ_SEED"))
            state_random = (unsigned)atoi(getenv("FUZZ_SEED"));
        masks = [NSMutableArray array];
        UIBarAppearance *systemBar = [[UIBarAppearance alloc] init];
        id portBar = [[port_class(@"UIBarAppearance") alloc] init];
        add_mask(systemBar.shadowColor, [portBar shadowColor], @"<SHADOW>");
        UIBarAppearance *systemOpaque = [[UIBarAppearance alloc] init];
        [systemOpaque configureWithOpaqueBackground];
        id portOpaque = [[port_class(@"UIBarAppearance") alloc] init];
        [portOpaque configureWithOpaqueBackground];
        add_mask(systemOpaque.backgroundColor, [portOpaque backgroundColor], @"<WHITE>");

        UINavigationBarAppearance *systemNavigation = [[UINavigationBarAppearance alloc] init];
        id portNavigation = [[port_class(@"UINavigationBarAppearance") alloc] init];
        add_mask(systemNavigation.titleTextAttributes[NSForegroundColorAttributeName], [portNavigation titleTextAttributes][NSForegroundColorAttributeName], @"<LABEL>");
        charon_check(port_class(@"UIBarAppearance") && port_class(@"UINavigationBarAppearance") && port_class(@"UIToolbarAppearance") && port_class(@"UITabBarAppearance") &&
                     port_class(@"UIBarButtonItemAppearance") && port_class(@"UIBarButtonItemStateAppearance") && port_class(@"UITabBarItemAppearance") && port_class(@"UITabBarItemStateAppearance"),
                     "the eight classes are there", @"one is missing");
        for (NSString *name in @[@"UIBarAppearance", @"UINavigationBarAppearance", @"UIToolbarAppearance", @"UITabBarAppearance", @"UIBarButtonItemAppearance", @"UITabBarItemAppearance"]) {
            Class ours = port_class(name), system = NSClassFromString(name);
            charon_check([ours supportsSecureCoding] == [system supportsSecureCoding] && [ours conformsToProtocol:@protocol(NSCopying)] == [system conformsToProtocol:@protocol(NSCopying)],
                         NAMED(@"%@ adopts NSCopying and secure coding as the system's does", name), @"the adoption differs");
            charon_check(class_getSuperclass(ours) == port_class(class_getName(class_getSuperclass(system)) ? [NSString stringWithUTF8String:class_getName(class_getSuperclass(system))] : @"")
                         || (class_getSuperclass(system) == [NSObject class] && class_getSuperclass(ours) == [NSObject class]),
                         NAMED(@"%@ has the superclass of the system's", name), @"the superclass differs");
        }

        run_fuzz("UIBarButtonItemAppearance", ^id(BOOL port) {
            return port ? [[port_class(@"UIBarButtonItemAppearance") alloc] init] : [[UIBarButtonItemAppearance alloc] init];
        }, root_button_operations(), 1500, 16);
        run_fuzz("UITabBarItemAppearance", ^id(BOOL port) {
            return port ? [[port_class(@"UITabBarItemAppearance") alloc] init] : [[UITabBarItemAppearance alloc] init];
        }, root_item_operations(), 1500, 16);
        run_fuzz("UIBarAppearance", ^id(BOOL port) { return make_kind(@"UIBarAppearance", port); }, shared_bar_operations(@"UIBarAppearance"), 1500, 16);
        run_fuzz("UINavigationBarAppearance", ^id(BOOL port) { return make_kind(@"UINavigationBarAppearance", port); }, navigation_operations(), 1500, 20);
        run_fuzz("UIToolbarAppearance", ^id(BOOL port) { return make_kind(@"UIToolbarAppearance", port); }, toolbar_operations(), 1500, 16);
        run_fuzz("UITabBarAppearance", ^id(BOOL port) { return make_kind(@"UITabBarAppearance", port); }, tab_operations(), 1500, 20);

        UINavigationBar *ourNavigation = [[UINavigationBar alloc] init], *systemNavigation2 = [[UINavigationBar alloc] init];
        check_accessors(@"UINavigationBar", ourNavigation, systemNavigation2, @[@"standardAppearance", @"compactAppearance", @"scrollEdgeAppearance", @"compactScrollEdgeAppearance"], @"UINavigationBarAppearance");
        UIToolbar *ourToolbar = [[UIToolbar alloc] init], *systemToolbar = [[UIToolbar alloc] init];
        check_accessors(@"UIToolbar", ourToolbar, systemToolbar, @[@"standardAppearance", @"compactAppearance", @"scrollEdgeAppearance", @"compactScrollEdgeAppearance"], @"UIToolbarAppearance");
        UITabBar *ourTabs = [[UITabBar alloc] init], *systemTabs = [[UITabBar alloc] init];
        check_accessors(@"UITabBar", ourTabs, systemTabs, @[@"standardAppearance", @"scrollEdgeAppearance"], @"UITabBarAppearance");
        charon_check(![ourTabs respondsToSelector:NSSelectorFromString(@"charonHostCompactAppearance")] && ![systemTabs respondsToSelector:NSSelectorFromString(@"compactAppearance")], "a tab bar has no compact appearance, as the system's has none", @"it answers");
        UINavigationItem *ourItem = [[UINavigationItem alloc] initWithTitle:@"t"], *systemItem = [[UINavigationItem alloc] initWithTitle:@"t"];
        check_accessors(@"UINavigationItem", ourItem, systemItem, @[@"standardAppearance", @"compactAppearance", @"scrollEdgeAppearance", @"compactScrollEdgeAppearance"], @"UINavigationBarAppearance");
        UITabBarItem *ourTabItem = [[UITabBarItem alloc] initWithTitle:@"t" image:nil tag:0], *systemTabItem = [[UITabBarItem alloc] initWithTitle:@"t" image:nil tag:0];
        check_accessors(@"UITabBarItem", ourTabItem, systemTabItem, @[@"standardAppearance", @"scrollEdgeAppearance"], @"UITabBarAppearance");
        check_application();
        check_equality();
        check_selectors();
        check_cases();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}

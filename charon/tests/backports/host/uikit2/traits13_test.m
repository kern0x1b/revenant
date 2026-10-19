#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "check.h"

@interface CharonHostUITraitCollection : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)traitCollectionWithTraitsFromCollections:(NSArray *)traitCollections;
+ (instancetype)traitCollectionWithDisplayScale:(CGFloat)scale;
+ (instancetype)traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass;
+ (instancetype)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)style;
+ (instancetype)traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)contrast;
+ (instancetype)traitCollectionWithLegibilityWeight:(UILegibilityWeight)weight;
+ (instancetype)traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)level;
+ (instancetype)traitCollectionWithActiveAppearance:(UIUserInterfaceActiveAppearance)appearance;
+ (instancetype)currentTraitCollection;
+ (void)setCurrentTraitCollection:(id)collection;
- (void)performAsCurrentTraitCollection:(void (^)(void))actions;
- (BOOL)hasDifferentColorAppearanceComparedToTraitCollection:(id)other;
- (BOOL)containsTraitsInCollection:(id)trait;
@property (nonatomic, readonly) UIUserInterfaceStyle userInterfaceStyle;
@property (nonatomic, readonly) UIAccessibilityContrast accessibilityContrast;
@property (nonatomic, readonly) UILegibilityWeight legibilityWeight;
@property (nonatomic, readonly) UIUserInterfaceLevel userInterfaceLevel;
@property (nonatomic, readonly) UIUserInterfaceActiveAppearance activeAppearance;
@property (nonatomic, readonly) CGFloat displayScale;
@property (nonatomic, readonly) id imageConfiguration;
@end

@interface UIScreen (CharonHostTraits)
- (id)charonHostTraitCollection;
@end

void charon_windowed_run(UIWindow *window);

static NSString *appearance(id c)
{
    return [NSString stringWithFormat:@"contrast %ld legibility %ld level %ld scale %g", (long)[c accessibilityContrast], (long)[c legibilityWeight], (long)[c userInterfaceLevel], (double)[c displayScale]];
}

static NSString *fields(id c)
{
    return [NSString stringWithFormat:@"style %ld contrast %ld legibility %ld level %ld active %ld scale %g", (long)[c userInterfaceStyle], (long)[c accessibilityContrast], (long)[c legibilityWeight],
            (long)[c userInterfaceLevel], (long)[c activeAppearance], (double)[c displayScale]];
}

static NSString *traits_of(id collection)
{
    NSString *description = [collection description];
    NSRange separator = [description rangeOfString:@"; "];
    return separator.location == NSNotFound ? description : [description substringFromIndex:NSMaxRange(separator)];
}

static NSArray *archive_keys(id object)
{
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:NULL];
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
    NSMutableArray *rows = [NSMutableArray array];
    for (id entry in [plist objectForKey:@"$objects"]) {
        if (![entry isKindOfClass:[NSDictionary class]])
            continue;
        for (NSString *key in entry) {
            if (![key hasPrefix:@"$"])
                [rows addObject:[NSString stringWithFormat:@"%@=%@", key, entry[key]]];
        }
    }
    [rows sortUsingSelector:@selector(compare:)];
    return rows;
}

static void agree(NSString *name, NSString *ours, NSString *system)
{
    charon_check([ours isEqualToString:system], name.UTF8String, [NSString stringWithFormat:@"port   %@\nsystem %@", ours, system]);
}

static unsigned long long state = 88172645463325252ULL;
static NSUInteger next(NSUInteger below)
{
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return (NSUInteger)(state % below);
}

void charon_windowed_run(UIWindow *window)
{
    Class port = NSClassFromString(@"CharonHostUITraitCollection"), system = [UITraitCollection class];
    charon_check(port != Nil, "the port's collection is linked under its host name", @"missing");

    NSInteger levels[] = {-1, 0, 1};
    for (int index = 0; index < 3; index++) {
        NSInteger v = levels[index];
        agree([NSString stringWithFormat:@"contrast %ld", (long)v], fields([port traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)v]), fields([system traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)v]));
        agree([NSString stringWithFormat:@"legibility %ld", (long)v], fields([port traitCollectionWithLegibilityWeight:(UILegibilityWeight)v]), fields([system traitCollectionWithLegibilityWeight:(UILegibilityWeight)v]));
        agree([NSString stringWithFormat:@"level %ld", (long)v], fields([port traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)v]), fields([system traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)v]));
        agree([NSString stringWithFormat:@"active %ld", (long)v], fields([port traitCollectionWithActiveAppearance:(UIUserInterfaceActiveAppearance)v]), fields([system traitCollectionWithActiveAppearance:(UIUserInterfaceActiveAppearance)v]));
        agree([NSString stringWithFormat:@"contrast description %ld", (long)v], traits_of([port traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)v]), traits_of([system traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)v]));
        agree([NSString stringWithFormat:@"level description %ld", (long)v], traits_of([port traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)v]), traits_of([system traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)v]));
        agree([NSString stringWithFormat:@"legibility description %ld", (long)v], traits_of([port traitCollectionWithLegibilityWeight:(UILegibilityWeight)v]), traits_of([system traitCollectionWithLegibilityWeight:(UILegibilityWeight)v]));
        agree([NSString stringWithFormat:@"contrast archive %ld", (long)v], [archive_keys([port traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)v]) componentsJoinedByString:@"|"],
              [archive_keys([system traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)v]) componentsJoinedByString:@"|"]);
    }

    for (int round = 0; round < 400; round++) {
        NSMutableArray *ours = [NSMutableArray array], *theirs = [NSMutableArray array];
        NSUInteger count = 1 + next(5);
        for (NSUInteger part = 0; part < count; part++) {
            NSInteger value = (NSInteger)next(3) - 1;
            switch (next(7)) {
            case 0:
                [ours addObject:[port traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)value]];
                [theirs addObject:[system traitCollectionWithAccessibilityContrast:(UIAccessibilityContrast)value]];
                break;
            case 1:
                [ours addObject:[port traitCollectionWithLegibilityWeight:(UILegibilityWeight)value]];
                [theirs addObject:[system traitCollectionWithLegibilityWeight:(UILegibilityWeight)value]];
                break;
            case 2:
                [ours addObject:[port traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)value]];
                [theirs addObject:[system traitCollectionWithUserInterfaceLevel:(UIUserInterfaceLevel)value]];
                break;
            case 3:
                [ours addObject:[port traitCollectionWithActiveAppearance:(UIUserInterfaceActiveAppearance)value]];
                [theirs addObject:[system traitCollectionWithActiveAppearance:(UIUserInterfaceActiveAppearance)value]];
                break;
            case 4:
                [ours addObject:[port traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)(value + 1)]];
                [theirs addObject:[system traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)(value + 1)]];
                break;
            case 5:
                [ours addObject:[port traitCollectionWithDisplayScale:(CGFloat)(value + 2)]];
                [theirs addObject:[system traitCollectionWithDisplayScale:(CGFloat)(value + 2)]];
                break;
            default:
                [ours addObject:[port traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)(value + 1)]];
                [theirs addObject:[system traitCollectionWithHorizontalSizeClass:(UIUserInterfaceSizeClass)(value + 1)]];
            }
        }
        id a = [port traitCollectionWithTraitsFromCollections:ours], b = [system traitCollectionWithTraitsFromCollections:theirs];
        NSString *label = [NSString stringWithFormat:@"random %d", round];
        agree([label stringByAppendingString:@" fields"], fields(a), fields(b));
        agree([label stringByAppendingString:@" description"], traits_of(a), traits_of(b));
        agree([label stringByAppendingString:@" archive"], [archive_keys(a) componentsJoinedByString:@"|"], [archive_keys(b) componentsJoinedByString:@"|"]);
        id other = [port traitCollectionWithTraitsFromCollections:@[[port traitCollectionWithAccessibilityContrast:UIAccessibilityContrastHigh]]];
        id otherSystem = [system traitCollectionWithTraitsFromCollections:@[[system traitCollectionWithAccessibilityContrast:UIAccessibilityContrastHigh]]];
        charon_check([a containsTraitsInCollection:other] == [b containsTraitsInCollection:otherSystem], [label stringByAppendingString:@" contains"].UTF8String, @"contains differs");
        charon_check([a hasDifferentColorAppearanceComparedToTraitCollection:other] == [b hasDifferentColorAppearanceComparedToTraitCollection:otherSystem], [label stringByAppendingString:@" different color appearance"].UTF8String,
                     [NSString stringWithFormat:@"%@ against %@: port %d system %d", fields(a), fields(other), [a hasDifferentColorAppearanceComparedToTraitCollection:other], [b hasDifferentColorAppearanceComparedToTraitCollection:otherSystem]]);
        id a2 = [port traitCollectionWithTraitsFromCollections:ours];
        charon_check([a isEqual:a2] && [a hash] == [a2 hash] && [b isEqual:[system traitCollectionWithTraitsFromCollections:theirs]], [label stringByAppendingString:@" equality"].UTF8String, @"equality differs");
    }

    id darkPort = [port traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark], darkSystem = [system traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark];
    id highPort = [port traitCollectionWithTraitsFromCollections:@[[port traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight], [port traitCollectionWithAccessibilityContrast:UIAccessibilityContrastHigh]]],
       highSystem = [system traitCollectionWithTraitsFromCollections:@[[system traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight], [system traitCollectionWithAccessibilityContrast:UIAccessibilityContrastHigh]]];
    agree(@"current at first", appearance([port currentTraitCollection]), appearance([system currentTraitCollection]));
    charon_check([[port currentTraitCollection] userInterfaceStyle] == UIUserInterfaceStyleLight, "the port's current collection is light, as the release's only appearance", @"it is not");
    NSMutableArray *ours = [NSMutableArray array], *theirs = [NSMutableArray array];
    [darkPort performAsCurrentTraitCollection:^{
        [ours addObject:[NSString stringWithFormat:@"%ld %@", (long)[[port currentTraitCollection] userInterfaceStyle], appearance([port currentTraitCollection])]];
        [highPort performAsCurrentTraitCollection:^{
            [ours addObject:[NSString stringWithFormat:@"%ld %@", (long)[[port currentTraitCollection] userInterfaceStyle], appearance([port currentTraitCollection])]];
        }];
        [ours addObject:[NSString stringWithFormat:@"%ld %@", (long)[[port currentTraitCollection] userInterfaceStyle], appearance([port currentTraitCollection])]];
    }];
    [ours addObject:appearance([port currentTraitCollection])];
    [darkSystem performAsCurrentTraitCollection:^{
        [theirs addObject:[NSString stringWithFormat:@"%ld %@", (long)[[system currentTraitCollection] userInterfaceStyle], appearance([system currentTraitCollection])]];
        [highSystem performAsCurrentTraitCollection:^{
            [theirs addObject:[NSString stringWithFormat:@"%ld %@", (long)[[system currentTraitCollection] userInterfaceStyle], appearance([system currentTraitCollection])]];
        }];
        [theirs addObject:[NSString stringWithFormat:@"%ld %@", (long)[[system currentTraitCollection] userInterfaceStyle], appearance([system currentTraitCollection])]];
    }];
    [theirs addObject:appearance([system currentTraitCollection])];
    agree(@"nested current trait collections", [ours componentsJoinedByString:@"\n"], [theirs componentsJoinedByString:@"\n"]);
    [port setCurrentTraitCollection:darkPort];
    [system setCurrentTraitCollection:darkSystem];
    agree(@"set current", [NSString stringWithFormat:@"%ld %@", (long)[[port currentTraitCollection] userInterfaceStyle], appearance([port currentTraitCollection])], [NSString stringWithFormat:@"%ld %@", (long)[[system currentTraitCollection] userInterfaceStyle], appearance([system currentTraitCollection])]);
    [port setCurrentTraitCollection:nil];
    [system setCurrentTraitCollection:nil];
    agree(@"set current back", appearance([port currentTraitCollection]), appearance([system currentTraitCollection]));

    id screen = [[UIScreen mainScreen] charonHostTraitCollection], systemScreen = [UIScreen mainScreen].traitCollection;
    agree(@"screen appearance traits", appearance(screen), appearance(systemScreen));
    charon_check([screen userInterfaceStyle] == UIUserInterfaceStyleLight && [screen activeAppearance] == UIUserInterfaceActiveAppearanceActive, "the screen of the port is light and active", @"it is not");
    id config = [darkPort imageConfiguration], systemConfig = [darkSystem imageConfiguration];
    agree(@"image configuration of a collection", [config description], [systemConfig description]);
    // traitCollection, not charonHostTraitCollection: UIImageConfiguration is a class THIS group defines, so
    // the class is renamed whole and its members keep their names - which is what prefix_selectors.py's
    // ported() decides, and why it refuses to carry a member of a class the port defines. The prefixed name
    // belongs to the UIScreen category two lines above, which is a category on a class the system owns. The
    // check read the wrong one and raised "unrecognized selector" on CharonHostUIImageConfiguration.
    charon_check([[config performSelector:NSSelectorFromString(@"traitCollection")] isEqual:darkPort], "an image configuration holds the collection", @"it does not");
}

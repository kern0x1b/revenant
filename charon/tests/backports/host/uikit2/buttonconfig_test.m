#import <UIKit/UIKit.h>
#import "check.h"
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

@interface CharonHostUIButtonConfiguration : NSObject
+ (instancetype)plainButtonConfiguration;
+ (instancetype)tintedButtonConfiguration;
+ (instancetype)grayButtonConfiguration;
+ (instancetype)filledButtonConfiguration;
+ (instancetype)borderlessButtonConfiguration;
+ (instancetype)borderedButtonConfiguration;
+ (instancetype)borderedTintedButtonConfiguration;
+ (instancetype)borderedProminentButtonConfiguration;
- (instancetype)updatedConfigurationForButton:(UIButton *)button;
- (void)setDefaultContentInsets;
@property (nonatomic, readwrite, strong) UIBackgroundConfiguration *background;
@property (nonatomic, readwrite, assign) UIButtonConfigurationCornerStyle cornerStyle;
@property (nonatomic, readwrite, assign) UIButtonConfigurationSize buttonSize;
@property (nonatomic, readwrite, strong, nullable) UIColor *baseForegroundColor;
@property (nonatomic, readwrite, strong, nullable) UIColor *baseBackgroundColor;
@property (nonatomic, readwrite, strong, nullable) UIImage *image;
@property (nonatomic, readwrite, copy, nullable) UIConfigurationColorTransformer imageColorTransformer;
@property (nonatomic, readwrite, copy, nullable) UIImageSymbolConfiguration *preferredSymbolConfigurationForImage;
@property (nonatomic, readwrite, copy, nullable) NSString *title;
@property (nonatomic, readwrite, copy, nullable) NSAttributedString *attributedTitle;
@property (nonatomic, readwrite, copy, nullable) UIConfigurationTextAttributesTransformer titleTextAttributesTransformer;
@property (nonatomic, readwrite, assign) NSLineBreakMode titleLineBreakMode;
@property (nonatomic, readwrite, copy, nullable) NSString *subtitle;
@property (nonatomic, readwrite, copy, nullable) NSAttributedString *attributedSubtitle;
@property (nonatomic, readwrite, copy, nullable) UIConfigurationTextAttributesTransformer subtitleTextAttributesTransformer;
@property (nonatomic, readwrite, assign) NSLineBreakMode subtitleLineBreakMode;
@property (nonatomic, readwrite, assign) NSDirectionalEdgeInsets contentInsets;
@property (nonatomic, readwrite, assign) NSDirectionalRectEdge imagePlacement;
@property (nonatomic, readwrite, assign) CGFloat imagePadding;
@property (nonatomic, readwrite, assign) CGFloat titlePadding;
@property (nonatomic, readwrite, assign) UIButtonConfigurationTitleAlignment titleAlignment;
@property (nonatomic, readwrite, assign) BOOL automaticallyUpdateForSelection;
@property (nonatomic, readwrite, assign) BOOL showsActivityIndicator;
@property (nonatomic, readwrite, copy, nullable) UIConfigurationColorTransformer activityIndicatorColorTransformer;
@property (nonatomic, readwrite, assign) UIButtonConfigurationMacIdiomStyle macIdiomStyle;
@end

static NSString *charonMutation = nil;
static NSMutableArray *charonKeys = nil;
static BOOL charonPlanted = NO;

static void mutation_refuse(NSString *why)
{
    fprintf(stderr, "MUTATION refused: %s\n", why.UTF8String);
    if (charonKeys.count)
        fprintf(stderr, "MUTATION the keys this case compares are: %s\n",
                [[charonKeys componentsJoinedByString:@" | "] UTF8String]);
    exit(2);
}

static void BOTH(NSString *what, NSString *ours, NSString *theirs)
{
    if (charonMutation) {
        [charonKeys addObject:what];
        BOOL asks = [what isEqualToString:charonMutation];
        if (asks || ([charonMutation isEqualToString:@"auto"] && !charonPlanted)) {
            if (![ours isEqualToString:theirs])
                mutation_refuse([NSString stringWithFormat:
                    @"%@ is asked for, and the two sides do NOT agree on it (%@ vs %@), so a mutation there"
                    @" would fail for a reason that has nothing to do with the mutation", what, ours, theirs]);
            if (asks && charonPlanted)
                mutation_refuse([NSString stringWithFormat:@"%@ was asked for twice", what]);
            printf("MUTATION planted on %s: the port's answer %s becomes %s-PLANTED\n",
                   what.UTF8String, ours.UTF8String, ours.UTF8String);
            ours = [ours stringByAppendingString:@"-PLANTED"];
            charonPlanted = YES;
        }
    }
    charon_check([ours isEqualToString:theirs], what.UTF8String,
                 [NSString stringWithFormat:@"port %@ != system %@", ours, theirs]);
}

#define SIDES(sel) \
    id ours = [sel]; id theirs = [sel]

static void check_constructors(void)
{
    Class port = NSClassFromString(@"CharonHostUIButtonConfiguration");
    charon_check(port != Nil, "the port's configuration class is in the process", @"it is not");

    BOTH(@"a plain configuration is made on both sides",
         [port plainButtonConfiguration] != Nil ? @"made" : @"nothing",
         [UIButtonConfiguration plainButtonConfiguration] != Nil ? @"made" : @"nothing");
    BOTH(@"a tinted configuration is made on both sides",
         [port tintedButtonConfiguration] != Nil ? @"made" : @"nothing",
         [UIButtonConfiguration tintedButtonConfiguration] != Nil ? @"made" : @"nothing");
    BOTH(@"a gray configuration is made on both sides",
         [port grayButtonConfiguration] != Nil ? @"made" : @"nothing",
         [UIButtonConfiguration grayButtonConfiguration] != Nil ? @"made" : @"nothing");
    BOTH(@"a filled configuration is made on both sides",
         [port filledButtonConfiguration] != Nil ? @"made" : @"nothing",
         [UIButtonConfiguration filledButtonConfiguration] != Nil ? @"made" : @"nothing");
    BOTH(@"a borderless configuration is made on both sides",
         [port borderlessButtonConfiguration] != Nil ? @"made" : @"nothing",
         [UIButtonConfiguration borderlessButtonConfiguration] != Nil ? @"made" : @"nothing");
    BOTH(@"a bordered configuration is made on both sides",
         [port borderedButtonConfiguration] != Nil ? @"made" : @"nothing",
         [UIButtonConfiguration borderedButtonConfiguration] != Nil ? @"made" : @"nothing");
    BOTH(@"a bordered tinted configuration is made on both sides",
         [port borderedTintedButtonConfiguration] != Nil ? @"made" : @"nothing",
         [UIButtonConfiguration borderedTintedButtonConfiguration] != Nil ? @"made" : @"nothing");
    BOTH(@"a bordered prominent configuration is made on both sides",
         [port borderedProminentButtonConfiguration] != Nil ? @"made" : @"nothing",
         [UIButtonConfiguration borderedProminentButtonConfiguration] != Nil ? @"made" : @"nothing");
}

static void check_constructor_differences(void)
{
    Class port = NSClassFromString(@"CharonHostUIButtonConfiguration");
    BOTH(@"a filled configuration does not update for selection",
         [@(((CharonHostUIButtonConfiguration *)[port filledButtonConfiguration]).automaticallyUpdateForSelection) stringValue],
         [@([UIButtonConfiguration filledButtonConfiguration].automaticallyUpdateForSelection) stringValue]);
    BOTH(@"a bordered prominent configuration does not update for selection",
         [@(((CharonHostUIButtonConfiguration *)[port borderedProminentButtonConfiguration]).automaticallyUpdateForSelection) stringValue],
         [@([UIButtonConfiguration borderedProminentButtonConfiguration].automaticallyUpdateForSelection) stringValue]);
    BOTH(@"a plain configuration does update for selection",
         [@(((CharonHostUIButtonConfiguration *)[port plainButtonConfiguration]).automaticallyUpdateForSelection) stringValue],
         [@([UIButtonConfiguration plainButtonConfiguration].automaticallyUpdateForSelection) stringValue]);
    BOTH(@"a gray configuration does update for selection",
         [@(((CharonHostUIButtonConfiguration *)[port grayButtonConfiguration]).automaticallyUpdateForSelection) stringValue],
         [@([UIButtonConfiguration grayButtonConfiguration].automaticallyUpdateForSelection) stringValue]);
}

static void check_defaults(void)
{
    CharonHostUIButtonConfiguration *ours = [NSClassFromString(@"CharonHostUIButtonConfiguration") plainButtonConfiguration];
    UIButtonConfiguration *system = [UIButtonConfiguration plainButtonConfiguration];
    charon_check(ours != nil && system != nil, "both sides make a configuration", @"one of the two answered nothing");

    BOTH(@"a fresh configuration's background has the same corner radius",
         ours.background == nil ? @"nil" : [@(ours.background.cornerRadius) stringValue],
         system.background == nil ? @"nil" : [@(system.background.cornerRadius) stringValue]);
    BOTH(@"a fresh configuration's corner style", [@(ours.cornerStyle) stringValue], [@(system.cornerStyle) stringValue]);
    BOTH(@"a fresh configuration's button size", [@(ours.buttonSize) stringValue], [@(system.buttonSize) stringValue]);
    BOTH(@"a fresh configuration has no base foreground colour",
         ours.baseForegroundColor == nil ? @"nil" : @"set", system.baseForegroundColor == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration has no base background colour",
         ours.baseBackgroundColor == nil ? @"nil" : @"set", system.baseBackgroundColor == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration has no image", ours.image == nil ? @"nil" : @"set", system.image == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration has no image colour transformer",
         ours.imageColorTransformer == nil ? @"nil" : @"set", system.imageColorTransformer == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration has no preferred symbol configuration",
         ours.preferredSymbolConfigurationForImage == nil ? @"nil" : @"set",
         system.preferredSymbolConfigurationForImage == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration has no title", ours.title == nil ? @"nil" : @"set", system.title == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration has no attributed title",
         ours.attributedTitle == nil ? @"nil" : @"set", system.attributedTitle == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration has no title text transformer",
         ours.titleTextAttributesTransformer == nil ? @"nil" : @"set",
         system.titleTextAttributesTransformer == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration's title line break mode",
         [@(ours.titleLineBreakMode) stringValue], [@(system.titleLineBreakMode) stringValue]);
    BOTH(@"a fresh configuration has no subtitle", ours.subtitle == nil ? @"nil" : @"set", system.subtitle == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration has no attributed subtitle",
         ours.attributedSubtitle == nil ? @"nil" : @"set", system.attributedSubtitle == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration has no subtitle text transformer",
         ours.subtitleTextAttributesTransformer == nil ? @"nil" : @"set",
         system.subtitleTextAttributesTransformer == nil ? @"nil" : @"set");
    BOTH(@"a fresh configuration's subtitle line break mode",
         [@(ours.subtitleLineBreakMode) stringValue], [@(system.subtitleLineBreakMode) stringValue]);
    BOTH(@"a fresh configuration's top content inset", [@(ours.contentInsets.top) stringValue], [@(system.contentInsets.top) stringValue]);
    BOTH(@"a fresh configuration's image placement", [@(ours.imagePlacement) stringValue], [@(system.imagePlacement) stringValue]);
    BOTH(@"a fresh configuration's image padding", [@(ours.imagePadding) stringValue], [@(system.imagePadding) stringValue]);
    BOTH(@"a fresh configuration's title padding", [@(ours.titlePadding) stringValue], [@(system.titlePadding) stringValue]);
    BOTH(@"a fresh configuration's title alignment", [@(ours.titleAlignment) stringValue], [@(system.titleAlignment) stringValue]);
    BOTH(@"a fresh configuration's selection flag",
         [@(ours.automaticallyUpdateForSelection) stringValue], [@(system.automaticallyUpdateForSelection) stringValue]);
}

static void check_writes(void)
{
    CharonHostUIButtonConfiguration *ours = [NSClassFromString(@"CharonHostUIButtonConfiguration") plainButtonConfiguration];
    UIButtonConfiguration *system = [UIButtonConfiguration plainButtonConfiguration];
    UIColor *colour = [UIColor redColor];
    NSString *title = @"a title";
    NSString *subtitle = @"a subtitle";

    for (id configuration in @[ours, system]) {
        [configuration setValue:title forKey:@"title"];
        [configuration setValue:subtitle forKey:@"subtitle"];
        [configuration setValue:colour forKey:@"baseForegroundColor"];
        [configuration setValue:@(2) forKey:@"titlePadding"];
        [configuration setValue:@(1) forKey:@"imagePadding"];
        [configuration setValue:@(3) forKey:@"cornerStyle"];
        [configuration setValue:@(1) forKey:@"titleAlignment"];
        [configuration setValue:@(2) forKey:@"titleLineBreakMode"];
        [configuration setValue:@(YES) forKey:@"automaticallyUpdateForSelection"];
    }

    BOTH(@"a configuration reads back the title it was given", ours.title, system.title);
    BOTH(@"a configuration reads back the subtitle it was given", ours.subtitle, system.subtitle);
    BOTH(@"a configuration reads back the colour it was given",
         ours.baseForegroundColor == colour ? @"set" : @"other", system.baseForegroundColor == colour ? @"set" : @"other");
    BOTH(@"a configuration reads back the title padding it was given",
         [@(ours.titlePadding) stringValue], [@(system.titlePadding) stringValue]);
    BOTH(@"a configuration reads back the image padding it was given",
         [@(ours.imagePadding) stringValue], [@(system.imagePadding) stringValue]);
    BOTH(@"a configuration reads back the corner style it was given",
         [@(ours.cornerStyle) stringValue], [@(system.cornerStyle) stringValue]);
    BOTH(@"a configuration reads back the title alignment it was given",
         [@(ours.titleAlignment) stringValue], [@(system.titleAlignment) stringValue]);
    BOTH(@"a configuration reads back the line break mode it was given",
         [@(ours.titleLineBreakMode) stringValue], [@(system.titleLineBreakMode) stringValue]);
    BOTH(@"a configuration reads back the selection flag it was given",
         [@(ours.automaticallyUpdateForSelection) stringValue], [@(system.automaticallyUpdateForSelection) stringValue]);

    CharonHostUIButtonConfiguration *ourCopy = [ours copy];
    UIButtonConfiguration *systemCopy = [system copy];
    BOTH(@"a configuration's copy holds the title", ourCopy.title, systemCopy.title);
    BOTH(@"a configuration's copy holds the title padding",
         [@(ourCopy.titlePadding) stringValue], [@(systemCopy.titlePadding) stringValue]);
    BOTH(@"a configuration's copy is a different object", ourCopy == ours ? @"same" : @"other",
         systemCopy == system ? @"same" : @"other");
}

static void check_methods(void)
{
    CharonHostUIButtonConfiguration *ours = [NSClassFromString(@"CharonHostUIButtonConfiguration") plainButtonConfiguration];
    UIButtonConfiguration *system = [UIButtonConfiguration plainButtonConfiguration];
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    id ourUpdated = [ours updatedConfigurationForButton:button];
    charon_check([ourUpdated isKindOfClass:[NSClassFromString(@"CharonHostUIButtonConfiguration") class]],
                 "the port's -updatedConfigurationForButton: answers a configuration",
                 [NSString stringWithFormat:@"%@", ourUpdated]);

    NSString *ourInsets = [NSString stringWithFormat:@"%g %g %g %g", ours.contentInsets.top,
                           ours.contentInsets.leading, ours.contentInsets.bottom, ours.contentInsets.trailing];
    NSString *systemInsets = [NSString stringWithFormat:@"%g %g %g %g", system.contentInsets.top,
                              system.contentInsets.leading, system.contentInsets.bottom, system.contentInsets.trailing];
    BOTH(@"setDefaultContentInsets answers the same insets on both sides", ourInsets, systemInsets);
}

static void check_archive(void)
{
    CharonHostUIButtonConfiguration *ours = [NSClassFromString(@"CharonHostUIButtonConfiguration") plainButtonConfiguration];
    UIButtonConfiguration *system = [UIButtonConfiguration plainButtonConfiguration];
    ours.title = @"archived"; system.title = @"archived";
    ours.cornerStyle = 2; system.cornerStyle = 2;
    ours.titlePadding = 7; system.titlePadding = 7;

    NSMutableData *ourData = [NSMutableData data];
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Wdeprecated-declarations"
    NSKeyedArchiver *ourArchiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:ourData];
    [ourArchiver setRequiresSecureCoding:YES];
    [ourArchiver encodeObject:ours forKey:NSKeyedArchiveRootObjectKey];
    [ourArchiver finishEncoding];
    NSKeyedUnarchiver *ourReader = [[NSKeyedUnarchiver alloc] initForReadingFromData:ourData error:nil];
    [ourReader setRequiresSecureCoding:YES];
    CharonHostUIButtonConfiguration *ourBack = [ourReader decodeObjectOfClass:[NSClassFromString(@"CharonHostUIButtonConfiguration") class]
                                                        forKey:NSKeyedArchiveRootObjectKey];

    NSMutableData *systemData = [NSMutableData data];
    NSKeyedArchiver *systemArchiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:systemData];
    [systemArchiver setRequiresSecureCoding:YES];
    [systemArchiver encodeObject:system forKey:NSKeyedArchiveRootObjectKey];
    [systemArchiver finishEncoding];
    NSKeyedUnarchiver *systemReader = [[NSKeyedUnarchiver alloc] initForReadingFromData:systemData error:nil];
    [systemReader setRequiresSecureCoding:YES];
    UIButtonConfiguration *systemBack = [systemReader decodeObjectOfClass:[UIButtonConfiguration class]
                                                             forKey:NSKeyedArchiveRootObjectKey];

    charon_check(ourBack != nil && systemBack != nil, "both sides read a configuration back from an archive",
                 @"one of the two answered nothing");
    #pragma clang diagnostic pop
    if (ourBack && systemBack) {
        BOTH(@"an archived configuration keeps its title", ourBack.title, systemBack.title);
        BOTH(@"an archived configuration keeps its corner style",
             [@(ourBack.cornerStyle) stringValue], [@(systemBack.cornerStyle) stringValue]);
        BOTH(@"an archived configuration keeps its title padding",
             [@(ourBack.titlePadding) stringValue], [@(systemBack.titlePadding) stringValue]);
    }
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        charonKeys = [NSMutableArray array];
        const char *asked = getenv("CHARON_MUTATION");
        for (int i = 1; i < argc; i++)
            if (strcmp(argv[i], "--mutation") == 0 && i + 1 < argc)
                asked = argv[++i];
            else if (strncmp(argv[i], "--mutation=", 11) == 0)
                asked = argv[i] + 11;
        if (asked && *asked) {
            if (*asked == '-')
                mutation_refuse([NSString stringWithFormat:
                    @"--mutation was given the flag %@ and no key, and a control that plants nothing must"
                    @" fail rather than report a clean run", @(asked)]);
            charonMutation = @(asked);
        }
        check_constructors();
        check_constructor_differences();
        check_defaults();
        check_writes();
        check_methods();
        check_archive();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        if (charonMutation && !charonPlanted) {
            fprintf(stderr, "MUTATION refused: %s was asked for and no case carries it\n",
                    charonMutation.UTF8String);
            return 2;
        }
    }
    return charon_failures;
}

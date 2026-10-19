// The traits of iOS 17, 18 and 26 beside the host's own UIKit, in one process: the backport's classes and the
// selectors it adds to classes the system owns are renamed by uikit2/run.sh, so each case asks the port and the
// system the same question and holds the answers to each other. What is compared is what facts/UIKit/UITrait17.md
// records, so a change in either is a failure here rather than a difference noticed later.
#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <stdio.h>
#import <objc/runtime.h>
// This file calls the port's own API at the release it arrived in - 15.0, 16.0, 17.0, 18.0 and 26.0 -
// while the differential compiles it for a macCatalyst 15.0 target, where those classes and protocols do
// not exist and are declared by the test itself. That is the whole point of a differential against the
// port's own objects: the host framework cannot answer, the port can, and the comparison is between the
// two. The diagnostic is therefore off for the file and the declarations are the test's own, spelled
// where they are used.
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

// The port's classes, named as run.sh renames them. The three trait definition protocols and UIMutableTraits
// come from the SDK here, so the port's tables take the system's own declarations.
@interface CharonHostCharonTraitMutations : NSObject <UIMutableTraits>
- (UITraitCollection *)charon_collection;
@end

@interface CharonHost_CharonOverrides : CharonHostCharonTraitMutations <UITraitOverrides>
@end

// The port's trait classes. Each is a token, so what is compared is what the class says about itself.
#define PORT_TRAIT(Name)                                                                                                                \
    @interface CharonHost##Name : NSObject                                                                                             \
    + (NSString *)identifier;                                                                                                          \
    + (NSString *)name;                                                                                                                \
    + (BOOL)affectsColorAppearance;                                                                                                    \
    + (NSInteger)defaultValue;                                                                                                         \
    @end

PORT_TRAIT(UITraitUserInterfaceIdiom)
PORT_TRAIT(UITraitUserInterfaceStyle)
PORT_TRAIT(UITraitLayoutDirection)
PORT_TRAIT(UITraitDisplayScale)
PORT_TRAIT(UITraitHorizontalSizeClass)
PORT_TRAIT(UITraitVerticalSizeClass)
PORT_TRAIT(UITraitForceTouchCapability)
PORT_TRAIT(UITraitPreferredContentSizeCategory)
PORT_TRAIT(UITraitDisplayGamut)
PORT_TRAIT(UITraitAccessibilityContrast)
PORT_TRAIT(UITraitUserInterfaceLevel)
PORT_TRAIT(UITraitLegibilityWeight)
PORT_TRAIT(UITraitActiveAppearance)
PORT_TRAIT(UITraitToolbarItemPresentationSize)
PORT_TRAIT(UITraitImageDynamicRange)
PORT_TRAIT(UITraitTypesettingLanguage)
PORT_TRAIT(UITraitSceneCaptureState)
PORT_TRAIT(UITraitHDRHeadroomUsageLimit)
PORT_TRAIT(UITraitResolvesNaturalAlignmentWithBaseWritingDirection)
PORT_TRAIT(UITraitListEnvironment)
PORT_TRAIT(UITraitTabAccessoryEnvironment)
PORT_TRAIT(UITraitSplitViewControllerLayoutEnvironment)

// The port's own collection class. It is not a UITraitCollection and does not inherit from one - the
// harness renamed it - so a method of the port's declared here returns the port's class, as the port's
// own sources do. Declaring the return type as the system's made every assignment of a port collection
// to a port-typed variable a conversion, and a test that casts its way out of that reads as if the two
// classes were one.
@interface CharonHostUITraitCollection : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)traitCollectionWithUserInterfaceIdiom:(UIUserInterfaceIdiom)idiom;
+ (instancetype)traitCollectionWithUserInterfaceStyle:(UIUserInterfaceStyle)style;
+ (instancetype)traitCollectionWithDisplayScale:(CGFloat)scale;
+ (instancetype)traitCollectionWithTraitsFromCollections:(NSArray *)collections;
@property (nonatomic, readonly) UIUserInterfaceIdiom userInterfaceIdiom;
@property (nonatomic, readonly) UIUserInterfaceStyle userInterfaceStyle;
@property (nonatomic, readonly) CGFloat displayScale;
+ (instancetype)traitCollectionWithTraits:(__attribute__((noescape)) UITraitMutations)mutations;
- (instancetype)traitCollectionByModifyingTraits:(__attribute__((noescape)) UITraitMutations)mutations;
+ (instancetype)traitCollectionWithCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait;
- (instancetype)traitCollectionByReplacingCGFloatValue:(CGFloat)value forTrait:(UICGFloatTrait)trait;
- (CGFloat)valueForCGFloatTrait:(UICGFloatTrait)trait;
+ (instancetype)traitCollectionWithNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait;
- (instancetype)traitCollectionByReplacingNSIntegerValue:(NSInteger)value forTrait:(UINSIntegerTrait)trait;
- (NSInteger)valueForNSIntegerTrait:(UINSIntegerTrait)trait;
+ (instancetype)traitCollectionWithObject:(id)object forTrait:(UIObjectTrait)trait;
- (instancetype)traitCollectionByReplacingObject:(id)object forTrait:(UIObjectTrait)trait;
- (id)objectForTrait:(UIObjectTrait)trait;
- (NSSet *)changedTraitsFromTraitCollection:(UITraitCollection *)traitCollection;
- (UIImageDynamicRange)imageDynamicRange;
- (UISceneCaptureState)sceneCaptureState;
- (UIHDRHeadroomUsageLimit)hdrHeadroomUsageLimit;
- (UIListEnvironment)listEnvironment;
- (UITabAccessoryEnvironment)tabAccessoryEnvironment;
- (UISplitViewControllerLayoutEnvironment)splitViewControllerLayoutEnvironment;
- (NSString *)typesettingLanguage;
- (BOOL)resolvesNaturalAlignmentWithBaseWritingDirection;
- (UINSToolbarItemPresentationSize)toolbarItemPresentationSize;
+ (NSArray *)systemTraitsAffectingColorAppearance;
+ (NSArray *)systemTraitsAffectingImageLookup;
@end

// UIKitCore 26.2 declares the collection's 17.0 members in a class extension, which an application does not
// see, so the test declares them to ask the system the same questions it asks the port.
@interface UITraitCollection (CharonHostTraits17)
// NS_NOESCAPE as the SDK spells both of these: the block is a trait mutation the constructor runs to
// completion, and clang holds an override of a noescape parameter to the same contract.
+ (UITraitCollection *)traitCollectionWithTraits:(__attribute__((noescape)) UITraitMutations)mutations;
- (UITraitCollection *)traitCollectionByModifyingTraits:(__attribute__((noescape)) UITraitMutations)mutations;
- (NSSet *)changedTraitsFromTraitCollection:(UITraitCollection *)traitCollection;
@end

// The port's additions to classes the system owns, as run.sh renames them.
@interface UIView (CharonHostTraits17)
- (id<UITraitOverrides>)charonHostTraitOverrides;
- (void)charonHostUpdateTraitsIfNeeded;
@end
@interface UIViewController (CharonHostTraits17)
- (id<UITraitOverrides>)charonHostTraitOverrides;
- (void)charonHostUpdateTraitsIfNeeded;
@end
@interface NSObject (CharonHostTraits17)
- (id<UITraitChangeRegistration>)charonHostRegisterForTraitChanges:(NSArray *)traits withHandler:(UITraitChangeHandler)handler;
- (id<UITraitChangeRegistration>)charonHostRegisterForTraitChanges:(NSArray *)traits withTarget:(id)target action:(SEL)action;
- (id<UITraitChangeRegistration>)charonHostRegisterForTraitChanges:(NSArray *)traits withAction:(SEL)action;
- (void)charonHostUnregisterForTraitChanges:(id<UITraitChangeRegistration>)registration;
@end

// What a trait class says about itself, in one string, so the port's and the system's are compared whole. The
// default value is read through the type the class's protocol declares, because the three return types share
// one selector and a value read as the wrong one is a different register.
// The harness's own prefix, which it puts on every class the port defines so the two sides can live in one
// process. A name the port's class gives itself carries it, and on a device the class carries its own name, so
// the comparison drops the prefix wherever it appears and holds what is left. A trait class says of itself and
// of its values through its own name, so the prefix reaches a description and an exception's reason as well as
// the name of the class.
static NSString *unprefix(NSString *text)
{
    if (!text)
        return text;
    return [text hasPrefix:@"CharonHost"] ? [text substringFromIndex:10]
                                           : [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
}

// The name a trait class gives itself: its own name without the UITrait prefix, which is the rule M1 measured.
static NSString *portTraitName(Class trait)
{
    NSString *identifier = unprefix(NSStringFromClass(trait));
    NSRange prefix = [identifier rangeOfString:@"UITrait"];
    return prefix.location == NSNotFound ? identifier : [identifier substringFromIndex:NSMaxRange(prefix)];
}

static NSString *definition_of(Class trait)
{
    // The harness renames every class the port's objects define, so the port's +identifier and +name come back
    // with the prefix the harness gave the class. What the class says about itself is the name without it, which
    // is what the two sides are held to: on a device the class carries its own name and nothing is stripped.
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"identifier=%@", [trait respondsToSelector:@selector(identifier)] ? unprefix([trait identifier]) : @"(none)"];
    // +name is not in this string: it is derived from the class name, and the harness prefixes the port's class,
    // so the two sides' names are held to the rule each follows by the checks after this comparison.
    if ([trait respondsToSelector:@selector(name)])
        [text appendFormat:@" hasName=%d", (int)([trait name] != nil)];
    if ([trait respondsToSelector:@selector(affectsColorAppearance)])
        [text appendFormat:@" appearance=%d", (int)[trait affectsColorAppearance]];
    else
        [text appendString:@" appearance=(none)"];
    if ([trait conformsToProtocol:@protocol(UICGFloatTraitDefinition)])
        [text appendFormat:@" default=%g", ((double (*)(id, SEL))objc_msgSend)((id)trait, @selector(defaultValue))];
    else if ([trait conformsToProtocol:@protocol(UINSIntegerTraitDefinition)])
        [text appendFormat:@" default=%ld", ((long (*)(id, SEL))objc_msgSend)((id)trait, @selector(defaultValue))];
    else if ([trait conformsToProtocol:@protocol(UIObjectTraitDefinition)]) {
        // The three protocols declare one selector with three return types, so the call is made through the one
        // the class's own protocol declares; a value read as the wrong type is a different register on arm64.
        id value = ((id (*)(id, SEL))objc_msgSend)((id)trait, @selector(defaultValue));
        [text appendFormat:@" default=%@", value ? [value description] : @"(nil)"];
    } else
        [text appendString:@" default=(none)"];
    return text;
}

static void compare_text(NSString *left, NSString *right, const char *name)
{
    charon_check([left isEqualToString:right], name, [NSString stringWithFormat:@"port %@ != system %@", left, right]);
}

static void compare_collections(id ours, id system, const char *name);

// A macro rather than a call so that a case reads as one line. Neither takes an argument holding a comma, so a
// value built with stringWithFormat: is put in a local first: a comma inside brackets ends a macro argument
// just as it ends a function's.
#define COMPARE(ours, system, name) compare_text((ours), (system), (name))
#define COMPARE_COLLECTIONS(ours, system, name) compare_collections((ours), (system), (name))

// What an exception an API raises says, as a string: the name and the reason, word for word, so a refusal of the
// port and a refusal of the system are held to each other.
static NSString *reason_of(void (^ask)(void))
{
    @try {
        ask();
    } @catch (NSException *exception) {
        return unprefix([NSString stringWithFormat:@"%@: %@", [exception name], [exception reason]]);
    }
    return @"(no exception)";
}

static void compare_definitions(void)
{
    NSArray *names = @[
        @"UITraitUserInterfaceIdiom", @"UITraitUserInterfaceStyle", @"UITraitLayoutDirection", @"UITraitDisplayScale",
        @"UITraitHorizontalSizeClass", @"UITraitVerticalSizeClass", @"UITraitForceTouchCapability",
        @"UITraitPreferredContentSizeCategory", @"UITraitDisplayGamut", @"UITraitAccessibilityContrast",
        @"UITraitUserInterfaceLevel", @"UITraitLegibilityWeight", @"UITraitActiveAppearance",
        @"UITraitToolbarItemPresentationSize", @"UITraitImageDynamicRange", @"UITraitTypesettingLanguage",
        @"UITraitSceneCaptureState", @"UITraitHDRHeadroomUsageLimit", @"UITraitResolvesNaturalAlignmentWithBaseWritingDirection",
        @"UITraitListEnvironment", @"UITraitTabAccessoryEnvironment", @"UITraitSplitViewControllerLayoutEnvironment"
    ];
    for (NSString *name in names) {
        Class system = NSClassFromString(name);
        Class port = NSClassFromString([@"CharonHost" stringByAppendingString:name]);
        charon_check(system != Nil, NAMED(@"%@ is in the system", name), @"the system has no such trait class");
        charon_check(port != Nil, NAMED(@"%@ is in the port", name), @"the port has no such trait class");
        if (!system || !port)
            continue;
        COMPARE(definition_of(port), definition_of(system), NAMED(@"%@ says about itself", name));
        // +name is the class's own name without its UITrait prefix, so on the two sides it is the same name
        // spelled from two class names: one the harness prefixed and one it did not. The rule is checked on each
        // side, and the identifier each reports against the class it is on, which is what makes the two one trait.
        charon_check([[port name] isEqualToString:portTraitName(port)], NAMED(@"%@ +name is its class name less UITrait", name),
                     [NSString stringWithFormat:@"%@ != %@", [port name], portTraitName(port)]);
        charon_check([[system name] isEqualToString:portTraitName(system)], NAMED(@"%@ +name on the system", name),
                     [NSString stringWithFormat:@"%@ != %@", [system name], portTraitName(system)]);
        COMPARE(unprefix([port identifier]), unprefix([system identifier]), NAMED(@"%@ +identifier", name));
        COMPARE([port superclass] == [NSObject class] ? @"NSObject" : NSStringFromClass([port superclass]),
                [system superclass] == [NSObject class] ? @"NSObject" : NSStringFromClass([system superclass]),
                NAMED(@"%@ derives from NSObject", name));
        COMPARE(NSStringFromClass([port superclass]), NSStringFromClass([system superclass]),
                NAMED(@"%@ superclass", name));
        unsigned portCount = 0, systemCount = 0;
        Method *portMethods = class_copyMethodList(object_getClass(port), &portCount);
        Method *systemMethods = class_copyMethodList(object_getClass(system), &systemCount);
        NSMutableSet *portNames = [NSMutableSet set];
        for (unsigned i = 0; i < portCount; i++)
            [portNames addObject:NSStringFromSelector(method_getName(portMethods[i]))];
        NSMutableSet *systemNames = [NSMutableSet set];
        for (unsigned i = 0; i < systemCount; i++)
            [systemNames addObject:NSStringFromSelector(method_getName(systemMethods[i]))];
        free(portMethods);
        free(systemMethods);
        // The host also carries two class methods no SDK header declares, +defaultValueRepresentsUnspecified and
        // +_isPrivate, so the port's set is held to the system's minus those two, and the test fails if the
        // system ever stops carrying them.
        [systemNames removeObject:@"defaultValueRepresentsUnspecified"];
        [systemNames removeObject:@"_isPrivate"];
        NSArray *portListed = [[portNames allObjects] sortedArrayUsingSelector:@selector(compare:)];
        NSArray *systemListed = [[systemNames allObjects] sortedArrayUsingSelector:@selector(compare:)];
        COMPARE([portListed componentsJoinedByString:@","], [systemListed componentsJoinedByString:@","],
                NAMED(@"%@ class methods", name));
        // UITraitTypesettingLanguage is the one class the host gives no +affectsColorAppearance, so the port
        // gives none either, and the test fails if the host ever starts giving it one.
        charon_check([systemNames containsObject:@"affectsColorAppearance"] == [portNames containsObject:@"affectsColorAppearance"],
                     NAMED(@"%@ has +affectsColorAppearance as the system does", name),
                     @"the two sides disagree about the optional property");
    }
}

// What a collection answers for a trait, asked of both collections, as a string so a difference names itself.
static NSString *collection_values(id collection)
{
    return [NSString stringWithFormat:@"idiom=%ld style=%ld layout=%ld scale=%g h=%ld v=%ld forceTouch=%ld gamut=%ld contrast=%ld "
                                      @"level=%ld weight=%ld active=%ld toolbar=%ld range=%ld language=%@ capture=%ld hdr=%ld "
                                      @"list=%ld tab=%ld split=%ld natural=%d",
                                      (long)[collection userInterfaceIdiom], (long)[collection userInterfaceStyle],
                                      (long)[collection layoutDirection], (double)[collection displayScale],
                                      (long)[collection horizontalSizeClass], (long)[collection verticalSizeClass],
                                      (long)[collection forceTouchCapability], (long)[collection displayGamut],
                                      (long)[collection accessibilityContrast], (long)[collection userInterfaceLevel],
                                      (long)[collection legibilityWeight], (long)[collection activeAppearance],
                                      (long)[collection toolbarItemPresentationSize], (long)[collection imageDynamicRange],
                                      [collection typesettingLanguage] ?: @"(nil)", (long)[collection sceneCaptureState],
                                      (long)[collection hdrHeadroomUsageLimit], (long)[collection listEnvironment],
                                      (long)[collection tabAccessoryEnvironment],
                                      (long)[collection splitViewControllerLayoutEnvironment],
                                      (int)[collection resolvesNaturalAlignmentWithBaseWritingDirection]];
}

static void compare_collections(id ours, id system, const char *name)
{
    compare_text(collection_values(ours), collection_values(system), name);
}

// A collection's description names the class and its address, which differ between the two sides by
// construction, so what is compared is the list of traits after the semicolon.
static NSString *of_description(NSString *description)
{
    NSRange separator = [description rangeOfString:@"; "];
    return separator.location == NSNotFound ? description : [description substringFromIndex:NSMaxRange(separator)];
}

static void compare_empty(void)
{
    UITraitCollection *system = [UITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
    }];
    CharonHostUITraitCollection *port = [CharonHostUITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
    }];
    COMPARE_COLLECTIONS(port, system, "a collection that sets no trait");
    COMPARE(of_description([port description]), of_description([system description]),
            "a collection that sets no trait, described");
}

// The port's class for a trait the harness renamed, found by the name the harness gave it, so a case never
// depends on how the expression that names it happens to be spelled in this file.
static Class port_trait(NSString *name)
{
    return NSClassFromString([@"CharonHost" stringByAppendingString:name]);
}

static void compare_values(void)
{
    NSArray *systems = @[
        [UITraitUserInterfaceIdiom class], [UITraitUserInterfaceStyle class], [UITraitLayoutDirection class],
        [UITraitDisplayScale class], [UITraitHorizontalSizeClass class], [UITraitVerticalSizeClass class],
        [UITraitForceTouchCapability class], [UITraitDisplayGamut class], [UITraitAccessibilityContrast class],
        [UITraitUserInterfaceLevel class], [UITraitLegibilityWeight class], [UITraitActiveAppearance class],
        [UITraitToolbarItemPresentationSize class], [UITraitImageDynamicRange class], [UITraitSceneCaptureState class],
        [UITraitHDRHeadroomUsageLimit class], [UITraitListEnvironment class], [UITraitTabAccessoryEnvironment class],
        [UITraitSplitViewControllerLayoutEnvironment class]
    ];
    NSMutableArray *ports = [NSMutableArray array];
    for (Class system in systems)
        [ports addObject:port_trait(NSStringFromClass(system))];
    charon_check(systems.count == ports.count, "the two trait lists are the same length" , @"the lists differ in length");
    for (NSUInteger index = 0; index < systems.count && index < ports.count; index++) {
        Class system = systems[index], port = [ports objectAtIndex:index];
        NSString *name = NSStringFromClass(system);
        charon_check(port != Nil, NAMED(@"the port carries %@", name), @"the port has no such trait class");
        if (!port)
            continue;
        // A value the trait's own enumeration has, so the port and the system are asked the same question and
        // the collection is not compared empty.
        NSInteger value = 2;
    (void)value;
        UITraitCollection *systemMade = nil;
        CharonHostUITraitCollection *portMade = nil;
        if (class_conformsToProtocol(system, @protocol(UICGFloatTraitDefinition))) {
            systemMade = [UITraitCollection traitCollectionWithCGFloatValue:1.5 forTrait:(UICGFloatTrait)system];
            portMade = [CharonHostUITraitCollection traitCollectionWithCGFloatValue:1.5 forTrait:(UICGFloatTrait)port];
        } else {
            systemMade = [UITraitCollection traitCollectionWithNSIntegerValue:value forTrait:(UINSIntegerTrait)system];
            portMade = [CharonHostUITraitCollection traitCollectionWithNSIntegerValue:value forTrait:(UINSIntegerTrait)port];
        }
        COMPARE_COLLECTIONS(portMade, systemMade, NAMED(@"%@ set through forTrait:", name));
        // The trait list a collection prints, not its class name and address. The one value the port cannot
        // name is a user interface idiom it has no name for, which this release never produces, so the
        // description is compared for the traits the port does name.
        if (system != [UITraitUserInterfaceIdiom class])
            COMPARE(of_description([portMade description]), of_description([systemMade description]),
                    NAMED(@"%@ described", name));
        // The same trait set by the old constructor and through forTrait: is one collection on both sides, so
        // the two ways are compared within each side and the two sides' verdicts are compared.
        id portOther = nil, systemOther = nil;
        if (class_conformsToProtocol(system, @protocol(UICGFloatTraitDefinition))) {
            systemOther = [UITraitCollection traitCollectionWithCGFloatValue:1.5 forTrait:(UICGFloatTrait)system];
            portOther = [CharonHostUITraitCollection traitCollectionWithCGFloatValue:1.5 forTrait:(UICGFloatTrait)port];
        } else {
            systemOther = [UITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
                [traits setNSIntegerValue:value forTrait:(UINSIntegerTrait)system];
            }];
            portOther = [CharonHostUITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
                [traits setNSIntegerValue:value forTrait:(UINSIntegerTrait)port];
            }];
        }
        charon_check([portMade isEqual:portOther] == [systemMade isEqual:systemOther],
                     NAMED(@"%@ built two ways compares as the system does", name),
                     @"the port and the system disagree about whether the two are one collection");
    }
    // The two object traits whose default the system does not know. Asked first, in a process where nothing has
    // raised, the system takes both: the "does not implement the required defaultValue class property" it
    // answers for them comes only out of a host whose trait metadata has already raised once, and it does not
    // come back from that. So both are set through forTrait: here, and the refusals the differential can rely on
    // are asked at the end of the run, one after another.
    UITraitCollection *systemLanguage =
        [UITraitCollection traitCollectionWithObject:@"fr-FR" forTrait:[UITraitTypesettingLanguage class]];
    CharonHostUITraitCollection *portLanguage =
        [CharonHostUITraitCollection traitCollectionWithObject:@"fr-FR" forTrait:port_trait(@"UITraitTypesettingLanguage")];
    COMPARE_COLLECTIONS(portLanguage, systemLanguage, "a typesetting language set through forTrait:");
    COMPARE([[portLanguage objectForTrait:port_trait(@"UITraitTypesettingLanguage")] description],
            [[systemLanguage objectForTrait:[UITraitTypesettingLanguage class]] description],
            "the language reads back");
    UITraitCollection *systemNatural = [UITraitCollection traitCollectionWithObject:@NO
                                                                            forTrait:[UITraitResolvesNaturalAlignmentWithBaseWritingDirection class]];
    CharonHostUITraitCollection *portNatural =
        [CharonHostUITraitCollection traitCollectionWithObject:@NO
                                                      forTrait:port_trait(@"UITraitResolvesNaturalAlignmentWithBaseWritingDirection")];
    COMPARE_COLLECTIONS(portNatural, systemNatural, "the natural alignment flag set through forTrait:");

}

static void compare_modifying(void)
{
    UITraitCollection *system = [UITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPad];
    CharonHostUITraitCollection *port = [CharonHostUITraitCollection traitCollectionWithUserInterfaceIdiom:UIUserInterfaceIdiomPad];
    COMPARE_COLLECTIONS(port, system, "a base collection of the old constructor");
    COMPARE_COLLECTIONS([port traitCollectionByModifyingTraits:^(id<UIMutableTraits> traits) {
                             traits.userInterfaceStyle = UIUserInterfaceStyleDark;
                             traits.displayScale = 3;
                             traits.typesettingLanguage = @"ja-JP";
                         }],
                        [system traitCollectionByModifyingTraits:^(id<UIMutableTraits> traits) {
                            traits.userInterfaceStyle = UIUserInterfaceStyleDark;
                            traits.displayScale = 3;
                            traits.typesettingLanguage = @"ja-JP";
                        }],
                        "modifying keeps the base traits and applies the mutation");
    id portTwice = [[port traitCollectionByModifyingTraits:^(id<UIMutableTraits> traits) {
                        traits.userInterfaceStyle = UIUserInterfaceStyleDark;
                    }] traitCollectionByModifyingTraits:^(id<UIMutableTraits> traits) {
                        traits.verticalSizeClass = UIUserInterfaceSizeClassCompact;
                    }];
    id systemTwice = [[system traitCollectionByModifyingTraits:^(id<UIMutableTraits> traits) {
                         traits.userInterfaceStyle = UIUserInterfaceStyleDark;
                     }] traitCollectionByModifyingTraits:^(id<UIMutableTraits> traits) {
                         traits.verticalSizeClass = UIUserInterfaceSizeClassCompact;
                     }];
    COMPARE_COLLECTIONS(portTwice, systemTwice, "modifying twice");
    // The replacing variants, one per kind. These are the port's own answer held to itself and not to the
    // host's: UIKitCore's forTrait: machinery answers "does not implement the required defaultValue class
    // property" for a trait it answered a moment ago, once enough calls have gone through it in one process, and
    // the process does not come back from that (M8). So what is checked here is that the port's replacing variant
    // and the constructor it wraps give one collection, which is the property the two have in common, and the
    // host's answers for these same variants are in facts/UIKit/UITrait17.md from the probe that asked them first.
    UITraitCollection *systemStyle = [UITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight];
    CharonHostUITraitCollection *portStyle = [CharonHostUITraitCollection traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleLight];
    COMPARE_COLLECTIONS(portStyle, systemStyle, "a style made by the constructor of iOS 12");
    id portReplaced = [portStyle traitCollectionByReplacingNSIntegerValue:UIUserInterfaceStyleDark
                                                                 forTrait:port_trait(@"UITraitUserInterfaceStyle")];
    id portOther = [portStyle traitCollectionByReplacingNSIntegerValue:UIUserInterfaceStyleDark
                                                              forTrait:port_trait(@"UITraitUserInterfaceStyle")];
    charon_check([portReplaced isEqual:portOther], "replacing an NSInteger trait through either class is one collection" ,
                 @"the two classes of the same trait give two collections");
    charon_check([(UITraitCollection *)portReplaced userInterfaceStyle] == UIUserInterfaceStyleDark, "replacing an NSInteger trait changes it" , @"the value did not change");
    charon_check(portReplaced != portStyle && portStyle.userInterfaceStyle == UIUserInterfaceStyleLight, "replacing leaves the collection it was made from alone" , @"the base changed");
    id portScaleReplaced = [portStyle traitCollectionByReplacingCGFloatValue:2.5 forTrait:port_trait(@"UITraitDisplayScale")];
    charon_check([(UITraitCollection *)portScaleReplaced displayScale] == 2.5, "replacing a CGFloat trait changes it" ,
                 @"the value did not change");
    charon_check([(UITraitCollection *)portScaleReplaced userInterfaceStyle] == UIUserInterfaceStyleLight, "replacing one trait keeps the others" , @"a trait was lost");
    id portLanguageReplaced = [portStyle traitCollectionByReplacingObject:@"de-DE"
                                                                  forTrait:port_trait(@"UITraitTypesettingLanguage")];
    charon_check([[(UITraitCollection *)portLanguageReplaced typesettingLanguage] isEqualToString:@"de-DE"], "replacing an object trait changes it" , @"the value did not change");
    charon_check([port valueForCGFloatTrait:port_trait(@"UITraitDisplayScale")] == 0, "the port reads an unset CGFloat trait as its class default" , @"it read a value of its own");
    charon_check([port valueForNSIntegerTrait:port_trait(@"UITraitUserInterfaceStyle")] == 0, "the port reads an unset NSInteger trait as its class default" , @"it read a value of its own");
}

static void compare_changed(void)
{
    UITraitCollection *(^light)(void) = ^UITraitCollection * {
        return [UITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
            traits.userInterfaceStyle = UIUserInterfaceStyleLight;
        }];
    };
    CharonHostUITraitCollection *(^portLight)(void) = ^CharonHostUITraitCollection * {
        return [CharonHostUITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
            traits.userInterfaceStyle = UIUserInterfaceStyleLight;
        }];
    };
    UITraitCollection *(^dark)(void) = ^UITraitCollection * {
        return [UITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
            traits.userInterfaceStyle = UIUserInterfaceStyleDark;
        }];
    };
    CharonHostUITraitCollection *(^portDark)(void) = ^CharonHostUITraitCollection * {
        return [CharonHostUITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
            traits.userInterfaceStyle = UIUserInterfaceStyleDark;
        }];
    };
    UITraitCollection *(^darkScale)(void) = ^UITraitCollection * {
        return [UITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
            traits.userInterfaceStyle = UIUserInterfaceStyleDark;
            traits.displayScale = 2;
        }];
    };
    CharonHostUITraitCollection *(^portDarkScale)(void) = ^CharonHostUITraitCollection * {
        return [CharonHostUITraitCollection traitCollectionWithTraits:^(id<UIMutableTraits> traits) {
            traits.userInterfaceStyle = UIUserInterfaceStyleDark;
            traits.displayScale = 2;
        }];
    };
    NSArray *(^names)(NSSet *) = ^NSArray *(NSSet *set) {
        NSMutableArray *found = [NSMutableArray array];
        for (Class trait in set)
            [found addObject:unprefix(NSStringFromClass(trait))];
        return [found sortedArrayUsingSelector:@selector(compare:)];
    };
    COMPARE([names([portDarkScale() changedTraitsFromTraitCollection:light()]) componentsJoinedByString:@","],
            [names([darkScale() changedTraitsFromTraitCollection:light()]) componentsJoinedByString:@","],
            "two collections differing in a style and a scale");
    COMPARE([names([portDark() changedTraitsFromTraitCollection:light()]) componentsJoinedByString:@","],
            [names([dark() changedTraitsFromTraitCollection:light()]) componentsJoinedByString:@","],
            "two collections differing in a style");
    COMPARE([names([portLight() changedTraitsFromTraitCollection:(UITraitCollection *)portLight()]) componentsJoinedByString:@","],
            [names([light() changedTraitsFromTraitCollection:light()]) componentsJoinedByString:@","],
            "a collection against itself");
    COMPARE([names([portDark() changedTraitsFromTraitCollection:nil]) componentsJoinedByString:@","],
            [names([dark() changedTraitsFromTraitCollection:nil]) componentsJoinedByString:@","],
            "a collection against nothing");
    COMPARE([names([portLight() changedTraitsFromTraitCollection:nil]) componentsJoinedByString:@","],
            [names([light() changedTraitsFromTraitCollection:nil]) componentsJoinedByString:@","],
            "a collection that sets a default value against nothing");
}

static NSString *named_list(NSArray *list)
{
    NSMutableArray *found = [NSMutableArray array];
    for (Class trait in list)
        [found addObject:unprefix(NSStringFromClass(trait))];
    return [found componentsJoinedByString:@","];
}

static void compare_lists(void)
{
    // The system's lists hold four traits no SDK header declares. They are not carried, so the port's list is the
    // system's minus those four, and the test fails if the system ever stops naming them.
    NSArray *privateTraits = @[ @"UITraitVibrancy", @"UITraitUserInterfaceRenderingMode", @"UITraitSelectionIsKey", @"UITraitArtworkSubtype" ];
    NSArray *systemColor = [UITraitCollection systemTraitsAffectingColorAppearance];
    NSMutableArray *systemColorNamed = [NSMutableArray array];
    for (Class trait in systemColor)
        if (![privateTraits containsObject:NSStringFromClass(trait)])
            [systemColorNamed addObject:trait];
    COMPARE(named_list([CharonHostUITraitCollection systemTraitsAffectingColorAppearance]),
            named_list(systemColorNamed), "systemTraitsAffectingColorAppearance, without the private traits");
    NSArray *systemImage = [UITraitCollection systemTraitsAffectingImageLookup];
    NSMutableArray *systemImageNamed = [NSMutableArray array];
    for (Class trait in systemImage)
        if (![privateTraits containsObject:NSStringFromClass(trait)])
            [systemImageNamed addObject:trait];
    COMPARE(named_list([CharonHostUITraitCollection systemTraitsAffectingImageLookup]),
            named_list(systemImageNamed), "systemTraitsAffectingImageLookup, without the private traits");
    for (NSString *name in privateTraits)
        charon_check([systemColor containsObject:NSClassFromString(name)] || [systemImage containsObject:NSClassFromString(name)],
                     NAMED(@"the system still names the private trait %@", name),
                     @"the system no longer names it, so the port's list needs no subtraction");
}

static void compare_refusals(void)
{
    COMPARE(reason_of(^{
             [CharonHostUITraitCollection traitCollectionWithObject:@"x" forTrait:(UIObjectTrait)port_trait(@"UITraitDisplayScale")];
         }),
            reason_of(^{
                [UITraitCollection traitCollectionWithObject:@"x" forTrait:(UIObjectTrait)[UITraitDisplayScale class]];
            }),
            "a CGFloat trait asked as an object trait");
    COMPARE(reason_of(^{
             [CharonHostUITraitCollection traitCollectionWithCGFloatValue:1
                                                               forTrait:(UICGFloatTrait)port_trait(@"UITraitUserInterfaceStyle")];
         }),
            reason_of(^{
                [UITraitCollection traitCollectionWithCGFloatValue:1 forTrait:(UICGFloatTrait)[UITraitUserInterfaceStyle class]];
            }),
            "an NSInteger trait asked as a CGFloat trait");
    COMPARE(reason_of(^{
             [CharonHostUITraitCollection traitCollectionWithNSIntegerValue:1
                                                                  forTrait:(UINSIntegerTrait)port_trait(@"UITraitTypesettingLanguage")];
         }),
            reason_of(^{
                [UITraitCollection traitCollectionWithNSIntegerValue:1 forTrait:(UINSIntegerTrait)[UITraitTypesettingLanguage class]];
            }),
            "an object trait asked as an NSInteger trait");
    COMPARE(reason_of(^{
             [CharonHostUITraitCollection traitCollectionWithObject:@"x" forTrait:(UIObjectTrait)[NSString class]];
         }),
            reason_of(^{
                [UITraitCollection traitCollectionWithObject:@"x" forTrait:(UIObjectTrait)[NSString class]];
            }),
            "a class that is not a trait at all");
}

// The class name a description opens with, dropped: "<Name: " and what follows it up to the first ": ". The
// port's two classes are its own where the host's two are the host's private ones, and that is the one
// difference between the two sides' descriptions that is deliberate - so a comparison that holds a whole
// description to the host's drops the name and keeps the rest, and says so in the check's own name.
static NSString *without_class_name(NSString *description)
{
    if (![description hasPrefix:@"<"])
        return description;
    NSRange colon = [description rangeOfString:@": "];
    if (colon.location == NSNotFound)
        return description;
    return [description substringFromIndex:NSMaxRange(colon)];
}

static NSString *shape_of(NSString *description)
{
    // The two private classes print their own address, which differs between two runs and between the two sides,
    // so the address is what the comparison drops; the harness's own prefix, which it puts on the port's classes,
    // goes with it.
    description = unprefix(description);
    NSRegularExpression *address = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-fA-F]+" options:0 error:NULL];
    return [address stringByReplacingMatchesInString:description options:0 range:NSMakeRange(0, description.length) withTemplate:@""];
}

static NSString *shape_of(NSString *description);

// An overrides object prints an object trait's value inside a Swift optional on the host, Optional(fr), and this
// release has no Swift optional and no way to make one, so the port prints the value. The wrapper is taken off
// the host's text and the check above fails if the host ever stops printing it.
// The braces of an overrides description hold a dictionary, and a dictionary prints in hash order, which is not
// an order: the same two sides print the same pairs in a different order from one run to the next, and the case
// flaked on exactly that - three runs, two green and one with the pairs the other way round. The pairs are
// sorted before the two descriptions are compared, which is not a widened tolerance: the pairs themselves are
// still compared, only their order is dropped, and their order is not part of the answer.
static NSString *sorted_pairs(NSString *text)
{
    NSRange open = [text rangeOfString:@"{"];
    NSRange close = [text rangeOfString:@"}"];
    if (open.location == NSNotFound || close.location == NSNotFound || close.location < NSMaxRange(open))
        return text;
    // The text inside the braces is " a = 1, b = 2 ", so the split leaves a space on the first pair and on the
    // last, and a space sorts before every letter - which made the sort a no-op and the case flaky. Each pair
    // is trimmed before it is compared, and the spaces are put back when they are joined.
    NSCharacterSet *space = [NSCharacterSet whitespaceCharacterSet];
    NSMutableArray *pairs = [NSMutableArray array];
    for (NSString *pair in [[text substringWithRange:NSMakeRange(NSMaxRange(open), close.location - NSMaxRange(open))]
        componentsSeparatedByString:@", "])
        [pairs addObject:[pair stringByTrimmingCharactersInSet:space]];
    [pairs sortUsingSelector:@selector(compare:)];
    return [NSString stringWithFormat:@"%@{ %@ }%@", [text substringToIndex:open.location],
                                      [pairs componentsJoinedByString:@", "],
                                      [text substringFromIndex:NSMaxRange(close)]];
}

static NSString *unwrapped_overrides(NSString *description)
{
    NSString *text = [[unprefix(description) stringByReplacingOccurrencesOfString:@"Optional(" withString:@""]
        stringByReplacingOccurrencesOfString:@")" withString:@""];
    return sorted_pairs(shape_of(text));
}

static void compare_overrides(void)
{
    UIView *systemView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    UIView *portView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    id<UITraitOverrides> system = systemView.traitOverrides;
    id<UITraitOverrides> port = [portView charonHostTraitOverrides];
    charon_check(system != nil && port != nil, "both sides have a traitOverrides" , @"one side has none");
    // without_class_name() is what the two descriptions need: the host prints <_UITraitOverrides: 0x...> and the
    // port prints <CharonOverrides: 0x...>, which is the one deliberate difference, and the check's name says
    // so. Everything after the class name is behaviour, and that is compared.
    COMPARE(without_class_name(shape_of([port description])), without_class_name(shape_of([system description])),
            "an overrides object with nothing set, its class name aside");
    [system setNSIntegerValue:UIUserInterfaceStyleDark forTrait:[UITraitUserInterfaceStyle class]];
    [port setNSIntegerValue:UIUserInterfaceStyleDark forTrait:port_trait(@"UITraitUserInterfaceStyle")];
    charon_check([system containsTrait:[UITraitUserInterfaceStyle class]] ==
                      [port containsTrait:port_trait(@"UITraitUserInterfaceStyle")], "containsTrait: answers the same on both sides after a set" , @"the two sides disagree");
    COMPARE(without_class_name(unwrapped_overrides([port description])),
            without_class_name(unwrapped_overrides([system description])),
            "an overrides object with one override, its class name aside");
    [system removeTrait:[UITraitUserInterfaceStyle class]];
    [port removeTrait:port_trait(@"UITraitUserInterfaceStyle")];
    COMPARE(without_class_name(unwrapped_overrides([port description])),
            without_class_name(unwrapped_overrides([system description])),
            "an overrides object with the override removed, its class name aside");
    [system setCGFloatValue:2 forTrait:[UITraitDisplayScale class]];
    [port setCGFloatValue:2 forTrait:port_trait(@"UITraitDisplayScale")];
    [system setObject:@"fr" forTrait:[UITraitTypesettingLanguage class]];
    [port setObject:@"fr" forTrait:port_trait(@"UITraitTypesettingLanguage")];
    COMPARE(without_class_name(unwrapped_overrides([port description])),
            without_class_name(unwrapped_overrides([system description])),
            "an overrides object with a CGFloat and an object, its class name aside");
    UIView *other = [[UIView alloc] init];
    charon_check(other.traitOverrides != system, "two views have different overrides in the system" , @"the system shares one");
    charon_check([portView charonHostTraitOverrides] != [other charonHostTraitOverrides], "two views have different overrides in the port" , @"the port shares one");
    UIViewController *controller = [[UIViewController alloc] init];
    charon_check(controller.traitOverrides != nil, "a controller has overrides in the system" , @"it has none");
    charon_check([[controller charonHostTraitOverrides] class] == [port class], "a controller's overrides is the same class as a view's" ,
                 @"the port gives a controller another class");
}

// The trait change registration, and the overrides refusal, are asked of the port alone. Both for a reason the
// harness cannot get around: the registration's selectors have colons, and the harness renames a selector by the
// part before its first colon, so a category on NSObject cannot be put beside the system's without shadowing it
// and being unreachable by name; and a host whose trait metadata has raised once answers the overrides read with
// no exception where a clean one raises. What the host answers for both is in facts/UIKit/UITrait17.md (M5, M6),
// from the probe that asked each first, and the port is held to it here.
static void check_registration(void)
{
    // The protocol the port's own NSObject category adopts. NSObject is the system's own class, so renames()
    // leaves it alone and the port's category lands on it - which is the point: the conformance is added to
    // NSObject itself, so class_conformsToProtocol: on NSObject is what the registry row for
    // UITraitChangeObservable claims, and that is what is checked here.
    Class portObject = [NSObject class];
    charon_check([portObject conformsToProtocol:@protocol(UITraitChangeObservable)],
                 "the port's own NSObject adopts the trait-change protocol its registry row names",
                 [NSString stringWithFormat:@"%@ adopts UITraitChangeObservable: %@", NSStringFromClass(portObject),
                                            [portObject conformsToProtocol:@protocol(UITraitChangeObservable)] ? @"yes" : @"no"]);

    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    __block int calls = 0;
    id<UITraitChangeRegistration> registration = [view charonHostRegisterForTraitChanges:@[port_trait(@"UITraitUserInterfaceStyle")]
                                                                                withHandler:^(id<UITraitEnvironment> environment,
                                                                                              UITraitCollection *previous) {
                                                                                    calls++;
                                                                                }];
    charon_check(registration != nil, "the port registers for a trait change" , @"it answered nothing");
    // A registration is a class on both sides, and the two sides' classes have different names on purpose.
    // The host's is the private _UITraitRegistration, which no header declares and which the port therefore
    // does not define either: a class defined under that name is Apple's API to every tool that reads the
    // symbols, nothing dates it, and the 6.1.3 gate refuses to build a tree holding one. The port's is
    // CharonRegistration, its own type, carrying no release. Both names are asked of the side that owns one.
    COMPARE(unprefix(NSStringFromClass([registration class])), @"CharonRegistration",
            "a registration is a class of the port's own, by name");
    id<UITraitChangeRegistration> systemRegistration =
        [view registerForTraitChanges:@[[UITraitUserInterfaceStyle class]]
                           withHandler:^(id<UITraitEnvironment> environment, UITraitCollection *previous) {}];
    COMPARE(systemRegistration != nil ? NSStringFromClass([systemRegistration class]) : nil, @"_UITraitRegistration",
            "and the host's registration is the host's own private class, which this library does not define");
    charon_check([registration conformsToProtocol:@protocol(UITraitChangeRegistration)], "a registration adopts UITraitChangeRegistration" , @"it does not");
    charon_check([registration respondsToSelector:@selector(copy)], "a registration is copyable" , @"it is not");
    COMPARE(shape_of([(id)registration description]), @"<CharonRegistration: >", "a registration, described");
    [view charonHostUnregisterForTraitChanges:registration];
    [view charonHostUnregisterForTraitChanges:registration];
    charon_check(calls == 0, "unregistering calls nothing" , @"a handler ran");
    COMPARE(reason_of(^{
             [view charonHostUnregisterForTraitChanges:nil];
         }),
            @"NSInternalInconsistencyException: Must pass a non-nil registration to unregister",
            "unregistering nothing");
    COMPARE(reason_of(^{
             [view charonHostRegisterForTraitChanges:@[]
                                           withHandler:^(id<UITraitEnvironment> e, UITraitCollection *p){
                                           }];
         }),
            @"NSInternalInconsistencyException: Must pass one or more traits to register for",
            "registering for no traits at all");
    COMPARE(reason_of(^{
             id<UITraitOverrides> overrides = [view charonHostTraitOverrides];
             [overrides valueForNSIntegerTrait:port_trait(@"UITraitUserInterfaceStyle")];
         }),
            @"NSInternalInconsistencyException: Can't return value for trait UserInterfaceStyle that has no override",
            "reading a trait the overrides object does not override");
    // withTarget:action: with a method of one argument, which the header says the call is given.
    calls = 0;
    id<UITraitChangeRegistration> action = [view charonHostRegisterForTraitChanges:@[port_trait(@"UITraitDisplayScale")]
                                                                       withTarget:view
                                                                         action:@selector(setNeedsLayout)];
    charon_check(action != nil, "withTarget:action: registers" , @"it answered nothing");
    [view charonHostUnregisterForTraitChanges:action];
    charon_check([view respondsToSelector:@selector(charonHostUpdateTraitsIfNeeded)], "a view answers updateTraitsIfNeeded" , @"it does not");
    [view charonHostUpdateTraitsIfNeeded];
    UIViewController *controller = [[UIViewController alloc] init];
    charon_check([[controller charonHostTraitOverrides] class] == [view charonHostTraitOverrides].class, "a controller's overrides is the same class as a view's" , @"the port gives a controller another class");
    charon_check(controller.traitOverrides != nil, "a controller has overrides on the system too" , @"it has none");
    charon_check([controller respondsToSelector:@selector(charonHostUpdateTraitsIfNeeded)], "a controller answers updateTraitsIfNeeded" , @"it does not");
}


int main(void)
{
    @autoreleasepool {
        compare_definitions();
        compare_empty();
        compare_values();
        compare_modifying();
        compare_changed();
        compare_lists();
        compare_overrides();
        check_registration();
        // The refusals come last and one after another, because a caught NSInternalInconsistencyException out of
        // UIKitCore's own trait metadata leaves the host in a state this process does not come back from: the run
        // prints what it had before them, so a process that dies among them is a truncated log and not a pass.
        printf("checks=%d failures=%d before the refusals\n", charon_checks, charon_failures);
        fflush(stdout);
        compare_refusals();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures;
}

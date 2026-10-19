#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <stdio.h>
#import <objc/runtime.h>
#pragma clang diagnostic ignored "-Wunguarded-availability-new"

#import "check.h"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface CharonHostCharonTraitMutations : NSObject <UIMutableTraits>
- (UITraitCollection *)charon_collection;
@end

@interface CharonHost_CharonOverrides : CharonHostCharonTraitMutations <UITraitOverrides>
@end

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

@interface UITraitCollection (CharonHostTraits17)
+ (UITraitCollection *)traitCollectionWithTraits:(__attribute__((noescape)) UITraitMutations)mutations;
- (UITraitCollection *)traitCollectionByModifyingTraits:(__attribute__((noescape)) UITraitMutations)mutations;
- (NSSet *)changedTraitsFromTraitCollection:(UITraitCollection *)traitCollection;
@end

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

static NSString *unprefix(NSString *text)
{
    if (!text)
        return text;
    return [text hasPrefix:@"CharonHost"] ? [text substringFromIndex:10]
                                           : [text stringByReplacingOccurrencesOfString:@"CharonHost" withString:@""];
}

static NSString *portTraitName(Class trait)
{
    NSString *identifier = unprefix(NSStringFromClass(trait));
    NSRange prefix = [identifier rangeOfString:@"UITrait"];
    return prefix.location == NSNotFound ? identifier : [identifier substringFromIndex:NSMaxRange(prefix)];
}

static NSString *definition_of(Class trait)
{
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"identifier=%@", [trait respondsToSelector:@selector(identifier)] ? unprefix([trait identifier]) : @"(none)"];
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

#define COMPARE(ours, system, name) compare_text((ours), (system), (name))
#define COMPARE_COLLECTIONS(ours, system, name) compare_collections((ours), (system), (name))

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
        [systemNames removeObject:@"defaultValueRepresentsUnspecified"];
        [systemNames removeObject:@"_isPrivate"];
        NSArray *portListed = [[portNames allObjects] sortedArrayUsingSelector:@selector(compare:)];
        NSArray *systemListed = [[systemNames allObjects] sortedArrayUsingSelector:@selector(compare:)];
        COMPARE([portListed componentsJoinedByString:@","], [systemListed componentsJoinedByString:@","],
                NAMED(@"%@ class methods", name));
        charon_check([systemNames containsObject:@"affectsColorAppearance"] == [portNames containsObject:@"affectsColorAppearance"],
                     NAMED(@"%@ has +affectsColorAppearance as the system does", name),
                     @"the two sides disagree about the optional property");
    }
}

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
        if (system != [UITraitUserInterfaceIdiom class])
            COMPARE(of_description([portMade description]), of_description([systemMade description]),
                    NAMED(@"%@ described", name));
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
    description = unprefix(description);
    NSRegularExpression *address = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-fA-F]+" options:0 error:NULL];
    return [address stringByReplacingMatchesInString:description options:0 range:NSMakeRange(0, description.length) withTemplate:@""];
}

static NSString *shape_of(NSString *description);

static NSString *sorted_pairs(NSString *text)
{
    NSRange open = [text rangeOfString:@"{"];
    NSRange close = [text rangeOfString:@"}"];
    if (open.location == NSNotFound || close.location == NSNotFound || close.location < NSMaxRange(open))
        return text;
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

static void check_registration(void)
{
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
        printf("checks=%d failures=%d before the refusals\n", charon_checks, charon_failures);
        fflush(stdout);
        compare_refusals();
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    }
    return charon_failures;
}

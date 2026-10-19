#import <UIKit/UIKit.h>
#import "check.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#define NAMED(...) ([NSString stringWithFormat:__VA_ARGS__].UTF8String)

@interface CharonHostUIUserNotificationAction : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, copy, readonly) NSString *title;
@property (nonatomic, readonly) UIUserNotificationActivationMode activationMode;
@property (nonatomic, readonly, getter=isAuthenticationRequired) BOOL authenticationRequired;
@property (nonatomic, readonly, getter=isDestructive) BOOL destructive;
@end

@interface CharonHostUIMutableUserNotificationAction : CharonHostUIUserNotificationAction
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) UIUserNotificationActivationMode activationMode;
@property (nonatomic, getter=isAuthenticationRequired) BOOL authenticationRequired;
@property (nonatomic, getter=isDestructive) BOOL destructive;
@end

@interface CharonHostUIUserNotificationCategory : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
@property (nonatomic, copy, readonly) NSString *identifier;
- (NSArray *)actionsForContext:(UIUserNotificationActionContext)context;
@end

@interface CharonHostUIMutableUserNotificationCategory : CharonHostUIUserNotificationCategory
@property (nonatomic, copy) NSString *identifier;
- (void)setActions:(NSArray *)actions forContext:(UIUserNotificationActionContext)context;
@end

@interface CharonHostUIUserNotificationSettings : NSObject
+ (instancetype)settingsForTypes:(UIUserNotificationType)types categories:(NSSet *)categories;
@property (nonatomic, readonly) UIUserNotificationType types;
@property (nonatomic, copy, readonly) NSSet *categories;
@end

static NSString *normalized(id object)
{
    NSMutableString *text = [[object description] mutableCopy];
    NSRegularExpression *pointers = [NSRegularExpression regularExpressionWithPattern:@"0x[0-9a-f]+" options:0 error:NULL];
    [pointers replaceMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@"0x0"];
    NSRegularExpression *ninth = [NSRegularExpression regularExpressionWithPattern:@"(behavior: [A-Za-z]+, |, parameters: \\(null\\))" options:0 error:NULL];
    [ninth replaceMatchesInString:text options:0 range:NSMakeRange(0, text.length) withTemplate:@""];
    [text replaceOccurrencesOfString:@"CharonHost" withString:@"" options:0 range:NSMakeRange(0, text.length)];
    return text;
}

static void compare_description(id ours, id system, const char *name)
{
    charon_check([normalized(ours) isEqualToString:normalized(system)], name, [NSString stringWithFormat:@"%@ != %@", normalized(ours), normalized(system)]);
}

static id make_action(Class kind, NSString *identifier, NSString *title, UIUserNotificationActivationMode mode, BOOL authentication, BOOL destructive)
{
    id action = [[kind alloc] init];
    [action setIdentifier:identifier];
    [action setTitle:title];
    [action setActivationMode:mode];
    [action setAuthenticationRequired:authentication];
    [action setDestructive:destructive];
    return action;
}

static id make_category(Class kind, NSString *identifier, NSArray *actions, NSArray *minimal)
{
    id category = [[kind alloc] init];
    [category setIdentifier:identifier];
    if (actions)
        [category setActions:actions forContext:UIUserNotificationActionContextDefault];
    if (minimal)
        [category setActions:minimal forContext:UIUserNotificationActionContextMinimal];
    return category;
}

int main(void)
{
    @autoreleasepool {
        id ourAction = make_action([CharonHostUIMutableUserNotificationAction class], @"reply", @"Reply", UIUserNotificationActivationModeBackground, YES, NO);
        UIMutableUserNotificationAction *systemAction = make_action([UIMutableUserNotificationAction class], @"reply", @"Reply", UIUserNotificationActivationModeBackground, YES, NO);
        charon_check([[ourAction identifier] isEqualToString:systemAction.identifier], "action identifier", @"identifier differs");
        charon_check([[ourAction title] isEqualToString:systemAction.title], "action title", @"title differs");
        charon_check([ourAction activationMode] == systemAction.activationMode, "action activation mode", @"activation mode differs");
        charon_check([ourAction isAuthenticationRequired] == systemAction.isAuthenticationRequired, "action authentication", @"authentication differs");
        charon_check([ourAction isDestructive] == systemAction.isDestructive, "action destructive", @"destructive differs");
        compare_description(ourAction, systemAction, "action description");

        id ourFrozen = [ourAction copy];
        UIUserNotificationAction *systemFrozen = [systemAction copy];
        charon_check([NSStringFromClass([ourFrozen class]) isEqualToString:[@"CharonHost" stringByAppendingString:NSStringFromClass([systemFrozen class])]], "action copy class", NSStringFromClass([ourFrozen class]));
        charon_check([ourFrozen isEqual:ourAction] == [systemFrozen isEqual:systemAction], "action copy equality", @"copy equality differs");
        charon_check([[ourFrozen title] isEqualToString:[systemFrozen title]], "action copy title", @"copied title differs");
        id ourThawed = [ourFrozen mutableCopy];
        UIMutableUserNotificationAction *systemThawed = [systemFrozen mutableCopy];
        charon_check([NSStringFromClass([ourThawed class]) isEqualToString:[@"CharonHost" stringByAppendingString:NSStringFromClass([systemThawed class])]], "action mutable copy class", NSStringFromClass([ourThawed class]));
        [ourThawed setTitle:@"Other"];
        [systemThawed setTitle:@"Other"];
        charon_check([[ourFrozen title] isEqualToString:[systemFrozen title]], "mutable copy is independent", @"the copy changed the original");

        id ourSecond = make_action([CharonHostUIMutableUserNotificationAction class], @"later", @"Later", UIUserNotificationActivationModeForeground, NO, YES);
        UIMutableUserNotificationAction *systemSecond = make_action([UIMutableUserNotificationAction class], @"later", @"Later", UIUserNotificationActivationModeForeground, NO, YES);

        id ourCategory = make_category([CharonHostUIMutableUserNotificationCategory class], @"message", @[ourAction, ourSecond], nil);
        UIMutableUserNotificationCategory *systemCategory = make_category([UIMutableUserNotificationCategory class], @"message", @[systemAction, systemSecond], nil);
        charon_check([[ourCategory actionsForContext:UIUserNotificationActionContextDefault] count] == [systemCategory actionsForContext:UIUserNotificationActionContextDefault].count, "category default actions", @"default action count differs");
        charon_check(([ourCategory actionsForContext:UIUserNotificationActionContextMinimal] == nil) == ([systemCategory actionsForContext:UIUserNotificationActionContextMinimal] == nil), "category minimal actions", @"minimal actions differ");
        charon_check([[ourCategory actionsForContext:UIUserNotificationActionContextDefault] objectAtIndex:0] == ourAction, "category keeps action identity", @"the action was copied");
        compare_description(ourCategory, systemCategory, "category description");
        charon_check([[[ourCategory class] alloc] init] != nil && [[ourCategory class] supportsSecureCoding] == [[systemCategory class] supportsSecureCoding], "category secure coding", @"secure coding differs");

        id emptyOurs = [[CharonHostUIUserNotificationCategory alloc] init];
        UIUserNotificationCategory *emptySystem = [[UIUserNotificationCategory alloc] init];
        charon_check([emptyOurs isEqual:[[CharonHostUIUserNotificationCategory alloc] init]] == [emptySystem isEqual:[[UIUserNotificationCategory alloc] init]], "empty categories equality", @"empty category equality differs");
        charon_check([[ourCategory copy] isEqual:ourCategory] == [[systemCategory copy] isEqual:systemCategory], "category copy equality", @"category copy equality differs");
        id otherOurs = make_category([CharonHostUIMutableUserNotificationCategory class], @"message", nil, nil);
        UIMutableUserNotificationCategory *otherSystem = make_category([UIMutableUserNotificationCategory class], @"message", nil, nil);
        charon_check([otherOurs isEqual:ourCategory] == [otherSystem isEqual:systemCategory], "categories with the same identifier", @"equality differs");
        id sameOurs = make_category([CharonHostUIMutableUserNotificationCategory class], @"message", @[ourAction, ourSecond], nil);
        UIMutableUserNotificationCategory *sameSystem = make_category([UIMutableUserNotificationCategory class], @"message", @[systemAction, systemSecond], nil);
        charon_check([sameOurs isEqual:ourCategory] == [sameSystem isEqual:systemCategory], "categories with the same actions", @"equality differs");
        charon_check(([sameOurs hash] == [ourCategory hash]) == ([sameSystem hash] == [systemCategory hash]), "category hash", @"hash agreement differs");
        [ourCategory setActions:nil forContext:UIUserNotificationActionContextDefault];
        [systemCategory setActions:nil forContext:UIUserNotificationActionContextDefault];
        charon_check([[ourCategory actionsForContext:UIUserNotificationActionContextDefault] count] == [systemCategory actionsForContext:UIUserNotificationActionContextDefault].count, "clearing the actions", @"cleared actions differ");
        [ourCategory setActions:@[ourAction, ourSecond] forContext:UIUserNotificationActionContextDefault];
        [systemCategory setActions:@[systemAction, systemSecond] forContext:UIUserNotificationActionContextDefault];

        UIUserNotificationType types[] = {0, UIUserNotificationTypeAlert, UIUserNotificationTypeBadge | UIUserNotificationTypeSound,
                                          UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound, 0xff};
        for (NSUInteger index = 0; index < sizeof(types) / sizeof(*types); index++) {
            CharonHostUIUserNotificationSettings *ours = [CharonHostUIUserNotificationSettings settingsForTypes:types[index] categories:[NSSet setWithObject:ourCategory]];
            UIUserNotificationSettings *system = [UIUserNotificationSettings settingsForTypes:types[index] categories:[NSSet setWithObject:systemCategory]];
            charon_check(ours.types == system.types, NAMED(@"settings types %lu", (unsigned long)types[index]), @"types differ");
            charon_check(ours.categories.count == system.categories.count, NAMED(@"settings categories %lu", (unsigned long)types[index]), @"category count differs");
            charon_check([[ours.categories anyObject] isKindOfClass:[CharonHostUIMutableUserNotificationCategory class]] == [[system.categories anyObject] isKindOfClass:[UIMutableUserNotificationCategory class]],
                         NAMED(@"settings copies its categories %lu", (unsigned long)types[index]), @"the mutable category was kept");
            compare_description(ours, system, NAMED(@"settings description %lu", (unsigned long)types[index]));
        }
        CharonHostUIUserNotificationSettings *withoutOurs = [CharonHostUIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];
        UIUserNotificationSettings *withoutSystem = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:nil];
        charon_check(withoutOurs.categories.count == withoutSystem.categories.count, "settings without categories", @"category count differs");
        charon_check([withoutOurs isEqual:[CharonHostUIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:[NSSet set]]] ==
                     [withoutSystem isEqual:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert categories:[NSSet set]]], "settings equality without categories", @"equality differs");
        charon_check([withoutOurs isEqual:[CharonHostUIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge categories:nil]] ==
                     [withoutSystem isEqual:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeBadge categories:nil]], "settings equality with other types", @"equality differs");
        compare_description([[CharonHostUIUserNotificationSettings alloc] init], [[UIUserNotificationSettings alloc] init], "empty settings description");

        NSData *ourData = [NSKeyedArchiver archivedDataWithRootObject:ourCategory requiringSecureCoding:YES error:NULL];
        NSData *systemData = [NSKeyedArchiver archivedDataWithRootObject:systemCategory requiringSecureCoding:YES error:NULL];
        NSDictionary *ourPlist = [NSPropertyListSerialization propertyListWithData:ourData options:0 format:NULL error:NULL];
        NSDictionary *systemPlist = [NSPropertyListSerialization propertyListWithData:systemData options:0 format:NULL error:NULL];
        NSMutableSet *ourKeys = [NSMutableSet set], *systemKeys = [NSMutableSet set];
        for (id entry in [ourPlist objectForKey:@"$objects"]) {
            if ([entry isKindOfClass:[NSDictionary class]])
                [ourKeys addObjectsFromArray:[entry allKeys]];
        }
        for (id entry in [systemPlist objectForKey:@"$objects"]) {
            if ([entry isKindOfClass:[NSDictionary class]])
                [systemKeys addObjectsFromArray:[entry allKeys]];
        }
        [systemKeys minusSet:[NSSet setWithObjects:@"kBehaviorKey", @"kParametersKey", nil]];
        charon_check([ourKeys isEqual:systemKeys], "category archive keys", [NSString stringWithFormat:@"%@ != %@", ourKeys, systemKeys]);
        id decoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[CharonHostUIUserNotificationCategory class], [CharonHostUIMutableUserNotificationCategory class], [CharonHostUIUserNotificationAction class], [CharonHostUIMutableUserNotificationAction class], [NSArray class], [NSDictionary class], [NSNumber class], [NSString class], nil] fromData:ourData error:NULL];
        UIUserNotificationCategory *systemDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithObjects:[UIUserNotificationCategory class], [UIMutableUserNotificationCategory class], [UIUserNotificationAction class], [UIMutableUserNotificationAction class], [NSArray class], [NSDictionary class], [NSNumber class], [NSString class], nil] fromData:systemData error:NULL];
        charon_check([[decoded identifier] isEqualToString:[systemDecoded identifier]], "decoded identifier", @"decoded identifier differs");
        charon_check([[decoded actionsForContext:UIUserNotificationActionContextDefault] count] == [systemDecoded actionsForContext:UIUserNotificationActionContextDefault].count, "decoded actions", @"decoded action count differs");
        charon_check([[[decoded actionsForContext:UIUserNotificationActionContextDefault] objectAtIndex:0] activationMode] ==
                     [[systemDecoded actionsForContext:UIUserNotificationActionContextDefault] objectAtIndex:0].activationMode, "decoded action activation mode", @"decoded activation mode differs");
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        return charon_failures;
    }
}

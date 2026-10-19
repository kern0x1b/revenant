#import <UIKit/UIKit.h>
#include <stdio.h>

static void report(const char *check, NSString *value)
{
    printf("%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

static NSString *describe(NSDictionary *dictionary)
{
    if (!dictionary)
        return @"nil";
    return [NSString stringWithFormat:@"dictionary:%lu", (unsigned long)dictionary.count];
}

static NSString *outcome(void (^change)(void))
{
    @try {
        change();
        return @"ok";
    } @catch (NSException *exception) {
        return exception.name;
    }
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        UIMutableUserNotificationAction *action = [[UIMutableUserNotificationAction alloc] init];
        report("class", class_name(action));
        report("behavior-default", [NSString stringWithFormat:@"%ld", (long)action.behavior]);
        report("parameters-default", describe(action.parameters));

        action.behavior = UIUserNotificationActionBehaviorTextInput;
        report("behavior-set", [NSString stringWithFormat:@"%ld", (long)action.behavior]);
        action.behavior = UIUserNotificationActionBehaviorDefault;
        report("behavior-cleared", [NSString stringWithFormat:@"%ld", (long)action.behavior]);

        NSMutableDictionary *given = [NSMutableDictionary dictionaryWithObject:@"value" forKey:@"key"];
        action.parameters = given;
        report("parameters-set", describe(action.parameters));
        report("parameters-same-object", yes_no(action.parameters == given));
        report("parameters-value", action.parameters[@"key"]);
        [given setObject:@"other" forKey:@"second"];
        report("parameters-after-change", describe(action.parameters));
        report("parameters-nil", outcome(^{ action.parameters = nil; }));
        report("parameters-after-nil", describe(action.parameters));

        action.behavior = UIUserNotificationActionBehaviorTextInput;
        action.parameters = @{@"copied": @"yes"};
        id copied = [action copy];
        report("copy-class", class_name(copied));
        report("copy-behavior", [NSString stringWithFormat:@"%ld", (long)[copied behavior]]);
        report("copy-parameters", describe([copied parameters]));
        id mutableCopied = [action mutableCopy];
        report("mutable-copy-class", class_name(mutableCopied));
        report("mutable-copy-behavior", [NSString stringWithFormat:@"%ld", (long)[mutableCopied behavior]]);
        report("mutable-copy-parameters", describe([mutableCopied parameters]));

        NSError *error = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:action requiringSecureCoding:YES error:&error];
        report("archive", archive ? @"made" : @"failed");
        if (archive) {
            NSSet *classes = [NSSet setWithObjects:[UIUserNotificationAction class], [NSDictionary class], [NSString class], nil];
            UIUserNotificationAction *thawed = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:archive error:&error];
            report("archive-class", class_name(thawed));
            report("archive-behavior", [NSString stringWithFormat:@"%ld", (long)[thawed behavior]]);
            report("archive-parameters", describe([thawed parameters]));
        }
    }
    return 0;
}

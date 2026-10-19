#import <UserNotifications/UserNotifications.h>
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
    return [name hasPrefix:@"RevenantPort"] ? [name substringFromIndex:12] : name;
}

static NSString *number(double value)
{
    return [NSString stringWithFormat:@"%g", value];
}

static NSString *text(NSString *value)
{
    return value ?: @"nil";
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

static NSString *describe(UNNotificationContent *content)
{
    return [NSString stringWithFormat:@"%@|%lu|%@|%ld|%@|%@", text(content.summaryArgument), (unsigned long)content.summaryArgumentCount,
            text(content.targetContentIdentifier), (long)content.interruptionLevel, number(content.relevanceScore), text(content.filterCriteria)];
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        report("class", class_name(content));
        report("defaults", describe(content));

        content.summaryArgument = @"argument";
        content.summaryArgumentCount = 3;
        content.targetContentIdentifier = @"target";
        content.interruptionLevel = UNNotificationInterruptionLevelTimeSensitive;
        content.relevanceScore = 0.75;
        content.filterCriteria = @"filter";
        report("set", describe(content));

        NSMutableString *given = [NSMutableString stringWithString:@"first"];
        content.filterCriteria = given;
        [given appendString:@"-changed"];
        report("filter-copied", content.filterCriteria);
        report("filter-same-object", yes_no(content.filterCriteria == given));
        content.filterCriteria = nil;
        report("filter-cleared", text(content.filterCriteria));
        content.targetContentIdentifier = nil;
        report("target-cleared", text(content.targetContentIdentifier));

        content.interruptionLevel = UNNotificationInterruptionLevelActive;
        report("level-active", [NSString stringWithFormat:@"%ld", (long)content.interruptionLevel]);
        content.interruptionLevel = UNNotificationInterruptionLevelCritical;
        report("level-critical", [NSString stringWithFormat:@"%ld", (long)content.interruptionLevel]);
        content.relevanceScore = 0;
        report("relevance-zero", number(content.relevanceScore));
        content.summaryArgumentCount = 0;
        report("count-zero", [NSString stringWithFormat:@"%lu", (unsigned long)content.summaryArgumentCount]);
        content.summaryArgument = nil;
        report("summary-nil", text(content.summaryArgument));

        content.summaryArgument = @"argument";
        content.summaryArgumentCount = 4;
        content.targetContentIdentifier = @"target";
        content.relevanceScore = 0.25;
        content.filterCriteria = @"filter";
        UNNotificationContent *copied = [content copy];
        report("copy-class", class_name(copied));
        report("copy-values", describe(copied));
        UNMutableNotificationContent *mutableCopied = [content mutableCopy];
        report("mutable-copy-class", class_name(mutableCopied));
        report("mutable-copy-values", describe(mutableCopied));

        UNMutableNotificationContent *same = [content mutableCopy];
        report("equal-to-copy", yes_no([same isEqual:content]));
        same.relevanceScore = 0.5;
        report("unequal-relevance", yes_no([same isEqual:content]));
        same.relevanceScore = 0.25;
        same.filterCriteria = @"other";
        report("unequal-filter", yes_no([same isEqual:content]));
        same.filterCriteria = @"filter";
        same.interruptionLevel = UNNotificationInterruptionLevelPassive;
        report("unequal-level", yes_no([same isEqual:content]));
        same.interruptionLevel = content.interruptionLevel;
        same.targetContentIdentifier = @"elsewhere";
        report("unequal-target", yes_no([same isEqual:content]));
        same.targetContentIdentifier = content.targetContentIdentifier;
        same.summaryArgument = @"elsewhere";
        report("unequal-summary", yes_no([same isEqual:content]));
        same.summaryArgument = content.summaryArgument;
        same.summaryArgumentCount = 9;
        report("unequal-count", yes_no([same isEqual:content]));

        NSError *error = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:content requiringSecureCoding:YES error:&error];
        report("archive", archive ? @"made" : @"failed");
        if (archive) {
            UNNotificationContent *thawed = [NSKeyedUnarchiver unarchivedObjectOfClass:[UNNotificationContent class] fromData:archive error:&error];
            report("archive-class", class_name(thawed));
            report("archive-values", describe(thawed));
        }
        report("set-outcome", outcome(^{ content.relevanceScore = 1.5; }));
        report("relevance-above", number(content.relevanceScore));
        content.relevanceScore = -0.5;
        report("relevance-below", number(content.relevanceScore));
        content.relevanceScore = 0.4;
        report("relevance-inside", number(content.relevanceScore));
    }
    return 0;
}

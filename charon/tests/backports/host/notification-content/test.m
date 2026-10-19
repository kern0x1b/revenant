#import <UserNotifications/UserNotifications.h>
#include <stdio.h>

// UNNotificationContent and UNMutableNotificationContent's iOS 12 to 16 properties (the summary argument and its count, the target content
// identifier, the interruption level, the relevance score and the filter criteria), checked on the same values in two processes: the host's
// classes in one, and the port's (renamed by run.sh, so this file's names mean the port's classes in that build) in the other. Each line is
// "check<TAB>value"; the two outputs must match line for line. The archive is checked as a round trip of the port's own format.

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

static NSString *number(double value)
{
    return [NSString stringWithFormat:@"%g", value];
}

static NSString *text(NSString *value)
{
    return value ?: @"nil";
}

// A setter may raise. The outcome is "ok", or the exception's name.
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

        // Each string is copied on set, as the header says: a change to the mutable string given afterwards does not reach the content.
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

        // The copies carry the values and their classes, and an immutable copy is the immutable kind.
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

        // Equality compares the new values: a content that differs in one of them is not equal to the others.
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

        // An archive, under secure coding, reads back what it held.
        NSError *error = nil;
        NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:content requiringSecureCoding:YES error:&error];
        report("archive", archive ? @"made" : @"failed");
        if (archive) {
            UNNotificationContent *thawed = [NSKeyedUnarchiver unarchivedObjectOfClass:[UNNotificationContent class] fromData:archive error:&error];
            report("archive-class", class_name(thawed));
            report("archive-values", describe(thawed));
        }
        // The relevance is kept within [0, 1]: a value above one reads as one, and a value below zero as zero.
        report("set-outcome", outcome(^{ content.relevanceScore = 1.5; }));
        report("relevance-above", number(content.relevanceScore));
        content.relevanceScore = -0.5;
        report("relevance-below", number(content.relevanceScore));
        content.relevanceScore = 0.4;
        report("relevance-inside", number(content.relevanceScore));
    }
    return 0;
}

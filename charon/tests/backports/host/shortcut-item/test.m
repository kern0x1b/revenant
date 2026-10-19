#import <UIKit/UIKit.h>
#include <stdio.h>

// UIApplicationShortcutItem's target content identifier, checked on the same values in two processes: the host's classes in one, and the
// port's (renamed by run.sh, so this file's names mean the port's classes in that build) in the other. Each line is "check<TAB>value"; the
// two outputs must match line for line. The identifier is readonly on the item and writable on its mutable subclass, and copied.

static void report(const char *check, NSString *value)
{
    printf("%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

// The port's classes carry the CharonPort prefix in this build; it is stripped, so the two sides print the same class names.
static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

static NSString *describe(id value)
{
    return value ? [NSString stringWithFormat:@"%@:%@", NSStringFromClass([value class]), value] : @"nil";
}

int main(void)
{
    @autoreleasepool {
        setvbuf(stdout, NULL, _IONBF, 0);

        UIApplicationShortcutItem *item = [[UIApplicationShortcutItem alloc] initWithType:@"type" localizedTitle:@"title"];
        report("item-target-default", describe(item.targetContentIdentifier));

        UIMutableApplicationShortcutItem *mutable = [[UIMutableApplicationShortcutItem alloc] initWithType:@"type" localizedTitle:@"title"];
        report("mutable-target-default", describe(mutable.targetContentIdentifier));

        // The identifier is kept as the object given, not copied, when the given object is not mutable.
        mutable.targetContentIdentifier = @"scene";
        report("mutable-target-set", describe(mutable.targetContentIdentifier));

        // A mutable string given is copied on set, as the header says: a change to it afterwards does not reach the item.
        NSMutableString *given = [NSMutableString stringWithString:@"first"];
        mutable.targetContentIdentifier = given;
        [given appendString:@"-changed"];
        report("mutable-target-copied", describe(mutable.targetContentIdentifier));
        report("mutable-target-same-object", yes_no(mutable.targetContentIdentifier == given));

        // A copy of the mutable item is the immutable kind, and a mutable copy is the mutable kind; each says what it carries.
        mutable.targetContentIdentifier = @"carried";
        id copied = [mutable copy];
        report("mutable-copy-class", class_name(copied));
        report("mutable-copy-target", describe([copied targetContentIdentifier]));
        id mutableCopied = [mutable mutableCopy];
        report("mutable-mutable-copy-class", class_name(mutableCopied));
        report("mutable-mutable-copy-target", describe([mutableCopied targetContentIdentifier]));

        // The immutable item answers nil, and its own copy is itself.
        report("item-copy-same", yes_no([item copy] == item));

        // Nil clears the identifier.
        mutable.targetContentIdentifier = nil;
        report("mutable-target-cleared", describe(mutable.targetContentIdentifier));
    }
    return 0;
}

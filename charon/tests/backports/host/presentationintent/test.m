#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

/* NSPresentationIntent: the port's class and the system's in one process.
   The port's sources are compiled with their class and their selectors renamed, so the two
   implementations never meet: every case below builds one intent with each and holds the answers
   side by side. The class is a value, so a case is a chain of kinds, and the whole chain is
   compared: every property the header declares, the raise the table factory makes, equality
   against identity, the archive's keys and the round trip. */

/* The keys an intent's archive carries, read back out of a real keyed archive. Each side writes
   through its own -encodeWithCoder:, because the two classes are two classes and each carries the
   method of its own name. */
static NSArray *keysInArchive(id intent)
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:intent requiringSecureCoding:YES error:&error];
    if (!data)
        return @[([NSString stringWithFormat:@"raises %@: %@", error.domain, error.localizedDescription])];
    id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
    NSArray *objects = plist[@"$objects"];
    NSMutableArray *keys = [NSMutableArray array];
    for (id entry in objects)
        if ([entry isKindOfClass:[NSDictionary class]] && ![(NSDictionary *)entry objectForKey:@"$class"])
            [keys addObjectsFromArray:[(NSDictionary *)entry allKeys]];
    return [keys sortedArrayUsingSelector:@selector(compare:)];
}

static Class ourClass;

/* With the port's class compiled under a name of its own and its selectors left alone (the "*"
   of uikit2/renames.sh), the two classes never collide, so both sides are called the same way. */
static id makeIn(Class kind, NSString *factory, NSInteger identity, NSInteger number, id parent, NSArray *alignments)
{
    SEL selector = NSSelectorFromString(factory);
    NSMethodSignature *signature = [kind methodSignatureForSelector:selector];
    if (!signature)
        return nil;
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    invocation.selector = selector;
    invocation.target = kind;
    /* The arguments go in by the name of the selector's part, since a factory's two numbers and its
       two objects come in a different order in each of the twelve. */
    /* Every part of a selector ends in a colon, so splitting leaves an empty piece at the end. */
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *part in [factory componentsSeparatedByString:@":"])
        if (part.length)
            [parts addObject:part];
    for (NSUInteger index = 0; index < parts.count; index++) {
        NSString *part = parts[index];
        const char *type = [signature getArgumentTypeAtIndex:index + 2];
        if (type[0] == 'q' || type[0] == 'l' || type[0] == 'i' || type[0] == 's' || type[0] == 'S') {
            NSInteger value = [part isEqualToString:@"identity"] ? identity : number;
            [invocation setArgument:&value atIndex:index + 2];
            continue;
        }
        id value = nil;
        if ([part isEqualToString:@"nestedInsideIntent"])
            value = parent;
        else if ([part isEqualToString:@"alignments"])
            value = alignments;
        else if ([part isEqualToString:@"languageHint"])
            value = @"c";
        [invocation setArgument:&value atIndex:index + 2];
    }
    [invocation invoke];
    /* The return value of an object-returning method read through an invocation is +0 and the
       invocation may have put it in the pool itself; taking it unretained and letting the caller's
       ARC own it is what keeps one release and not two. */
    id __unsafe_unretained read = nil;
    [invocation getReturnValue:&read];
    return read;
}

static NSString *factoryFor(NSInteger kind)
{
    switch (kind) {
        case 0: return @"paragraphIntentWithIdentity:nestedInsideIntent:";
        case 1: return @"headerIntentWithIdentity:level:nestedInsideIntent:";
        case 2: return @"orderedListIntentWithIdentity:nestedInsideIntent:";
        case 3: return @"unorderedListIntentWithIdentity:nestedInsideIntent:";
        case 4: return @"listItemIntentWithIdentity:ordinal:nestedInsideIntent:";
        case 5: return @"codeBlockIntentWithIdentity:languageHint:nestedInsideIntent:";
        case 6: return @"blockQuoteIntentWithIdentity:nestedInsideIntent:";
        case 7: return @"thematicBreakIntentWithIdentity:nestedInsideIntent:";
        case 8: return @"tableIntentWithIdentity:columnCount:alignments:nestedInsideIntent:";
        case 9: return @"tableHeaderRowIntentWithIdentity:nestedInsideIntent:";
        case 10: return @"tableRowIntentWithIdentity:row:nestedInsideIntent:";
        case 11: return @"tableCellIntentWithIdentity:column:nestedInsideIntent:";
    }
    return nil;
}

static id build(BOOL ours, NSInteger kind, id parent, NSInteger identity, NSInteger number)
{
    NSString *factory = factoryFor(kind);
    Class target = ours ? ourClass : [NSPresentationIntent class];
    NSArray *alignments = nil;
    if (kind == 8) {
        NSMutableArray *made = [NSMutableArray array];
        for (NSInteger index = 0; index < number; index++)
            [made addObject:@((index % 3))];
        alignments = made;
    }
    return makeIn(target, factory, identity, number, parent, alignments);
}

static const char *numbers[] = {"IntentKind", "Identity", "Ordinal", "ColumnCount", "HeaderLevel", "Column",
                                "Row", "IndentationLevel"};
static const char *plainNumbers[] = {"intentKind", "identity", "ordinal", "columnCount", "headerLevel", "column",
                                     "row", "indentationLevel"};
static const char *objects[] = {"columnAlignments", "languageHint", "parentIntent"};

static NSString *answer(id intent)
{
    if (!intent)
        return @"nil";
    NSMutableString *text = [NSMutableString string];
    for (NSUInteger index = 0; index < sizeof(plainNumbers) / sizeof(plainNumbers[0]); index++) {
        SEL selector = NSSelectorFromString(@(plainNumbers[index]));
        NSInteger value = ((NSInteger (*)(id, SEL))objc_msgSend)(intent, selector);
        [text appendFormat:@"%s=%ld ", plainNumbers[index], (long)value];
    }
    for (NSUInteger index = 0; index < 3; index++) {
        SEL selector = NSSelectorFromString(@(objects[index]));
        id value = ((id (*)(id, SEL))objc_msgSend)(intent, selector);
        /* The parent is compared by presence, not by its description: the two classes describe
           themselves differently, which says nothing about the intent. */
        if (index == 2)
            value = value ? (id)@"some" : nil;
        [text appendFormat:@"%s=%@ ", objects[index], value ? [value description] : @"nil"];
    }
    return text;
}

static void compare(NSString *label, id ourIntent, id systemIntent)
{
    NSString *ours = answer(ourIntent), *system = answer(systemIntent);
    charon_check([system isEqualToString:ours], label.UTF8String,
                  [NSString stringWithFormat:@"the system answers %@, the backport answers %@", system, ours]);
}

int main(void)
{
    @autoreleasepool {
        ourClass = NSClassFromString(@"CharonHostNSPresentationIntent");
        CHECK(ourClass != Nil, "the port defines NSPresentationIntent under its own name");

        /* Every chain of two kinds, and every chain of three: the level is what the chain decides. */
        for (NSInteger first = 0; first < 8; first++) {
            for (NSInteger second = 0; second < 8; second++) {
                id ourParent = build(YES, first, nil, 10, 1), systemParent = build(NO, first, nil, 10, 1);
                id ourIntent = build(YES, second, ourParent, 11, 2), systemIntent = build(NO, second, systemParent, 11, 2);
                compare([NSString stringWithFormat:@"chain %ld>%ld", (long)first, (long)second], ourIntent, systemIntent);
            }
        }
        for (NSInteger a = 0; a < 8; a++) {
            for (NSInteger b = 0; b < 8; b++) {
                for (NSInteger c = 0; c < 8; c++) {
                    id ourOne = build(YES, a, nil, 20, 1), systemOne = build(NO, a, nil, 20, 1);
                    id ourTwo = build(YES, b, ourOne, 21, 2), systemTwo = build(NO, b, systemOne, 21, 2);
                    id ourIntent = build(YES, c, ourTwo, 22, 3), systemIntent = build(NO, c, systemTwo, 22, 3);
                    compare([NSString stringWithFormat:@"chain %ld>%ld>%ld", (long)a, (long)b, (long)c], ourIntent, systemIntent);
                }
            }
        }
        /* The table kinds, with a column count and the alignments that have to match it. */
        for (NSInteger columns = 0; columns < 4; columns++) {
            id ourTable = build(YES, 8, nil, 30, columns), systemTable = build(NO, 8, nil, 30, columns);
            compare([NSString stringWithFormat:@"table with %ld columns", (long)columns], ourTable, systemTable);
            for (NSInteger kind = 9; kind < 12; kind++) {
                id ourIntent = build(YES, kind, ourTable, 40 + kind, kind - 9);
                id systemIntent = build(NO, kind, systemTable, 40 + kind, kind - 9);
                compare([NSString stringWithFormat:@"table %ld columns, kind %ld", (long)columns, (long)kind], ourIntent, systemIntent);
            }
        }
        /* Runs of spans, where the level is above two. */
        for (NSInteger length = 1; length <= 6; length++) {
            id ourNode = nil, systemNode = nil;
            for (NSInteger step = 0; step < length; step++) {
                ourNode = build(YES, step % 2 ? 6 : 4, ourNode, 50 + step, 0);
                systemNode = build(NO, step % 2 ? 6 : 4, systemNode, 50 + step, 0);
            }
            compare([NSString stringWithFormat:@"a run of %ld spans", (long)length], ourNode, systemNode);
        }
        /* Identities out of the ordinary, kept as they are. */
        for (NSInteger identity = -3; identity < 3; identity++)
            compare([NSString stringWithFormat:@"identity %ld", (long)identity], build(YES, 4, nil, identity, 0), build(NO, 4, nil, identity, 0));

        /* The check the table factory makes, on both sides. */
        for (NSInteger columns = -1; columns < 3; columns++) {
            for (NSInteger given = 0; given < 3; given++) {
                NSMutableArray *alignments = [NSMutableArray array];
                for (NSInteger index = 0; index < given; index++)
                    [alignments addObject:@0];
                NSString *system = @"no raise", *ours = @"no raise";
                @try {
                    [NSPresentationIntent tableIntentWithIdentity:1 columnCount:columns alignments:alignments nestedInsideIntent:nil];
                } @catch (NSException *exception) {
                    system = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
                }
                @try {
                    ((id (*)(id, SEL, NSInteger, NSInteger, NSArray *, id))objc_msgSend)(
                        ourClass, NSSelectorFromString(@"tableIntentWithIdentity:columnCount:alignments:nestedInsideIntent:"),
                        (NSInteger)1, columns, alignments, nil);
                } @catch (NSException *exception) {
                    ours = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
                }
                charon_check([system isEqualToString:ours],
                              ([NSString stringWithFormat:@"table %ld columns and %ld alignments", (long)columns, (long)given]).UTF8String,
                              [NSString stringWithFormat:@"the system answers %@, the backport answers %@", system, ours]);
            }
        }

        /* Equality, and equivalence with the identity left out. Every pair is one case, held on
           both sides at once, and the port's two answers are compared with the system's two. */
        id ourParagraph = build(YES, 0, nil, 70, 0), systemParagraph = build(NO, 0, nil, 70, 0);
        id ourOtherParagraph = build(YES, 0, nil, 71, 0), systemOtherParagraph = build(NO, 0, nil, 71, 0);
        id ourQuote = build(YES, 6, nil, 72, 0), systemQuote = build(NO, 6, nil, 72, 0);
        id ourList = build(YES, 4, ourParagraph, 73, 1), systemList = build(NO, 4, systemParagraph, 73, 1);
        id ourSame = build(YES, 4, ourParagraph, 73, 1), systemSame = build(NO, 4, systemParagraph, 73, 1);
        id ourOtherIdentity = build(YES, 4, ourOtherParagraph, 74, 1), systemOtherIdentity = build(NO, 4, systemOtherParagraph, 74, 1);
        id ourUnderQuote = build(YES, 4, ourQuote, 73, 1), systemUnderQuote = build(NO, 4, systemQuote, 73, 1);
        id ourNoParent = build(YES, 4, nil, 73, 1), systemNoParent = build(NO, 4, nil, 73, 1);
        id ourOtherLevel = build(YES, 1, ourParagraph, 73, 2), systemOtherLevel = build(NO, 1, systemParagraph, 73, 2);
        id ourSameLevel = build(YES, 1, ourParagraph, 73, 1), systemSameLevel = build(NO, 1, systemParagraph, 73, 1);
        struct { const char *label; id ours, others, systems, othersSystems; } pairs[] = {
            {"equal parents, same identity", ourList, ourSame, systemList, systemSame},
            {"equal parents, other identity", ourList, ourOtherIdentity, systemList, systemOtherIdentity},
            {"other parent kind", ourList, ourUnderQuote, systemList, systemUnderQuote},
            {"no parent", ourList, ourNoParent, systemList, systemNoParent},
            {"other level", ourSameLevel, ourOtherLevel, systemSameLevel, systemOtherLevel},
            {"itself", ourList, ourList, systemList, systemList},
            {"a table and a row", build(YES, 8, nil, 80, 3), build(YES, 10, nil, 80, 0), build(NO, 8, nil, 80, 3), build(NO, 10, nil, 80, 0)},
            {"two equal tables", build(YES, 8, nil, 80, 3), build(YES, 8, nil, 81, 3), build(NO, 8, nil, 80, 3), build(NO, 8, nil, 81, 3)},
            {"two tables that differ", build(YES, 8, nil, 80, 3), build(YES, 8, nil, 80, 2), build(NO, 8, nil, 80, 3), build(NO, 8, nil, 80, 2)},
        };
        for (NSUInteger index = 0; index < sizeof(pairs) / sizeof(pairs[0]); index++) {
            id ourLeft = pairs[index].ours, ourRight = pairs[index].others;
            id systemLeft = pairs[index].systems, systemRight = pairs[index].othersSystems;
            BOOL systemEqual = [systemLeft isEqual:systemRight];
            BOOL systemEquivalent = [systemLeft isEquivalentToPresentationIntent:systemRight];
            charon_check(systemEqual == ((BOOL (*)(id, SEL, id))objc_msgSend)(ourLeft, @selector(isEqual:), ourRight),
                          [[NSString stringWithFormat:@"isEqual: %s", pairs[index].label] UTF8String],
                          [NSString stringWithFormat:@"the system answers %d, the backport answers %d", systemEqual,
                           ((BOOL (*)(id, SEL, id))objc_msgSend)(ourLeft, @selector(isEqual:), ourRight)]);
            charon_check(systemEquivalent == ((BOOL (*)(id, SEL, id))objc_msgSend)(ourLeft, @selector(isEquivalentToPresentationIntent:), ourRight),
                          [[NSString stringWithFormat:@"isEquivalentToPresentationIntent: %s", pairs[index].label] UTF8String],
                          [NSString stringWithFormat:@"the system answers %d, the backport answers %d", systemEquivalent,
                           ((BOOL (*)(id, SEL, id))objc_msgSend)(ourLeft, @selector(isEquivalentToPresentationIntent:), ourRight)]);
            if (systemEqual && [ourLeft isEqual:ourRight]) {
                /* -hash owes one thing and one thing only: two equal intents hash equal, which is
                   what a set or a dictionary of intents needs. The number itself is the host's own
                   mixing of private fields, which no API fixes, so the two numbers are printed
                   rather than held equal -- facts/Foundation/NSPresentationIntent.md says so. */
                NSUInteger systemHash = ((NSUInteger (*)(id, SEL))objc_msgSend)(systemLeft, @selector(hash));
                NSUInteger ourHash = ((NSUInteger (*)(id, SEL))objc_msgSend)(ourLeft, @selector(hash));
                NSUInteger ourOtherHash = ((NSUInteger (*)(id, SEL))objc_msgSend)(ourRight, @selector(hash));
                charon_check(ourHash == ourOtherHash,
                             [[NSString stringWithFormat:@"equal intents hash alike: %s", pairs[index].label] UTF8String],
                             [NSString stringWithFormat:@"the backport answers %lu and %lu for two equal intents",
                              (unsigned long)ourHash, (unsigned long)ourOtherHash]);
                printf("ok   the hash itself, %s: the system %lu, the backport %lu\n", pairs[index].label,
                       (unsigned long)systemHash, (unsigned long)ourHash);
            }
        }
        charon_check([systemList isEquivalentToPresentationIntent:nil] ==
                         ((BOOL (*)(id, SEL, id))objc_msgSend)(ourList, @selector(isEquivalentToPresentationIntent:), nil),
                     "isEquivalentToPresentationIntent: nil", @"the two answers differ");
        charon_check(![[NSObject class] isKindOfClass:[systemList class]], "the system's class is its own",
                     @"the system's class is not what the test thinks it is");

        /* The archive: the keys, then the round trip through the backport's own coder. */
        id ourTable = build(YES, 8, build(YES, 0, nil, 90, 0), 91, 3);
        id systemTable = build(NO, 8, build(NO, 0, nil, 90, 0), 91, 3);
        NSArray *systemKeys = keysInArchive(systemTable);
        NSArray *ourKeys = keysInArchive(ourTable);
        charon_check([systemKeys isEqualToArray:ourKeys], "the archive's keys",
                     [NSString stringWithFormat:@"the system writes %@, the backport writes %@", systemKeys, ourKeys]);

        /* And a round trip: the port's own archive, read back by the port's own decoder. */
        id read = nil;
        @try {
            NSError *readError = nil;
            NSData *data = [NSKeyedArchiver archivedDataWithRootObject:ourTable requiringSecureCoding:YES error:&readError];
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&readError];
            unarchiver.requiresSecureCoding = YES;
            read = [unarchiver decodeObjectOfClass:ourClass forKey:NSKeyedArchiveRootObjectKey];
            [unarchiver finishDecoding];
        } @catch (NSException *exception) {
            read = nil;
            printf("FAIL the round trip raises %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }
        charon_check(read && [answer(read) isEqualToString:answer(ourTable)] && [read isKindOfClass:ourClass],
                     "the round trip",
                     [NSString stringWithFormat:@"the intent in is %@, the intent out is %@", answer(ourTable), answer(read)]);

        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        fflush(stdout);
    }
    return charon_failures;
}

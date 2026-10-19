#import <Foundation/Foundation.h>
#import <objc/message.h>
#import "check.h"

extern NSString *const RevenantHostNSMarkdownSourcePositionAttributeName;

static NSString *answer(id position)
{
    if (!position)
        return @"nil";
    return [NSString stringWithFormat:@"%ld/%ld..%ld/%ld", (long)[position startLine], (long)[position startColumn],
                                      (long)[position endLine], (long)[position endColumn]];
}

static id makeIn(Class kind, NSInteger sl, NSInteger sc, NSInteger el, NSInteger ec)
{
    SEL selector = @selector(initWithStartLine:startColumn:endLine:endColumn:);
    id target = [kind alloc];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[kind instanceMethodSignatureForSelector:selector]];
    invocation.selector = selector;
    invocation.target = target;
    NSInteger numbers[4] = {sl, sc, el, ec};
    for (NSUInteger index = 0; index < 4; index++)
        [invocation setArgument:&numbers[index] atIndex:index + 2];
    [invocation invoke];
    id __unsafe_unretained read = nil;
    [invocation getReturnValue:&read];
    return read;
}

static NSArray *keysInArchive(id position)
{
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:position requiringSecureCoding:YES error:&error];
    if (!data)
        return @[([NSString stringWithFormat:@"raises %@: %@", error.domain, error.localizedDescription])];
    id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:&error];
    NSMutableArray *found = [NSMutableArray array];
    for (id entry in plist[@"$objects"])
        if ([entry isKindOfClass:[NSDictionary class]] && ![(NSDictionary *)entry objectForKey:@"$classname"])
            for (NSString *key in [[(NSDictionary *)entry allKeys] sortedArrayUsingSelector:@selector(compare:)])
                if (![key hasPrefix:@"$"])
                    [found addObject:[NSString stringWithFormat:@"%@=%@", key, [(NSDictionary *)entry[key] description]]];
    return [found sortedArrayUsingSelector:@selector(compare:)];
}

static NSData *archiveRenamed(NSData *archive, NSString *from, NSString *to)
{
    NSError *error = nil;
    id plist = [NSPropertyListSerialization propertyListWithData:archive options:NSPropertyListMutableContainers format:NULL error:&error];
    if (!plist)
        return nil;
    NSMutableArray *objects = [plist[@"$objects"] mutableCopy];
    NSMutableArray *classes = [plist[@"$classes"] mutableCopy];
    for (NSUInteger index = 0; index < objects.count; index++) {
        id entry = objects[index];
        if ([entry isKindOfClass:[NSString class]] && [entry isEqualToString:from])
            objects[index] = to;
        else if ([entry isKindOfClass:[NSDictionary class]] &&
                 [[(NSDictionary *)entry objectForKey:@"$classname"] isEqualToString:from])
            [(NSMutableDictionary *)entry setObject:to forKey:@"$classname"];
    }
    for (NSUInteger index = 0; index < classes.count; index++)
        if ([classes[index] isEqualToString:from])
            classes[index] = to;
    NSMutableDictionary *root = [plist mutableCopy];
    root[@"$objects"] = objects;
    root[@"$classes"] = classes;
    return [NSPropertyListSerialization dataWithPropertyList:root format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
}

static NSString *selected(NSString *document, NSRange range)
{
    if (range.location == NSNotFound || NSMaxRange(range) > document.length)
        return nil;
    return [document substringWithRange:range];
}

static NSArray *documents(void)
{
    return @[@"plain text",
             @"one\ntwo",
             @"A paragraph\nand a *list*\n- one\n- two\n",
             @"# A heading\n\nwith *emphasis* and **strong** text\n",
             @"    indented code\n    second line\n",
             @"    indented code\r\n    second line\r\n",
             @"a \xc3\xa9\xc3\xa9 two-byte run here\n",
             @"a\ttab and a \xf0\x9f\x98\x80 four-byte face\n",
             @"\xf0\x9f\x98\x80 a face alone\n",
             @"and a face at the end \xf0\x9f\x98\x80\n",
             @"trailing blank line\n\n",
             @"- outer\n  - inner\n    - deepest\n",
             @"| a | b |\n| - | - |\n| 1 | 2 |\n",
             @"```\ncode fence\n```\n"];
}

int main(void)
{
    @autoreleasepool {
        Class system = NSClassFromString(@"NSAttributedStringMarkdownSourcePosition");
        Class ours = NSClassFromString(@"RevenantHostNSAttributedStringMarkdownSourcePosition");
        CHECK(system != Nil, "the system has NSAttributedStringMarkdownSourcePosition");
        CHECK(ours != Nil, "the port defines NSAttributedStringMarkdownSourcePosition under its own name");

        CHECK_EQUAL(NSMarkdownSourcePositionAttributeName, @"NSMarkdownSourcePosition",
                    "the system's attribute key is NSMarkdownSourcePosition");
        CHECK_EQUAL(RevenantHostNSMarkdownSourcePositionAttributeName, NSMarkdownSourcePositionAttributeName,
                    "the backport's attribute key is the system's own string");

        const NSInteger cases[][4] = {
            {0, 0, 0, 0}, {1, 1, 1, 1}, {2, 3, 4, 5}, {1, 1, 2, 2}, {-1, -1, -1, -1},
            {-2, 0, 7, -3}, {1000000, 1000000, 1000000, 1000000}, {1, 2, 1, 1}, {5, 5, 5, 4},
        };
        for (unsigned index = 0; index < sizeof cases / sizeof cases[0]; index++) {
            id ourPosition = makeIn(ours, cases[index][0], cases[index][1], cases[index][2], cases[index][3]);
            id systemPosition = makeIn(system, cases[index][0], cases[index][1], cases[index][2], cases[index][3]);
            revenant_check([answer(ourPosition) isEqualToString:answer(systemPosition)],
                         [[NSString stringWithFormat:@"the four numbers, %@", answer(systemPosition)] UTF8String],
                         [NSString stringWithFormat:@"the system answers %@, the backport answers %@",
                          answer(systemPosition), answer(ourPosition)]);
        }

        id ourEmpty = [[ours alloc] init], systemEmpty = [[system alloc] init];
        revenant_check([answer(ourEmpty) isEqualToString:answer(systemEmpty)],
                     [[NSString stringWithFormat:@"-init gives four zeroes, %@", answer(systemEmpty)] UTF8String],
                     [NSString stringWithFormat:@"the system answers %@, the backport answers %@",
                      answer(systemEmpty), answer(ourEmpty)]);

        id ourPosition = makeIn(ours, 2, 3, 4, 5), systemPosition = makeIn(system, 2, 3, 4, 5);
        CHECK([systemPosition conformsToProtocol:@protocol(NSCopying)] && [ours conformsToProtocol:@protocol(NSCopying)],
              "both sides answer NSCopying");
        id ourCopy = [ourPosition copy], systemCopy = [systemPosition copy];
        revenant_check([answer(ourCopy) isEqualToString:answer(systemCopy)],
                     [[NSString stringWithFormat:@"the copy carries the four numbers, %@", answer(systemCopy)] UTF8String],
                     [NSString stringWithFormat:@"the system answers %@, the backport answers %@",
                      answer(systemCopy), answer(ourCopy)]);
        CHECK([ourCopy isKindOfClass:ours] && [systemCopy isKindOfClass:system],
              "a copy is of the class that made it, on both sides");
        CHECK([ourPosition isEqual:ourCopy] && [systemPosition isEqual:systemCopy],
              "a position equals its copy on both sides");
        id ourOther = makeIn(ours, 2, 3, 4, 6), systemOther = makeIn(system, 2, 3, 4, 6);
        CHECK(![ourPosition isEqual:ourOther] && ![systemPosition isEqual:systemOther],
              "a position that differs in one number is not equal, on both sides");
        CHECK(![ourPosition isEqual:@"a string"] && ![systemPosition isEqual:@"a string"] &&
                  ![ourPosition isEqual:nil] && ![systemPosition isEqual:nil],
              "a position is not equal to another class's object or to nil, on both sides");
        CHECK([ourPosition hash] == [ourCopy hash] && [systemPosition hash] == [systemCopy hash],
              "equal positions hash alike on both sides");
        printf("ok   the hash itself: the system %lu, the backport %lu\n", (unsigned long)[systemPosition hash],
               (unsigned long)[ourPosition hash]);

        NSString *ourText = [ourPosition description], *systemText = [systemPosition description];
        CHECK([ourText hasSuffix:@"{startLine=2, startColumn=3, endLine=4, endColumn=5}"] &&
                  [systemText hasSuffix:@"{startLine=2, startColumn=3, endLine=4, endColumn=5}"],
              "the description carries the four numbers, on both sides");
        CHECK([ourText rangeOfString:NSStringFromClass(ours)].location != NSNotFound &&
                  [systemText rangeOfString:NSStringFromClass(system)].location != NSNotFound,
              "the description names the class that made it, on both sides");
        id ourNegative = makeIn(ours, -2, -2, -2, -2), systemNegative = makeIn(system, -2, -2, -2, -2);
        NSString *unsignedTail = @"{startLine=18446744073709551614, startColumn=18446744073709551614, endLine=18446744073709551614, endColumn=18446744073709551614}";
        CHECK([[ourNegative description] hasSuffix:unsignedTail] && [[systemNegative description] hasSuffix:unsignedTail],
              "a negative number goes out unsigned on both sides");

        BOOL (*supportsSecureCoding)(Class, SEL) = (BOOL (*)(Class, SEL))objc_msgSend;
        CHECK(supportsSecureCoding(system, @selector(supportsSecureCoding)) &&
                  supportsSecureCoding(ours, @selector(supportsSecureCoding)),
              "both sides answer +supportsSecureCoding YES");

        NSArray *systemKeys = keysInArchive(systemPosition);
        NSArray *ourKeys = keysInArchive(ourPosition);
        revenant_check([systemKeys isEqualToArray:ourKeys], "the archive's keys and their values",
                      [NSString stringWithFormat:@"the system writes %@, the backport writes %@", systemKeys, ourKeys]);

        NSError *error = nil;
        NSData *systemArchive = [NSKeyedArchiver archivedDataWithRootObject:systemPosition requiringSecureCoding:YES error:&error];
        NSData *ourArchive = [NSKeyedArchiver archivedDataWithRootObject:ourPosition requiringSecureCoding:YES error:&error];
        id readOurOwn = nil, readSystemBySystem = nil;
        @try {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:ourArchive error:&error];
            unarchiver.requiresSecureCoding = YES;
            readOurOwn = [unarchiver decodeObjectOfClass:ours forKey:NSKeyedArchiveRootObjectKey];
            [unarchiver finishDecoding];
            unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:systemArchive error:&error];
            unarchiver.requiresSecureCoding = YES;
            readSystemBySystem = [unarchiver decodeObjectOfClass:system forKey:NSKeyedArchiveRootObjectKey];
            [unarchiver finishDecoding];
        } @catch (NSException *exception) {
            readOurOwn = readSystemBySystem = nil;
            printf("FAIL an archive raises %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }
        revenant_check(readOurOwn && [answer(readOurOwn) isEqualToString:answer(ourPosition)],
                     "the backport's own archive reads back",
                     [NSString stringWithFormat:@"the position in is %@, the position out is %@", answer(ourPosition), answer(readOurOwn)]);
        revenant_check(readSystemBySystem && [answer(readSystemBySystem) isEqualToString:answer(systemPosition)],
                     "the system's archive reads back into the system's class",
                     [NSString stringWithFormat:@"the position in is %@, the position out is %@", answer(systemPosition), answer(readSystemBySystem)]);

        NSData *systemArchiveAsOurs = archiveRenamed(systemArchive, NSStringFromClass(system), NSStringFromClass(ours));
        NSData *ourArchiveAsSystem = archiveRenamed(ourArchive, NSStringFromClass(ours), NSStringFromClass(system));
        id readSystemByOurs = nil, readOursBySystem = nil;
        @try {
            NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:systemArchiveAsOurs error:&error];
            unarchiver.requiresSecureCoding = YES;
            readSystemByOurs = [unarchiver decodeObjectOfClass:ours forKey:NSKeyedArchiveRootObjectKey];
            [unarchiver finishDecoding];
            unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:ourArchiveAsSystem error:&error];
            unarchiver.requiresSecureCoding = YES;
            readOursBySystem = [unarchiver decodeObjectOfClass:system forKey:NSKeyedArchiveRootObjectKey];
            [unarchiver finishDecoding];
        } @catch (NSException *exception) {
            readSystemByOurs = readOursBySystem = nil;
            printf("FAIL an archive read across raises %s: %s\n", exception.name.UTF8String, exception.reason.UTF8String);
        }
        revenant_check(readSystemByOurs && [answer(readSystemByOurs) isEqualToString:answer(systemPosition)],
                     "the system's archive reads back into the backport's class",
                     [NSString stringWithFormat:@"the position in is %@, the position out is %@", answer(systemPosition), answer(readSystemByOurs)]);
        revenant_check(readOursBySystem && [answer(readOursBySystem) isEqualToString:answer(ourPosition)],
                     "the backport's archive reads back into the system's class",
                     [NSString stringWithFormat:@"the position in is %@, the position out is %@", answer(ourPosition), answer(readOursBySystem)]);

        __block NSUInteger marked = 0, agreed = 0, differed = 0, outside = 0, portSelects = 0, systemSelects = 0;
        for (NSString *document in documents()) {
            NSAttributedStringMarkdownParsingOptions *options = [[NSAttributedStringMarkdownParsingOptions alloc] init];
            options.appliesSourcePositionAttributes = YES;
            NSError *parseError = nil;
            NSAttributedString *parsed = [[NSAttributedString alloc] initWithMarkdownString:document
                                                                                     options:options
                                                                                     baseURL:nil
                                                                                       error:&parseError];
            revenant_check(parsed != nil, "the system's own parser reads a document of the corpus",
                         [NSString stringWithFormat:@"the parser answers %@", parseError]);
            if (!parsed)
                continue;
            [parsed enumerateAttribute:NSMarkdownSourcePositionAttributeName
                             inRange:NSMakeRange(0, parsed.length)
                             options:0
                          usingBlock:^(id value, NSRange run, BOOL *stop) {
                if (!value)
                    return;
                marked++;
                id portCopy = makeIn(ours, [value startLine], [value startColumn], [value endLine], [value endColumn]);
                NSRange systemRange = NSMakeRange(NSNotFound, NSNotFound), portRange = NSMakeRange(NSNotFound, NSNotFound);
                @try {
                    systemRange = [value rangeInString:document];
                } @catch (NSException *exception) {
                }
                @try {
                    portRange = [portCopy rangeInString:document];
                } @catch (NSException *exception) {
                    printf("FAIL the backport's -rangeInString: raises %s: %s\n", exception.name.UTF8String,
                           exception.reason.UTF8String);
                }
                NSString *runText = [parsed.string substringWithRange:run];
                if ([selected(document, systemRange) isEqualToString:runText])
                    systemSelects++;
                if ([selected(document, portRange) isEqualToString:runText])
                    portSelects++;
                if (portRange.location != NSNotFound && NSMaxRange(portRange) > document.length)
                    outside++;
                if (systemRange.location == portRange.location && systemRange.length == portRange.length) {
                    agreed++;
                } else {
                    differed++;
                    printf("ok   a range the two answer differently, %s: the system {%lu,%lu} %s, the backport "
                           "{%lu,%lu} %s, the run %s\n",
                           [answer(value) UTF8String], (unsigned long)systemRange.location, (unsigned long)systemRange.length,
                           [selected(document, systemRange) UTF8String], (unsigned long)portRange.location,
                           (unsigned long)portRange.length, [selected(document, portRange) UTF8String], [runText UTF8String]);
                }
            }];
        }
        revenant_check(outside == 0, "the backport's range is inside the document it was handed",
                     [NSString stringWithFormat:@"%lu of %lu answers point outside it", (unsigned long)outside, (unsigned long)marked]);
        revenant_check(agreed + differed == 29 && agreed == 28 && differed == 1,
                     [[NSString stringWithFormat:@"the two answer the same range on 28 of the %lu marked positions", (unsigned long)marked] UTF8String],
                     [NSString stringWithFormat:@"they agree on %lu and differ on %lu", (unsigned long)agreed, (unsigned long)differed]);
        printf("ok   the range over the parser's own positions: %lu marked, the two agree on %lu and differ on %lu; "
               "the backport selects the run in %lu of %lu, the system in %lu\n",
               (unsigned long)marked, (unsigned long)agreed, (unsigned long)differed, (unsigned long)portSelects,
               (unsigned long)marked, (unsigned long)systemSelects);

        const NSInteger beyond[][4] = {
            {3, 1, 3, 1}, {1, 9, 1, 9}, {1, 0, 1, 0}, {0, 1, 0, 1}, {-1, -1, -1, -1}, {2, 2, 1, 1},
        };
        NSArray *beyondDocuments = @[@"ab\ncd\n", @"\xc3\xa9\n"];
        NSUInteger refused = 0, asked = 0;
        for (NSString *document in beyondDocuments)
            for (unsigned index = 0; index < sizeof beyond / sizeof beyond[0]; index++) {
                asked++;
                id portCopy = makeIn(ours, beyond[index][0], beyond[index][1], beyond[index][2], beyond[index][3]);
                NSRange portRange = NSMakeRange(NSNotFound, NSNotFound);
                @try {
                    portRange = [portCopy rangeInString:document];
                } @catch (NSException *exception) {
                    printf("FAIL the backport's -rangeInString: raises %s: %s\n", exception.name.UTF8String,
                           exception.reason.UTF8String);
                }
                if (portRange.location == NSNotFound)
                    refused++;
                else
                    printf("ok   a position the document does not reach, %ld/%ld..%ld/%ld of %s: the backport "
                           "answers {%lu,%lu}\n",
                           (long)beyond[index][0], (long)beyond[index][1], (long)beyond[index][2], (long)beyond[index][3],
                           [document UTF8String], (unsigned long)portRange.location, (unsigned long)portRange.length);
                id systemCopy = makeIn(system, beyond[index][0], beyond[index][1], beyond[index][2], beyond[index][3]);
                NSRange systemRange = NSMakeRange(NSNotFound, NSNotFound);
                @try {
                    systemRange = [systemCopy rangeInString:document];
                } @catch (NSException *exception) {
                }
                printf("ok   the system answers the same position {%lu,%lu}\n", (unsigned long)systemRange.location,
                       (unsigned long)systemRange.length);
            }
        revenant_check(refused == asked, "a position the document does not reach has no range",
                     [NSString stringWithFormat:@"%lu of %lu are answered with a range", (unsigned long)(asked - refused),
                      (unsigned long)asked]);

        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        fflush(stdout);
    }
    return revenant_failures;
}

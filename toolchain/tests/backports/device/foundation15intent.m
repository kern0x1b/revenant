#import <Foundation/Foundation.h>
#import <objc/message.h>
#include <dlfcn.h>
#import "check.h"

static void one_intent_class(void)
{
    Class kind = NSClassFromString(@"NSPresentationIntent");
    CHECK(kind != Nil, "NSPresentationIntent is there");
    if (!kind)
        return;

    id paragraph = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)(kind, @selector(paragraphIntentWithIdentity:nestedInsideIntent:), (NSInteger)1, nil);
    id list = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)(kind, @selector(orderedListIntentWithIdentity:nestedInsideIntent:), (NSInteger)2, paragraph);
    id item = ((id (*)(id, SEL, NSInteger, NSInteger, id))objc_msgSend)(kind, @selector(listItemIntentWithIdentity:ordinal:nestedInsideIntent:), (NSInteger)3, (NSInteger)1, list);
    id quote = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)(kind, @selector(blockQuoteIntentWithIdentity:nestedInsideIntent:), (NSInteger)4, item);
    id header = ((id (*)(id, SEL, NSInteger, NSInteger, id))objc_msgSend)(kind, @selector(headerIntentWithIdentity:level:nestedInsideIntent:), (NSInteger)5, (NSInteger)2, paragraph);
    id code = ((id (*)(id, SEL, NSInteger, id, id))objc_msgSend)(kind, @selector(codeBlockIntentWithIdentity:languageHint:nestedInsideIntent:), (NSInteger)6, @"c", paragraph);
    id unordered = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)(kind, @selector(unorderedListIntentWithIdentity:nestedInsideIntent:), (NSInteger)7, paragraph);
    id break_ = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)(kind, @selector(thematicBreakIntentWithIdentity:nestedInsideIntent:), (NSInteger)8, nil);
    id table = ((id (*)(id, SEL, NSInteger, NSInteger, NSArray *, id))objc_msgSend)(kind, @selector(tableIntentWithIdentity:columnCount:alignments:nestedInsideIntent:),
                     (NSInteger)9, (NSInteger)2, @[@0, @2], paragraph);
    id headerRow = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)(kind, @selector(tableHeaderRowIntentWithIdentity:nestedInsideIntent:), (NSInteger)10, table);
    id row = ((id (*)(id, SEL, NSInteger, NSInteger, id))objc_msgSend)(kind, @selector(tableRowIntentWithIdentity:row:nestedInsideIntent:), (NSInteger)11, (NSInteger)1, table);
    id cell = ((id (*)(id, SEL, NSInteger, NSInteger, id))objc_msgSend)(kind, @selector(tableCellIntentWithIdentity:column:nestedInsideIntent:), (NSInteger)12, (NSInteger)1, row);
    id nestedItem = ((id (*)(id, SEL, NSInteger, NSInteger, id))objc_msgSend)(kind, @selector(listItemIntentWithIdentity:ordinal:nestedInsideIntent:), (NSInteger)13, (NSInteger)0, unordered);

    NSArray *intents = @[paragraph, list, item, quote, header, code, unordered, break_, table, headerRow, row, cell, nestedItem];
    CHECK(intents.count == 13, "the twelve factories and a thirteenth intent are made");

    NSArray *numbers = @[@"intentKind", @"identity", @"ordinal", @"columnCount", @"headerLevel", @"column", @"row", @"indentationLevel"];
    for (id intent in intents) {
        for (NSString *name in numbers) {
            NSMethodSignature *signature = [intent methodSignatureForSelector:NSSelectorFromString(name)];
            CHECK(signature != nil, ([[NSString stringWithFormat:@"%@ answers %@", intent.class, name] UTF8String]));
            if (!signature)
                continue;
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
            invocation.selector = NSSelectorFromString(name);
            [invocation invokeWithTarget:intent];
            NSInteger value = 0;
            [invocation getReturnValue:&value];
            CHECK(YES, ([[NSString stringWithFormat:@"%@ %@ is %ld", intent.class, name, (long)value] UTF8String]));
        }
        for (NSString *name in @[@"columnAlignments", @"languageHint", @"parentIntent"]) {
            id value = ((id (*)(id, SEL))objc_msgSend)(intent, NSSelectorFromString(name));
            CHECK(YES, ([[NSString stringWithFormat:@"%@ %@ is %@", intent.class, name, value ?: @"(nil)"] UTF8String]));
        }
    }

    CHECK([paragraph valueForKey:@"indentationLevel"] && [[paragraph valueForKey:@"indentationLevel"] integerValue] == 0,
          "a paragraph with no parent has no indentation");
    CHECK([[list valueForKey:@"indentationLevel"] integerValue] == 0, "a list under a paragraph has none either");
    CHECK([[item valueForKey:@"indentationLevel"] integerValue] == 1, "an item inside the list has one level");
    CHECK([[quote valueForKey:@"indentationLevel"] integerValue] == 2, "a block quote inside the item has two");
    CHECK([[header valueForKey:@"indentationLevel"] integerValue] == 0, "a header under a paragraph has none");
    CHECK([[item valueForKey:@"ordinal"] integerValue] == 1, "an item keeps the ordinal it was given");
    CHECK([[header valueForKey:@"headerLevel"] integerValue] == 2, "a header keeps its level");
    CHECK_EQUAL([code valueForKey:@"languageHint"], @"c", "a code block keeps the language it was given");
    CHECK([[table valueForKey:@"columnCount"] integerValue] == 2, "a table keeps its column count");
    CHECK_EQUAL([table valueForKey:@"columnAlignments"], (@[@0, @2]), "a table keeps the alignments it was given");
    CHECK([[row valueForKey:@"row"] integerValue] == 1 && [[cell valueForKey:@"column"] integerValue] == 1,
          "a row and a cell keep where they are");
    CHECK([table valueForKey:@"parentIntent"] == paragraph && [cell valueForKey:@"parentIntent"] == row,
          "an intent keeps the parent it was nested inside");

    @try {
        ((id (*)(id, SEL, NSInteger, NSInteger, NSArray *, id))objc_msgSend)(kind, @selector(tableIntentWithIdentity:columnCount:alignments:nestedInsideIntent:),
                     (NSInteger)14, (NSInteger)3, @[@0, @2], nil);
        CHECK(NO, "a table whose column count does not match its alignments raises");
    } @catch (NSException *exception) {
        CHECK([exception.name isEqualToString:NSInvalidArgumentException] &&
              [exception.reason rangeOfString:@"column count does not match count of alignments"].location != NSNotFound,
              "a table whose column count does not match its alignments raises as the host does");
    }

    id same = ((id (*)(id, SEL, NSInteger, id))objc_msgSend)(kind, @selector(listItemIntentWithIdentity:ordinal:nestedInsideIntent:), (NSInteger)3, (NSInteger)1, list);
    id other = ((id (*)(id, SEL, NSInteger, NSInteger, id))objc_msgSend)(kind, @selector(listItemIntentWithIdentity:ordinal:nestedInsideIntent:), (NSInteger)99, (NSInteger)1, list);
    CHECK([item isEqual:same], "two items with the same identity under the same parent are equal");
    CHECK(![item isEqual:other], "and one with another identity is not");
    CHECK([item isEquivalentToPresentationIntent:other], "but they are equivalent, which leaves the identity out");
    CHECK([[item copy] isEqual:item], "a copy is equal to the intent it was made from");
    CHECK([kind instancesRespondToSelector:@selector(isEquivalentToPresentationIntent:)], "isEquivalentToPresentationIntent: is there");
    CHECK(![kind instancesRespondToSelector:@selector(init)], "-init stays unavailable, as the SDK's header says");
    CHECK(![kind respondsToSelector:@selector(new)], "+new stays unavailable too");

    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:table requiringSecureCoding:YES error:&error];
    CHECK(data.length > 0, "a table intent is archived");
    if (data.length) {
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:&error];
        unarchiver.requiresSecureCoding = YES;
        id read = [unarchiver decodeObjectOfClass:kind forKey:NSKeyedArchiveRootObjectKey];
        [unarchiver finishDecoding];
        CHECK([read isKindOfClass:kind] && [read isEqual:table], "and reads back equal to the intent that went in");
        CHECK([[read valueForKey:@"parentIntent"] isKindOfClass:kind], "with the tree it was nested in");
    }
}

static void key_values(void)
{
    NSDictionary *expected = @{
        @"NSPresentationIntentAttributeName": @"NSPresentationIntent",
        @"NSReplacementIndexAttributeName": @"NSReplacementIndex",
        @"NSUserDefaultsSizeLimitExceededNotification": @"com.apple.CFPreferences.byteCountLimitReached",
        @"NSStreamNetworkServiceTypeCallSignaling": @"kCFStreamNetworkServiceTypeCallSignaling",
        @"NSURLIsApplicationKey": @"_NSURLIsApplicationKey",
        @"NSURLFileProtectionKey": @"NSURLFileProtectionKey",
        @"NSURLFileProtectionNone": @"NSURLFileProtectionNone",
        @"NSURLFileProtectionComplete": @"NSURLFileProtectionComplete",
        @"NSURLVolumeIsEncryptedKey": @"NSURLVolumeIsEncryptedKey",
        @"NSURLVolumeSupportsFileCloningKey": @"NSURLVolumeSupportsFileCloningKey",
        @"NSURLCanonicalPathKey": @"NSURLCanonicalPathKey",
        @"NSUbiquitousUserDefaultsNoCloudAccountNotification": @"NSUbiquitousUserDefaultsNoCloudAccountNotification",
        @"NSURLUbiquitousSharedItemRoleOwner": @"NSURLUbiquitousSharedItemRoleOwner",
        @"NSURLCredentialStorageRemoveSynchronizableCredentials": @"NSURLCredentialStorageRemoveSynchronizableCredentials",
        @"NSThumbnail1024x1024SizeKey": @"NSThumbnail1024x1024SizeKey",
        @"NSProgressFileOperationKindDuplicating": @"NSProgressFileOperationKindDuplicating",
    };
    for (NSString *name in expected) {
        void *symbol = dlsym(RTLD_DEFAULT, ("_" + name).UTF8String);
        if (!symbol) {
            printf("note %s is not in this band: the release exports it\n", name.UTF8String);
            continue;
        }
        id value = (__bridge id)(*(void **)symbol);
        CHECK_EQUAL(value, expected[name], name.UTF8String);
    }
    NSURL *file = [NSURL fileURLWithPath:NSTemporaryDirectory()];
    id protection = nil;
    CHECK([file getResourceValue:&protection forKey:NSURLFileProtectionKey error:NULL] || protection == nil,
          "the file protection key answers for a directory, or says it has none");
}

int main(int argc, char **argv)
{
    @autoreleasepool {
        if (argc > 1)
            revenant_log_to(@(argv[1]));
        one_intent_class();
        key_values();
        printf("checks=%d failures=%d\n", revenant_checks, revenant_failures);
        return revenant_failures;
    }
}

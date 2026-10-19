#import "CharonContacts.h"

#define CharonHistoryMaxGenerations 24

@implementation CharonContactsHistory

+ (NSString *)directory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *base = paths.firstObject ?: NSTemporaryDirectory();
    NSString *directory = [base stringByAppendingPathComponent:@"CharonContacts/History"];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    return directory;
}

+ (NSString *)pathForGeneration:(NSString *)generation
{
    return [[[self directory] stringByAppendingPathComponent:generation] stringByAppendingPathExtension:@"plist"];
}

+ (NSString *)identifierOfRecord:(ABRecordRef)record
{
    return [NSString stringWithFormat:@"%d", (int)ABRecordGetRecordID(record)];
}

+ (NSDictionary *)snapshotFromBook:(ABAddressBookRef)book
{
    NSMutableDictionary *contacts = [NSMutableDictionary dictionary];
    CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(book);
    for (CFIndex index = 0; people && index < CFArrayGetCount(people); index++) {
        ABRecordRef person = (ABRecordRef)CFArrayGetValueAtIndex(people, index);
        CFTypeRef modifiedRef = ABRecordCopyValue(person, kABPersonModificationDateProperty);
        NSDate *modified = modifiedRef ? (__bridge_transfer NSDate *)modifiedRef : nil;
        contacts[[self identifierOfRecord:person]] = @(modified.timeIntervalSinceReferenceDate);
    }
    if (people)
        CFRelease(people);

    NSMutableDictionary *groups = [NSMutableDictionary dictionary];
    CFArrayRef groupRecords = ABAddressBookCopyArrayOfAllGroups(book);
    for (CFIndex index = 0; groupRecords && index < CFArrayGetCount(groupRecords); index++) {
        ABRecordRef group = (ABRecordRef)CFArrayGetValueAtIndex(groupRecords, index);
        groups[[self identifierOfRecord:group]] = [self memberInfoForGroup:group];
    }
    if (groupRecords)
        CFRelease(groupRecords);

    return @{@"contacts": contacts, @"groups": groups};
}

+ (NSDictionary *)memberInfoForGroup:(ABRecordRef)group
{
    CFTypeRef nameRef = ABRecordCopyValue(group, kABGroupNameProperty);
    NSString *name = nameRef ? (__bridge_transfer NSString *)nameRef : @"";
    NSMutableArray *members = [NSMutableArray array];
    CFArrayRef people = ABGroupCopyArrayOfAllMembers(group);
    for (CFIndex index = 0; people && index < CFArrayGetCount(people); index++)
        [members addObject:[self identifierOfRecord:(ABRecordRef)CFArrayGetValueAtIndex(people, index)]];
    if (people)
        CFRelease(people);
    [members sortUsingSelector:@selector(compare:)];
    return @{@"name": name, @"members": members};
}

+ (NSString *)writeGeneration:(NSDictionary *)snapshot
{
    NSString *generation = [[NSUUID UUID] UUIDString];
    [snapshot writeToFile:[self pathForGeneration:generation] atomically:YES];
    [self pruneGenerations];
    return generation;
}

+ (void)pruneGenerations
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *directory = [self directory];
    NSArray *names = [manager contentsOfDirectoryAtPath:directory error:NULL];
    if (names.count <= CharonHistoryMaxGenerations)
        return;
    NSArray *sorted = [names sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSDate *dateA = [manager attributesOfItemAtPath:[directory stringByAppendingPathComponent:a] error:NULL][NSFileModificationDate];
        NSDate *dateB = [manager attributesOfItemAtPath:[directory stringByAppendingPathComponent:b] error:NULL][NSFileModificationDate];
        return [dateA compare:dateB];
    }];
    NSInteger overflow = (NSInteger)sorted.count - CharonHistoryMaxGenerations;
    for (NSInteger index = 0; index < overflow; index++)
        [manager removeItemAtPath:[directory stringByAppendingPathComponent:sorted[index]] error:NULL];
}

+ (NSData *)tokenForGeneration:(NSString *)generation
{
    return [NSKeyedArchiver archivedDataWithRootObject:generation];
}

+ (NSString *)generationForToken:(NSData *)token
{
    id object = nil;
    @try {
        object = [NSKeyedUnarchiver unarchiveObjectWithData:token];
    } @catch (__unused NSException *exception) {
        return nil;
    }
    return [object isKindOfClass:[NSString class]] ? object : nil;
}

+ (void)addContactEventsFrom:(NSDictionary *)previous to:(NSDictionary *)current book:(ABAddressBookRef)book
                      request:(CNChangeHistoryFetchRequest *)request into:(NSMutableArray *)events
{
    NSSet *keys = [CharonContactsBook keysFromDescriptors:request.additionalContactKeyDescriptors];
    for (NSString *identifier in current) {
        ABRecordRef person = ABAddressBookGetPersonWithRecordID(book, (ABRecordID)[identifier intValue]);
        if (!person)
            continue;
        NSNumber *previousStamp = previous[identifier];
        if (!previousStamp) {
            CNContact *contact = [CharonContactsBook contactWithRecord:person keys:keys unify:request.shouldUnifyResults
                                                                mutable:request.mutableObjects];
            ABRecordRef source = [CharonContactsBook sourceOfPersonWithIdentifier:identifier inBook:book];
            NSString *containerIdentifier = source ? [self identifierOfRecord:source] : nil;
            [events addObject:[CNChangeHistoryAddContactEvent charon_eventWithContact:contact containerIdentifier:containerIdentifier]];
        } else if (![previousStamp isEqual:current[identifier]]) {
            CNContact *contact = [CharonContactsBook contactWithRecord:person keys:keys unify:request.shouldUnifyResults
                                                                mutable:request.mutableObjects];
            [events addObject:[CNChangeHistoryUpdateContactEvent charon_eventWithContact:contact]];
        }
    }
    for (NSString *identifier in previous) {
        if (!current[identifier])
            [events addObject:[CNChangeHistoryDeleteContactEvent charon_eventWithContactIdentifier:identifier]];
    }
}

+ (void)addGroupEventsFrom:(NSDictionary *)previous to:(NSDictionary *)current book:(ABAddressBookRef)book
                    request:(CNChangeHistoryFetchRequest *)request into:(NSMutableArray *)events
{
    NSSet *keys = [CharonContactsBook keysFromDescriptors:request.additionalContactKeyDescriptors];
    for (NSString *identifier in current) {
        ABRecordRef group = ABAddressBookGetGroupWithRecordID(book, (ABRecordID)[identifier intValue]);
        if (!group)
            continue;
        NSDictionary *previousInfo = previous[identifier];
        if (!previousInfo) {
            CNGroup *cnGroup = [CharonContactsBook groupWithRecord:group mutable:NO];
            ABRecordRef source = [CharonContactsBook sourceOfGroupWithIdentifier:identifier inBook:book];
            NSString *containerIdentifier = source ? [self identifierOfRecord:source] : nil;
            [events addObject:[CNChangeHistoryAddGroupEvent charon_eventWithGroup:cnGroup containerIdentifier:containerIdentifier]];
            continue;
        }
        NSDictionary *currentInfo = current[identifier];
        if (![previousInfo[@"name"] isEqual:currentInfo[@"name"]])
            [events addObject:[CNChangeHistoryUpdateGroupEvent charon_eventWithGroup:[CharonContactsBook groupWithRecord:group mutable:NO]]];
        NSArray *previousMembers = previousInfo[@"members"];
        NSArray *currentMembers = currentInfo[@"members"];
        if ([previousMembers isEqual:currentMembers])
            continue;
        CNGroup *cnGroup = [CharonContactsBook groupWithRecord:group mutable:NO];
        NSMutableSet *added = [NSMutableSet setWithArray:currentMembers];
        [added minusSet:[NSSet setWithArray:previousMembers]];
        NSMutableSet *removed = [NSMutableSet setWithArray:previousMembers];
        [removed minusSet:[NSSet setWithArray:currentMembers]];
        for (NSString *memberIdentifier in added) {
            ABRecordRef person = ABAddressBookGetPersonWithRecordID(book, (ABRecordID)[memberIdentifier intValue]);
            if (!person)
                continue;
            CNContact *contact = [CharonContactsBook contactWithRecord:person keys:keys unify:request.shouldUnifyResults
                                                                mutable:request.mutableObjects];
            [events addObject:[CNChangeHistoryAddMemberToGroupEvent charon_eventWithMember:contact group:cnGroup]];
        }
        for (NSString *memberIdentifier in removed) {
            ABRecordRef person = ABAddressBookGetPersonWithRecordID(book, (ABRecordID)[memberIdentifier intValue]);
            if (!person)
                continue;
            CNContact *contact = [CharonContactsBook contactWithRecord:person keys:keys unify:request.shouldUnifyResults
                                                                mutable:request.mutableObjects];
            [events addObject:[CNChangeHistoryRemoveMemberFromGroupEvent charon_eventWithMember:contact group:cnGroup]];
        }
    }
    for (NSString *identifier in previous) {
        if (!current[identifier])
            [events addObject:[CNChangeHistoryDeleteGroupEvent charon_eventWithGroupIdentifier:identifier]];
    }
}

+ (NSData *)currentToken
{
    ABAddressBookRef book = [CharonContactsBook createBook:NULL];
    if (!book)
        return nil;
    NSDictionary *snapshot = [self snapshotFromBook:book];
    CFRelease(book);
    return [self tokenForGeneration:[self writeGeneration:snapshot]];
}

+ (CNFetchResult<NSEnumerator<CNChangeHistoryEvent *> *> *)enumeratorForRequest:(CNChangeHistoryFetchRequest *)request error:(NSError **)error
{
    ABAddressBookRef book = [CharonContactsBook createBook:error];
    if (!book)
        return nil;

    NSDictionary *current = [self snapshotFromBook:book];
    NSMutableArray *events = [NSMutableArray array];
    NSDictionary *previous;

    NSData *startingToken = request.startingToken;
    if (startingToken) {
        NSString *generation = [self generationForToken:startingToken];
        previous = generation ? [NSDictionary dictionaryWithContentsOfFile:[self pathForGeneration:generation]] : nil;
        if (!previous) {
            CFRelease(book);
            if (error)
                *error = [CharonContacts errorWithCode:CNErrorCodeChangeHistoryInvalidAnchor
                                                 reason:@"This token does not name a snapshot this store still holds."];
            return nil;
        }
    } else {
        [events addObject:[[CNChangeHistoryDropEverythingEvent alloc] init]];
        previous = @{@"contacts": @{}, @"groups": @{}};
    }

    [self addContactEventsFrom:previous[@"contacts"] to:current[@"contacts"] book:book request:request into:events];
    if (request.includeGroupChanges)
        [self addGroupEventsFrom:previous[@"groups"] to:current[@"groups"] book:book request:request into:events];

    NSString *newGeneration = [self writeGeneration:current];
    CFRelease(book);

    return [CNFetchResult charon_resultWithValue:[events objectEnumerator] historyToken:[self tokenForGeneration:newGeneration]];
}

@end

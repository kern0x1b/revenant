#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CNContactStore

- (NSData *)currentHistoryToken
{
    return [CharonContactsHistory currentToken];
}

+ (CNAuthorizationStatus)authorizationStatusForEntityType:(CNEntityType)entityType
{
    if (entityType != CNEntityTypeContacts)
        return CNAuthorizationStatusDenied;
    return (CNAuthorizationStatus)ABAddressBookGetAuthorizationStatus();
}

- (void)requestAccessForEntityType:(CNEntityType)entityType completionHandler:(void (^)(BOOL granted, NSError *error))completionHandler
{
    void (^answer)(BOOL, NSError *) = [completionHandler copy];
    if (!answer)
        return;
    if (entityType != CNEntityTypeContacts) {
        answer(NO, [CharonContacts errorWithCode:CNErrorCodeDataAccessError reason:@"The entity type is not contacts."]);
        return;
    }
    CFErrorRef failure = NULL;
    ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, &failure);
    if (!book) {
        NSError *error = failure ? (__bridge_transfer NSError *)failure
                                 : [CharonContacts errorWithCode:CNErrorCodeAuthorizationDenied reason:@"The address book could not be opened."];
        answer(NO, error);
        return;
    }
    ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
        answer(granted ? YES : NO, (__bridge NSError *)error);
        CFRelease(book);
    });
}

- (NSArray<CNContact *> *)unifiedContactsMatchingPredicate:(NSPredicate *)predicate keysToFetch:(NSArray *)keys error:(NSError **)error
{
    return [self charon_contactsMatching:predicate keysToFetch:keys unify:YES mutable:NO sortOrder:CNContactSortOrderNone error:error];
}

- (CNContact *)unifiedContactWithIdentifier:(NSString *)identifier keysToFetch:(NSArray *)keys error:(NSError **)error
{
    if (!identifier) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodeRecordIdentifierInvalid reason:@"No identifier was given."];
        return nil;
    }
    NSArray *found = [self unifiedContactsMatchingPredicate:[CNContact predicateForContactsWithIdentifiers:@[identifier]]
                                                keysToFetch:keys error:error];
    if (!found)
        return nil;
    if (found.count == 0) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodeRecordDoesNotExist reason:@"No contact with that identifier is in the address book."];
        return nil;
    }
    return found.firstObject;
}

- (BOOL)enumerateContactsWithFetchRequest:(CNContactFetchRequest *)fetchRequest error:(NSError **)error usingBlock:(void (NS_NOESCAPE ^)(CNContact *contact, BOOL *stop))block
{
    if (!fetchRequest || !block) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodeDataAccessError reason:@"A fetch request and a block are both needed."];
        return NO;
    }
    NSArray *contacts = [self charon_contactsMatching:fetchRequest.predicate keysToFetch:fetchRequest.keysToFetch
                                                unify:fetchRequest.unifyResults mutable:fetchRequest.mutableObjects
                                            sortOrder:fetchRequest.sortOrder error:error];
    if (!contacts)
        return NO;
    BOOL stop = NO;
    for (CNContact *contact in contacts) {
        block(contact, &stop);
        if (stop)
            break;
    }
    return YES;
}

- (NSArray *)charon_contactsMatching:(NSPredicate *)predicate keysToFetch:(NSArray *)keys unify:(BOOL)unify
                             mutable:(BOOL)mutableObjects sortOrder:(CNContactSortOrder)sortOrder error:(NSError **)error
{
    ABAddressBookRef book = [CharonContactsBook createBook:error];
    if (!book)
        return nil;
    NSArray *contacts = [CharonContactsBook contactsInBook:book matching:predicate
                                                      keys:[CharonContactsBook keysFromDescriptors:keys]
                                                     unify:unify mutable:mutableObjects error:error];
    CFRelease(book);
    if (contacts && sortOrder != CNContactSortOrderNone)
        contacts = [contacts sortedArrayUsingComparator:[CNContact comparatorForNameSortOrder:sortOrder]];
    return contacts;
}

- (NSError *)charon_errorFrom:(CFErrorRef)failure code:(CNErrorCode)code reason:(NSString *)reason
{
    NSError *underlying = failure ? (__bridge_transfer NSError *)failure : nil;
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (reason)
        info[NSLocalizedDescriptionKey] = reason;
    if (underlying)
        info[NSUnderlyingErrorKey] = underlying;
    return [NSError errorWithDomain:CNErrorDomain code:code userInfo:info];
}

- (BOOL)executeSaveRequest:(CNSaveRequest *)saveRequest error:(NSError **)error
{
    if (!saveRequest) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodeDataAccessError reason:@"No save request was given."];
        return NO;
    }
    ABAddressBookRef book = [CharonContactsBook createBook:error];
    if (!book)
        return NO;
    NSMutableArray *added = [NSMutableArray array];
    NSError *failed = nil;
    for (NSArray *pair in [saveRequest charon_added]) {
        CNMutableContact *contact = pair[0];
        NSString *container = pair[1];
        if (![CharonContactsBook contactFitsTheBook:contact error:&failed])
            break;
        ABRecordRef record = NULL;
        if (container.length > 0) {
            ABRecordRef source = ABAddressBookGetSourceWithRecordID(book, (ABRecordID)[container intValue]);
            if (!source) {
                failed = [CharonContacts errorWithCode:CNErrorCodeParentRecordDoesNotExist reason:@"No container of the address book has that identifier."];
                break;
            }
            record = ABPersonCreateInSource(source);
        } else {
            record = ABPersonCreate();
        }
        [CharonContactsBook applyContact:contact toRecord:record error:NULL];
        CFErrorRef failure = NULL;
        if (!ABAddressBookAddRecord(book, record, &failure)) {
            failed = [self charon_errorFrom:failure code:CNErrorCodeDataAccessError reason:@"The address book refused the new contact."];
            CFRelease(record);
            break;
        }
        [added addObject:@[contact, (__bridge_transfer id)record]];
    }
    for (CNMutableContact *contact in failed ? @[] : [saveRequest charon_updated]) {
        if (![CharonContactsBook contactFitsTheBook:contact error:&failed])
            break;
        ABRecordRef record = ABAddressBookGetPersonWithRecordID(book, (ABRecordID)[contact.identifier intValue]);
        if (!record) {
            failed = [CharonContacts errorWithCode:CNErrorCodeRecordDoesNotExist reason:@"The contact being updated is not in the address book."];
            break;
        }
        [CharonContactsBook applyContact:contact toRecord:record error:NULL];
    }
    for (CNMutableContact *contact in failed ? @[] : [saveRequest charon_deleted]) {
        ABRecordRef record = ABAddressBookGetPersonWithRecordID(book, (ABRecordID)[contact.identifier intValue]);
        if (!record) {
            failed = [CharonContacts errorWithCode:CNErrorCodeRecordDoesNotExist reason:@"The contact being deleted is not in the address book."];
            break;
        }
        CFErrorRef failure = NULL;
        if (!ABAddressBookRemoveRecord(book, record, &failure)) {
            failed = [self charon_errorFrom:failure code:CNErrorCodeDataAccessError reason:@"The address book refused to remove the contact."];
            break;
        }
    }
    NSMutableArray *addedGroups = [NSMutableArray array];
    for (NSArray *pair in failed ? @[] : [saveRequest charon_addedGroups]) {
        CNMutableGroup *group = pair[0];
        NSString *container = pair[1];
        ABRecordRef record = NULL;
        if (container.length > 0) {
            ABRecordRef source = ABAddressBookGetSourceWithRecordID(book, (ABRecordID)[container intValue]);
            if (!source) {
                failed = [CharonContacts errorWithCode:CNErrorCodeParentRecordDoesNotExist reason:@"No container of the address book has that identifier."];
                break;
            }
            record = ABGroupCreateInSource(source);
        } else {
            record = ABGroupCreate();
        }
        ABRecordSetValue(record, kABGroupNameProperty, (__bridge CFStringRef)group.name, NULL);
        CFErrorRef failure = NULL;
        if (!ABAddressBookAddRecord(book, record, &failure)) {
            failed = [self charon_errorFrom:failure code:CNErrorCodeDataAccessError reason:@"The address book refused the new group."];
            CFRelease(record);
            break;
        }
        [addedGroups addObject:@[group, (__bridge_transfer id)record]];
    }
    for (CNMutableGroup *group in failed ? @[] : [saveRequest charon_updatedGroups]) {
        ABRecordRef record = ABAddressBookGetGroupWithRecordID(book, (ABRecordID)[group.identifier intValue]);
        if (!record) {
            failed = [CharonContacts errorWithCode:CNErrorCodeRecordDoesNotExist reason:@"The group being updated is not in the address book."];
            break;
        }
        ABRecordSetValue(record, kABGroupNameProperty, (__bridge CFStringRef)group.name, NULL);
    }
    for (CNMutableGroup *group in failed ? @[] : [saveRequest charon_deletedGroups]) {
        ABRecordRef record = ABAddressBookGetGroupWithRecordID(book, (ABRecordID)[group.identifier intValue]);
        if (!record) {
            failed = [CharonContacts errorWithCode:CNErrorCodeRecordDoesNotExist reason:@"The group being deleted is not in the address book."];
            break;
        }
        CFErrorRef failure = NULL;
        if (!ABAddressBookRemoveRecord(book, record, &failure)) {
            failed = [self charon_errorFrom:failure code:CNErrorCodeDataAccessError reason:@"The address book refused to remove the group."];
            break;
        }
    }
    for (NSArray *pair in failed ? @[] : [saveRequest charon_addedMembers]) {
        CNContact *contact = pair[0];
        CNGroup *group = pair[1];
        ABRecordRef person = ABAddressBookGetPersonWithRecordID(book, (ABRecordID)[contact.identifier intValue]);
        ABRecordRef groupRecord = ABAddressBookGetGroupWithRecordID(book, (ABRecordID)[group.identifier intValue]);
        if (!person || !groupRecord) {
            failed = [CharonContacts errorWithCode:CNErrorCodeRecordDoesNotExist reason:@"The contact or the group is not in the address book."];
            break;
        }
        CFErrorRef failure = NULL;
        if (!ABGroupAddMember(groupRecord, person, &failure)) {
            failed = [self charon_errorFrom:failure code:CNErrorCodeDataAccessError reason:@"The address book refused to add the member to the group."];
            break;
        }
    }
    for (NSArray *pair in failed ? @[] : [saveRequest charon_removedMembers]) {
        CNContact *contact = pair[0];
        CNGroup *group = pair[1];
        ABRecordRef person = ABAddressBookGetPersonWithRecordID(book, (ABRecordID)[contact.identifier intValue]);
        ABRecordRef groupRecord = ABAddressBookGetGroupWithRecordID(book, (ABRecordID)[group.identifier intValue]);
        if (!person || !groupRecord) {
            failed = [CharonContacts errorWithCode:CNErrorCodeRecordDoesNotExist reason:@"The contact or the group is not in the address book."];
            break;
        }
        CFErrorRef failure = NULL;
        if (!ABGroupRemoveMember(groupRecord, person, &failure)) {
            failed = [self charon_errorFrom:failure code:CNErrorCodeDataAccessError reason:@"The address book refused to remove the member from the group."];
            break;
        }
    }
    if (!failed) {
        CFErrorRef failure = NULL;
        if (!ABAddressBookSave(book, &failure))
            failed = [self charon_errorFrom:failure code:CNErrorCodeDataAccessError reason:@"The address book could not be saved."];
    }
    if (failed) {
        ABAddressBookRevert(book);
        CFRelease(book);
        if (error)
            *error = failed;
        return NO;
    }
    for (NSArray *pair in added) {
        CNMutableContact *contact = pair[0];
        ABRecordRef record = (__bridge ABRecordRef)pair[1];
        ABRecordID identifier = ABRecordGetRecordID(record);
        if (identifier != kABRecordInvalidID)
            [contact charon_setValues:[contact charon_values] available:[contact charon_availableKeys]
                           identifier:[NSString stringWithFormat:@"%d", (int)identifier]];
    }
    for (NSArray *pair in addedGroups) {
        CNMutableGroup *group = pair[0];
        ABRecordRef record = (__bridge ABRecordRef)pair[1];
        ABRecordID identifier = ABRecordGetRecordID(record);
        if (identifier != kABRecordInvalidID)
            [group charon_setIdentifier:[NSString stringWithFormat:@"%d", (int)identifier] name:group.name];
    }
    if (saveRequest.shouldRefetchContacts) {
        NSMutableArray *refetch = [NSMutableArray array];
        for (NSArray *pair in added)
            [refetch addObject:pair[0]];
        [refetch addObjectsFromArray:[saveRequest charon_updated]];
        for (CNMutableContact *contact in refetch) {
            ABRecordRef record = ABAddressBookGetPersonWithRecordID(book, (ABRecordID)[contact.identifier intValue]);
            if (!record)
                continue;
            NSSet *keys = [contact charon_availableKeys];
            NSMutableDictionary *values = [NSMutableDictionary dictionary];
            [CharonContactsBook readRecord:record into:values keys:keys filling:NO];
            values[CNContactIdentifierKey] = contact.identifier;
            [contact charon_setValues:values available:keys identifier:contact.identifier];
        }
    }
    CFRelease(book);
    return YES;
}

- (NSArray<CNGroup *> *)groupsMatchingPredicate:(NSPredicate *)predicate error:(NSError **)error
{
    ABAddressBookRef book = [CharonContactsBook createBook:error];
    if (!book)
        return nil;
    NSArray *groups = [CharonContactsBook groupsInBook:book matching:predicate mutable:NO error:error];
    CFRelease(book);
    return groups;
}

- (NSArray<CNContainer *> *)containersMatchingPredicate:(NSPredicate *)predicate error:(NSError **)error
{
    ABAddressBookRef book = [CharonContactsBook createBook:error];
    if (!book)
        return nil;
    NSArray *containers = [CharonContactsBook containersInBook:book matching:predicate error:error];
    CFRelease(book);
    return containers;
}

- (CNFetchResult<NSEnumerator<CNContact *> *> *)enumeratorForContactFetchRequest:(CNContactFetchRequest *)request error:(NSError **)error
{
    NSArray *contacts = [self charon_contactsMatching:request.predicate keysToFetch:request.keysToFetch
                                                unify:request.unifyResults mutable:request.mutableObjects
                                            sortOrder:request.sortOrder error:error];
    if (!contacts)
        return nil;
    return [CNFetchResult charon_resultWithValue:[contacts objectEnumerator] historyToken:nil];
}

- (CNFetchResult<NSEnumerator<CNChangeHistoryEvent *> *> *)enumeratorForChangeHistoryFetchRequest:(CNChangeHistoryFetchRequest *)fetchRequest error:(NSError **)error
{
    if (!fetchRequest) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodeDataAccessError reason:@"No change-history fetch request was given."];
        return nil;
    }
    return [CharonContactsHistory enumeratorForRequest:fetchRequest error:error];
}

- (NSString *)defaultContainerIdentifier
{
    CFErrorRef failure = NULL;
    ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, &failure);
    if (!book) {
        if (failure)
            CFRelease(failure);
        return nil;
    }
    ABRecordRef source = ABAddressBookCopyDefaultSource(book);
    NSString *identifier = source ? [NSString stringWithFormat:@"%d", (int)ABRecordGetRecordID(source)] : nil;
    if (source)
        CFRelease(source);
    CFRelease(book);
    return identifier;
}

@end

#import "CharonContacts.h"

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@implementation CNContactVCardSerialization

+ (id<CNKeyDescriptor>)descriptorForRequiredKeys
{
    return [CharonContactsKeyDescriptor descriptorWithKeys:[CharonContacts contactKeys]];
}

+ (NSData *)dataWithContacts:(NSArray<CNContact *> *)contacts error:(NSError **)error
{
    if (!contacts) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodeDataAccessError reason:@"No contacts were given."];
        return nil;
    }
    NSMutableArray *records = [NSMutableArray array];
    for (CNContact *contact in contacts) {
        ABRecordRef record = [CharonContactsBook createRecordWithContact:contact];
        [records addObject:(__bridge_transfer id)record];
    }
    CFDataRef data = ABPersonCreateVCardRepresentationWithPeople((__bridge CFArrayRef)records);
    if (!data) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodeDataAccessError reason:@"The address book could not write a vCard for the contacts."];
        return nil;
    }
    return (__bridge_transfer NSData *)data;
}

+ (NSArray<CNContact *> *)contactsWithData:(NSData *)data error:(NSError **)error
{
    if (!data) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodeDataAccessError reason:@"No data was given."];
        return nil;
    }
    CFArrayRef people = ABPersonCreatePeopleInSourceWithVCardRepresentation(NULL, (__bridge CFDataRef)data);
    if (!people) {
        if (error)
            *error = [CharonContacts errorWithCode:CNErrorCodeDataAccessError reason:@"The data is not a vCard the address book can read."];
        return nil;
    }
    NSSet *keys = [NSSet setWithArray:[CharonContacts contactKeys]];
    NSMutableArray *contacts = [NSMutableArray array];
    for (CFIndex index = 0; index < CFArrayGetCount(people); index++) {
        ABRecordRef record = (ABRecordRef)CFArrayGetValueAtIndex(people, index);
        [contacts addObject:[CharonContactsBook contactWithRecord:record keys:keys unify:NO mutable:NO]];
    }
    CFRelease(people);
    return contacts;
}

@end

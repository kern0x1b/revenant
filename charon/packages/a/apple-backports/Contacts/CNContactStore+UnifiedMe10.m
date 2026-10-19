#import <Contacts/Contacts.h>
#import "CharonContacts.h"

@interface CNContactStore (CharonUnifiedMe10)

- (nullable CNContact *)unifiedMeContactWithKeysToFetch:(NSArray<id<CNKeyDescriptor>> *)keys error:(NSError **)error;

@end

@implementation CNContactStore (CharonUnifiedMe10)

- (CNContact *)unifiedMeContactWithKeysToFetch:(NSArray<id<CNKeyDescriptor>> *)keys error:(NSError **)error
{
    (void)keys;
    if (error) {
        *error = [CharonContacts errorWithCode:CNErrorCodeRecordDoesNotExist
                                       reason:@"This release has no \"me\" card: the address book of iOS 6 has no record of the person who owns the device."];
    }
    return nil;
}

@end

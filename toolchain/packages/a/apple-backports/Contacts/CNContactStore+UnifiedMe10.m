#import <Contacts/Contacts.h>
#import "RevenantContacts.h"

@interface CNContactStore (RevenantUnifiedMe10)

- (nullable CNContact *)unifiedMeContactWithKeysToFetch:(NSArray<id<CNKeyDescriptor>> *)keys error:(NSError **)error;

@end

@implementation CNContactStore (RevenantUnifiedMe10)

- (CNContact *)unifiedMeContactWithKeysToFetch:(NSArray<id<CNKeyDescriptor>> *)keys error:(NSError **)error
{
    (void)keys;
    if (error) {
        *error = [RevenantContacts errorWithCode:CNErrorCodeRecordDoesNotExist
                                       reason:@"This release has no \"me\" card: the address book of iOS 6 has no record of the person who owns the device."];
    }
    return nil;
}

@end

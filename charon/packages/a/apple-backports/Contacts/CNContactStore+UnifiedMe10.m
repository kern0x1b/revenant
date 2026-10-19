#import <Contacts/Contacts.h>
#import "CharonContacts.h"

// The "me" card of iOS 10.11: the one contact the system keeps of the person who owns the device,
// which the store hands back without a fetch request.
//
// iOS 6.1.3 has no such card. There is no Contacts framework, no me card in the release's
// AddressBook, and nothing that could be asked for permission to read one - so the card does not
// exist, and that is what the error says (facts/Contacts/Values.md). It is not a refusal: nothing was
// denied, there is nothing to find.
@interface CNContactStore (CharonUnifiedMe10)

- (nullable CNContact *)unifiedMeContactWithKeysToFetch:(NSArray<id<CNKeyDescriptor>> *)keys error:(NSError **)error;

@end

@implementation CNContactStore (CharonUnifiedMe10)

- (CNContact *)unifiedMeContactWithKeysToFetch:(NSArray<id<CNKeyDescriptor>> *)keys error:(NSError **)error
{
    // The keys are not read: there is no contact for them to be read out of, and a request that names
    // a key nobody has is not the reason this fails.
    (void)keys;
    if (error) {
        *error = [CharonContacts errorWithCode:CNErrorCodeRecordDoesNotExist
                                       reason:@"This release has no \"me\" card: the address book of iOS 6 has no record of the person who owns the device."];
    }
    return nil;
}

@end

// CKUserIdentity, which arrived in iOS 8.3 and not in iOS 10 with the rest of this file's values.
// An object that carries both 8.3's and 10.0.1's symbols belongs to no band, so it is its own file;
// the rule and the measurement are written down in CKOperations83.m and facts/CloudKit/Values.md.

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

#import "CharonCKSubscription.h"
#import "CharonCKValue.h"

#pragma mark - CKUserIdentity

@implementation CKUserIdentity

- (instancetype)charon_identity
{
    return [super init];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKUserIdentity: %p; userRecordID=%@, hasiCloudAccount=%d, lookupInfo=%@, contactIdentifiers=%@>",
            self, _userRecordID, _hasiCloudAccount, _lookupInfo, _contactIdentifiers];
}

@end

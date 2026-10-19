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

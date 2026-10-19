#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CloudKit/CloudKit.h>

#import "RevenantCKConstants.h"
#import "RevenantCKValue.h"

#pragma mark - CKShareParticipant

@implementation CKShareParticipant
{
    NSString *_participantID;
}

- (instancetype)initWithType:(CKShareParticipantType)type
{
    self = [super init];
    if (self) {
        _type = type;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKShareParticipant: %p; userIdentity=%@, permission=%ld, role=%ld, type=%ld, acceptanceStatus=%ld, participantID=%@>",
            self, _userIdentity, (long)_permission, (long)_role, (long)_type, (long)_acceptanceStatus, _participantID];
}

@end

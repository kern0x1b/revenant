#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

#import "RevenantCKValue.h"

@implementation CKAllowedSharingOptions

@synthesize allowsAccessRequests = _allowsAccessRequests;
@synthesize allowsParticipantsToInviteOthers = _allowsParticipantsToInviteOthers;

- (instancetype)initWithAllowedParticipantPermissionOptions:(CKSharingParticipantPermissionOption)permissionOptions
                           allowedParticipantAccessOptions:(CKSharingParticipantAccessOption)accessOptions
{
    self = [super init];
    if (self) {
        _allowedParticipantPermissionOptions = permissionOptions;
        _allowedParticipantAccessOptions = accessOptions;
        _allowsAccessRequests = NO;
        _allowsParticipantsToInviteOthers = NO;
    }
    return self;
}

+ (instancetype)new
{
    return [[self alloc] initWithAllowedParticipantPermissionOptions:0
                                        allowedParticipantAccessOptions:CKSharingParticipantAccessOptionSpecifiedRecipientsOnly];
}

+ (CKAllowedSharingOptions *)standardOptions
{
    return [[self alloc] initWithAllowedParticipantPermissionOptions:CKSharingParticipantPermissionOptionReadOnly
                                        allowedParticipantAccessOptions:CKSharingParticipantAccessOptionSpecifiedRecipientsOnly];
}

- (id)copyWithZone:(NSZone *)zone
{
    CKAllowedSharingOptions *copy = [[CKAllowedSharingOptions allocWithZone:zone]
        initWithAllowedParticipantPermissionOptions:_allowedParticipantPermissionOptions
                       allowedParticipantAccessOptions:_allowedParticipantAccessOptions];
    copy.allowsAccessRequests = _allowsAccessRequests;
    copy.allowsParticipantsToInviteOthers = _allowsParticipantsToInviteOthers;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[CKAllowedSharingOptions class]]) {
        return NO;
    }
    CKAllowedSharingOptions *options = other;
    return _allowedParticipantPermissionOptions == options.allowedParticipantPermissionOptions &&
           _allowedParticipantAccessOptions == options.allowedParticipantAccessOptions &&
           _allowsAccessRequests == options.allowsAccessRequests &&
           _allowsParticipantsToInviteOthers == options.allowsParticipantsToInviteOthers;
}

- (NSUInteger)hash
{
    return (NSUInteger)_allowedParticipantPermissionOptions ^ ((NSUInteger)_allowedParticipantAccessOptions << 1) ^
           ((NSUInteger)_allowsAccessRequests << 2) ^ ((NSUInteger)_allowsParticipantsToInviteOthers << 3);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKAllowedSharingOptions: %p; permissionOptions=%lu, accessOptions=%lu, allowsAccessRequests=%d, allowsParticipantsToInviteOthers=%d>",
            self, (unsigned long)_allowedParticipantPermissionOptions, (unsigned long)_allowedParticipantAccessOptions,
            _allowsAccessRequests, _allowsParticipantsToInviteOthers];
}

@end

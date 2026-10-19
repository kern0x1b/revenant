// What iOS 16 added to the sharing surface that is a value: the options a share says who may be
// added with what permission, and under which access.
//
// CKAllowedSharingOptions is what an application sets on a share it is about to save, and what the
// share carries afterwards: which permissions a participant may be given, whether a participant may
// look the share's owner up, and - the members of iOS 26 - whether a share may ask for access at all
// and whether a participant may bring others in. A share that has not been told is a share that
// invites nobody, which is what a new one of this class answers.
//
// The request the share is saved in, and the transfer representation of iOS 16 that carries it out
// of the process, are the transport and a later delivery.

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

#import "CharonCKValue.h"

// The two members iOS 26 added. The SDK this package builds against is 16.4 and does not declare
// them, and they are the share's own state, so they are declared here rather than answered as nil.
@interface CKAllowedSharingOptions ()
@property (nonatomic, assign) BOOL allowsAccessRequests;
@property (nonatomic, assign) BOOL allowsParticipantsToInviteOthers;
@end

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

// What a share gets when an application has not said otherwise: read-only participants, no discovery
// of who else is in the share, and no access requests. CloudKit's own standard options are the
// read-only and no-discovery pair, and a share with no options at all invites nobody.
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

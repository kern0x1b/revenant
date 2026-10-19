// What the subscription family of this package shares.
//
// The SDK's CKSubscription declares no initialiser at all - a caller is meant to build one of the
// three subclasses - so the base class's own designated initialiser, the one that takes the name the
// service will know it by, is declared here for the subclasses in the other files of this folder. It
// is the port's declaration and not the SDK's, which is why it is not in the registry: no SDK header
// names it, and the rule that covers such a name is R4 of .agents/skills/patch-merge.

#ifndef CHARON_CK_SUBSCRIPTION_H
#define CHARON_CK_SUBSCRIPTION_H

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

@interface CKServerChangeToken (CharonCKBuilding)
// The token of a server change token, and the change token of one: the service carries these as the
// continuation marker of a changes answer, and the SDK's class declares no way to get at either.
+ (instancetype)tokenWithData:(NSData *)data;
- (NSData *)data;
@end

@interface CKQueryCursor (CharonCKBuilding)
// The cursor is the service's own token and nothing else, and the SDK's class declares no way to be
// built from one, so this is the initialiser the transport uses to hand the service's answer back to
// a caller. -serverChangeToken reads it out again.
- (instancetype)initWithToken:(NSData *)token;
- (NSData *)serverChangeToken;
@end

// The members of a share's metadata that arrived after the 16.4 header this package builds
// against: the URL the share is under, the record of the hierarchy's root, and the owner and the
// status and role of the participant. The SDK's own `share` property is a CKShare of iOS 15, so the
// ivar is named apart from it and never read as that.
// A user identity, a participant and a lookup are values the service fills in and the port keeps:
// there is no initializer of any of the three that a caller may use, so what the service sent is the
// only thing that can build one.
// A user identity and a participant are values the service fills in and the SDK marks unbuildable
// by a caller, and a share's metadata is one too - so all three are made here, and the one
// initializer declared is the port's own. This is the fourth port-declared initialiser, after
// -[CKSubscription initWithSubscriptionID:], -[CKNotificationID initWithNotificationName:object:]
// and -[CKShareParticipant initWithType:].
// The properties and the initialiser were each declared as a category of this one name by a
// different half of the pile. Two categories of one name on one class are not two categories: the
// runtime keeps one and the other's members are never registered, so the initialiser was declared
// where nothing could see it. It is one category here, carrying every member it had between them.
@interface CKUserIdentity (CharonCKBuilding)
@property (nonatomic, copy, nullable) CKRecordID *userRecordID;
@property (nonatomic, assign) BOOL hasiCloudAccount;
@property (nonatomic, copy, nullable) CKUserIdentityLookupInfo *lookupInfo;
@property (nonatomic, copy, nullable) NSArray<NSString *> *contactIdentifiers;
- (instancetype)charon_identity;
@end

@interface CKShareParticipant (CharonCKBuilding)
@property (nonatomic, copy, nullable) CKUserIdentity *userIdentity;
@property (nonatomic, copy, nullable) NSString *participantID;
- (instancetype)initWithType:(CKShareParticipantType)type;
@end

// A user identity and a participant are values the service fills in and the SDK marks unbuildable
// by a caller, and a share's metadata is one too - so all three are made here, and the one
// initializer declared is the port's own. This is the fourth port-declared initialiser, after
// -[CKSubscription initWithSubscriptionID:], -[CKNotificationID initWithNotificationName:object:]
// and -[CKShareParticipant initWithType:].
@interface CKShareMetadata (CharonCKBuilding)
- (instancetype)initWithRootRecordID:(CKRecordID *)rootRecordID
                  containerIdentifier:(nullable NSString *)containerIdentifier
                             shareURL:(NSURL *)shareURL
                      participantType:(CKShareParticipantType)participantType
                           permission:(CKShareParticipantPermission)permission;


@property (nonatomic, copy, nullable) NSURL *shareURL;
@property (nonatomic, copy, nullable) CKRecordID *hierarchicalRootRecordID;
@property (nonatomic, copy, nullable) CKUserIdentity *ownerIdentity;
@property (nonatomic, assign) CKShareParticipantAcceptanceStatus participantStatus;
@property (nonatomic, assign) CKShareParticipantRole participantRole;
@end

// A CKUserIdentity, a CKShareParticipant and a CKLookupInfo are values the service fills in, so
// their state is the port's own and is declared here rather than synthesized: the SDK declares the
// properties readonly and no initializer of any of the three that a caller may use.

@interface CKSubscription (CharonCKBuilding)
- (instancetype)initWithSubscriptionID:(CKSubscriptionID)subscriptionID;
@end

// CKNotificationID is an empty class in the SDK: it declares no method at all, so the initialiser
// that gives one a name is declared here for the notification files of this folder.
@interface CKNotificationID (CharonCKBuilding)
- (instancetype)initWithNotificationName:(NSString *)notificationName object:(id)object;
@end

#endif

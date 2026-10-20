#ifndef REVENANT_CK_SUBSCRIPTION_H
#define REVENANT_CK_SUBSCRIPTION_H

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

@interface CKServerChangeToken (RevenantCKBuilding)
+ (instancetype)tokenWithData:(NSData *)data;
- (NSData *)data;
@end

@interface CKQueryCursor (RevenantCKBuilding)
- (instancetype)initWithToken:(NSData *)token;
- (NSData *)serverChangeToken;
@end

@interface CKUserIdentity (RevenantCKBuilding)
@property (nonatomic, copy, nullable) CKRecordID *userRecordID;
@property (nonatomic, assign) BOOL hasiCloudAccount;
@property (nonatomic, copy, nullable) CKUserIdentityLookupInfo *lookupInfo;
@property (nonatomic, copy, nullable) NSArray<NSString *> *contactIdentifiers;
- (instancetype)revenant_identity;
@end

@interface CKShareParticipant (RevenantCKBuilding)
@property (nonatomic, copy, nullable) CKUserIdentity *userIdentity;
@property (nonatomic, copy, nullable) NSString *participantID;
- (instancetype)initWithType:(CKShareParticipantType)type;
@end

@interface CKShareMetadata (RevenantCKBuilding)
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

@interface CKSubscription (RevenantCKBuilding)
- (instancetype)initWithSubscriptionID:(CKSubscriptionID)subscriptionID;
@end

@interface CKNotificationID (RevenantCKBuilding)
- (instancetype)initWithNotificationName:(NSString *)notificationName object:(id)object;
@end

#endif

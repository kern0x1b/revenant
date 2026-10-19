// CloudKit's iOS 26 sharing-access surface, transcribed from the iOS 26.2 headers.
//
// The SDK this package builds against is 16.4 and declares none of it, so the port declares it here
// and **every class and every member below is a rule R4 case**.
//
// Why a plain transcription can live in a header at all: the build compiles with
// -Werror=objc-missing-property-synthesis, and that check fires on *implicit* synthesis. The
// @implementation in CKOperations26.m therefore carries an explicit @synthesize for each of its
// properties, so a declaration here and an implementation in that file is fine.

#ifndef CHARON_CK_IOS26_H
#define CHARON_CK_IOS26_H

#import <Foundation/Foundation.h>
#import <CloudKit/CloudKit.h>

NS_ASSUME_NONNULL_BEGIN

// Asking to be let into a share: the other half of accepting one. The inviter says who may ask and the
// asker asks, and the service's answer is per share URL. The three declarations below are the iOS
// 26.2 header's own, transcribed.
@interface CKShareRequestAccessOperation : CKOperation

- (instancetype)initWithShareURLs:(NSArray<NSURL *> *)shareURLs NS_SWIFT_NAME(init(shareURLs:));

@property (nullable, copy, nonatomic) NSArray<NSURL *> *shareURLs;

// Called once per share URL, in the order the service answered them, and an item it refused arrives
// as that item's own error.
@property (nullable, copy, nonatomic) void (^perShareAccessRequestCompletionBlock)(NSURL *shareURL,
                                                                                  NSError *_Nullable shareRequestAccessError) NS_REFINED_FOR_SWIFT;

// Called last and exactly once, with a partial answer as CKErrorPartialFailure.
@property (nullable, copy, nonatomic) void (^shareRequestAccessCompletionBlock)(NSError *_Nullable operationError) NS_REFINED_FOR_SWIFT;

@end

// NOT carried yet, named here so the next delivery does not lose them:
//   CKShareAccessRequester            - who asked to be let into a share, and how
//   CKShareBlockedIdentity            - an identity the owner has blocked
//   CKShare.allowsAccessRequests      - and .allowsParticipantsToInviteOthers, .requesters,
//                                       .blockedIdentities, and -blockRequesters:,
//                                       -unblockIdentities:, -denyRequesters: - members of CKShare,
//                                       which this family does not carry yet
// The two value classes are values the service fills in; the CKShare members are answered with
// CKShare itself, in a later delivery, where a save can carry them. facts/CloudKit/Values.md says what
// each of these answers.

NS_ASSUME_NONNULL_END

#endif
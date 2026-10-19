// CKShareParticipant, the participant a share carries, which arrived in iOS 8.0 with the rest of
// CloudKit's first release. It is a value like the others of that release: built, kept, compared and
// read back, with nothing reaching the network.
//
// The seven other classes of that release - the record, the zone, the reference, the asset, the
// identifier pair and the server's change token - used to be defined here as well as in
// CKRecords8.m, and the nm sweep read that as each of them defined twice, which is two objects
// exporting one class. CKRecords8.m owns them: its own header names exactly those seven, and the
// bodies that were here carried +new on four of them, the change token's whole data API, and the
// record's parent, encryptedValues and equality - all of which are in that file now, so nothing this
// file answered is lost by it no longer answering it.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CloudKit/CloudKit.h>

#import "CharonCKConstants.h"
#import "CharonCKValue.h"

// The keys these classes archive under. Apple's own names are the keys the release's own archive
// uses, and an archive is what a caller hands between two processes, so the names cannot be the
// port's; they are the ones the measured -description output and the host's own archive round trip
// agree on, and they are listed in facts/CloudKit/Values.md.

// CKShareParticipant is a value of the first release, and the participant a share carries is
// one of them: built, kept and read back, with nothing reaching the network. It sat in
// CKValues10.m beside CKUserIdentity, which is 8.3, and a file carrying 8.0, 8.3 and 10.0.1
// symbols belongs to no band.

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

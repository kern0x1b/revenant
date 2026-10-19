// CKRecord's private storage, and the writable view of the properties the port fills in.
//
// CKRecord's own surface arrived in two releases: the record type, the name, the fields and the copy
// are iOS 8.0, and the parent and the share are iOS 10.0. The build refuses one object that holds the
// API of more than one release, so the class is in two - CKRecords8.m for the 8.0 half and
// CKRecords10.m for the 10.0 one - and what spans them is here: the ivars of the class, which only
// the @implementation that owns the class may declare, and the SDK's readonly properties redeclared
// readwrite, which is what lets CKRecords8.m write out an accessor for each of them instead of
// @synthesize'ing one (a synthesized ivar is private to its own @implementation) and lets
// CharonCKRecords.m hand the service's answers to a record it did not build.
//
// CKRecords10.m does NOT read any of this. It reaches the record through the SDK's own properties and
// keeps the parent and the share beside the record, in its own storage, because from iOS 8.0 on the
// record is the release's class and its layout is the release's: an offset this port compiled is an
// offset into somebody else's object. That is the whole reason this header names one file for the
// ivars and another for the answers.
//
// This header is not installed. The class's own surface is the device SDK's, and nothing here is
// CloudKit API.

#import "CharonCloudKit.h"

@interface CKRecord () {
    // The ivars, declared here rather than left to @synthesize, because a synthesized ivar is private
    // to the @implementation that made it and this header is where the class's own object file reads
    // them from.
    NSString *_recordType;
    CKRecordID *_recordID;
    NSString *_recordChangeTag;
    CKRecordID *_creatorUserRecordID;
    NSDate *_creationDate;
    CKRecordID *_lastModifiedUserRecordID;
    NSDate *_modificationDate;
    // The fields, in the order they were first set, and the keys that were ever set - which is not the
    // same set: a field set and then removed stays in changedKeys and leaves allKeys. Measured, not
    // assumed: after setting six fields and removing one, allKeys holds five and changedKeys holds six.
    NSMutableDictionary *_fields;
    NSMutableArray *_changedKeys;
}
// The SDK declares these readonly; they are readwrite here so the accessors written out in
// CKRecords8.m are implementations of something rather than a second definition of the property.
@property (nonatomic, copy) NSString *recordType;
@property (nonatomic, copy) CKRecordID *recordID;
@property (nonatomic, copy, nullable) NSString *recordChangeTag;
@property (nonatomic, copy, nullable) CKRecordID *creatorUserRecordID;
@property (nonatomic, copy, nullable) NSDate *creationDate;
@property (nonatomic, copy, nullable) CKRecordID *lastModifiedUserRecordID;
@property (nonatomic, copy, nullable) NSDate *modificationDate;
// `share` and `parent` are not redeclared and not stored here: the SDK declares both, and the 10.0 half
// of the class keeps them beside the record (CKRecords10.m).
@end
// CKRecord's parent and its share, and the two SDK wrappers that build a parent, written once in
// CKRecords10.m - the object that is in every band, and so the only one that may keep the state beside
// the record rather than inside it. The port's own class forwards to these (see CKRecords8.m); the
// release's class is given them by the installer in that same file for the bands of 8.0 to 9.3. This
// is internal to the package and is not a CloudKit API of this port's own.
extern void CharonCKRecordSetParent(CKRecord *_Nonnull record, CKReference *_Nullable parent);
extern void CharonCKRecordSetParentReferenceFromRecordID(CKRecord *_Nonnull record, CKRecordID *_Nullable parentRecordID);
extern void CharonCKRecordSetParentReferenceFromRecord(CKRecord *_Nonnull record, CKRecord *_Nullable parentRecord);

// The two decoders that turn a record out of the service's answer: one record, and a list of them.
//
// They live in a file of their own because both are C functions shared by several of this package's
// objects - charon/AGENTS.md's rule, and the reason it is a rule is that a file which implements a
// class is left out of some bands, so a call to a function defined in one of those files is an
// `Undefined symbols` in later bands only. A file that exports no API symbol of its own is in every
// band.
//
// The field mapping is not written here: CharonCKValueFromJSON and CharonCKFieldsFromJSON in
// CharonCloudKitPaths.m already carry one value to and from the wire, and a record's fields are the
// same values under a `fields` key. What is here is the record around them - its type, its name, its
// zone - and the answer's own bookkeeping: the service sends `recordName` and `zoneID` beside the
// fields, and a `desiredKeys` set limits the fields that were asked for and answered.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKRecordPrivate.h"

CKRecord *CharonCKRecordFromResult(NSDictionary *result, NSSet *desiredKeys)
{
    if (![result isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSString *recordType = [result[@"recordType"] isKindOfClass:[NSString class]] ? result[@"recordType"] : nil;
    CKRecordID *recordID = CharonCKRecordIDFromDocument(result[@"recordID"]);
    if (!recordID) {
        // The service names a record either inside a recordID or beside it as recordName.
        recordID = CharonCKRecordIDFromDocument(result);
    }
    if (!recordType && !recordID) {
        return nil;
    }
    CKRecord *record = [[CKRecord alloc] initWithRecordType:recordType ?: @"" recordID:recordID
        ?: [[CKRecordID alloc] initWithRecordName:[[NSUUID UUID] UUIDString]]];

    NSDictionary *fields = CharonCKFieldsFromJSON(result[@"fields"]);
    for (NSString *key in fields) {
        if (desiredKeys && ![desiredKeys containsObject:key]) {
            continue;
        }
        [record setObject:fields[key] forKey:key];
    }

    // The service's own answers about the record, and only the ones the answer carries, so a record
    // that has never been saved keeps nil for all of them.
    //
    // They go in through the record's own properties. Below iOS 8.0 the record is this port's class
    // and CKRecords8.m writes out the five setters, which CharonCKRecordPrivate.h declares readwrite
    // for exactly this. From 8.0 on the record is the release's class, which carries all five readonly
    // and so cannot be given them at all: the answer is nil, which is what this library's own readers
    // already read there - CharonCKDocuments.m builds the outgoing document out of record.recordChangeTag
    // and skips what a record does not hold, and CKOperations8.m calls the same record an update or a
    // create on that one value. So the property is asked, once, whether this record takes the answers.
    if ([record respondsToSelector:@selector(setRecordChangeTag:)]) {
        record.recordChangeTag = [result[@"recordChangeTag"] isKindOfClass:[NSString class]] ? result[@"recordChangeTag"] : nil;
        record.creatorUserRecordID = CharonCKRecordIDFromDocument(result[@"creatorUserRecordID"]);
        record.creationDate = CharonCKDateFromJSON(result[@"creationDate"]);
        record.lastModifiedUserRecordID = CharonCKRecordIDFromDocument(result[@"lastModifiedUserRecordID"]);
        record.modificationDate = CharonCKDateFromJSON(result[@"modificationDate"]);
    }
    return record;
}

NSArray<CKRecord *> *CharonCKRecordsFromResults(NSArray *results, NSSet *desiredKeys)
{
    if (![results isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray *records = [NSMutableArray arrayWithCapacity:results.count];
    for (id result in results) {
        CKRecord *record = CharonCKRecordFromResult(result, desiredKeys);
        if (record) {
            [records addObject:record];
        }
    }
    return records;
}

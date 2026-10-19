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

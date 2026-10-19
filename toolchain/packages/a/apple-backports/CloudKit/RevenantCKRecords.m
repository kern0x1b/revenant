#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKRecordPrivate.h"

CKRecord *RevenantCKRecordFromResult(NSDictionary *result, NSSet *desiredKeys)
{
    if (![result isKindOfClass:[NSDictionary class]]) {
        return nil;
    }
    NSString *recordType = [result[@"recordType"] isKindOfClass:[NSString class]] ? result[@"recordType"] : nil;
    CKRecordID *recordID = RevenantCKRecordIDFromDocument(result[@"recordID"]);
    if (!recordID) {
        recordID = RevenantCKRecordIDFromDocument(result);
    }
    if (!recordType && !recordID) {
        return nil;
    }
    CKRecord *record = [[CKRecord alloc] initWithRecordType:recordType ?: @"" recordID:recordID
        ?: [[CKRecordID alloc] initWithRecordName:[[NSUUID UUID] UUIDString]]];

    NSDictionary *fields = RevenantCKFieldsFromJSON(result[@"fields"]);
    for (NSString *key in fields) {
        if (desiredKeys && ![desiredKeys containsObject:key]) {
            continue;
        }
        [record setObject:fields[key] forKey:key];
    }

    if ([record respondsToSelector:@selector(setRecordChangeTag:)]) {
        record.recordChangeTag = [result[@"recordChangeTag"] isKindOfClass:[NSString class]] ? result[@"recordChangeTag"] : nil;
        record.creatorUserRecordID = RevenantCKRecordIDFromDocument(result[@"creatorUserRecordID"]);
        record.creationDate = RevenantCKDateFromJSON(result[@"creationDate"]);
        record.lastModifiedUserRecordID = RevenantCKRecordIDFromDocument(result[@"lastModifiedUserRecordID"]);
        record.modificationDate = RevenantCKDateFromJSON(result[@"modificationDate"]);
    }
    return record;
}

NSArray<CKRecord *> *RevenantCKRecordsFromResults(NSArray *results, NSSet *desiredKeys)
{
    if (![results isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray *records = [NSMutableArray arrayWithCapacity:results.count];
    for (id result in results) {
        CKRecord *record = RevenantCKRecordFromResult(result, desiredKeys);
        if (record) {
            [records addObject:record];
        }
    }
    return records;
}

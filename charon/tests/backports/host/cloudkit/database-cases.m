// CKRecordZone, asked once of whichever CloudKit this binary was compiled against.
//
// No CKContainer and no CKDatabase appear anywhere in this file, and cannot: a process without the
// com.apple.developer.icloud-services entitlement traps the moment a container is built - CloudKit
// itself says so, from CKContainer.m:760 - so a differential that needed one would measure nothing. A
// record zone is a value: it is built, read, copied, compared, archived and printed, and every case
// here does one of those in memory. The runner refuses its own answers if this file mentions a
// database operation selector, so "no container" is checked rather than promised.
//
// What is asked, and why each: a zone is identified by a name and an owner, so the two initializers
// and the zoneID property are the identity; capabilities is the one property that says something about
// the zone rather than naming it, and a port that reads 0 for a zone made with a name is a port that
// lost it; copy, equality and hash are what a caller puts a zone in a set with; the archive round trip
// is what a caller persists one with; description is what a caller reads in a log; and -init is asked
// with no arguments because CloudKit refuses it and refusing is the answer worth holding to.

#import <Foundation/Foundation.h>

#import "database-cases.h"

@interface CKRecordZoneID : NSObject <NSCopying>
- (instancetype)initWithZoneName:(NSString *)zoneName ownerName:(NSString *)ownerName;
@property (nonatomic, readonly, copy) NSString *zoneName;
@property (nonatomic, readonly, copy) NSString *ownerName;
@end

@interface CKRecordZone : NSObject <NSSecureCoding, NSCopying>
+ (CKRecordZone *)defaultRecordZone;
+ (instancetype)new;
- (instancetype)init;
- (instancetype)initWithZoneName:(NSString *)zoneName;
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID;
@property (nonatomic, readonly, copy) CKRecordZoneID *zoneID;
@property (nonatomic, readonly) NSInteger capabilities;
@property (nonatomic, readonly) NSInteger encryptionScope;
@property (nonatomic, readonly, copy) id share;
@property (nonatomic, readonly, copy) NSString *description;
- (id)copyWithZone:(NSZone *)zone;
- (BOOL)isEqual:(id)other;
- (NSUInteger)hash;
- (instancetype)initWithCoder:(NSCoder *)coder;
- (void)encodeWithCoder:(NSCoder *)coder;
@end

static NSDictionary *CharonZoneAnswers(NSString *name, CKRecordZone *zone)
{
    NSMutableDictionary *answer = [NSMutableDictionary dictionary];
    answer[@"zoneID.zoneName"] = zone.zoneID.zoneName ?: @"(nil)";
    answer[@"zoneID.ownerName"] = zone.zoneID.ownerName ?: @"(nil)";
    answer[@"capabilities"] = @(zone.capabilities);
    // encryptionScope and share are readonly in the header - there are no setters to measure - so what
    // a local zone answers for them is the default, and the default is the measurement
    answer[@"encryptionScope"] = @(zone.encryptionScope);
    answer[@"share"] = zone.share ? [zone.share description] : @"(nil)";
    answer[@"description"] = zone.description ?: @"(nil)";
    answer[@"equalToSelf"] = @([zone isEqual:zone]);
    answer[@"hashIsStable"] = @([zone hash] == [zone hash]);
    answer[@"copyIsEqual"] = @([[zone copy] isEqual:zone]);
    return answer;
}

void CharonDatabaseCases(NSMutableDictionary *out)
{
    NSMutableDictionary *cases = [NSMutableDictionary dictionary];
    out[@"cases"] = cases;

    // the two initializers, which are the identity
    cases[@"initWithZoneName"] = CharonZoneAnswers(@"initWithZoneName",
        [[CKRecordZone alloc] initWithZoneName:@"probe"]);
    cases[@"initWithZoneID"] = CharonZoneAnswers(@"initWithZoneID",
        [[CKRecordZone alloc] initWithZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"probe"
                                                                                ownerName:@"__defaultOwner__"]]);
    cases[@"new"] = CharonZoneAnswers(@"new", [CKRecordZone new]);
    cases[@"defaultRecordZone"] = CharonZoneAnswers(@"defaultRecordZone", [CKRecordZone defaultRecordZone]);

    // -init refuses, and refusing is the answer: CloudKit raises rather than answering a default
    @try {
        CKRecordZone *made = [[CKRecordZone alloc] init];
        cases[@"init"] = @{@"raised": @"no", @"value": made.zoneID.zoneName ?: @"(nil)"};
    } @catch (NSException *raised) {
        cases[@"init"] = @{@"raised": raised.name ?: @"(unnamed)", @"value": @"(raised)"};
    }

    // the archive round trip, which is what a caller persists a zone with
    @try {
        NSMutableData *data = [NSMutableData data];
        NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
        [archiver encodeObject:[[CKRecordZone alloc] initWithZoneName:@"probe"] forKey:@"zone"];
        [archiver finishEncoding];
        NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
        CKRecordZone *back = [unarchiver decodeObjectForKey:@"zone"];
        cases[@"archiveRoundTrip"] = @{@"raised": @"no",
            @"decoded": [back isKindOfClass:[CKRecordZone class]] ? @"yes" : @"no",
            @"zoneName": back.zoneID.zoneName ?: @"(nil)",
            @"equal": @([back isEqual:[[CKRecordZone alloc] initWithZoneName:@"probe"]])};
    } @catch (NSException *raised) {
        cases[@"archiveRoundTrip"] = @{@"raised": raised.name ?: @"(unnamed)", @"value": @"(raised)"};
    }
}

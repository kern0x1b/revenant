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

static NSDictionary *RevenantZoneAnswers(NSString *name, CKRecordZone *zone)
{
    NSMutableDictionary *answer = [NSMutableDictionary dictionary];
    answer[@"zoneID.zoneName"] = zone.zoneID.zoneName ?: @"(nil)";
    answer[@"zoneID.ownerName"] = zone.zoneID.ownerName ?: @"(nil)";
    answer[@"capabilities"] = @(zone.capabilities);
    answer[@"encryptionScope"] = @(zone.encryptionScope);
    answer[@"share"] = zone.share ? [zone.share description] : @"(nil)";
    answer[@"description"] = zone.description ?: @"(nil)";
    answer[@"equalToSelf"] = @([zone isEqual:zone]);
    answer[@"hashIsStable"] = @([zone hash] == [zone hash]);
    answer[@"copyIsEqual"] = @([[zone copy] isEqual:zone]);
    return answer;
}

void RevenantDatabaseCases(NSMutableDictionary *out)
{
    NSMutableDictionary *cases = [NSMutableDictionary dictionary];
    out[@"cases"] = cases;

    cases[@"initWithZoneName"] = RevenantZoneAnswers(@"initWithZoneName",
        [[CKRecordZone alloc] initWithZoneName:@"probe"]);
    cases[@"initWithZoneID"] = RevenantZoneAnswers(@"initWithZoneID",
        [[CKRecordZone alloc] initWithZoneID:[[CKRecordZoneID alloc] initWithZoneName:@"probe"
                                                                                ownerName:@"__defaultOwner__"]]);
    cases[@"new"] = RevenantZoneAnswers(@"new", [CKRecordZone new]);
    cases[@"defaultRecordZone"] = RevenantZoneAnswers(@"defaultRecordZone", [CKRecordZone defaultRecordZone]);

    @try {
        CKRecordZone *made = [[CKRecordZone alloc] init];
        cases[@"init"] = @{@"raised": @"no", @"value": made.zoneID.zoneName ?: @"(nil)"};
    } @catch (NSException *raised) {
        cases[@"init"] = @{@"raised": raised.name ?: @"(unnamed)", @"value": @"(raised)"};
    }

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

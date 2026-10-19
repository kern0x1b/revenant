#import <Foundation/Foundation.h>

@class CKRecordZoneID, CKRecordID, CKRecordZone, CKReference, CKAsset, CKRecord;

@interface CKRecordZoneID : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithZoneName:(NSString *)zoneName ownerName:(NSString *)ownerName;
@property (nonatomic, readonly, copy) NSString *zoneName;
@property (nonatomic, readonly, copy) NSString *ownerName;
@end

@interface CKRecordID : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithRecordName:(NSString *)recordName;
- (instancetype)initWithRecordName:(NSString *)recordName zoneID:(CKRecordZoneID *)zoneID;
@property (nonatomic, readonly, copy) NSString *recordName;
@property (nonatomic, readonly, copy) CKRecordZoneID *zoneID;
@end

@interface CKServerChangeToken : NSObject <NSSecureCoding, NSCopying>
@end

typedef NS_ENUM(NSUInteger, CKReferenceAction) {
    CKReferenceActionNone = 0,
    CKReferenceActionDeleteSelf = 1,
};

@interface CKReference : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithRecordID:(CKRecordID *)recordID action:(CKReferenceAction)action;
- (instancetype)initWithRecord:(CKRecord *)record action:(CKReferenceAction)action;
@property (nonatomic, readonly, assign) CKReferenceAction referenceAction;
@property (nonatomic, readonly, copy) CKRecordID *recordID;
@end

@interface CKAsset : NSObject
- (instancetype)initWithFileURL:(NSURL *)fileURL;
@property (nonatomic, readonly, copy) NSURL *fileURL;
@end

@interface CKRecordZone : NSObject <NSSecureCoding, NSCopying>
+ (CKRecordZone *)defaultRecordZone;
- (instancetype)initWithZoneName:(NSString *)zoneName;
- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID;
@property (nonatomic, readonly, copy) CKRecordZoneID *zoneID;
@property (nonatomic, readonly, assign) NSUInteger capabilities;
@end

@interface CKRecord : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithRecordType:(NSString *)recordType;
- (instancetype)initWithRecordType:(NSString *)recordType recordID:(CKRecordID *)recordID;
- (instancetype)initWithRecordType:(NSString *)recordType zoneID:(CKRecordZoneID *)zoneID;
@property (nonatomic, readonly, copy) NSString *recordType;
@property (nonatomic, readonly, copy) CKRecordID *recordID;
@property (nonatomic, readonly, copy) NSString *recordChangeTag;
@property (nonatomic, readonly, copy) CKRecordID *creatorUserRecordID;
@property (nonatomic, readonly, copy) NSDate *creationDate;
@property (nonatomic, readonly, copy) CKRecordID *lastModifiedUserRecordID;
@property (nonatomic, readonly, copy) NSDate *modificationDate;
@property (nonatomic, readonly, copy) CKReference *share;
@property (nonatomic, copy) CKReference *parent;
- (id)objectForKey:(NSString *)key;
- (void)setObject:(id)object forKey:(NSString *)key;
- (id)objectForKeyedSubscript:(NSString *)key;
- (void)setObject:(id)object forKeyedSubscript:(NSString *)key;
- (NSArray *)allKeys;
- (NSArray *)allTokens;
- (NSArray *)changedKeys;
- (void)setParentReferenceFromRecord:(CKRecord *)parentRecord;
- (void)setParentReferenceFromRecordID:(CKRecordID *)parentRecordID;
@end

static NSString *RevenantProbeDescribe(id value)
{
    if (!value) { return @"(nil)"; }
    if ([value isKindOfClass:[NSString class]]) { return [NSString stringWithFormat:@"\"%@\"", value]; }
    if ([value isKindOfClass:[NSNumber class]]) { return [NSString stringWithFormat:@"%@", value]; }
    if ([value isKindOfClass:[NSData class]]) {
        NSData *data = value;
        NSMutableString *hex = [NSMutableString stringWithCapacity:data.length * 2];
        for (NSUInteger at = 0; at < data.length; at++) {
            [hex appendFormat:@"%02x", ((const uint8_t *)data.bytes)[at]];
        }
        return [NSString stringWithFormat:@"<%lu bytes: %@>", (unsigned long)data.length, hex];
    }
    if ([value isKindOfClass:[NSDate class]]) {
        return [NSString stringWithFormat:@"<date %.0f>", [value timeIntervalSince1970] * 1000];
    }
    if ([value isKindOfClass:[NSArray class]]) {
        NSMutableArray *parts = [NSMutableArray array];
        for (id item in (NSArray *)value) { [parts addObject:RevenantProbeDescribe(item)]; }
        return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@", "]];
    }
    if ([value isKindOfClass:[NSURL class]]) { return [NSString stringWithFormat:@"<url %@>", [value absoluteString]]; }
    return [NSString stringWithFormat:@"<%@: %p>", [value class], value];
}

static void RevenantProbeRoundTrip(Class cls, id object, NSMutableDictionary *out)
{
    NSString *key = [NSString stringWithFormat:@"archive.%@", NSStringFromClass(cls)];
    NSError *error = nil;
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:object requiringSecureCoding:YES error:&error];
    if (!data) {
        out[key] = [NSString stringWithFormat:@"encode failed: %@", error.localizedDescription];
        return;
    }
    id back = [NSKeyedUnarchiver unarchivedObjectOfClass:cls fromData:data error:&error];
    out[key] = back ? @"decoded" : [NSString stringWithFormat:@"unarchive failed: %@", error.localizedDescription];
    if (!back) { return; }
    out[[key stringByAppendingString:@".equal"]] =
        back == object ? @"identical" : ([back isEqual:object] ? @"equal" : @"different");
    out[[key stringByAppendingString:@".bytes"]] = [NSString stringWithFormat:@"%lu", (unsigned long)data.length];
}

static id RevenantProbeTry(NSMutableDictionary *out, NSString *key, id (^body)(void))
{
    @try {
        return body();
    } @catch (NSException *exception) {
        out[key] = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
        return nil;
    }
}

static void RevenantProbeRefusals(NSMutableDictionary *out)
{
    struct { NSString *name; id (^make)(void); } cases[] = {
        {@"CKRecordID.new", ^{ return [[NSClassFromString(@"CKRecordID") alloc] init]; }},
        {@"CKRecordZoneID.new", ^{ return [[NSClassFromString(@"CKRecordZoneID") alloc] init]; }},
        {@"CKServerChangeToken.new", ^{ return [[NSClassFromString(@"CKServerChangeToken") alloc] init]; }},
        {@"CKReference.new", ^{ return [[NSClassFromString(@"CKReference") alloc] init]; }},
        {@"CKAsset.new", ^{ return [[NSClassFromString(@"CKAsset") alloc] init]; }},
        {@"CKRecordZone.new", ^{ return [[NSClassFromString(@"CKRecordZone") alloc] init]; }},
        {@"CKRecord.new", ^{ return [[NSClassFromString(@"CKRecord") alloc] init]; }},
        {@"CKRecordID.nilName", ^{ return [[NSClassFromString(@"CKRecordID") alloc] initWithRecordName:nil]; }},
        {@"CKRecordZoneID.nilZone", ^{ return [[NSClassFromString(@"CKRecordZoneID") alloc] initWithZoneName:nil ownerName:nil]; }},
        {@"CKReference.nilRecordID", ^{
            return [[NSClassFromString(@"CKReference") alloc] initWithRecordID:nil action:0]; }},
    };
    for (NSUInteger at = 0; at < sizeof cases / sizeof cases[0]; at++) {
        @try {
            id made = cases[at].make();
            out[cases[at].name] = [NSString stringWithFormat:@"made %@", RevenantProbeDescribe(made)];
        } @catch (NSException *exception) {
            out[cases[at].name] = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
        }
    }
}

static void RevenantRecordCases(NSMutableDictionary *out)
{
    @autoreleasepool {
        CKRecordZoneID *zone = [[CKRecordZoneID alloc] initWithZoneName:@"widgets" ownerName:@"_defaultOwner"];
        out[@"zoneID.zoneName"] = zone.zoneName;
        out[@"zoneID.ownerName"] = zone.ownerName;
        out[@"zoneID.describes"] = RevenantProbeDescribe(zone);

        CKRecordZoneID *other = [[CKRecordZoneID alloc] initWithZoneName:@"widgets" ownerName:@"_defaultOwner"];
        out[@"zoneID.equal"] = [zone isEqual:other] ? @"equal" : @"different";
        out[@"zoneID.hash.equal"] = @(zone.hash == other.hash) ? @"same" : @"different";
        CKRecordZoneID *otherOwner = [[CKRecordZoneID alloc] initWithZoneName:@"widgets" ownerName:@"someone-else"];
        out[@"zoneID.otherOwner.equal"] = [zone isEqual:otherOwner] ? @"equal" : @"different";

        CKRecordID *named = [[CKRecordID alloc] initWithRecordName:@"a-record"];
        out[@"recordID.recordName"] = named.recordName;
        out[@"recordID.zoneID"] = RevenantProbeDescribe(named.zoneID);
        out[@"recordID.zoneID.zoneName"] = named.zoneID.zoneName;
        out[@"recordID.zoneID.ownerName"] = named.zoneID.ownerName;

        CKRecordID *inZone = [[CKRecordID alloc] initWithRecordName:@"a-record" zoneID:zone];
        out[@"recordID.inZone.zoneID.zoneName"] = inZone.zoneID.zoneName;
        out[@"recordID.inZone.recordName"] = inZone.recordName;
        out[@"recordID.plain.inZone.equal"] = [named isEqual:inZone] ? @"equal" : @"different";
        CKRecordID *otherName = [[CKRecordID alloc] initWithRecordName:@"another"];
        out[@"recordID.otherName.equal"] = [named isEqual:otherName] ? @"equal" : @"different";
        CKRecordID *sameElsewhere = [[CKRecordID alloc] initWithRecordName:@"a-record" zoneID:zone];
        out[@"recordID.sameInZone.equal"] = [named isEqual:sameElsewhere] ? @"equal" : @"different";
        out[@"recordID.sameInZone.inZone.equal"] = [inZone isEqual:sameElsewhere] ? @"equal" : @"different";

        CKRecordZone *defaultZone = [CKRecordZone defaultRecordZone];
        out[@"defaultRecordZone.zoneName"] = defaultZone.zoneID.zoneName;
        out[@"defaultRecordZone.ownerName"] = defaultZone.zoneID.ownerName;
        out[@"defaultRecordZone.capabilities"] = @(defaultZone.capabilities);
        out[@"defaultRecordZone.twice.equal"] =
            [[CKRecordZone defaultRecordZone] isEqual:defaultZone] ? @"equal" : @"different";
        out[@"defaultRecordZone.id"] = RevenantProbeDescribe(defaultZone.zoneID);

        CKRecordZone *byName = [[CKRecordZone alloc] initWithZoneName:@"widgets"];
        out[@"zone.byName.zoneName"] = byName.zoneID.zoneName;
        out[@"zone.byName.ownerName"] = byName.zoneID.ownerName;
        out[@"zone.byName.capabilities"] = @(byName.capabilities);
        CKRecordZone *byID = [[CKRecordZone alloc] initWithZoneID:zone];
        out[@"zone.byID.zoneName"] = byID.zoneID.zoneName;
        out[@"zone.byID.capabilities"] = @(byID.capabilities);
        CKRecordZone *byIDagain = [[CKRecordZone alloc] initWithZoneID:other];
        out[@"zone.sameName.equal"] = [byName isEqual:byID] ? @"equal" : @"different";
        out[@"zone.otherOwner.equal"] = [byID isEqual:byIDagain] ? @"equal" : @"different";
        out[@"zone.copy.equal"] = [[byID copy] isEqual:byID] ? @"equal" : @"different";

        CKReference *ref = [[CKReference alloc] initWithRecordID:inZone action:CKReferenceActionDeleteSelf];
        out[@"reference.action"] = @(ref.referenceAction);
        out[@"reference.recordID.recordName"] = ref.recordID.recordName;
        out[@"reference.recordID.zoneName"] = ref.recordID.zoneID.zoneName;
        CKReference *plain = [[CKReference alloc] initWithRecordID:inZone action:CKReferenceActionNone];
        out[@"reference.plain.action"] = @(plain.referenceAction);
        out[@"reference.same.equal"] = [ref isEqual:plain] ? @"equal" : @"different";
        CKReference *fromRecord = [[CKReference alloc] initWithRecord:
                                    [[CKRecord alloc] initWithRecordType:@"T" recordID:inZone]
                                                          action:CKReferenceActionNone];
        out[@"reference.fromRecord.recordName"] = fromRecord.recordID.recordName;
        out[@"reference.fromRecord.zoneName"] = fromRecord.recordID.zoneID.zoneName;
        out[@"reference.copy.equal"] = [[ref copy] isEqual:ref] ? @"equal" : @"different";

        NSURL *missing = [NSURL fileURLWithPath:@"/private/tmp/cloudkit-does-not-exist.bin"];
        CKAsset *nilAsset = RevenantProbeTry(out, @"asset.nilURL", ^{ return [[CKAsset alloc] initWithFileURL:nil]; });
        out[@"asset.nilURL.fileURL"] = RevenantProbeDescribe(nilAsset.fileURL);
        CKAsset *missingAsset = [[CKAsset alloc] initWithFileURL:missing];
        out[@"asset.missingURL.fileURL"] = RevenantProbeDescribe(missingAsset.fileURL);
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"cloudkit-asset.bin"];
        [[NSData dataWithBytes:"asset-bytes" length:11] writeToFile:path atomically:YES];
        CKAsset *real = [[CKAsset alloc] initWithFileURL:[NSURL fileURLWithPath:path]];
        out[@"asset.realURL.isFile"] = real.fileURL ? @"yes" : @"no";
        out[@"asset.realURL.name"] = [real.fileURL lastPathComponent];
        out[@"asset.realURL.exists"] = [[NSFileManager defaultManager] fileExistsAtPath:real.fileURL.path] ? @"yes" : @"no";
        out[@"asset.same.equal"] = [real isEqual:missingAsset] ? @"equal" : @"different";
        RevenantProbeTry(out, @"asset.copy", ^{
            id copied = [real copy];
            return [NSString stringWithFormat:@"%@", RevenantProbeDescribe(copied)];
        });

        CKRecord *record = [[CKRecord alloc] initWithRecordType:@"Widget"];
        out[@"record.recordType"] = record.recordType;
        out[@"record.recordID.recordName"] = record.recordID.recordName;
        out[@"record.recordID.zoneName"] = record.recordID.zoneID.zoneName;
        out[@"record.recordID.ownerName"] = record.recordID.zoneID.ownerName;
        out[@"record.recordChangeTag"] = RevenantProbeDescribe(record.recordChangeTag);
        out[@"record.creatorUserRecordID"] = RevenantProbeDescribe(record.creatorUserRecordID);
        out[@"record.creationDate"] = RevenantProbeDescribe(record.creationDate);
        out[@"record.lastModifiedUserRecordID"] = RevenantProbeDescribe(record.lastModifiedUserRecordID);
        out[@"record.modificationDate"] = RevenantProbeDescribe(record.modificationDate);
        out[@"record.share"] = RevenantProbeDescribe(record.share);
        out[@"record.parent"] = RevenantProbeDescribe(record.parent);
        out[@"record.allKeys.empty"] = [NSString stringWithFormat:@"%lu", (unsigned long)record.allKeys.count];
        out[@"record.changedKeys.empty"] = [NSString stringWithFormat:@"%lu", (unsigned long)record.changedKeys.count];
        out[@"record.allTokens.empty"] = [NSString stringWithFormat:@"%lu", (unsigned long)record.allTokens.count];
        out[@"record.missingKey"] = RevenantProbeDescribe([record objectForKey:@"nope"]);

        CKRecord *inZoneRecord = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        out[@"record.givenID.recordName"] = inZoneRecord.recordID.recordName;
        out[@"record.givenID.zoneName"] = inZoneRecord.recordID.zoneID.zoneName;
        CKRecord *byZone = [[CKRecord alloc] initWithRecordType:@"Widget" zoneID:zone];
        out[@"record.byZone.zoneName"] = byZone.recordID.zoneID.zoneName;
        out[@"record.byZone.recordName"] = byZone.recordID.recordName;
        out[@"record.sameType.equal"] = [record isEqual:byZone] ? @"equal" : @"different";
        out[@"record.sameTypeAndID.equal"] = [inZoneRecord isEqual:byZone] ? @"equal" : @"different";

        CKRecord *fields = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        [fields setObject:@"a string" forKey:@"name"];
        [fields setObject:[NSNumber numberWithInt:42] forKey:@"count"];
        [fields setObject:[NSDate dateWithTimeIntervalSince1970:1000000] forKey:@"when"];
        [fields setObject:[NSData dataWithBytes:"ab" length:2] forKey:@"blob"];
        [fields setObject:real forKey:@"attachment"];
        [fields setObject:ref forKey:@"link"];
        out[@"fields.allKeys.count"] = [NSString stringWithFormat:@"%lu", (unsigned long)fields.allKeys.count];
        NSArray *keys = [fields.allKeys sortedArrayUsingSelector:@selector(compare:)];
        out[@"fields.allKeys.sorted"] = RevenantProbeDescribe(keys);
        out[@"fields.name"] = RevenantProbeDescribe([fields objectForKey:@"name"]);
        out[@"fields.count"] = RevenantProbeDescribe([fields objectForKey:@"count"]);
        out[@"fields.when"] = RevenantProbeDescribe([fields objectForKey:@"when"]);
        out[@"fields.blob"] = RevenantProbeDescribe([fields objectForKey:@"blob"]);
        out[@"fields.link.action"] = @([[fields objectForKey:@"link"] referenceAction]);
        out[@"fields.attachment"] = [fields objectForKey:@"attachment"] ? @"present" : @"(nil)";
        out[@"fields.name.class"] = NSStringFromClass([[fields objectForKey:@"name"] class]);
        out[@"fields.count.class"] = NSStringFromClass([[fields objectForKey:@"count"] class]);
        out[@"fields.blob.class"] = NSStringFromClass([[fields objectForKey:@"blob"] class]);

        [fields setObject:@"another" forKey:@"name"];
        out[@"fields.overwritten"] = RevenantProbeDescribe([fields objectForKey:@"name"]);
        out[@"fields.afterOverwrite.count"] = [NSString stringWithFormat:@"%lu", (unsigned long)fields.allKeys.count];
        [fields setObject:nil forKey:@"name"];
        out[@"fields.removed"] = RevenantProbeDescribe([fields objectForKey:@"name"]);
        out[@"fields.afterRemoval.count"] = [NSString stringWithFormat:@"%lu", (unsigned long)fields.allKeys.count];
        out[@"fields.afterRemoval.sorted"] =
            RevenantProbeDescribe([fields.allKeys sortedArrayUsingSelector:@selector(compare:)]);

        out[@"fields.changedKeys.afterRemoval"] =
            RevenantProbeDescribe([fields.changedKeys sortedArrayUsingSelector:@selector(compare:)]);

        CKRecord *sub = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        sub[@"viaSubscript"] = @"set";
        out[@"fields.subscriptRead"] = RevenantProbeDescribe(sub[@"viaSubscript"]);
        out[@"fields.subscriptMatches"] = [sub objectForKey:@"viaSubscript"] == sub[@"viaSubscript"] ? @"same" : @"different";
        sub[@"viaSubscript"] = nil;
        out[@"fields.subscriptAfterNil"] = RevenantProbeDescribe(sub[@"viaSubscript"]);

        for (NSString *bad in @[@"via-subscript", @"", @"with space", @"with.dot", @"1leading"]) {
            NSString *label = [NSString stringWithFormat:@"fields.badKey.%@", bad.length ? bad : @"empty"];
            CKRecord *probe = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
            RevenantProbeTry(out, label, ^{
                [probe setObject:@"x" forKey:bad];
                return [NSString stringWithFormat:@"accepted, allKeys=%lu", (unsigned long)probe.allKeys.count];
            });
        }

        out[@"fields.allTokens.count"] = [NSString stringWithFormat:@"%lu", (unsigned long)fields.allTokens.count];
        out[@"fields.allTokens.sorted"] = RevenantProbeDescribe([fields.allTokens sortedArrayUsingSelector:@selector(compare:)]);

        CKRecord *copied = [fields copy];
        out[@"fields.copy.count"] = [NSString stringWithFormat:@"%lu", (unsigned long)copied.allKeys.count];
        out[@"fields.copy.blob"] = RevenantProbeDescribe([copied objectForKey:@"blob"]);
        out[@"fields.copy.equal"] = [copied isEqual:fields] ? @"equal" : @"different";

        CKRecord *parented = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        CKRecord *crossZone = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        RevenantProbeTry(out, @"record.parent.crossZone", ^{
            [crossZone setParentReferenceFromRecordID:otherName];
            return [NSString stringWithFormat:@"taken, zone %@", crossZone.parent.recordID.zoneID.zoneName];
        });
        out[@"record.parent.recordName"] = crossZone.parent.recordID.recordName;
        out[@"record.parent.zoneName"] = crossZone.parent.recordID.zoneID.zoneName;
        out[@"record.parent.action"] = @(crossZone.parent.referenceAction);

        CKRecord *sameZone = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        RevenantProbeTry(out, @"record.parent.sameZone", ^{
            [sameZone setParentReferenceFromRecord:[[CKRecord alloc] initWithRecordType:@"P" recordID:sameElsewhere]];
            return [NSString stringWithFormat:@"taken, zone %@", sameZone.parent.recordID.zoneID.zoneName];
        });
        out[@"record.parent.fromRecord.name"] = sameZone.parent.recordID.recordName;
        out[@"record.parent.fromRecord.zoneName"] = sameZone.parent.recordID.zoneID.zoneName;

        RevenantProbeTry(out, @"record.parent.cleared", ^{
            [sameZone setParentReferenceFromRecord:nil];
            return RevenantProbeDescribe(sameZone.parent);
        });
        out[@"record.parent.cleared"] = RevenantProbeDescribe(sameZone.parent);

        out[@"record.parent.isReadable"] = sameZone.parent ? @"yes" : @"no";

        RevenantProbeRefusals(out);
        out[@"copy.zoneID"] = [[zone copy] isEqual:zone] ? @"equal" : @"different";
        out[@"copy.recordID"] = [[inZone copy] isEqual:inZone] ? @"equal" : @"different";
        RevenantProbeRoundTrip([CKRecordZoneID class], zone, out);
        RevenantProbeRoundTrip([CKRecordID class], inZone, out);
        RevenantProbeRoundTrip([CKRecordZone class], byID, out);
        RevenantProbeRoundTrip([CKReference class], ref, out);
        RevenantProbeRoundTrip([CKRecord class], fields, out);

        out[@"token.conforms"] = RevenantProbeDescribe([CKServerChangeToken class]);
        out[@"token.new"] = RevenantProbeDescribe(RevenantProbeTry(out, @"token.newCall", ^{
            return [[NSClassFromString(@"CKServerChangeToken") alloc] init];
        }));
        out[@"token.isSecureCoding"] =
            [NSClassFromString(@"CKServerChangeToken") conformsToProtocol:@protocol(NSSecureCoding)] ? @"yes" : @"no";
        out[@"token.isCopying"] =
            [NSClassFromString(@"CKServerChangeToken") conformsToProtocol:@protocol(NSCopying)] ? @"yes" : @"no";
        out[@"asset.isSecureCoding"] =
            [NSClassFromString(@"CKAsset") conformsToProtocol:@protocol(NSSecureCoding)] ? @"yes" : @"no";
        out[@"asset.isCopying"] =
            [NSClassFromString(@"CKAsset") conformsToProtocol:@protocol(NSCopying)] ? @"yes" : @"no";
        out[@"zone.isEqualOverridden"] =
            [NSClassFromString(@"CKRecordZone") instancesRespondToSelector:@selector(isEqual:)] ? @"responds" : @"inherited";
    }
}

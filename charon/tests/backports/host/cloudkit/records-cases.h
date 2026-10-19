// The record value half, asked once of whichever CloudKit this binary was compiled against.
//
// One file, two builds: record.m compiles it against the host's own CloudKit, and the port's runner
// compiles it against packages/a/apple-backports/CloudKit with no framework linked at all. The port
// ships the real CK names - it *is* the CloudKit backport - so the two cannot be in one binary, and
// running the same cases against both is what makes the comparison a statement about behaviour
// rather than about a re-implementation.
//
// Nothing here asks for a container, a database, a fetch or a save, so nothing here touches the
// network or anyone's own iCloud account. Every case builds its objects in memory and reads them
// back: the record names, the zones, the fields, the equality, the copy and the archive round trip.

#import <Foundation/Foundation.h>

// The surface, declared here rather than imported, so this one file compiles the same way against
// the host's framework and against the port: the host build links CloudKit and gets the classes from
// the runtime, the port build links nothing and gets them from packages/a/apple-backports. The
// declarations are the device SDK's, which is the release the port carries.
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

static NSString *CharonProbeDescribe(id value)
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
        for (id item in (NSArray *)value) { [parts addObject:CharonProbeDescribe(item)]; }
        return [NSString stringWithFormat:@"[%@]", [parts componentsJoinedByString:@", "]];
    }
    if ([value isKindOfClass:[NSURL class]]) { return [NSString stringWithFormat:@"<url %@>", [value absoluteString]]; }
    return [NSString stringWithFormat:@"<%@: %p>", [value class], value];
}

// The archive round trip, and what it does to each class. The one-argument archiver and unarchiver
// are used rather than the inits that take an NSError, because the macOS SDK's Foundation - the one a
// Mac Catalyst binary compiles against - has no initRequiringSecureCoding:error:.
static void CharonProbeRoundTrip(Class cls, id object, NSMutableDictionary *out)
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

// A call that may refuse, recorded either way: what the host raises is the answer the port owes, and
// a case that lets an exception out of the probe records nothing at all.
static id CharonProbeTry(NSMutableDictionary *out, NSString *key, id (^body)(void))
{
    @try {
        return body();
    } @catch (NSException *exception) {
        out[key] = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
        return nil;
    }
}

static void CharonProbeRefusals(NSMutableDictionary *out)
{
    // The initializers the headers mark NS_UNAVAILABLE. What the host actually does is the thing the
    // port has to answer, and a header is not a measurement.
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
            out[cases[at].name] = [NSString stringWithFormat:@"made %@", CharonProbeDescribe(made)];
        } @catch (NSException *exception) {
            out[cases[at].name] = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
        }
    }
}

static void CharonRecordCases(NSMutableDictionary *out)
{
    @autoreleasepool {
        // --- the zone identifiers, which every other value is named inside
        CKRecordZoneID *zone = [[CKRecordZoneID alloc] initWithZoneName:@"widgets" ownerName:@"_defaultOwner"];
        out[@"zoneID.zoneName"] = zone.zoneName;
        out[@"zoneID.ownerName"] = zone.ownerName;
        out[@"zoneID.describes"] = CharonProbeDescribe(zone);

        CKRecordZoneID *other = [[CKRecordZoneID alloc] initWithZoneName:@"widgets" ownerName:@"_defaultOwner"];
        out[@"zoneID.equal"] = [zone isEqual:other] ? @"equal" : @"different";
        out[@"zoneID.hash.equal"] = @(zone.hash == other.hash) ? @"same" : @"different";
        CKRecordZoneID *otherOwner = [[CKRecordZoneID alloc] initWithZoneName:@"widgets" ownerName:@"someone-else"];
        out[@"zoneID.otherOwner.equal"] = [zone isEqual:otherOwner] ? @"equal" : @"different";

        // --- the record name, and the zone a name lands in when none is given
        CKRecordID *named = [[CKRecordID alloc] initWithRecordName:@"a-record"];
        out[@"recordID.recordName"] = named.recordName;
        out[@"recordID.zoneID"] = CharonProbeDescribe(named.zoneID);
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

        // --- the default zone, and the constant that names it
        CKRecordZone *defaultZone = [CKRecordZone defaultRecordZone];
        out[@"defaultRecordZone.zoneName"] = defaultZone.zoneID.zoneName;
        out[@"defaultRecordZone.ownerName"] = defaultZone.zoneID.ownerName;
        out[@"defaultRecordZone.capabilities"] = @(defaultZone.capabilities);
        out[@"defaultRecordZone.twice.equal"] =
            [[CKRecordZone defaultRecordZone] isEqual:defaultZone] ? @"equal" : @"different";
        out[@"defaultRecordZone.id"] = CharonProbeDescribe(defaultZone.zoneID);

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

        // --- a reference, and the two things it can point at
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

        // --- an asset, with a file behind it and without one
        NSURL *missing = [NSURL fileURLWithPath:@"/private/tmp/cloudkit-does-not-exist.bin"];
        CKAsset *nilAsset = CharonProbeTry(out, @"asset.nilURL", ^{ return [[CKAsset alloc] initWithFileURL:nil]; });
        out[@"asset.nilURL.fileURL"] = CharonProbeDescribe(nilAsset.fileURL);
        CKAsset *missingAsset = [[CKAsset alloc] initWithFileURL:missing];
        out[@"asset.missingURL.fileURL"] = CharonProbeDescribe(missingAsset.fileURL);
        NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"cloudkit-asset.bin"];
        [[NSData dataWithBytes:"asset-bytes" length:11] writeToFile:path atomically:YES];
        CKAsset *real = [[CKAsset alloc] initWithFileURL:[NSURL fileURLWithPath:path]];
        out[@"asset.realURL.isFile"] = real.fileURL ? @"yes" : @"no";
        out[@"asset.realURL.name"] = [real.fileURL lastPathComponent];
        out[@"asset.realURL.exists"] = [[NSFileManager defaultManager] fileExistsAtPath:real.fileURL.path] ? @"yes" : @"no";
        out[@"asset.same.equal"] = [real isEqual:missingAsset] ? @"equal" : @"different";
        // CKAsset is not NSCopying on iOS - its @interface says plain NSObject - so what -copy does is
        // part of the surface and is recorded rather than assumed
        CharonProbeTry(out, @"asset.copy", ^{
            id copied = [real copy];
            return [NSString stringWithFormat:@"%@", CharonProbeDescribe(copied)];
        });

        // --- a record, and every field it answers before anything has been saved
        CKRecord *record = [[CKRecord alloc] initWithRecordType:@"Widget"];
        out[@"record.recordType"] = record.recordType;
        out[@"record.recordID.recordName"] = record.recordID.recordName;
        out[@"record.recordID.zoneName"] = record.recordID.zoneID.zoneName;
        out[@"record.recordID.ownerName"] = record.recordID.zoneID.ownerName;
        out[@"record.recordChangeTag"] = CharonProbeDescribe(record.recordChangeTag);
        out[@"record.creatorUserRecordID"] = CharonProbeDescribe(record.creatorUserRecordID);
        out[@"record.creationDate"] = CharonProbeDescribe(record.creationDate);
        out[@"record.lastModifiedUserRecordID"] = CharonProbeDescribe(record.lastModifiedUserRecordID);
        out[@"record.modificationDate"] = CharonProbeDescribe(record.modificationDate);
        out[@"record.share"] = CharonProbeDescribe(record.share);
        out[@"record.parent"] = CharonProbeDescribe(record.parent);
        out[@"record.allKeys.empty"] = [NSString stringWithFormat:@"%lu", (unsigned long)record.allKeys.count];
        out[@"record.changedKeys.empty"] = [NSString stringWithFormat:@"%lu", (unsigned long)record.changedKeys.count];
        out[@"record.allTokens.empty"] = [NSString stringWithFormat:@"%lu", (unsigned long)record.allTokens.count];
        out[@"record.missingKey"] = CharonProbeDescribe([record objectForKey:@"nope"]);

        CKRecord *inZoneRecord = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        out[@"record.givenID.recordName"] = inZoneRecord.recordID.recordName;
        out[@"record.givenID.zoneName"] = inZoneRecord.recordID.zoneID.zoneName;
        CKRecord *byZone = [[CKRecord alloc] initWithRecordType:@"Widget" zoneID:zone];
        out[@"record.byZone.zoneName"] = byZone.recordID.zoneID.zoneName;
        out[@"record.byZone.recordName"] = byZone.recordID.recordName;
        out[@"record.sameType.equal"] = [record isEqual:byZone] ? @"equal" : @"different";
        out[@"record.sameTypeAndID.equal"] = [inZoneRecord isEqual:byZone] ? @"equal" : @"different";

        // --- the field store, which is the part with the most to answer
        CKRecord *fields = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        [fields setObject:@"a string" forKey:@"name"];
        [fields setObject:[NSNumber numberWithInt:42] forKey:@"count"];
        [fields setObject:[NSDate dateWithTimeIntervalSince1970:1000000] forKey:@"when"];
        [fields setObject:[NSData dataWithBytes:"ab" length:2] forKey:@"blob"];
        [fields setObject:real forKey:@"attachment"];
        [fields setObject:ref forKey:@"link"];
        out[@"fields.allKeys.count"] = [NSString stringWithFormat:@"%lu", (unsigned long)fields.allKeys.count];
        NSArray *keys = [fields.allKeys sortedArrayUsingSelector:@selector(compare:)];
        out[@"fields.allKeys.sorted"] = CharonProbeDescribe(keys);
        out[@"fields.name"] = CharonProbeDescribe([fields objectForKey:@"name"]);
        out[@"fields.count"] = CharonProbeDescribe([fields objectForKey:@"count"]);
        out[@"fields.when"] = CharonProbeDescribe([fields objectForKey:@"when"]);
        out[@"fields.blob"] = CharonProbeDescribe([fields objectForKey:@"blob"]);
        out[@"fields.link.action"] = @([[fields objectForKey:@"link"] referenceAction]);
        out[@"fields.attachment"] = [fields objectForKey:@"attachment"] ? @"present" : @"(nil)";
        out[@"fields.name.class"] = NSStringFromClass([[fields objectForKey:@"name"] class]);
        out[@"fields.count.class"] = NSStringFromClass([[fields objectForKey:@"count"] class]);
        out[@"fields.blob.class"] = NSStringFromClass([[fields objectForKey:@"blob"] class]);

        // overwriting keeps one key, setting nil removes it
        [fields setObject:@"another" forKey:@"name"];
        out[@"fields.overwritten"] = CharonProbeDescribe([fields objectForKey:@"name"]);
        out[@"fields.afterOverwrite.count"] = [NSString stringWithFormat:@"%lu", (unsigned long)fields.allKeys.count];
        [fields setObject:nil forKey:@"name"];
        out[@"fields.removed"] = CharonProbeDescribe([fields objectForKey:@"name"]);
        out[@"fields.afterRemoval.count"] = [NSString stringWithFormat:@"%lu", (unsigned long)fields.allKeys.count];
        out[@"fields.afterRemoval.sorted"] =
            CharonProbeDescribe([fields.allKeys sortedArrayUsingSelector:@selector(compare:)]);

        // changedKeys: what the record says it has touched
        out[@"fields.changedKeys.afterRemoval"] =
            CharonProbeDescribe([fields.changedKeys sortedArrayUsingSelector:@selector(compare:)]);

        // the subscript spelling of the same two methods
        CKRecord *sub = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        sub[@"viaSubscript"] = @"set";
        out[@"fields.subscriptRead"] = CharonProbeDescribe(sub[@"viaSubscript"]);
        out[@"fields.subscriptMatches"] = [sub objectForKey:@"viaSubscript"] == sub[@"viaSubscript"] ? @"same" : @"different";
        sub[@"viaSubscript"] = nil;
        out[@"fields.subscriptAfterNil"] = CharonProbeDescribe(sub[@"viaSubscript"]);

        // the field key grammar, which is not "any string": what the host refuses is the answer
        for (NSString *bad in @[@"via-subscript", @"", @"with space", @"with.dot", @"1leading"]) {
            NSString *label = [NSString stringWithFormat:@"fields.badKey.%@", bad.length ? bad : @"empty"];
            CKRecord *probe = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
            CharonProbeTry(out, label, ^{
                [probe setObject:@"x" forKey:bad];
                return [NSString stringWithFormat:@"accepted, allKeys=%lu", (unsigned long)probe.allKeys.count];
            });
        }

        // allTokens: the field type names, and whether it has them
        out[@"fields.allTokens.count"] = [NSString stringWithFormat:@"%lu", (unsigned long)fields.allTokens.count];
        out[@"fields.allTokens.sorted"] = CharonProbeDescribe([fields.allTokens sortedArrayUsingSelector:@selector(compare:)]);

        // a copy carries the fields
        CKRecord *copied = [fields copy];
        out[@"fields.copy.count"] = [NSString stringWithFormat:@"%lu", (unsigned long)copied.allKeys.count];
        out[@"fields.copy.blob"] = CharonProbeDescribe([copied objectForKey:@"blob"]);
        out[@"fields.copy.equal"] = [copied isEqual:fields] ? @"equal" : @"different";

        // the parent, set both ways
        CKRecord *parented = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        // a parent in the default zone for a record in widgets, and one in widgets: which of the two
        // the host takes, and what it says to the other
        CKRecord *crossZone = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        CharonProbeTry(out, @"record.parent.crossZone", ^{
            [crossZone setParentReferenceFromRecordID:otherName];
            return [NSString stringWithFormat:@"taken, zone %@", crossZone.parent.recordID.zoneID.zoneName];
        });
        out[@"record.parent.recordName"] = crossZone.parent.recordID.recordName;
        out[@"record.parent.zoneName"] = crossZone.parent.recordID.zoneID.zoneName;
        out[@"record.parent.action"] = @(crossZone.parent.referenceAction);

        CKRecord *sameZone = [[CKRecord alloc] initWithRecordType:@"Widget" recordID:inZone];
        CharonProbeTry(out, @"record.parent.sameZone", ^{
            [sameZone setParentReferenceFromRecord:[[CKRecord alloc] initWithRecordType:@"P" recordID:sameElsewhere]];
            return [NSString stringWithFormat:@"taken, zone %@", sameZone.parent.recordID.zoneID.zoneName];
        });
        out[@"record.parent.fromRecord.name"] = sameZone.parent.recordID.recordName;
        out[@"record.parent.fromRecord.zoneName"] = sameZone.parent.recordID.zoneID.zoneName;

        CharonProbeTry(out, @"record.parent.cleared", ^{
            [sameZone setParentReferenceFromRecord:nil];
            return CharonProbeDescribe(sameZone.parent);
        });
        out[@"record.parent.cleared"] = CharonProbeDescribe(sameZone.parent);

        // and the parent read back off a record that has one
        out[@"record.parent.isReadable"] = sameZone.parent ? @"yes" : @"no";

        // --- the refusals, and the copy and the archive for each class
        CharonProbeRefusals(out);
        out[@"copy.zoneID"] = [[zone copy] isEqual:zone] ? @"equal" : @"different";
        out[@"copy.recordID"] = [[inZone copy] isEqual:inZone] ? @"equal" : @"different";
        CharonProbeRoundTrip([CKRecordZoneID class], zone, out);
        CharonProbeRoundTrip([CKRecordID class], inZone, out);
        CharonProbeRoundTrip([CKRecordZone class], byID, out);
        CharonProbeRoundTrip([CKReference class], ref, out);
        CharonProbeRoundTrip([CKRecord class], fields, out);

        // The token cannot be made - every initializer refuses - so what it conforms to is asked of the
        // runtime rather than guessed, and its archive is left unmeasured rather than claimed.
        out[@"token.conforms"] = CharonProbeDescribe([CKServerChangeToken class]);
        out[@"token.new"] = CharonProbeDescribe(CharonProbeTry(out, @"token.newCall", ^{
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

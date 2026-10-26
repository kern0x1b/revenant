#import "RevenantCloudKit.h"
#import "RevenantCKConstants.h"
#import "RevenantCKRecordPrivate.h"

static NSString *const RevenantCKExceptionName = @"CKException";
static NSString *const RevenantCKInvalidArgumentName = @"NSInvalidArgumentException";

static void RevenantCKRefuse(NSString *name, NSString *reason)
{
    [[NSException exceptionWithName:name reason:reason userInfo:nil] raise];
}

static BOOL RevenantCKFieldKeyIsValid(NSString *key)
{
    if (![key isKindOfClass:[NSString class]] || key.length == 0) {
        RevenantCKRefuse(RevenantCKInvalidArgumentName, @"recordKey can not be empty");
        return NO;
    }
    static NSCharacterSet *first = nil;
    static NSCharacterSet *rest = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *letters = [NSMutableCharacterSet characterSetWithCharactersInString:
                                           @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_"];
        first = [letters copy];
        [letters addCharactersInString:@"0123456789$"];
        rest = [letters copy];
    });
    if (![first characterIsMember:[key characterAtIndex:0]]) {
        RevenantCKRefuse(RevenantCKInvalidArgumentName,
                       [NSString stringWithFormat:@"recordKey (%@) contains invalid characters", key]);
        return NO;
    }
    for (NSUInteger at = 1; at < key.length; at++) {
        if (![rest characterIsMember:[key characterAtIndex:at]]) {
            RevenantCKRefuse(RevenantCKInvalidArgumentName,
                           [NSString stringWithFormat:@"recordKey (%@) contains invalid characters", key]);
            return NO;
        }
    }
    return YES;
}

#pragma mark - CKRecordZoneID

@implementation CKRecordZoneID {
    NSString *_zoneName;
    NSString *_ownerName;
}
@synthesize zoneName = _zoneName;
@synthesize ownerName = _ownerName;

- (instancetype)init
{
    RevenantCKRefuse(RevenantCKInvalidArgumentName,
                   @"You must call -[CKRecordZoneID initWithZoneName:ownerName:]");
    return nil;
}

- (instancetype)initWithZoneName:(NSString *)zoneName ownerName:(NSString *)ownerName
{
    if (!zoneName) {
        RevenantCKRefuse(RevenantCKExceptionName, @"zoneName can not be nil");
    }
    if (!ownerName) {
        RevenantCKRefuse(RevenantCKExceptionName, @"ownerName can not be nil");
    }
    self = [super init];
    if (self) {
        _zoneName = [zoneName copy];
        _ownerName = [ownerName copy];
    }
    return self;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *zoneName = [coder decodeObjectOfClass:[NSString class] forKey:@"zoneName"];
    NSString *ownerName = [coder decodeObjectOfClass:[NSString class] forKey:@"ownerName"];
    return [self initWithZoneName:zoneName ownerName:ownerName];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_zoneName forKey:@"zoneName"];
    [coder encodeObject:_ownerName forKey:@"ownerName"];
}

- (id)copyWithZone:(NSZone *)zone { return self; }

- (BOOL)isEqual:(id)other
{
    if (self == other) { return YES; }
    if (![other isKindOfClass:[CKRecordZoneID class]]) { return NO; }
    CKRecordZoneID *that = other;
    return [_zoneName isEqualToString:that->_zoneName] && [_ownerName isEqualToString:that->_ownerName];
}

- (NSUInteger)hash { return _zoneName.hash ^ _ownerName.hash; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKRecordZoneID: %@/%@>", _zoneName, _ownerName];
}


+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must call -[CKRecordZoneID initWithZoneName:ownerName:]", nil];
    return nil;
}

@end

#pragma mark - CKRecordID

@implementation CKRecordID {
    NSString *_recordName;
    CKRecordZoneID *_zoneID;
}
@synthesize recordName = _recordName;
@synthesize zoneID = _zoneID;

- (instancetype)init
{
    RevenantCKRefuse(RevenantCKInvalidArgumentName,
                   @"You must call -[CKRecordID initWithRecordName:] or -[CKRecordID initWithRecordName:zoneID:]");
    return nil;
}

- (instancetype)initWithRecordName:(NSString *)recordName
{
    return [self initWithRecordName:recordName
                             zoneID:[[CKRecordZoneID alloc] initWithZoneName:CKRecordZoneDefaultName
                                                                  ownerName:CKOwnerDefaultName]];
}

- (instancetype)initWithRecordName:(NSString *)recordName zoneID:(CKRecordZoneID *)zoneID
{
    if (!recordName) {
        RevenantCKRefuse(RevenantCKExceptionName, @"recordName can not be nil");
    }
    if (!zoneID) {
        RevenantCKRefuse(RevenantCKExceptionName, @"zoneID can not be nil");
    }
    self = [super init];
    if (self) {
        _recordName = [recordName copy];
        _zoneID = [zoneID copy];
    }
    return self;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSString *name = [coder decodeObjectOfClass:[NSString class] forKey:@"recordName"];
    CKRecordZoneID *zone = [coder decodeObjectOfClass:[CKRecordZoneID class] forKey:@"zoneID"];
    return [self initWithRecordName:name zoneID:zone];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_recordName forKey:@"recordName"];
    [coder encodeObject:_zoneID forKey:@"zoneID"];
}

- (id)copyWithZone:(NSZone *)zone { return self; }

- (BOOL)isEqual:(id)other
{
    if (self == other) { return YES; }
    if (![other isKindOfClass:[CKRecordID class]]) { return NO; }
    return [_recordName isEqualToString:((CKRecordID *)other)->_recordName]
        && [_zoneID isEqual:((CKRecordID *)other)->_zoneID];
}

- (NSUInteger)hash { return _recordName.hash ^ _zoneID.hash; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKRecordID: %@ in %@>", _recordName, _zoneID];
}


+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must call -[CKRecordID initWithRecordName:] or -[CKRecordID initWithRecordName:zoneID:]", nil];
    return nil;
}

@end

#pragma mark - CKServerChangeToken

@implementation CKServerChangeToken
{
    NSData *_token;
}

- (instancetype)init
{
    RevenantCKRefuse(RevenantCKExceptionName, @"You can't call init on CKServerChangeToken");
    return nil;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder { }

- (id)copyWithZone:(NSZone *)zone { return self; }

- (NSString *)description { return @"<CKServerChangeToken>"; }


+ (instancetype)new
{
    [NSException raise:@"CKException" format:@"You can't call init on CKServerChangeToken", nil];
    return nil;
}
+ (instancetype)tokenWithData:(NSData *)data
{
    CKServerChangeToken *token = [[self alloc] initWithData:data];
    return token;
}
- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self) {
        _token = [data copy];
    }
    return self;
}
- (NSData *)data
{
    return _token;
}
- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[CKServerChangeToken class]]) {
        return NO;
    }
    return [_token isEqualToData:((CKServerChangeToken *)other)->_token];
}
- (NSUInteger)hash
{
    return _token.hash;
}

@end

#pragma mark - CKReference

@implementation CKReference {
    CKRecordID *_recordID;
    CKReferenceAction _referenceAction;
}
@synthesize recordID = _recordID;
@synthesize referenceAction = _referenceAction;

- (instancetype)init
{
    RevenantCKRefuse(RevenantCKInvalidArgumentName,
                   @"You must call -[CKReference initWithRecordID:] or -[CKReference initWithRecord:] or -[CKReference initWithAsset:]");
    return nil;
}

- (instancetype)initWithRecordID:(CKRecordID *)recordID action:(CKReferenceAction)action
{
    if (!recordID) {
        RevenantCKRefuse(RevenantCKExceptionName, @"recordID can not be nil");
    }
    self = [super init];
    if (self) {
        _recordID = [recordID copy];
        _referenceAction = action;
    }
    return self;
}

- (instancetype)initWithRecord:(CKRecord *)record action:(CKReferenceAction)action
{
    if (!record) {
        RevenantCKRefuse(RevenantCKExceptionName, @"record can not be nil");
    }
    return [self initWithRecordID:record.recordID action:action];
}

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    CKRecordID *recordID = [coder decodeObjectOfClass:[CKRecordID class] forKey:@"recordID"];
    NSNumber *action = [coder decodeObjectOfClass:[NSNumber class] forKey:@"referenceAction"];
    return [self initWithRecordID:recordID action:(CKReferenceAction)action.unsignedIntegerValue];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_recordID forKey:@"recordID"];
    [coder encodeObject:@(_referenceAction) forKey:@"referenceAction"];
}

- (id)copyWithZone:(NSZone *)zone { return self; }

- (BOOL)isEqual:(id)other
{
    if (self == other) { return YES; }
    if (![other isKindOfClass:[CKReference class]]) { return NO; }
    CKReference *that = other;
    return [_recordID isEqual:that->_recordID] && _referenceAction == that->_referenceAction;
}

- (NSUInteger)hash { return _recordID.hash ^ (NSUInteger)_referenceAction; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKReference: %@ action %lu>", _recordID, (unsigned long)_referenceAction];
}


+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must call -[CKReference initWithRecordID:] or -[CKReference initWithRecord:] or -[CKReference initWithAsset:]", nil];
    return nil;
}

@end

#pragma mark - CKAsset

@interface CKAsset () <NSSecureCoding>
@end

@implementation CKAsset {
    NSURL *_fileURL;
}
@synthesize fileURL = _fileURL;

- (instancetype)init
{
    RevenantCKRefuse(RevenantCKInvalidArgumentName,
                   @"You must call -[CKAsset initWithFileURL:] or -[CKAsset initWithData:]");
    return nil;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL
{
    if (!fileURL) {
        RevenantCKRefuse(RevenantCKInvalidArgumentName, @"Null fileURL");
    }
    self = [super init];
    if (self) {
        _fileURL = [fileURL copy];
    }
    return self;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    NSURL *url = [coder decodeObjectOfClass:[NSURL class] forKey:@"fileURL"];
    return [self initWithFileURL:url];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_fileURL forKey:@"fileURL"];
}

- (NSString *)description { return [NSString stringWithFormat:@"<CKAsset: %@>", _fileURL]; }


+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must call -[CKAsset initWithFileURL:] or -[CKAsset initWithData:]", nil];
    return nil;
}

@end

#pragma mark - CKRecordZone

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 260000
typedef NS_ENUM(NSInteger, CKRecordZoneEncryptionScope) {
    CKRecordZoneEncryptionScopePerRecord = 0,
    CKRecordZoneEncryptionScopePerZone = 1,
};
#endif

#if __IPHONE_OS_VERSION_MAX_ALLOWED < 260000
@interface CKRecordZone ()
@property (nonatomic, readonly, assign) CKRecordZoneEncryptionScope encryptionScope;
@end
#endif

@implementation CKRecordZone {
    CKRecordZoneID *_zoneID;
    CKRecordZoneCapabilities _capabilities;
    CKRecordZoneEncryptionScope _encryptionScope;
    id _share;
}
@synthesize zoneID = _zoneID;
@synthesize capabilities = _capabilities;
@synthesize encryptionScope = _encryptionScope;
@synthesize share = _share;
+ (CKRecordZone *)defaultRecordZone
{
    static CKRecordZone *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CKRecordZone alloc] initWithZoneID:[[CKRecordZoneID alloc] initWithZoneName:CKRecordZoneDefaultName
                                                                                        ownerName:CKOwnerDefaultName]];
    });
    return shared;
}

- (instancetype)init
{
    return [super init];
}

- (instancetype)initWithZoneName:(NSString *)zoneName
{
    return [self initWithZoneID:[[CKRecordZoneID alloc] initWithZoneName:zoneName
                                                                  ownerName:CKOwnerDefaultName]];
}

- (instancetype)initWithZoneID:(CKRecordZoneID *)zoneID
{
    if (!zoneID) {
        RevenantCKRefuse(RevenantCKExceptionName, @"zoneID can not be nil");
    }
    self = [super init];
    if (self) {
        _zoneID = [zoneID copy];
    }
    return self;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    CKRecordZoneID *zone = [coder decodeObjectOfClass:[CKRecordZoneID class] forKey:@"zoneID"];
    return [self initWithZoneID:zone];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_zoneID forKey:@"zoneID"];
    [coder encodeObject:@(_capabilities) forKey:@"capabilities"];
}

static NSString *RevenantCapabilitiesText(NSUInteger capabilities)
{
    if (capabilities == 0) {
        return @"(none)";
    }
    NSMutableArray *names = [NSMutableArray array];
    if (capabilities & CKRecordZoneCapabilityFetchChanges)   { [names addObject:@"fetchChanges"]; }
    if (capabilities & CKRecordZoneCapabilityAtomic)         { [names addObject:@"atomic"]; }
    if (capabilities & CKRecordZoneCapabilitySharing)        { [names addObject:@"sharing"]; }
    if (capabilities & CKRecordZoneCapabilityZoneWideSharing) { [names addObject:@"zoneWideSharing"]; }
    return [NSString stringWithFormat:@"(%@)", [names componentsJoinedByString:@", "]];
}

static NSString *RevenantZoneText(CKRecordZoneID *zone)
{
    return zone ? [NSString stringWithFormat:@"%@:%@", zone.zoneName, zone.ownerName] : @"<null>";
}

- (id)copyWithZone:(NSZone *)zone
{
    CKRecordZone *copy = [[[self class] allocWithZone:zone] init];
    copy->_zoneID = [_zoneID copy];
    copy->_capabilities = _capabilities;
    return copy;
}

- (NSString *)description
{
    NSString *scopeText = _encryptionScope == CKRecordZoneEncryptionScopePerZone ? @"per-zone"
                                                                              : @"per-record";
    return [NSString stringWithFormat:@"<CKRecordZone: %p; zoneID=%@, capabilities=%@,"
                                      " encryptionScope=%@, share=%@>",
                                      self, RevenantZoneText(_zoneID), RevenantCapabilitiesText(_capabilities),
                                      scopeText, _share ? [_share description] : @"<null>"];
}

+ (instancetype)new
{
    return [[self alloc] init];
}

- (BOOL)isEqual:(id)other
{
    return self == other;
}

- (NSUInteger)hash
{
    return (NSUInteger)(__bridge void *)self;
}
@end

#pragma mark - CKRecord

@interface CKRecord (RevenantKeyValueSetting) <CKRecordKeyValueSetting>
@end

@implementation CKRecord
- (NSString *)recordType { return _recordType; }
- (void)setRecordType:(NSString *)recordType { _recordType = [recordType copy]; }
- (CKRecordID *)recordID { return _recordID; }
- (void)setRecordID:(CKRecordID *)recordID { _recordID = [recordID copy]; }
- (NSString *)recordChangeTag { return _recordChangeTag; }
- (void)setRecordChangeTag:(NSString *)tag { _recordChangeTag = [tag copy]; }
- (CKRecordID *)creatorUserRecordID { return _creatorUserRecordID; }
- (void)setCreatorUserRecordID:(CKRecordID *)id { _creatorUserRecordID = [id copy]; }
- (NSDate *)creationDate { return _creationDate; }
- (void)setCreationDate:(NSDate *)date { _creationDate = [date copy]; }
- (CKRecordID *)lastModifiedUserRecordID { return _lastModifiedUserRecordID; }
- (void)setLastModifiedUserRecordID:(CKRecordID *)id { _lastModifiedUserRecordID = [id copy]; }
- (NSDate *)modificationDate { return _modificationDate; }
- (void)setModificationDate:(NSDate *)date { _modificationDate = [date copy]; }

- (instancetype)init
{
    RevenantCKRefuse(RevenantCKInvalidArgumentName, @"You must call -[CKRecord initWithRecordType:]");
    return nil;
}

- (instancetype)initWithRecordType:(NSString *)recordType
{
    return [self initWithRecordType:recordType
                            recordID:[[CKRecordID alloc] initWithRecordName:[[NSUUID UUID] UUIDString]]];
}

- (instancetype)initWithRecordType:(NSString *)recordType recordID:(CKRecordID *)recordID
{
    if (!recordType) {
        RevenantCKRefuse(RevenantCKExceptionName, @"recordType can not be nil");
    }
    if (!recordID) {
        RevenantCKRefuse(RevenantCKExceptionName, @"recordID can not be nil");
    }
    self = [super init];
    if (self) {
        _recordType = [recordType copy];
        _recordID = [recordID copy];
        _fields = [NSMutableDictionary dictionary];
        _changedKeys = [NSMutableArray array];
    }
    return self;
}

- (instancetype)initWithRecordType:(NSString *)recordType zoneID:(CKRecordZoneID *)zoneID
{
    if (!zoneID) {
        RevenantCKRefuse(RevenantCKExceptionName, @"zoneID can not be nil");
    }
    return [self initWithRecordType:recordType
                            recordID:[[CKRecordID alloc] initWithRecordName:[[NSUUID UUID] UUIDString]
                                                                    zoneID:zoneID]];
}

#pragma mark The fields

- (id)objectForKey:(NSString *)key
{
    if (![key isKindOfClass:[NSString class]]) {
        return nil;
    }
    return _fields[key];
}

- (void)setObject:(id)object forKey:(NSString *)key
{
    if (!RevenantCKFieldKeyIsValid(key)) {
        return;
    }
    if (![_changedKeys containsObject:key]) {
        [_changedKeys addObject:key];
    }
    if (object) {
        _fields[key] = object;
    } else {
        [_fields removeObjectForKey:key];
    }
}

- (id)objectForKeyedSubscript:(NSString *)key { return [self objectForKey:key]; }
- (void)setObject:(id)object forKeyedSubscript:(NSString *)key { [self setObject:object forKey:key]; }

- (NSArray *)allKeys { return [_fields allKeys]; }

- (NSArray *)changedKeys { return [_changedKeys copy]; }

- (NSArray *)allTokens { return nil; }

#pragma mark The copy and the archive

- (id)copyWithZone:(NSZone *)zone
{
    CKRecord *copy = [[[self class] allocWithZone:zone] initWithRecordType:_recordType recordID:_recordID];
    [copy->_fields addEntriesFromDictionary:_fields];
    [copy->_changedKeys addObjectsFromArray:_changedKeys];
    copy->_recordChangeTag = [_recordChangeTag copy];
    copy->_creatorUserRecordID = [_creatorUserRecordID copy];
    copy->_creationDate = [_creationDate copy];
    copy->_lastModifiedUserRecordID = [_lastModifiedUserRecordID copy];
    copy->_modificationDate = [_modificationDate copy];
    return copy;
}

+ (BOOL)supportsSecureCoding { return YES; }

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _recordType = [coder decodeObjectOfClass:[NSString class] forKey:@"recordType"];
        _recordID = [coder decodeObjectOfClass:[CKRecordID class] forKey:@"recordID"];
        _recordChangeTag = [coder decodeObjectOfClass:[NSString class] forKey:@"recordChangeTag"];
        _creatorUserRecordID = [coder decodeObjectOfClass:[CKRecordID class] forKey:@"creatorUserRecordID"];
        _creationDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"creationDate"];
        _lastModifiedUserRecordID = [coder decodeObjectOfClass:[CKRecordID class] forKey:@"lastModifiedUserRecordID"];
        _modificationDate = [coder decodeObjectOfClass:[NSDate class] forKey:@"modificationDate"];
        NSDictionary *fields = [coder decodeObjectOfClasses:
                                [NSSet setWithObjects:[NSDictionary class], [NSString class], [NSNumber class],
                                 [NSDate class], [NSData class], [CKReference class], [CKAsset class], nil]
                                                 forKey:@"fields"];
        _fields = fields ? [fields mutableCopy] : [NSMutableDictionary dictionary];
        NSArray *changed = [coder decodeObjectOfClasses:
                            [NSSet setWithObjects:[NSArray class], [NSString class], nil] forKey:@"changedKeys"];
        _changedKeys = changed ? [changed mutableCopy] : [NSMutableArray array];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_recordType forKey:@"recordType"];
    [coder encodeObject:_recordID forKey:@"recordID"];
    [coder encodeObject:_recordChangeTag forKey:@"recordChangeTag"];
    [coder encodeObject:_creatorUserRecordID forKey:@"creatorUserRecordID"];
    [coder encodeObject:_creationDate forKey:@"creationDate"];
    [coder encodeObject:_lastModifiedUserRecordID forKey:@"lastModifiedUserRecordID"];
    [coder encodeObject:_modificationDate forKey:@"modificationDate"];
    [coder encodeObject:[_fields copy] forKey:@"fields"];
    [coder encodeObject:[_changedKeys copy] forKey:@"changedKeys"];
}

- (void)encodeSystemFieldsWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_recordType forKey:@"recordType"];
    [coder encodeObject:_recordID forKey:@"recordID"];
    [coder encodeObject:_recordChangeTag forKey:@"recordChangeTag"];
    [coder encodeObject:_creatorUserRecordID forKey:@"creatorUserRecordID"];
    [coder encodeObject:_creationDate forKey:@"creationDate"];
    [coder encodeObject:_lastModifiedUserRecordID forKey:@"lastModifiedUserRecordID"];
    [coder encodeObject:_modificationDate forKey:@"modificationDate"];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKRecord: %@ %@, %lu field(s)>", _recordType, _recordID,
            (unsigned long)_fields.count];
}

@dynamic parent, share;

- (void)setParentReferenceFromRecordID:(CKRecordID *)parentRecordID
{
    RevenantCKRecordSetParentReferenceFromRecordID(self, parentRecordID);
}

- (void)setParentReferenceFromRecord:(CKRecord *)parentRecord
{
    RevenantCKRecordSetParentReferenceFromRecord(self, parentRecord);
}
- (id<CKRecordKeyValueSetting>)encryptedValues
{
    return self;
}
- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[CKRecord class]]) {
        return NO;
    }
    CKRecord *record = other;
    return [_recordID isEqual:record.recordID] && [_recordType isEqualToString:record.recordType] &&
           (_recordChangeTag == record.recordChangeTag ||
            [_recordChangeTag isEqualToString:record.recordChangeTag]);
}
- (NSUInteger)hash
{
    return _recordID.hash ^ _recordType.hash;
}
+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException format:@"You must call -[CKRecord initWithRecordType:]", nil];
    return nil;
}

@end

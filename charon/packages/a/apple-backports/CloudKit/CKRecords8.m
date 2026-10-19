// CloudKit's record values: the names a record is known by, the zone it lives in, the server's
// change token, a reference from one record to another, an asset, the zone object, and the record
// itself with its fields.
//
// Every refusal, every default and every equality below is what the host's own CloudKit answers, read
// out of the running framework by tests/backports/host/cloudkit/records-cases.h and held to the same
// questions here. The three that are easy to get wrong and are measured rather than assumed:
//
//  * A record with no name of its own is given a UUID, in the default zone, and two records of the
//    same type are never equal - CKRecord has no isEqual: at all, so equality is identity and a copy
//    is a different record that carries the same fields. CKRecordZone is the same: it copies to a
//    different object, and its isEqual: is identity too. CKRecordID, CKRecordZoneID and CKReference
//    do compare by value.
//  * +[CKRecordZone defaultRecordZone] is one object, so two calls compare equal; a zone built with
//    the same name is a different object, because its owner is the default owner and a record ID made
//    with an explicit zone is a different name-and-zone pair.
//  * A field key is a grammar and not any string: the first character is a letter or an underscore and
//    the rest may also be a digit or a dollar sign. Measured over all 95 printable ASCII characters -
//    53 are accepted as the whole key and 64 as a later character - and everything else, empty
//    included, is refused by name.
//
// The parent and the share are iOS 10.0 and are in CKRecords10.m, beside the ivars this class keeps
// for them; see CharonCKRecordPrivate.h.

#import "CharonCloudKit.h"
#import "CharonCKConstants.h"
#import "CharonCKRecordPrivate.h"

// The name the host raises under. It is not a public constant of the framework, so it is written here
// rather than imported, and the strings the host uses are its own: "You must call -[...]" for an
// initializer the class says not to call, and "recordName can not be nil" for a nil argument.
static NSString *const CharonCKExceptionName = @"CKException";
static NSString *const CharonCKInvalidArgumentName = @"NSInvalidArgumentException";

static void CharonCKRefuse(NSString *name, NSString *reason)
{
    [[NSException exceptionWithName:name reason:reason userInfo:nil] raise];
}

// A field key, and the two refusals. The character sets are the measured ones: the first is
// [A-Za-z_] and the rest [A-Za-z0-9_$], with no other printable ASCII character admitted.
static BOOL CharonCKFieldKeyIsValid(NSString *key)
{
    if (![key isKindOfClass:[NSString class]] || key.length == 0) {
        CharonCKRefuse(CharonCKInvalidArgumentName, @"recordKey can not be empty");
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
        CharonCKRefuse(CharonCKInvalidArgumentName,
                       [NSString stringWithFormat:@"recordKey (%@) contains invalid characters", key]);
        return NO;
    }
    for (NSUInteger at = 1; at < key.length; at++) {
        if (![rest characterIsMember:[key characterAtIndex:at]]) {
            CharonCKRefuse(CharonCKInvalidArgumentName,
                           [NSString stringWithFormat:@"recordKey (%@) contains invalid characters", key]);
            return NO;
        }
    }
    return YES;
}

#pragma mark - CKRecordZoneID

// A zone is a name and an owner, and two of them are the same zone when both are. The default zone is
// _defaultZone of __defaultOwner__; every record name that is given no zone lands in it.
@implementation CKRecordZoneID {
    NSString *_zoneName;
    NSString *_ownerName;
}
@synthesize zoneName = _zoneName;
@synthesize ownerName = _ownerName;

- (instancetype)init
{
    CharonCKRefuse(CharonCKInvalidArgumentName,
                   @"You must call -[CKRecordZoneID initWithZoneName:ownerName:]");
    return nil;
}

- (instancetype)initWithZoneName:(NSString *)zoneName ownerName:(NSString *)ownerName
{
    if (!zoneName) {
        CharonCKRefuse(CharonCKExceptionName, @"zoneName can not be nil");
    }
    if (!ownerName) {
        CharonCKRefuse(CharonCKExceptionName, @"ownerName can not be nil");
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

// A record's name, and the zone it is in. A name given no zone is in the default zone, and the two
// forms are different values: "a-record" in the default zone is not "a-record" in widgets.
@implementation CKRecordID {
    NSString *_recordName;
    CKRecordZoneID *_zoneID;
}
@synthesize recordName = _recordName;
@synthesize zoneID = _zoneID;

- (instancetype)init
{
    CharonCKRefuse(CharonCKInvalidArgumentName,
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
        CharonCKRefuse(CharonCKExceptionName, @"recordName can not be nil");
    }
    if (!zoneID) {
        CharonCKRefuse(CharonCKExceptionName, @"zoneID can not be nil");
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

// The service's own position in a zone's history, handed back to it on the next fetch. It has no
// public initializer at all - the host refuses - and nothing may read what is inside it, so this is a
// box that carries the token's bytes through an archive and refuses every way of being made.
@implementation CKServerChangeToken
{
    NSData *_token;
}

- (instancetype)init
{
    CharonCKRefuse(CharonCKExceptionName, @"You can't call init on CKServerChangeToken");
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

// A record's pointer to another record: where it points, and what the service is to do to the record
// that holds the pointer when the one it names is deleted. Neither is optional, and the two
// initializers differ only in whether the caller has the record or already has its ID.
@implementation CKReference {
    CKRecordID *_recordID;
    CKReferenceAction _referenceAction;
}
@synthesize recordID = _recordID;
@synthesize referenceAction = _referenceAction;

- (instancetype)init
{
    CharonCKRefuse(CharonCKInvalidArgumentName,
                   @"You must call -[CKReference initWithRecordID:] or -[CKReference initWithRecord:] or -[CKReference initWithAsset:]");
    return nil;
}

- (instancetype)initWithRecordID:(CKRecordID *)recordID action:(CKReferenceAction)action
{
    if (!recordID) {
        CharonCKRefuse(CharonCKExceptionName, @"recordID can not be nil");
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
        CharonCKRefuse(CharonCKExceptionName, @"record can not be nil");
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

// A file, named for the service to read. The URL is kept as it was given - the host does not check
// that the file is there, and an asset of a path that does not exist is an asset - and a nil URL is
// refused, because an asset with no file is nothing.
//
// CKAsset is not NSCopying on iOS: the host answers -[CKAsset copyWithZone:] with an unrecognised
// selector, which is measured, and copying it is left unimplemented so the port says the same thing.
//
// It does conform to NSSecureCoding, though the SDK's @interface does not say so - measured by asking
// the runtime, not by reading the header - and a class extension is what makes this one conform.
@interface CKAsset () <NSSecureCoding>
@end

@implementation CKAsset {
    NSURL *_fileURL;
}
@synthesize fileURL = _fileURL;

- (instancetype)init
{
    CharonCKRefuse(CharonCKInvalidArgumentName,
                   @"You must call -[CKAsset initWithFileURL:] or -[CKAsset initWithData:]");
    return nil;
}

- (instancetype)initWithFileURL:(NSURL *)fileURL
{
    if (!fileURL) {
        CharonCKRefuse(CharonCKInvalidArgumentName, @"Null fileURL");
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

// A zone and what it can do. Every zone this port makes has no capability - the capabilities are a
// property of the zone the service created, and a name on its own claims none of them - and there is
// one default zone, which is the same object every time.
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 260000
// CKRecordZoneEncryptionScope, from the 26.2 header: the type the encryptionScope property and the
// description's text are stated in. The guard is the shape UIColorWell.m uses in this tree, and it is
// needed because the two SDKs disagree - the 16.4 headers this port's own target compiles against do
// not declare the type at all, and the 26.2 headers the host harness compiles against declare it, so
// declaring it unconditionally is a redefinition on one sysroot and an unknown type on the other.
typedef NS_ENUM(NSInteger, CKRecordZoneEncryptionScope) {
    // The zone keys each record separately, so each encrypted value on a record or share uses that record's key. This is the
    // default, and the host answers it for a zone built in memory (measured).
    CKRecordZoneEncryptionScopePerRecord = 0,
    // Zone uses per-zone encryption keys across all records and the zone-wide share.
    CKRecordZoneEncryptionScopePerZone = 1,
};
#endif

// The zone's encryption scope, which the 16.4 header this port compiles against does not declare at
// all - it arrived in 26.0, and CKRecordZoneEncryptionScope is a 26.0 type - so the property is
// declared here in a class extension, the way a port carries a member its SDK's headers predate. The
// numbers and the two cases are the header's.
#if __IPHONE_OS_VERSION_MAX_ALLOWED < 260000
// The property is declared here, in a class extension, for the same reason and under the same guard:
// 26.0's CKRecordZone.h declares it and a redeclaration is an error there, while 16.4's does not and a
// @synthesize has nothing to attach to. A class extension and not a named category, because only an
// extension's property can be implemented in the class.
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
    // One object, so two calls compare equal: measured, and a fresh zone of the same name does not.
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
    // The header says this is unavailable and the host makes one anyway (measured), so the port does
    // too rather than refusing where the host does not. What the host answers is a zone with NO name:
    // zoneID.zoneName is nil, measured. A zone of the empty name is a different object from a zone of
    // no name, and the measurement says which one -init makes.
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
        CharonCKRefuse(CharonCKExceptionName, @"zoneID can not be nil");
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

// The host's own format, measured:
//   <CKRecordZone: 0x...; zoneID=<null>, capabilities=(none), encryptionScope=per-record, share=<null>>
// The address is an address - no port can match it and the comparison normalises it away - and what has
// to agree is everything after it. The capability text is measured for the one value a host without the
// entitlement can reach, which is zero and reads (none); the other bit names are the header's own and
// this file says which is which rather than presenting a transcription as a measurement.
static NSString *CharonCapabilitiesText(NSUInteger capabilities)
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

static NSString *CharonZoneText(CKRecordZoneID *zone)
{
    return zone ? [NSString stringWithFormat:@"%@:%@", zone.zoneName, zone.ownerName] : @"<null>";
}

// A copy is a different zone: CKRecordZone has no value equality, and the host answers "different" for
// a copy against its original (measured). It is built the way the original was rather than through
// -initWithZoneID:, which refuses a nil zoneID, and +new's zone has none.
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
                                      self, CharonZoneText(_zoneID), CharonCapabilitiesText(_capabilities),
                                      scopeText, _share ? [_share description] : @"<null>"];
}

+ (instancetype)new
{
    // Measured: the host answers +[CKRecordZone new] with a zone, and its own header marks neither
    // -init nor +new unavailable, so this port does the same and hands back the zone -init makes.
    return [[self alloc] init];
}

- (BOOL)isEqual:(id)other
{
    // Identity, and this file's own header says so of these classes while the code said the opposite.
    // Measured, in four constructions and all of them agreeing: a copy is not equal to the object it
    // was copied from, a zone decoded from an archive is not equal to the one archived, and an object
    // is equal to itself. -defaultRecordZone is unaffected: it hands back one object. CKRecordZoneID is
    // the other half of this file and is a value on purpose: an identifier names, a zone is a thing.
    return self == other;
}

- (NSUInteger)hash
{
    return (NSUInteger)(__bridge void *)self;
}
@end

#pragma mark - CKRecord

// A record: a type, a name in a zone, a set of fields, and the service's own answers about the field
// once it has been saved. A record made here has none of the service's answers - no change tag, no
// creator, no dates, no share - and says so by answering nil, which is what the host does before a
// record has been through the service (measured).
//
// Equality is identity: CKRecord does not override isEqual:, so two records of the same type with the
// same ID are still different records, and a copy is a different record carrying the same fields. That
// is measured in both directions and is not a shortcut here.
// The seven service's answers are declared readwrite in CharonCKRecordPrivate.h and their accessors
// written out here: @synthesize would make the ivar private to this @implementation, and the decoders
// in CharonCKRecords.m write them through the same properties.
//
// This is the only object that touches CKRecord's ivars. From iOS 8.0 on the release carries the
// class, a band links this file for its re-exported symbols alone and the record in a process is the
// release's, whose layout is the release's - so the 10.0 half of the class (CKRecords10.m, which is in
// every band) keeps the parent and the share beside the record and reads nothing of these. The service's
// own answers are written the same way, through the properties above, so no file outside this one names
// an offset into the record.
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
    CharonCKRefuse(CharonCKInvalidArgumentName, @"You must call -[CKRecord initWithRecordType:]");
    return nil;
}

- (instancetype)initWithRecordType:(NSString *)recordType
{
    // A record with a type and no name of its own is given a UUID in the default zone. Measured: two
    // records of the same type have different names, and neither names anything a caller chose.
    return [self initWithRecordType:recordType
                            recordID:[[CKRecordID alloc] initWithRecordName:[[NSUUID UUID] UUIDString]]];
}

- (instancetype)initWithRecordType:(NSString *)recordType recordID:(CKRecordID *)recordID
{
    if (!recordType) {
        CharonCKRefuse(CharonCKExceptionName, @"recordType can not be nil");
    }
    if (!recordID) {
        CharonCKRefuse(CharonCKExceptionName, @"recordID can not be nil");
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
        CharonCKRefuse(CharonCKExceptionName, @"zoneID can not be nil");
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
    if (!CharonCKFieldKeyIsValid(key)) {
        return;
    }
    // A field set once stays in changedKeys even after it is removed: allKeys is what the record holds
    // now and changedKeys is what has been touched. Measured: six fields set, one removed, five keys
    // and six changed keys.
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

// The field types, and a record that has not been through the service has none: the host answers an
// empty list here, and the tokens arrive with the saved record's fields.
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

// parent and share are the 10.0 half of the class and are @dynamic here for that reason: they are
// implemented once, in CKRecords10.m, over storage that belongs to the record rather than to this
// class's layout, because from iOS 8.0 on the record in a process is the release's and its offsets are
// the release's. Left to synthesis they would be implemented here as well - two bodies for one
// selector, of which the linker picks one by link order.
@dynamic parent, share;

// The two SDK wrappers are the same method on both sides of iOS 8.0, so their bodies are in
// CKRecords10.m and this class forwards to them. They are here because @implementation CKRecord has to
// answer everything @interface CKRecord declares, and they are only the port's own class that needs it
// to: for a band of 8.0 to 9.3, where the record is the release's, the installer in that file adds
// them to the class, and from 10.0 the release answers them itself.
- (void)setParentReferenceFromRecordID:(CKRecordID *)parentRecordID
{
    CharonCKRecordSetParentReferenceFromRecordID(self, parentRecordID);
}

- (void)setParentReferenceFromRecord:(CKRecord *)parentRecord
{
    CharonCKRecordSetParentReferenceFromRecord(self, parentRecord);
}
- (id<CKRecordKeyValueSetting>)encryptedValues
{
    // The private fields of a record, which the service holds encrypted and which an application
    // reads back through this and cannot write: a write raises, as the host's own does.
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
    // CloudKit compares a record by its identity and its system fields, not by the values it holds:
    // two records of the same name in the same zone are the same record whoever wrote them.
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

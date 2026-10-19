// The query of CloudKit's first release and the three classes that describe it: the query itself, the
// cursor its answer is continued with, and the one sort descriptor that is not a field name.
//
// A CKQuery is a record type, an NSPredicate and a list of sort descriptors, and nothing else. The
// predicate is kept as it was given and printed as NSPredicate prints itself - the host's own
// -description output is `recordType=Thing, predicate=name == "bob"`, which is the predicate's own
// description and not a translation of it. Turning a predicate into the query document the service
// reads, and a cursor back into a token, is a later delivery with the transport; what is here is
// everything a caller can see before a request is made.

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import <CloudKit/CloudKit.h>

#import "CharonCKValue.h"

@implementation CKQuery

- (instancetype)initWithRecordType:(CKRecordType)recordType predicate:(NSPredicate *)predicate
{
    self = [super init];
    if (self) {
        _recordType = [recordType copy];
        _predicate = [predicate copy];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (self) {
        _recordType = [[coder decodeObjectOfClass:[NSString class] forKey:@"recordType"] copy];
        _predicate = [coder decodeObjectOfClass:[NSPredicate class] forKey:@"predicate"];
    }
    return self;
}

+ (instancetype)new
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must call -[CKQuery initWithRecordType:predicate:sortDescriptors:]", nil];
    return nil;
}

- (instancetype)init
{
    [NSException raise:NSInvalidArgumentException
                format:@"You must call -[CKQuery initWithRecordType:predicate:sortDescriptors:]", nil];
    return nil;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_recordType forKey:@"recordType"];
    [coder encodeObject:_predicate forKey:@"predicate"];
    [coder encodeObject:_sortDescriptors forKey:@"sortDescriptors"];
}

- (id)copyWithZone:(NSZone *)zone
{
    CKQuery *copy = [[CKQuery allocWithZone:zone] initWithRecordType:_recordType predicate:_predicate];
    copy.sortDescriptors = _sortDescriptors;
    return copy;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[CKQuery class]]) {
        return NO;
    }
    CKQuery *query = other;
    BOOL sameSorts = _sortDescriptors == query.sortDescriptors ||
                     [_sortDescriptors isEqualToArray:query.sortDescriptors];
    return [_recordType isEqualToString:query.recordType] && [_predicate isEqual:query.predicate] && sameSorts;
}

- (NSUInteger)hash
{
    return _recordType.hash ^ _predicate.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKQuery: %p; recordType=%@, predicate=%@>", self, _recordType, _predicate];
}

@end

#pragma mark - CKQueryCursor

@implementation CKQueryCursor
{
    NSData *_serverChangeToken;
}

// Measured: the host answers +[CKQueryCursor new] with CKException and exactly these words, and the
// same for -[CKQueryCursor init]. The cursor is the service's own token and nothing else, so a
// cursor this port has not been given a token for is not a cursor.
+ (instancetype)cursorWithToken:(NSData *)token
{
    CKQueryCursor *cursor = [[self alloc] initWithToken:token];
    return cursor;
}

- (instancetype)initWithToken:(NSData *)token
{
    self = [super init];
    if (self) {
        _serverChangeToken = [token copy];
    }
    return self;
}

+ (instancetype)new
{
    [NSException raise:@"CKException" format:@"You can't call init on CKQueryCursor", nil];
    return nil;
}

- (instancetype)init
{
    [NSException raise:@"CKException" format:@"You can't call init on CKQueryCursor", nil];
    return nil;
}

- (NSData *)serverChangeToken
{
    return _serverChangeToken;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:_serverChangeToken forKey:@"serverChangeToken"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    return [self initWithToken:[coder decodeObjectOfClass:[NSData class] forKey:@"serverChangeToken"]];
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    }
    if (![other isKindOfClass:[CKQueryCursor class]]) {
        return NO;
    }
    return [_serverChangeToken isEqualToData:((CKQueryCursor *)other)->_serverChangeToken];
}

- (NSUInteger)hash
{
    return _serverChangeToken.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKQueryCursor: %p>", self];
}

@end

#pragma mark - CKLocationSortDescriptor

@implementation CKLocationSortDescriptor

- (instancetype)initWithKey:(NSString *)key relativeLocation:(CLLocation *)relativeLocation
{
    self = [super initWithKey:key ascending:YES];
    if (self) {
        _relativeLocation = relativeLocation;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [self initWithKey:[coder decodeObjectOfClass:[NSString class] forKey:@"key"]
                      ascending:[coder decodeBoolForKey:@"ascending"]];
    if (self) {
        _relativeLocation = [coder decodeObjectOfClass:[CLLocation class] forKey:@"relativeLocation"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeObject:self.key forKey:@"key"];
    [coder encodeBool:self.ascending forKey:@"ascending"];
    [coder encodeObject:_relativeLocation forKey:@"relativeLocation"];
}

- (id)copyWithZone:(NSZone *)zone
{
    // ascending is readonly on NSSortDescriptor, so the copy is built with it rather than set.
    CKLocationSortDescriptor *copy = self.ascending
        ? [[CKLocationSortDescriptor allocWithZone:zone] initWithKey:self.key relativeLocation:_relativeLocation]
        : [[CKLocationSortDescriptor allocWithZone:zone] initWithKey:self.key ascending:NO];
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<CKLocationSortDescriptor: %p; key=%@, ascending=%d, relativeLocation=%@>",
            self, self.key, self.ascending, _relativeLocation];
}

@end

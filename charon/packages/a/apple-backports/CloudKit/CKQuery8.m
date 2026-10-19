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

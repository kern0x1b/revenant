#import <CoreData/CoreData.h>

@implementation NSPersistentHistoryChangeRequest {
    NSDate *_date;
    NSPersistentHistoryToken *_token;
    NSPersistentHistoryResultType _resultType;
    BOOL _delete;
}

@dynamic fetchRequest;

+ (instancetype)fetchHistoryAfterDate:(NSDate *)date
{
    return [[self alloc] initWithDate:date delete:NO];
}

+ (instancetype)fetchHistoryAfterToken:(NSPersistentHistoryToken *)token
{
    return [[self alloc] initWithToken:token delete:NO];
}

+ (instancetype)fetchHistoryAfterTransaction:(NSPersistentHistoryTransaction *)transaction
{
    return [[self alloc] initWithToken:[transaction token] delete:NO];
}

+ (instancetype)deleteHistoryBeforeDate:(NSDate *)date
{
    return [[self alloc] initWithDate:date delete:YES];
}

+ (instancetype)deleteHistoryBeforeToken:(NSPersistentHistoryToken *)token
{
    return [[self alloc] initWithToken:token delete:YES];
}

+ (instancetype)deleteHistoryBeforeTransaction:(NSPersistentHistoryTransaction *)transaction
{
    return [[self alloc] initWithToken:[transaction token] delete:YES];
}

- (instancetype)init
{
    self = [super init];
    if (self)
        _resultType = NSPersistentHistoryResultTypeTransactionsAndChanges;
    return self;
}

- (instancetype)initWithDate:(NSDate *)date delete:(BOOL)shouldDelete
{
    self = [super init];
    if (self) {
        _date = date;
        _resultType = shouldDelete ? NSPersistentHistoryResultTypeStatusOnly : NSPersistentHistoryResultTypeTransactionsAndChanges;
        _delete = shouldDelete;
    }
    return self;
}

- (instancetype)initWithToken:(NSPersistentHistoryToken *)token delete:(BOOL)shouldDelete
{
    self = [super init];
    if (self) {
        if (token)
            _token = token;
        _resultType = shouldDelete ? NSPersistentHistoryResultTypeStatusOnly : NSPersistentHistoryResultTypeTransactionsAndChanges;
        _delete = shouldDelete;
    }
    return self;
}

- (NSPersistentHistoryResultType)resultType
{
    return _resultType;
}

- (void)setResultType:(NSPersistentHistoryResultType)resultType
{
    _resultType = _delete ? NSPersistentHistoryResultTypeStatusOnly : resultType;
}

- (NSPersistentHistoryToken *)token
{
    return _token;
}

- (NSPersistentStoreRequestType)requestType
{
    return (NSPersistentStoreRequestType)8;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSPersistentHistoryChangeRequest *copy = [[[self class] allocWithZone:zone] init];
    copy->_date = _date;
    copy->_token = _token;
    copy->_resultType = _resultType;
    copy->_delete = _delete;
    copy.affectedStores = self.affectedStores;
    return copy;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"NSPersistentHistoryChangeRequest : %@ < %@ - %@-%@> %lu", _delete ? @"Delete" : @"Fetch", _date, _token, nil, (unsigned long)_resultType];
}

@end

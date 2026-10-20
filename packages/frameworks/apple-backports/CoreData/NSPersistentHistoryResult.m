#import <CoreData/CoreData.h>

@implementation NSPersistentHistoryResult {
    id _result;
    NSPersistentHistoryResultType _resultType;
}

- (instancetype)initWithResultType:(NSPersistentHistoryResultType)resultType andResult:(id)result
{
    self = [super init];
    if (self) {
        _resultType = resultType;
        _result = result;
    }
    return self;
}

- (id)result
{
    return _result;
}

- (NSPersistentHistoryResultType)resultType
{
    return _resultType;
}

@end

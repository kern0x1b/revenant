#import <CoreData/CoreData.h>

@implementation NSBatchDeleteResult {
    id _result;
    NSBatchDeleteRequestResultType _resultType;
}

- (instancetype)initWithResultType:(NSBatchDeleteRequestResultType)resultType andObject:(id)result
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

- (NSBatchDeleteRequestResultType)resultType
{
    return _resultType;
}

@end

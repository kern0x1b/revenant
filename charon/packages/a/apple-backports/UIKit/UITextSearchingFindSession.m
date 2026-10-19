#import <UIKit/UIKit.h>

@implementation UITextSearchingFindSession {
@private
    __weak id<UITextSearching> _searchableObject;
}

- (instancetype)initWithSearchableObject:(id<UITextSearching>)searchableObject
{
    if ((self = [super init]))
        _searchableObject = searchableObject;
    return self;
}

- (id<UITextSearching>)searchableObject
{
    return _searchableObject;
}

@end

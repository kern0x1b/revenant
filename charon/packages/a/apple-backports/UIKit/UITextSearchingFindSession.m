#import <UIKit/UIKit.h>

// UITextSearchingFindSession, iOS 16: a find session over an object that answers UITextSearching. The object is held weakly, as the header
// says, and an application's session reads the values UIFindSession gives an empty one (measured by tests/backports/host/find-interaction):
// the object it was made with is the searchable object, and the session supports no replacement. Its searching methods are not built.
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

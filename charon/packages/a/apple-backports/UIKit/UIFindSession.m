#import <UIKit/UIKit.h>

// UIFindSession, iOS 16: the base of a find session, with the values an empty session gives (measured by tests/backports/host/find-interaction):
// no results, no highlighted result, the display style 0, and no replacement support. A session that searches is built by a subclass; the port
// builds UITextSearchingFindSession, whose searching methods are not built yet.
@implementation UIFindSession

- (NSInteger)resultCount
{
    return 0;
}

- (NSInteger)highlightedResultIndex
{
    return NSNotFound;
}

- (UIFindSessionSearchResultDisplayStyle)searchResultDisplayStyle
{
    return 0;
}

- (void)setSearchResultDisplayStyle:(UIFindSessionSearchResultDisplayStyle)searchResultDisplayStyle
{
}

- (BOOL)supportsReplacement
{
    return NO;
}

- (BOOL)allowsReplacementForCurrentlyHighlightedResult
{
    return NO;
}

- (BOOL)allowsReplacement
{
    return NO;
}

@end

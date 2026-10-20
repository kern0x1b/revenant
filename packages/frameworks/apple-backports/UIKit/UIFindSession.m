#import <UIKit/UIKit.h>

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

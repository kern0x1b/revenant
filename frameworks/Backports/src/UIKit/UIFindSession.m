#import <UIKit/UIKit.h>

@interface UIFindSession (RevenantSearch)
- (NSString *)revenant_document;
- (void)revenant_highlight:(NSRange)range;
- (void)revenant_clearHighlight;
@end

static NSArray *revenant_matches(NSString *document, NSString *query, UITextSearchOptions *options)
{
    NSMutableArray *matches = [NSMutableArray array];
    NSUInteger length = document.length;
    if (!length || !query.length)
        return matches;
    NSStringCompareOptions compare = options ? options.stringCompareOptions : (NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch);
    UITextSearchMatchMethod method = options ? options.wordMatchMethod : UITextSearchMatchMethodContains;
    NSCharacterSet *letters = [NSCharacterSet alphanumericCharacterSet];
    NSUInteger from = 0;
    while (from < length) {
        NSRange found = [document rangeOfString:query options:compare range:NSMakeRange(from, length - from)];
        if (found.location == NSNotFound || !found.length)
            break;
        BOOL joinedBefore = found.location > 0 && [letters characterIsMember:[document characterAtIndex:found.location - 1]];
        BOOL joinedAfter = NSMaxRange(found) < length && [letters characterIsMember:[document characterAtIndex:NSMaxRange(found)]];
        BOOL accepted = method == UITextSearchMatchMethodFullWord ? (!joinedBefore && !joinedAfter)
                      : method == UITextSearchMatchMethodStartsWith ? !joinedBefore
                      : YES;
        if (accepted)
            [matches addObject:[NSValue valueWithRange:found]];
        from = NSMaxRange(found);
    }
    return matches;
}

@implementation UIFindSession {
@private
    NSString *_query;
    UITextSearchOptions *_options;
    NSArray *_results;
    NSInteger _highlightedResultIndex;
    UIFindSessionSearchResultDisplayStyle _searchResultDisplayStyle;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _results = @[];
        _highlightedResultIndex = NSNotFound;
    }
    return self;
}

- (NSInteger)resultCount
{
    return _results.count;
}

- (NSInteger)highlightedResultIndex
{
    return _highlightedResultIndex;
}

- (UIFindSessionSearchResultDisplayStyle)searchResultDisplayStyle
{
    return _searchResultDisplayStyle;
}

- (void)setSearchResultDisplayStyle:(UIFindSessionSearchResultDisplayStyle)searchResultDisplayStyle
{
    _searchResultDisplayStyle = searchResultDisplayStyle;
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

- (void)performSearchWithQuery:(NSString *)query options:(UITextSearchOptions *)options
{
    _query = [query copy];
    _options = options;
    _results = revenant_matches([self revenant_document], _query, options);
    _highlightedResultIndex = _results.count ? 0 : NSNotFound;
    if (_results.count)
        [self revenant_highlight:[_results[0] rangeValue]];
    else
        [self revenant_clearHighlight];
}

- (void)highlightNextResultInDirection:(UITextStorageDirection)direction
{
    NSUInteger count = _results.count;
    if (!count)
        return;
    NSUInteger current = _highlightedResultIndex == NSNotFound ? 0 : (NSUInteger)_highlightedResultIndex;
    NSUInteger next = direction == UITextStorageDirectionBackward ? (current + count - 1) % count : (current + 1) % count;
    _highlightedResultIndex = (NSInteger)next;
    [self revenant_highlight:[_results[next] rangeValue]];
}

- (void)performSingleReplacementWithSearchQuery:(NSString *)searchQuery replacementString:(NSString *)replacementString options:(UITextSearchOptions *)options
{
}

- (void)replaceAllInstancesOfSearchQuery:(NSString *)searchQuery withReplacementString:(NSString *)replacementString options:(UITextSearchOptions *)options
{
}

- (void)invalidateFoundResults
{
    [self performSearchWithQuery:_query options:_options];
}

- (NSString *)revenant_document
{
    return nil;
}

- (void)revenant_highlight:(NSRange)range
{
}

- (void)revenant_clearHighlight
{
}

@end

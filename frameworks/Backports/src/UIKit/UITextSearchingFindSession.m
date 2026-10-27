#import <UIKit/UIKit.h>

@interface UIFindSession (RevenantSearch)
- (NSString *)revenant_document;
- (void)revenant_highlight:(NSRange)range;
- (void)revenant_clearHighlight;
@end

@implementation UITextSearchingFindSession {
@private
    __weak id<UITextSearching> _searchableObject;
    NSValue *_highlightedRange;
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

- (NSString *)revenant_document
{
    id object = _searchableObject;
    return [object respondsToSelector:@selector(text)] ? [object text] : nil;
}

- (void)revenant_highlight:(NSRange)range
{
    id object = _searchableObject;
    _highlightedRange = [NSValue valueWithRange:range];
    if ([object respondsToSelector:@selector(setSelectedRange:)])
        [object setSelectedRange:range];
}

- (void)revenant_clearHighlight
{
    NSValue *last = _highlightedRange;
    _highlightedRange = nil;
    id object = _searchableObject;
    if (!last || ![object respondsToSelector:@selector(setSelectedRange:)])
        return;
    NSUInteger length = [self revenant_document].length;
    NSUInteger caret = MIN(NSMaxRange([last rangeValue]), length);
    [object setSelectedRange:NSMakeRange(caret, 0)];
}

@end

#import <UIKit/UIKit.h>

@interface UIFindSession (RevenantSearch)
- (NSString *)revenant_document;
- (void)revenant_highlight:(NSRange)range;
- (void)revenant_clearHighlight;
- (void)revenant_replaceRanges:(NSArray *)ranges withString:(NSString *)string;
@end

@interface RevenantTextReplacement : NSObject
- (instancetype)initWithInput:(id<UITextInput>)input range:(NSRange)range;
- (void)replaceWithString:(NSString *)string undoManager:(NSUndoManager *)undoManager;
- (void)swap:(id)sender;
@end

static UITextRange *revenant_text_range(id<UITextInput> input, NSRange range)
{
    UITextPosition *start = [input positionFromPosition:input.beginningOfDocument offset:range.location];
    UITextPosition *end = [input positionFromPosition:start offset:range.length];
    return [input textRangeFromPosition:start toPosition:end];
}

@implementation RevenantTextReplacement {
@private
    __weak id<UITextInput> _input;
    __weak NSUndoManager *_undoManager;
    NSRange _range;
    NSString *_text;
}

- (instancetype)initWithInput:(id<UITextInput>)input range:(NSRange)range
{
    if ((self = [super init])) {
        _input = input;
        _range = range;
    }
    return self;
}

- (void)replaceWithString:(NSString *)string undoManager:(NSUndoManager *)undoManager
{
    _text = [string copy] ?: @"";
    _undoManager = undoManager;
    [self swap:nil];
}

- (void)swap:(id)sender
{
    id<UITextInput> input = _input;
    if (!input)
        return;
    UITextRange *target = revenant_text_range(input, _range);
    NSString *previous = [input textInRange:target];
    [input replaceRange:target withText:_text];
    _range.length = _text.length;
    _text = previous;
    [_undoManager registerUndoWithTarget:self selector:@selector(swap:) object:nil];
}

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

- (BOOL)supportsReplacement
{
    id object = _searchableObject;
    return [object respondsToSelector:@selector(isEditable)] && [object isEditable];
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
    if ([object respondsToSelector:@selector(scrollRangeToVisible:)])
        [object scrollRangeToVisible:range];
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

- (void)revenant_replaceRanges:(NSArray *)ranges withString:(NSString *)string
{
    id object = _searchableObject;
    if (!ranges.count || ![object conformsToProtocol:@protocol(UITextInput)])
        return;
    NSUndoManager *undoManager = [object respondsToSelector:@selector(undoManager)] ? [object undoManager] : nil;
    [undoManager beginUndoGrouping];
    for (NSValue *value in [ranges reverseObjectEnumerator]) {
        RevenantTextReplacement *replacement = [[RevenantTextReplacement alloc] initWithInput:object range:[value rangeValue]];
        [replacement replaceWithString:string undoManager:undoManager];
    }
    [undoManager endUndoGrouping];
}

@end

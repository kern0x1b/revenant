#import <UIKit/UIKit.h>

@implementation NSTextElement

@synthesize textContentManager = _textContentManager;
@synthesize elementRange = _elementRange;

- (instancetype)initWithTextContentManager:(NSTextContentManager *)textContentManager
{
    if ((self = [super init]))
        _textContentManager = textContentManager;
    return self;
}

- (instancetype)init
{
    return [self initWithTextContentManager:nil];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>", [self class], self];
}

@end

@implementation NSTextParagraph

@synthesize attributedString = _attributedString;

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
{
    if ((self = [super initWithTextContentManager:nil]))
        _attributedString = attributedString;
    return self;
}

- (instancetype)initWithTextContentManager:(NSTextContentManager *)textContentManager
{
    return [self initWithAttributedString:nil];
}

- (NSUInteger)revenant_content_length
{
    NSUInteger length = _attributedString.length;
    if (!length)
        return 0;
    unichar last = [[_attributedString string] characterAtIndex:length - 1];
    if (last != 10 && last != 13)
        return length;
    NSUInteger content = length - 1;
    if (last == 10 && content > 0 && [[_attributedString string] characterAtIndex:content - 1] == 13)
        content--;
    return content;
}

- (NSUInteger)revenant_separator_offset
{
    NSUInteger length = _attributedString.length;
    if (!length)
        return 0;
    unichar last = [[_attributedString string] characterAtIndex:length - 1];
    if (last != 10 && last != 13)
        return 0;
    NSUInteger start = length - 1;
    if (last == 10 && start > 0 && [[_attributedString string] characterAtIndex:start - 1] == 13)
        start--;
    return start;
}

- (id<NSTextLocation>)revenant_paragraph_start
{
    NSTextContentManager *manager = self.textContentManager;
    NSTextRange *elementRange = self.elementRange;
    if (!manager || !elementRange || !elementRange.location)
        return nil;
    NSTextRange *document = manager.documentRange;
    if (!document || !document.location)
        return nil;
    if ([manager offsetFromLocation:document.location toLocation:elementRange.location] == NSNotFound)
        return nil;
    return elementRange.location;
}

- (NSTextRange *)paragraphContentRange
{
    id<NSTextLocation> start = [self revenant_paragraph_start];
    if (!start || !_attributedString.length)
        return nil;
    id<NSTextLocation> end = [self.textContentManager locationFromLocation:start
                                                                withOffset:(NSInteger)[self revenant_content_length]];
    if (!end)
        return nil;
    return [[NSTextRange alloc] initWithLocation:start endLocation:end];
}

- (NSTextRange *)paragraphSeparatorRange
{
    id<NSTextLocation> start = [self revenant_paragraph_start];
    if (!start || !_attributedString.length)
        return nil;
    NSUInteger offset = [self revenant_separator_offset];
    if (!offset)
        return nil;
    id<NSTextLocation> separator = [self.textContentManager locationFromLocation:start withOffset:(NSInteger)offset];
    id<NSTextLocation> end =
        [self.textContentManager locationFromLocation:start withOffset:(NSInteger)_attributedString.length];
    if (!separator || !end)
        return nil;
    return [[NSTextRange alloc] initWithLocation:separator endLocation:end];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p \"%@\">", [self class], self, [_attributedString string]];
}

@end

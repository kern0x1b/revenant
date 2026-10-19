// NSTextElement and NSTextParagraph: the smallest unit of a document's contents, and the paragraph that is the
// one the rest of the range layer is written against. What the headers declare is in NSTextElement.h of SDK
// 26.2; what the host's own UIKit answers is in facts/UIKit/NSTextRange15.md.
//
// An element is a range in a document plus the manager that owns it and, for a subclass, whatever the subclass
// means by the contents of that range. A paragraph's contents are an attributed string, and its two derived
// ranges are that string placed in the document: the content is everything but the trailing newline that ends
// the paragraph, and the separator is that newline, so the two together are the paragraph's whole range. Both
// are asked of the content manager, which is what owns the document they are positions in: it is asked where
// the paragraph starts, and for a location that many characters on. A paragraph with no manager has no document
// to be in, and the host answers nil for both ranges in that state whatever the string is and whatever element
// range is set (M4) - which is the state the port is in until NSTextContentManager arrives, so the derivation
// below is written out and is asked of the manager the moment one is attached.
//
// The three members that arrived in iOS 16 are in NSTextElement16.m, one release to an object file.

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
    // The header makes -initWithTextContentManager: the designated initialiser, so an element made any other
    // way is one with no content manager - which is a state every answer below already has an answer for. The
    // host faults on it (M9); an element with no manager is not a fault, it is an element outside any document,
    // and it is what -initWithTextContentManager:nil gives.
    return [self initWithTextContentManager:nil];
}

// The host's own text, which is the class and the address and nothing else.
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
    // The superclass's designated initialiser, which a paragraph has to answer because the header makes
    // -initWithAttributedString: its own: a paragraph's contents are its string, so there is nothing for a
    // manager to say about it here. The manager is the superclass's property and is set on the element.
    return [self initWithAttributedString:nil];
}

// The length of the paragraph's own string that is its contents, and the place in that string where its
// separator starts. The separator is the last character when it is a line feed or a carriage return, and a
// paragraph whose contents do not end in one has no separator, so its contents are the whole string. A
// carriage return before a line feed is one separator and not two.
- (NSUInteger)charon_content_length
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

- (NSUInteger)charon_separator_offset
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

// The paragraph's place in the document, as a location the content manager owns, or nil when there is no
// manager, no element range, or no document range to measure from. The document's own start is where every
// offset the manager is asked for is counted from, which is what makes an offset from it the paragraph's own
// place in the document, and asking the manager for it is what keeps the answer in the manager's own location
// type rather than in one this package made up.
- (id<NSTextLocation>)charon_paragraph_start
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
    id<NSTextLocation> start = [self charon_paragraph_start];
    if (!start || !_attributedString.length)
        return nil;
    id<NSTextLocation> end = [self.textContentManager locationFromLocation:start
                                                                withOffset:(NSInteger)[self charon_content_length]];
    if (!end)
        return nil;
    return [[NSTextRange alloc] initWithLocation:start endLocation:end];
}

- (NSTextRange *)paragraphSeparatorRange
{
    id<NSTextLocation> start = [self charon_paragraph_start];
    if (!start || !_attributedString.length)
        return nil;
    NSUInteger offset = [self charon_separator_offset];
    if (!offset)
        return nil;
    id<NSTextLocation> separator = [self.textContentManager locationFromLocation:start withOffset:(NSInteger)offset];
    id<NSTextLocation> end =
        [self.textContentManager locationFromLocation:start withOffset:(NSInteger)_attributedString.length];
    if (!separator || !end)
        return nil;
    return [[NSTextRange alloc] initWithLocation:separator endLocation:end];
}

// The host's own text, which adds the string the paragraph holds to what an element's description says: a
// paragraph over "Hello" prints as <NSTextParagraph: 0x... "Hello">, and one over no string at all prints
// "(null)", because that is what the format prints for nil (M4).
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p \"%@\">", [self class], self, [_attributedString string]];
}

@end

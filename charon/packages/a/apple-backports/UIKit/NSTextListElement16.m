// NSTextListElement: a text element whose contents are a list item - the marker, the text under it, and the
// items nested inside it. It is the one element type the document cuts differently from a plain paragraph, and it
// arrived in iOS 16, so it is a file of its own: a file carries the API of one release. What the header
// declares is NSTextListElement.h of SDK 26.2; what the host's own UIKit answers is in
// facts/UIKit/NSTextContent15.md.
//
// The element has three parts and one derivation. The contents are the item's own text, without its marker and
// without the formatting the marker carries; the marker attributes are what the marker is drawn with; and
// -attributedString is the two of them put together, which is the string the document holds and therefore the
// only part of an element that has characters in the document. The children are items nested inside this one,
// and the element's place among them - its item number - is what its list derives the marker from.

#import <UIKit/UIKit.h>

@implementation NSTextListElement {
    // The item's own text and the marker's formatting, written out because the superclass's attributedString is
    // the derived string and not the contents, so the two cannot share one storage.
    NSAttributedString *_contents;
    NSDictionary *_markerAttributes;
    NSTextList *_textList;
    NSArray<NSTextListElement *> *_childElements;
    __unsafe_unretained NSTextListElement *_parentElement;
    // Where this element sits among its siblings, which is what the marker is derived from. One for an element
    // with contents, and the number of the children above a nesting parent.
    NSInteger _itemNumber;
    // What -initWithAttributedString: was given, for the one element the host makes without a list.
    NSAttributedString *_displayedString;
}

// -includesTextListMarkers is a 26.0 member the build SDK does not declare, so it is not a property in this
// file; the 26.0 row's entry says where the port answers it.

- (instancetype)initWithParentElement:(NSTextListElement *)parent
                             textList:(NSTextList *)textList
                             contents:(NSAttributedString *)contents
                     markerAttributes:(NSDictionary<NSAttributedStringKey, id> *)markerAttributes
                        childElements:(NSArray<NSTextListElement *> *)children
{
    // The header's own precondition: one of contents, markerAttributes or childElements must be there, since an
    // element with none of the three is nothing to display and nothing to mark.
    if (!contents && !markerAttributes && !children.count) {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@ needs contents, marker attributes or child elements", NSStringFromClass([self class])];
        return nil;
    }
    if ((self = [super initWithAttributedString:nil])) {
        _textList = textList;
        _contents = [contents copy];
        _markerAttributes = [markerAttributes copy];
        _childElements = [children copy] ?: @[];
        _parentElement = parent;
        // A nesting parent's own number is the number of the children it holds, which is what makes a list of
        // nesting parents count the items inside them.
        _itemNumber = contents ? (NSInteger)[_childElements count] : 1;
    }
    return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
{
    // NS_UNAVAILABLE in the header, because an element's contents are not its attributed string - the marker is
    // in one and not the other. The host does not refuse it, though: measured, it makes an element with the string
    // as what it displays, and no list, no contents and no marker of its own (M12), so that is what this makes.
    // An application cannot compile the call, and a subclass of this port can.
    if ((self = [super initWithAttributedString:attributedString]))
        _displayedString = [attributedString copy];
    return self;
}

+ (instancetype)textListElementWithContents:(NSAttributedString *)contents
                           markerAttributes:(NSDictionary<NSAttributedStringKey, id> *)markerAttributes
                                   textList:(NSTextList *)textList
                              childElements:(NSArray<NSTextListElement *> *)children
{
    return [[self alloc] initWithParentElement:nil
                                      textList:textList
                                      contents:contents
                              markerAttributes:markerAttributes
                                 childElements:children];
}

+ (instancetype)textListElementWithChildElements:(NSArray<NSTextListElement *> *)children
                                        textList:(NSTextList *)textList
                                   nestingLevel:(NSInteger)nestingLevel
{
    // The header's own three: nil for no children, and an exception for a negative nesting level, which is not a
    // number of shifts a tree can have.
    if (nestingLevel < 0) {
        [NSException raise:NSInvalidArgumentException format:@"a nesting level cannot be %ld", (long)nestingLevel];
        return nil;
    }
    if (!children.count)
        return nil;
    return [[self alloc] initWithParentElement:nil
                                      textList:textList
                                      contents:nil
                              markerAttributes:nil
                                 childElements:children];
}

- (NSAttributedString *)contents
{
    return _contents;
}

- (NSDictionary<NSAttributedStringKey, id> *)markerAttributes
{
    return _markerAttributes;
}

- (NSTextList *)textList
{
    return _textList;
}

- (NSArray<NSTextListElement *> *)childElements
{
    return [_childElements copy];
}

- (NSTextListElement *)parentElement
{
    return _parentElement;
}

// What the document holds for this element: the marker's text with the marker's own formatting, then the
// contents. That is the string the header says is derived from the contents and the list, and it is what a
// document cuts this element into - which is the whole reason an element that is a list item is a different kind
// of element from a plain paragraph.
- (NSAttributedString *)attributedString
{
    if (_displayedString)
        return _displayedString;
    NSMutableAttributedString *text = [[NSMutableAttributedString alloc] initWithString:@""];
    NSString *marker = [self charon_marker];
    if (marker) {
        NSDictionary *attributes = _markerAttributes.count ? _markerAttributes
                                                           : @{ NSFontAttributeName : [UIFont systemFontOfSize:12] };
        [text appendAttributedString:[[NSAttributedString alloc] initWithString:marker attributes:attributes]];
    }
    if (_contents)
        [text appendAttributedString:_contents];
    return text;
}

// The marker's text, from the list, which is the one place that knows how a number becomes a marker. An element
// with no list has no marker, and an element with no number in it either - a nesting parent is marked by its
// children rather than by a number of its own.
- (NSString *)charon_marker
{
    if (!_textList || !_contents)
        return nil;
    return [_textList markerForItemNumber:_itemNumber];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; contents = %lu characters; children = %lu; list = %@>",
                                      NSStringFromClass([self class]), self, (unsigned long)_contents.length,
                                      (unsigned long)_childElements.count, _textList ? @"yes" : @"no"];
}

@end

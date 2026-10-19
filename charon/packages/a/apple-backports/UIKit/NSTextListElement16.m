#import <UIKit/UIKit.h>

@implementation NSTextListElement {
    NSAttributedString *_contents;
    NSDictionary *_markerAttributes;
    NSTextList *_textList;
    NSArray<NSTextListElement *> *_childElements;
    __unsafe_unretained NSTextListElement *_parentElement;
    NSInteger _itemNumber;
    NSAttributedString *_displayedString;
}

- (instancetype)initWithParentElement:(NSTextListElement *)parent
                             textList:(NSTextList *)textList
                             contents:(NSAttributedString *)contents
                     markerAttributes:(NSDictionary<NSAttributedStringKey, id> *)markerAttributes
                        childElements:(NSArray<NSTextListElement *> *)children
{
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
        _itemNumber = contents ? (NSInteger)[_childElements count] : 1;
    }
    return self;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
{
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

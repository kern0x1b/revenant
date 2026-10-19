#import <UIKit/UIKit.h>
#import "CharonTextLocation.h"

static BOOL charon_is_paragraph_ending(NSString *string, NSUInteger index)
{
    if (index >= string.length)
        return NO;
    unichar c = [string characterAtIndex:index];
    if (c == 10)
        return YES;
    if (c != 13)
        return NO;
    return index + 1 >= string.length || [string characterAtIndex:index + 1] != 10;
}

@implementation NSTextContentStorage {
    NSTextStorage *_textStorage;
    NSAttributedString *_attributedString;
    NSTextRange *_documentRange;
    NSRange _lastEditedRange;
    NSInteger _lastChangeInLength;
    BOOL _hasEdited;
}

@synthesize delegate = _delegate;

- (instancetype)init
{
    if ((self = [super init])) {
        _textStorage = [[NSTextStorage alloc] initWithAttributedString:[[NSAttributedString alloc] initWithString:@""]];
        _textStorage.textStorageObserver = self;
        _lastEditedRange = NSMakeRange(NSNotFound, 0);
    }
    return self;
}

- (instancetype)initWithTextStorage:(NSTextStorage *)textStorage
{
    if ((self = [super init])) {
        _textStorage = textStorage;
        _textStorage.textStorageObserver = self;
        _lastEditedRange = NSMakeRange(NSNotFound, 0);
    }
    return self;
}

#pragma mark - NSTextStorageObserving

- (NSTextStorage *)textStorage
{
    return _textStorage;
}

- (void)setTextStorage:(NSTextStorage *)textStorage
{
    if (_textStorage == textStorage)
        return;
    _textStorage.textStorageObserver = nil;
    _textStorage = textStorage;
    _textStorage.textStorageObserver = self;
    [self charon_rebuild_document_range];
}

- (void)processEditingForTextStorage:(NSTextStorage *)textStorage
                             edited:(NSTextStorageEditActions)editMask
                              range:(NSRange)newCharRange
                      changeInLength:(NSInteger)delta
                    invalidatedRange:(NSRange)invalidatedCharRange
{
    if (textStorage != _textStorage)
        return;
    _lastEditedRange = newCharRange;
    _lastChangeInLength = delta;
    _hasEdited = YES;
    [self charon_rebuild_document_range];
}

- (void)performEditingTransactionForTextStorage:(NSTextStorage *)textStorage usingBlock:(void (NS_NOESCAPE ^)(void))transaction
{
    [self performEditingTransactionUsingBlock:^{
        if (transaction)
            transaction();
    }];
}

#pragma mark - Document contents

- (NSAttributedString *)attributedString
{
    return _textStorage ? [_textStorage copy] : [_attributedString copy];
}

- (void)setAttributedString:(NSAttributedString *)attributedString
{
    if (_textStorage)
        return;
    _attributedString = [attributedString copy];
    [self charon_rebuild_document_range];
}

- (NSTextRange *)documentRange
{
    if (!_documentRange)
        [self charon_rebuild_document_range];
    return _documentRange;
}

- (void)charon_rebuild_document_range
{
    NSInteger length = (NSInteger)[self attributedString].length;
    _documentRange = [[NSTextRange alloc] initWithLocation:[[CharonTextLocation alloc] initWithTextContentStorage:self
                                                                                                             offset:0]
                                               endLocation:[[CharonTextLocation alloc] initWithTextContentStorage:self
                                                                                                               offset:length]];
}

#pragma mark - Locations

- (id<NSTextLocation>)locationFromLocation:(id<NSTextLocation>)location withOffset:(NSInteger)offset
{
    CharonTextLocation *from = (CharonTextLocation *)location;
    if (![from isKindOfClass:[CharonTextLocation class]] || from.textContentStorage != self)
        return nil;
    NSInteger where = from.offset + offset;
    NSInteger length = (NSInteger)[self attributedString].length;
    if (where < 0 || where > length)
        return nil;
    return [[CharonTextLocation alloc] initWithTextContentStorage:self offset:where];
}

- (NSInteger)offsetFromLocation:(id<NSTextLocation>)from toLocation:(id<NSTextLocation>)to
{
    CharonTextLocation *a = (CharonTextLocation *)from;
    CharonTextLocation *b = (CharonTextLocation *)to;
    if (![a isKindOfClass:[CharonTextLocation class]] || ![b isKindOfClass:[CharonTextLocation class]] ||
        a.textContentStorage != self || b.textContentStorage != self)
        return NSNotFound;
    return b.offset - a.offset;
}

#pragma mark - Elements

- (id<NSTextLocation>)enumerateTextElementsFromLocation:(id<NSTextLocation>)textLocation
                                                options:(NSTextContentManagerEnumerationOptions)options
                                             usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextElement *element))block
{
    if (!block)
        return nil;
    NSAttributedString *string = [self attributedString];
    NSInteger length = (NSInteger)string.length;
    NSTextContentManagerEnumerationOptions enumeration = options & NSTextContentManagerEnumerationOptionsReverse;
    NSInteger from = 0;
    if (textLocation) {
        if (![textLocation isKindOfClass:[CharonTextLocation class]] || ((CharonTextLocation *)textLocation).textContentStorage != self)
            return nil;
        from = ((CharonTextLocation *)textLocation).offset;
    } else if (enumeration == NSTextContentManagerEnumerationOptionsReverse) {
        from = length;
    }
    if (enumeration == NSTextContentManagerEnumerationOptionsReverse)
        from = textLocation ? [self charon_paragraph_start_before:from] : length;
    CharonTextLocation *edge = nil;
    for (NSInteger start = from;;) {
        NSInteger end = [self charon_paragraph_end_after:start limit:length];
        if (enumeration != NSTextContentManagerEnumerationOptionsReverse) {
            NSTextParagraph *paragraph = [self charon_paragraph_from:start to:end];
            if (paragraph && ![self charon_should_enumerate:paragraph options:enumeration])
                paragraph = nil;
            if (paragraph) {
                edge = [[CharonTextLocation alloc] initWithTextContentStorage:self offset:end];
                if (!block(paragraph))
                    break;
            } else {
                edge = edge ?: [[CharonTextLocation alloc] initWithTextContentStorage:self offset:end];
            }
            if (end >= length)
                break;
            start = end;
        } else {
            if (start <= 0)
                break;
            NSInteger paragraphStart = [self charon_paragraph_start_before:start - 1];
            NSTextParagraph *paragraph = [self charon_paragraph_from:paragraphStart to:start];
            if (paragraph && ![self charon_should_enumerate:paragraph options:enumeration])
                paragraph = nil;
            if (paragraph) {
                edge = [[CharonTextLocation alloc] initWithTextContentStorage:self offset:paragraphStart];
                if (!block(paragraph))
                    break;
            } else {
                edge = edge ?: [[CharonTextLocation alloc] initWithTextContentStorage:self offset:paragraphStart];
            }
            start = paragraphStart;
        }
    }
    return edge;
}

- (NSArray<NSTextElement *> *)textElementsForRange:(NSTextRange *)range
{
    if (!range || !range.location)
        return @[];
    NSMutableArray *elements = [NSMutableArray array];
    if ([self offsetFromLocation:range.location
                     toLocation:range.endLocation ?: [self locationFromLocation:nil withOffset:0]] == NSNotFound)
        return @[];
    NSInteger start = ((CharonTextLocation *)range.location).offset;
    NSInteger length = (NSInteger)[[self attributedString] length];
    NSInteger end = range.endLocation ? ((CharonTextLocation *)range.endLocation).offset : length;
    [self enumerateTextElementsFromLocation:range.location
                                    options:NSTextContentManagerEnumerationOptionsNone
                                 usingBlock:^BOOL(NSTextElement *element) {
                                     if (!element.elementRange)
                                         return NO;
                                     NSInteger from = ((CharonTextLocation *)element.elementRange.location).offset;
                                     NSInteger to = ((CharonTextLocation *)element.elementRange.endLocation).offset;
                                     if (from >= end || to <= start)
                                         return NO;
                                     [elements addObject:element];
                                     return YES;
                                 }];
    return elements;
}

- (NSTextParagraph *)charon_paragraph_from:(NSInteger)start to:(NSInteger)end
{
    NSRange range = NSMakeRange((NSUInteger)start, (NSUInteger)MAX((NSInteger)0, end - start));
    id<NSTextContentStorageDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(textContentStorage:textParagraphWithRange:)]) {
        NSTextParagraph *given = [delegate textContentStorage:self textParagraphWithRange:range];
        if (given)
            return given;
    }
    NSAttributedString *string = [self attributedString];
    if (range.location > string.length)
        return nil;
    if (NSMaxRange(range) > string.length)
        range.length = string.length - range.location;
    NSTextParagraph *paragraph = [[NSTextParagraph alloc] initWithAttributedString:[string attributedSubstringFromRange:range]];
    paragraph.textContentManager = self;
    paragraph.elementRange = [[NSTextRange alloc] initWithLocation:[[CharonTextLocation alloc] initWithTextContentStorage:self
                                                                                                                     offset:(NSInteger)range.location]
                                                      endLocation:[[CharonTextLocation alloc] initWithTextContentStorage:self
                                                                                                                offset:(NSInteger)NSMaxRange(range)]];
    return paragraph;
}

- (BOOL)charon_should_enumerate:(NSTextElement *)element
                       options:(NSTextContentManagerEnumerationOptions)options
{
    id<NSTextContentManagerDelegate> delegate = self.delegate;
    if (![delegate respondsToSelector:@selector(textContentManager:shouldEnumerateTextElement:options:)])
        return YES;
    return [delegate textContentManager:self shouldEnumerateTextElement:element options:options];
}

- (NSInteger)charon_paragraph_end_after:(NSInteger)start limit:(NSInteger)length
{
    NSString *string = [self attributedString].string;
    for (NSInteger index = start; index < length; index++) {
        if (!charon_is_paragraph_ending(string, (NSUInteger)index))
            continue;
        return index + 1;
    }
    return length;
}

- (NSInteger)charon_paragraph_start_before:(NSInteger)offset
{
    NSString *string = [self attributedString].string;
    NSInteger length = (NSInteger)string.length;
    if (offset <= 0)
        return 0;
    if (offset > length)
        offset = length;
    NSInteger start = 0;
    NSInteger index = 0;
    while (index < offset) {
        if (!charon_is_paragraph_ending(string, (NSUInteger)index)) {
            index++;
            continue;
        }
        index++;
        if (index <= offset)
            start = index;
    }
    return start;
}

#pragma mark - The element provider's own two questions

- (void)replaceContentsInRange:(NSTextRange *)range withTextElements:(NSArray<NSTextElement *> *)textElements
{
    if (!range || !range.location)
        return;
    NSInteger from = (NSInteger)[self offsetFromLocation:range.location toLocation:range.endLocation];
    if (from == NSNotFound)
        return;
    NSMutableAttributedString *replacement = [[NSMutableAttributedString alloc] initWithString:@""];
    for (NSTextElement *element in textElements) {
        NSAttributedString *contents = [element isKindOfClass:[NSTextParagraph class]]
                                          ? ((NSTextParagraph *)element).attributedString
                                          : nil;
        if (contents)
            [replacement appendAttributedString:contents];
    }
    NSInteger length = (NSInteger)[self attributedString].length;
    if (from > length)
        from = length;
    NSRange target = NSMakeRange((NSUInteger)from, (NSUInteger)(length - from));
    if (_textStorage) {
        [_textStorage replaceCharactersInRange:target withString:@""];
        [_textStorage replaceCharactersInRange:NSMakeRange((NSUInteger)from, 0) withString:replacement.string];
    } else {
        NSMutableAttributedString *document = [_attributedString mutableCopy];
        [document replaceCharactersInRange:target withString:@""];
        [document replaceCharactersInRange:NSMakeRange((NSUInteger)from, 0) withString:replacement.string];
        _attributedString = document;
    }
    [self charon_rebuild_document_range];
}

- (void)synchronizeToBackingStore:(void (^)(NSError *_Nullable error))completionHandler
{
    [super synchronizeToBackingStore:completionHandler];
}

- (NSTextRange *)adjustedRangeFromRange:(NSTextRange *)textRange forEditingTextSelection:(BOOL)forEditingTextSelection
{
    if (!_hasEdited || !textRange || !textRange.location)
        return nil;
    if (forEditingTextSelection && textRange.isEmpty)
        return textRange;
    NSInteger from = (NSInteger)[self offsetFromLocation:textRange.location toLocation:textRange.endLocation];
    if (from == NSNotFound)
        return nil;
    NSInteger start = (NSInteger)[self offsetFromLocation:self.documentRange.location toLocation:textRange.location];
    NSInteger end = start + from;
    NSRange edited = _lastEditedRange;
    if (edited.location == NSNotFound)
        return nil;
    if (end < edited.location)
        return textRange;
    NSInteger shift = _lastChangeInLength;
    NSInteger newStart = start, newEnd = end;
    if (start >= edited.location) {
        newStart = start + shift;
        newEnd = end + shift;
    } else if (end > edited.location) {
        newEnd = edited.location + MAX((NSInteger)0, edited.length + shift);
    }
    return [[NSTextRange alloc] initWithLocation:[[CharonTextLocation alloc] initWithTextContentStorage:self offset:newStart]
                                      endLocation:[[CharonTextLocation alloc] initWithTextContentStorage:self offset:newEnd]];
}

#pragma mark - The two conversions the header puts on the concrete store

- (NSAttributedString *)attributedStringForTextElement:(NSTextElement *)textElement
{
    if (![textElement isKindOfClass:[NSTextParagraph class]])
        return nil;
    return ((NSTextParagraph *)textElement).attributedString;
}

- (NSTextElement *)textElementForAttributedString:(NSAttributedString *)attributedString
{
    if (!attributedString)
        return nil;
    return [self charon_paragraph_from:0 to:(NSInteger)attributedString.length];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p; document = %@>", NSStringFromClass([self class]), self,
                                      [self documentRange]];
}

@end

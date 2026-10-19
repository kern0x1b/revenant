// NSTextContentStorage: the concrete content manager, over an NSTextStorage. It is the document, the elements
// the document is made of, and - the part the whole of TextKit 2 stands on - the factory for the locations a
// range is made of. What the header declares is NSTextContentManager.h of SDK 26.2; what the host's own UIKit
// answers is in facts/UIKit/NSTextContent15.md.
//
// The document is an NSTextStorage, and the storage observes it: NSTextStorage asks its observer to process an
// edit when one is finished, and that is how a range stays true while the text under it is edited. The elements
// are NSTextParagraphs, one per paragraph of the string, which is the mapping the header's own standard-mapping
// language describes and the only one a plain attributed string can have; a subclass supplies its own by
// answering the delegate. Locations are CharonTextLocation, over an offset, and every question about one is
// answered by the arithmetic in this file.

#import <UIKit/UIKit.h>
#import "CharonTextLocation.h"

// The two characters a paragraph ends with, which is where the document's elements are cut. A carriage return
// before a line feed is one ending and not two, which is what a paragraph separator is.
static BOOL charon_is_paragraph_ending(NSString *string, NSUInteger index)
{
    if (index >= string.length)
        return NO;
    unichar c = [string characterAtIndex:index];
    if (c == 10)
        return YES;
    if (c != 13)
        return NO;
    // A CR that is not followed by an LF is its own ending; a CR LF pair is one ending of two characters.
    return index + 1 >= string.length || [string characterAtIndex:index + 1] != 10;
}

// -includesTextListMarkers is a 26.0 member of THIS class the build SDK does not declare, so it is not a
// property in this file, and it is not answered on this class either: its registry row answers absent, and
// the reason is the text production rather than the spelling - this storage's elements are NSTextParagraphs
// and it produces no NSTextListMarker. The 26.0 member of the name that IS carried is NSTextList's, written
// out in UIKit26_0.m. -textStorage is the protocol's, and the port implements its getter and setter by hand
// because the protocol's is a plain property and the observer has to move with it.

@implementation NSTextContentStorage {
    // The backing store, and the string this object answers for. When there is a text storage the string is
    // the storage's, because the header says the storage wins over -attributedString; without one, the
    // attributed string is the document.
    NSTextStorage *_textStorage;
    NSAttributedString *_attributedString;
    // The document range in this object's own locations, kept because a document's range is asked for on every
    // question about a location and building it is two allocations.
    NSTextRange *_documentRange;
    // The most recent edit, in offsets, so that -adjustedRangeFromRange:forEditingTextSelection: has the one
    // thing it needs to answer without holding on to the ranges themselves, which the caller may have changed.
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
        // The observer is weak in the storage, so the storage is held here: a content storage with no text
        // storage of its own observes nothing, and one with a text storage is what keeps them both alive.
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
    // The observer is weak in the storage, so leaving the old one unobserved is what lets it go, and observing
    // the new one is what keeps the document and this object in step.
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
    // The document's range is built from the string's length, so an edit that changes the length has to rebuild
    // it; the last edit is recorded for -adjustedRangeFromRange:forEditingTextSelection: to answer from.
    _lastEditedRange = newCharRange;
    _lastChangeInLength = delta;
    _hasEdited = YES;
    [self charon_rebuild_document_range];
}

- (void)performEditingTransactionForTextStorage:(NSTextStorage *)textStorage usingBlock:(void (NS_NOESCAPE ^)(void))transaction
{
    // The storage's own transaction is this manager's transaction, so a beginEditing on the storage is what opens
    // one here: nesting and the outermost-synchronisation rules are then the manager's, which is what they are.
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
    // The header: a text storage of its own wins, so setting the string while there is one leaves the document
    // where it is rather than pretending to have changed it.
    if (_textStorage)
        return;
    _attributedString = [attributedString copy];
    [self charon_rebuild_document_range];
}

// The document's range, in this object's own locations: from offset zero to the string's length. A document of
// nothing is an empty range at zero, which is a range and not a nil, because the header types it nonnull.
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
    // A location outside the document is no legal location, which is what the header says a nil here is.
    if (where < 0 || where > length)
        return nil;
    return [[CharonTextLocation alloc] initWithTextContentStorage:self offset:where];
}

- (NSInteger)offsetFromLocation:(id<NSTextLocation>)from toLocation:(id<NSTextLocation>)to
{
    CharonTextLocation *a = (CharonTextLocation *)from;
    CharonTextLocation *b = (CharonTextLocation *)to;
    // The header: NSNotFound when the offset cannot be represented, which is what two documents' locations are.
    if (![a isKindOfClass:[CharonTextLocation class]] || ![b isKindOfClass:[CharonTextLocation class]] ||
        a.textContentStorage != self || b.textContentStorage != self)
        return NSNotFound;
    return b.offset - a.offset;
}

#pragma mark - Elements

// One element per paragraph, cut at the paragraph endings, and the delegate may give a paragraph of its own for
// any range it is asked about - which is the hook a subclass's document type uses, and the one the header
// describes as its standard mapping.
- (id<NSTextLocation>)enumerateTextElementsFromLocation:(id<NSTextLocation>)textLocation
                                                options:(NSTextContentManagerEnumerationOptions)options
                                             usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextElement *element))block
{
    if (!block)
        return nil;
    NSAttributedString *string = [self attributedString];
    NSInteger length = (NSInteger)string.length;
    NSTextContentManagerEnumerationOptions enumeration = options & NSTextContentManagerEnumerationOptionsReverse;
    // nil means the start of the document going forward and the end of it going back, which is the header's rule.
    NSInteger from = 0;
    if (textLocation) {
        if (![textLocation isKindOfClass:[CharonTextLocation class]] || ((CharonTextLocation *)textLocation).textContentStorage != self)
            return nil;
        from = ((CharonTextLocation *)textLocation).offset;
    } else if (enumeration == NSTextContentManagerEnumerationOptionsReverse) {
        from = length;
    }
    // Going backward the walk is over the paragraphs that END at an offset, so the offset it starts from is the
    // end of the document when the location is nil - the last paragraph is the first one enumerated - and the
    // start of the paragraph holding the location when it is not, because the header says the backward
    // enumeration starts with the element *preceding* the one containing it.
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
            // The paragraph that ends at `start`: the one before the paragraph holding the location, and the
            // next one further back after that. The walk ends because `start` strictly decreases:
            // charon_paragraph_start_before: is handed start - 1 and answers at most that, so the paragraph's own
            // start is below the offset asked of, and the loop's own `start <= 0` test is what ends it. A guard
            // saying `paragraphStart >= start` was here and could not be true for any start at all - it is
            // removed rather than kept as a check nothing can reach.
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

// The elements intersecting a range, in sequence: the enumeration from the range's start, stopping at its end.
// The header's own word for the result is "intersecting", so an element is in the array only while it shares a
// character with the range, and the enumeration stops at the first that does not - which is the last one, the
// sequence being in document order. An element that begins exactly where the range ends does not share a
// character with it and is not in the array.
- (NSArray<NSTextElement *> *)textElementsForRange:(NSTextRange *)range
{
    if (!range || !range.location)
        return @[];
    NSMutableArray *elements = [NSMutableArray array];
    // The two ends as offsets. -offsetFromLocation:toLocation: is the distance between them, not the position of
    // the second, so a range over the second paragraph would be read as ending where it starts. A range made of
    // one location ends at the document's end, which is what the header says the one-argument initialiser makes.
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
                                     // Two ranges meet when each has a character the other has not, so the element
                                     // is in the array while it both begins before the range's end and ends after
                                     // its start. The enumeration is in sequence, so the first element that does
                                     // not is the last one, and asking for more of them would be walking the
                                     // document to throw the answers away.
                                     if (from >= end || to <= start)
                                         return NO;
                                     [elements addObject:element];
                                     return YES;
                                 }];
    return elements;
}

// The paragraph of a range, from the delegate when it will give one and from the string's own attributes when
// it will not, which is the header's standard mapping.
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

// The delegate may skip an element from the enumeration, which is its own rule and not this file's.
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
        // One character past the ending is the next paragraph's start, and a CR LF pair is one ending of two
        // characters because charon_is_paragraph_ending does not call the CR of a pair an ending at all.
        return index + 1;
    }
    return length;
}

// The start of the paragraph that holds `offset`: the position just after the last paragraph ending before it,
// with a CR LF pair one ending of two characters. It is found by walking the endings forward rather than by
// stepping back from the offset, because stepping back stops at the first ending it meets and answers the
// start of the paragraph AFTER that one - which is a paragraph's own start handed straight back, and a walk
// that asks for the paragraph before that never moves.
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
        // An element's own contents are what the port can read, and an element it cannot read contributes
        // nothing, which is what the header calls adjusting the replacement range.
        NSAttributedString *contents = [element isKindOfClass:[NSTextParagraph class]]
                                          ? ((NSTextParagraph *)element).attributedString
                                          : nil;
        if (contents)
            [replacement appendAttributedString:contents];
    }
    // The document is edited where it is held: the text storage when there is one, and a mutable copy of the
    // attributed string otherwise. -attributedString answers a copy, and a copy is not the document.
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
    // The base class refuses a synchronization inside a transaction; a concrete store whose document lives
    // somewhere else writes it out here, and this one has nothing to write.
    [super synchronizeToBackingStore:completionHandler];
}

// The range a text range should be read at, after an edit moved the text under it. Nothing needs adjusting until
// something has been edited, and nothing needs it for a range that ends before the edit began.
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
    // The header's own rule: when the range meets or follows the edit, it is moved by what the edit did.
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
    // The contents of an element, and nil for one whose contents are not a string, which is the header's own
    // "returns if textElement cannot be mapped to NSAttributedString".
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

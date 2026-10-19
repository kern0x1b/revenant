#import "CharonPDFKit.h"
#import "PDFPageText11.h"
#include <ctype.h>

@interface CharonPDFSelectionSpan : NSObject
@property (nonatomic, strong) PDFPage *page;
@property (nonatomic) NSRange range;
@property (nonatomic) NSRange textRange;
@end

@implementation CharonPDFSelectionSpan
@synthesize page = _page;
@synthesize range = _range;
@synthesize textRange = _textRange;
@end

#if __has_include(<UIKit/UIKit.h>)
#import <UIKit/UIKit.h>
#define CHARON_SELECTION_HAS_UIFONT 1
#endif

@interface PDFSelection ()
- (void)charon_setUpWithSpans:(nullable NSArray<CharonPDFSelectionSpan *> *)spans
                      document:(nullable PDFDocument *)document;
@end

@implementation PDFSelection {
    NSMutableArray<CharonPDFSelectionSpan *> *_spans;
    __weak PDFDocument *_document;
    UIColor *_color;
}

- (void)charon_setUpWithSpans:(NSArray<CharonPDFSelectionSpan *> *)spans
                      document:(PDFDocument *)document
{
    _spans = spans != nil ? [spans mutableCopy] : [NSMutableArray array];
    _document = document;
}

- (instancetype)initWithDocument:(PDFDocument *)document
{
    self = [super init];
    if (self == nil)
        return nil;
    [self charon_setUpWithSpans:nil document:document];
    return self;
}

- (instancetype)init
{
    return [self initWithDocument:nil];
}

- (void)charon_addSpanOnPage:(PDFPage *)page range:(NSRange)range
{
    if (page == nil || range.location == NSNotFound || range.length == 0)
        return;
    CharonPDFSelectionSpan *span = [[CharonPDFSelectionSpan alloc] init];
    span.page = page;
    span.range = range;
    span.textRange = charonTextRangeForRange(page, range);
    [_spans addObject:span];
}

- (NSArray<CharonPDFSelectionSpan *> *)charon_spansOnPage:(PDFPage *)page
{
    NSMutableArray<CharonPDFSelectionSpan *> *answer = [NSMutableArray array];
    if (page == nil)
        return answer;
    for (CharonPDFSelectionSpan *span in _spans) {
        if (span.page == page)
            [answer addObject:span];
    }
    return answer;
}

static NSRange charonTextRangeForRange(PDFPage *page, NSRange range)
{
    NSRange textRange = range;
    if (page == nil || textRange.length == 0)
        return textRange;
    NSString *text = [page charon_textLayout].string;
    NSUInteger last = NSMaxRange(textRange);
    if (text != nil && last <= text.length && [text characterAtIndex:last - 1] == '\n')
        textRange.length -= 1;
    return textRange;
}

- (NSUInteger)charon_pageIndexOf:(PDFPage *)page
{
    return page.pageIndex;
}

- (NSArray<PDFPage *> *)pages
{
    NSMutableArray<PDFPage *> *answer = [NSMutableArray array];
    PDFPage *last = nil;
    for (CharonPDFSelectionSpan *span in _spans) {
        if (span.page != last) {
            [answer addObject:span.page];
            last = span.page;
        }
    }
    return answer;
}

- (NSString *)string
{
    if (_spans.count == 0)
        return nil;
    NSMutableString *answer = [NSMutableString string];
    PDFPage *page = nil;
    for (CharonPDFSelectionSpan *span in _spans) {
        CharonPDFPageText *layout = [span.page charon_textLayout];
        if (span.page != page) {
            if (page != nil)
                [answer appendString:@"\n"];
            page = span.page;
        }
        NSString *piece = [layout substringForRange:span.textRange];
        if (piece != nil)
            [answer appendString:piece];
    }
    return answer;
}

- (NSAttributedString *)attributedString
{
    NSString *text = [self string];
    if (text == nil)
        return nil;
    NSMutableAttributedString *answer = [[NSMutableAttributedString alloc] initWithString:text];
#ifdef CHARON_SELECTION_HAS_UIFONT
    NSUInteger at = 0;
    for (CharonPDFSelectionSpan *span in _spans) {
        CharonPDFPageText *layout = [span.page charon_textLayout];
        CharonPDFTextRun *run = [layout runForOffset:span.textRange.location];
        NSUInteger length = span.textRange.length;
        if (run == nil || length == 0)
            continue;
        NSString *name = run.fontName;
        if (name.length == 0)
            continue;
        UIFont *font = [UIFont fontWithName:name size:run.size];
        if (font != nil)
            [answer addAttribute:NSFontAttributeName value:font range:NSMakeRange(at, length)];
        at += length;
    }
#endif
    return answer;
}

- (NSUInteger)numberOfTextRangesOnPage:(PDFPage *)page
{
    return [self charon_spansOnPage:page].count;
}

- (NSRange)rangeAtIndex:(NSUInteger)index onPage:(PDFPage *)page
{
    NSArray<CharonPDFSelectionSpan *> *spans = [self charon_spansOnPage:page];
    if (index >= spans.count)
        return NSMakeRange(NSNotFound, 0);
    return spans[index].range;
}

- (CGRect)boundsForPage:(PDFPage *)page
{
    NSArray<CharonPDFSelectionSpan *> *spans = [self charon_spansOnPage:page];
    if (spans.count == 0)
        return CGRectNull;
    CGRect answer = CGRectNull;
    for (CharonPDFSelectionSpan *span in spans) {
        CGRect rect = [[span.page charon_textLayout] boundsForRange:span.range];
        if (CGRectIsNull(rect))
            continue;
        answer = CGRectIsNull(answer) ? rect : CGRectUnion(answer, rect);
    }
    return answer;
}

- (NSArray<PDFSelection *> *)selectionsByLine
{
    NSMutableArray<PDFSelection *> *answer = [NSMutableArray array];
    for (CharonPDFSelectionSpan *span in _spans) {
        CharonPDFPageText *layout = [span.page charon_textLayout];
        NSArray<NSValue *> *lines = [layout lineRangesForRange:span.range];
        for (NSValue *boxed in lines) {
            NSRange hit = [boxed rangeValue];
            CharonPDFSelectionSpan *line = [[CharonPDFSelectionSpan alloc] init];
            line.page = span.page;
            line.range = hit;
            line.textRange = charonTextRangeForRange(span.page, hit);
            PDFSelection *selection = [[PDFSelection alloc] initWithDocument:_document];
            [selection charon_setUpWithSpans:@[ line ] document:_document];
            [answer addObject:selection];
        }
    }
    return answer;
}

- (UIColor *)color
{
    return _color;
}

- (void)setColor:(UIColor *)color
{
    _color = color;
}

#pragma mark - the mutators

- (void)charon_unionWith:(NSArray<CharonPDFSelectionSpan *> *)other
{
    if (other.count == 0)
        return;
    NSMutableArray<CharonPDFSelectionSpan *> *merged = [NSMutableArray arrayWithArray:_spans];
    [merged addObjectsFromArray:other];
    [merged sortUsingComparator:^NSComparisonResult(CharonPDFSelectionSpan *a, CharonPDFSelectionSpan *b) {
        NSUInteger left = [self charon_pageIndexOf:a.page];
        NSUInteger right = [self charon_pageIndexOf:b.page];
        if (left != right)
            return left < right ? NSOrderedAscending : NSOrderedDescending;
        if (a.range.location < b.range.location)
            return NSOrderedAscending;
        if (a.range.location > b.range.location)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableArray<CharonPDFSelectionSpan *> *answer = [NSMutableArray array];
    for (CharonPDFSelectionSpan *span in merged) {
        CharonPDFSelectionSpan *last = answer.lastObject;
        if (last != nil && last.page == span.page && NSMaxRange(last.range) >= span.range.location &&
            span.range.location <= NSMaxRange(last.range)) {
            NSUInteger start = MIN(last.range.location, span.range.location);
            NSUInteger end = MAX(NSMaxRange(last.range), NSMaxRange(span.range));
            last.range = NSMakeRange(start, end - start);
            last.textRange = NSMakeRange(start, end - start);
            continue;
        }
        [answer addObject:span];
    }
    [_spans setArray:answer];
}

- (void)addSelection:(PDFSelection *)selection
{
    if (selection == nil)
        return;
    if (selection->_document != nil && _document != nil && selection->_document != _document)
        [NSException raise:NSGenericException
                    format:@"addSelection: selection document mismatch"];
    [self charon_unionWith:selection->_spans];
}

- (void)addSelections:(NSArray<PDFSelection *> *)selections
{
    NSMutableArray<CharonPDFSelectionSpan *> *spans = [NSMutableArray array];
    for (PDFSelection *selection in selections) {
        if (selection == nil)
            continue;
        if (selection->_document != nil && _document != nil && selection->_document != _document)
            [NSException raise:NSGenericException
                        format:@"addSelection: selection document mismatch"];
        [spans addObjectsFromArray:selection->_spans];
    }
    [self charon_unionWith:spans];
}

- (PDFPage *)charon_pageAfter:(PDFPage *)page
{
    PDFDocument *document = page.document;
    if (document == nil)
        return nil;
    NSUInteger at = [self charon_pageIndexOf:page];
    if (at + 1 >= document.pageCount)
        return nil;
    return [document pageAtIndex:at + 1];
}

- (PDFPage *)charon_pageBefore:(PDFPage *)page
{
    PDFDocument *document = page.document;
    if (document == nil)
        return nil;
    NSUInteger at = [self charon_pageIndexOf:page];
    if (at == 0)
        return nil;
    return [document pageAtIndex:at - 1];
}

- (CharonPDFSelectionSpan *)charon_lastSpan
{
    return _spans.lastObject;
}

- (void)charon_extendEndBy:(NSInteger)count
{
    if (_spans.count == 0 || count == 0)
        return;
    while (count != 0) {
        CharonPDFSelectionSpan *last = [self charon_lastSpan];
        if (last == nil)
            return;
        CharonPDFPageText *layout = [last.page charon_textLayout];
        NSUInteger length = layout.string.length;
        NSInteger room = (NSInteger)(length - NSMaxRange(last.range));
        if (count > 0) {
            NSInteger take = MIN(count, room);
            last.range = NSMakeRange(last.range.location, last.range.length + (NSUInteger)take);
            last.textRange = last.range;
            count -= take;
            if (count == 0)
                return;
            PDFPage *next = [self charon_pageAfter:last.page];
            if (next == nil)
                return;
            CharonPDFSelectionSpan *span = [[CharonPDFSelectionSpan alloc] init];
            span.page = next;
            span.range = NSMakeRange(0, 0);
            span.textRange = NSMakeRange(0, 0);
            [_spans addObject:span];
            continue;
        }
        NSInteger give = MIN(-count, (NSInteger)last.range.length);
        last.range = NSMakeRange(last.range.location, last.range.length - (NSUInteger)give);
        last.textRange = last.range;
        count += give;
        if (count == 0)
            return;
        if (last.range.length == 0) {
            [_spans removeObject:last];
            continue;
        }
        return;
    }
}

- (void)charon_extendStartBy:(NSInteger)count
{
    if (_spans.count == 0 || count == 0)
        return;
    while (count != 0) {
        CharonPDFSelectionSpan *first = _spans.firstObject;
        if (first == nil)
            return;
        if (count > 0) {
            NSInteger room = (NSInteger)first.range.location;
            NSInteger take = MIN(count, room);
            first.range = NSMakeRange(first.range.location - (NSUInteger)take, first.range.length + (NSUInteger)take);
            first.textRange = first.range;
            count -= take;
            if (count == 0)
                return;
            PDFPage *previous = [self charon_pageBefore:first.page];
            if (previous == nil)
                return;
            CharonPDFPageText *layout = [previous charon_textLayout];
            CharonPDFSelectionSpan *span = [[CharonPDFSelectionSpan alloc] init];
            span.page = previous;
            NSUInteger end = layout.string.length;
            span.range = NSMakeRange(end, 0);
            span.textRange = NSMakeRange(end, 0);
            [_spans insertObject:span atIndex:0];
            continue;
        }
        NSInteger give = MIN(-count, (NSInteger)first.range.length);
        first.range = NSMakeRange(first.range.location + (NSUInteger)give, first.range.length - (NSUInteger)give);
        first.textRange = first.range;
        count += give;
        if (count == 0)
            return;
        if (first.range.length == 0) {
            [_spans removeObject:first];
            continue;
        }
        return;
    }
}

- (void)extendSelectionAtEnd:(NSInteger)succeed
{
    [self charon_extendEndBy:succeed];
}

- (void)extendSelectionAtStart:(NSInteger)precede
{
    [self charon_extendStartBy:precede];
}

- (void)extendSelectionForLineBoundaries
{
    if (_spans.count == 0)
        return;
    CharonPDFSelectionSpan *first = _spans.firstObject;
    CharonPDFPageText *firstLayout = [first.page charon_textLayout];
    NSArray<NSValue *> *firstLines = [firstLayout lineRangesForRange:first.range];
    if (firstLines.count > 0)
        first.range = [[firstLines firstObject] rangeValue];
    CharonPDFSelectionSpan *last = [self charon_lastSpan];
    CharonPDFPageText *lastLayout = [last.page charon_textLayout];
    NSArray<NSValue *> *lastLines = [lastLayout lineRangesForRange:last.range];
    if (lastLines.count > 0)
        last.range = [[lastLines lastObject] rangeValue];
    for (CharonPDFSelectionSpan *span in _spans) {
        CharonPDFPageText *layout = [span.page charon_textLayout];
        NSRange textRange = span.range;
        NSUInteger last2 = NSMaxRange(textRange);
        if (last2 > textRange.location && last2 <= layout.string.length &&
            [layout.string characterAtIndex:last2 - 1] == '\n')
            textRange.length -= 1;
        span.textRange = textRange;
    }
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    NSMutableArray<CharonPDFSelectionSpan *> *spans = [NSMutableArray arrayWithCapacity:_spans.count];
    for (CharonPDFSelectionSpan *span in _spans) {
        CharonPDFSelectionSpan *copy = [[CharonPDFSelectionSpan alloc] init];
        copy.page = span.page;
        copy.range = span.range;
        copy.textRange = span.textRange;
        [spans addObject:copy];
    }
    PDFSelection *copy = [[PDFSelection alloc] initWithDocument:_document];
    [copy charon_setUpWithSpans:spans document:_document];
    copy->_color = _color;
    return copy;
}

@end

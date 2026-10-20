#import "PDFPageText11.h"

@implementation RevenantPDFTextRun {
    CGRect *_revenant_rects;
    NSUInteger _revenant_rectCount;
}@synthesize text = _text;
@synthesize offset = _offset;
@synthesize x = _x;
@synthesize y = _y;
@synthesize size = _size;
@synthesize fontName = _fontName;

- (void)dealloc
{
    free(_revenant_rects);
}

@end

@implementation RevenantPDFTextRun (RevenantGeometry)

- (void)revenant_setGlyphRects:(const CGRect *)rects count:(NSUInteger)count
{
    free(_revenant_rects);
    _revenant_rects = NULL;
    _revenant_rectCount = 0;
    if (rects == NULL || count == 0)
        return;
    _revenant_rects = malloc(sizeof(CGRect) * count);
    if (_revenant_rects == NULL)
        return;
    memcpy(_revenant_rects, rects, sizeof(CGRect) * count);
    _revenant_rectCount = count;
}

- (CGRect)rectAtIndex:(NSUInteger)index
{
    if (_revenant_rects == NULL || index >= _revenant_rectCount)
        return CGRectNull;
    return _revenant_rects[index];
}

@end

@interface RevenantBase14Widths : NSObject
+ (int)widthForCode:(int)code inFaceNamed:(const char *)name;
+ (double)descentForFaceNamed:(const char *)name;
@end

@implementation RevenantPDFFontMetrics {
    NSArray<NSNumber *> *_advances;
    CGPDFInteger _firstChar;
    char *_faceName;
}

@synthesize descent = _descent;
@synthesize size = _size;
@synthesize hasWidths = _hasWidths;

+ (instancetype)metricsWithFontDictionary:(CGPDFDictionaryRef)fontDictionary size:(CGFloat)size
{
    if (fontDictionary == NULL)
        return nil;
    RevenantPDFFontMetrics *metrics = [[RevenantPDFFontMetrics alloc] init];
    metrics->_size = size;
    metrics->_firstChar = 0;
    CGPDFDictionaryGetInteger(fontDictionary, "FirstChar", &metrics->_firstChar);

    CGPDFArrayRef widths = NULL;
    if (CGPDFDictionaryGetArray(fontDictionary, "Widths", &widths) && widths != NULL) {
        size_t count = CGPDFArrayGetCount(widths);
        NSMutableArray<NSNumber *> *scaled = [NSMutableArray arrayWithCapacity:count];
        CGFloat units = size / 1000.0;
        for (size_t i = 0; i < count; i++) {
            long width = 0;
            if (!CGPDFArrayGetInteger(widths, i, &width))
                width = 0;
            [scaled addObject:@((CGFloat)width * units)];
        }
        metrics->_advances = [scaled copy];
    }

    const char *base = NULL;
    if (CGPDFDictionaryGetName(fontDictionary, "BaseFont", &base) && base != NULL) {
        const char *face = base;
        if (strlen(face) > 7 && face[6] == '+')
            face += 7;
        size_t length = strlen(face);
        metrics->_faceName = malloc(length + 1);
        if (metrics->_faceName != NULL)
            memcpy(metrics->_faceName, face, length + 1);
    }

    CGFloat descent = 0;
    CGPDFDictionaryRef descriptor = NULL;
    if (CGPDFDictionaryGetDictionary(fontDictionary, "FontDescriptor", &descriptor) &&
        descriptor != NULL) {
        CGPDFReal value = 0;
        if (CGPDFDictionaryGetNumber(descriptor, "Descent", &value))
            descent = (CGFloat)value * (size / 1000.0);
    }
    if (descent == 0 && metrics->_faceName != nil)
        descent = (CGFloat)[RevenantBase14Widths descentForFaceNamed:metrics->_faceName] * (size / 1000.0);
    metrics->_descent = descent;
    metrics->_hasWidths = metrics->_advances != nil || metrics->_faceName != nil;
    return metrics;
}

- (void)dealloc
{
    free(_faceName);
}

- (CGFloat)advanceForCode:(int)code
{
    if (_advances != nil) {
        long at = (long)code - (long)_firstChar;
        if (at < 0 || (size_t)at >= _advances.count)
            return 0;
        return (CGFloat)[[_advances objectAtIndex:(NSUInteger)at] doubleValue];
    }
    if (_faceName == nil)
        return 0;
    int width = [RevenantBase14Widths widthForCode:code inFaceNamed:_faceName];
    if (width < 0)
        return 0;
    return (CGFloat)width * _size / 1000.0;
}

@end

@implementation RevenantPDFPageText {
    NSUInteger *_breaks;
    NSUInteger _breakCount;
    NSArray<NSNumber *> *_charOffsets;
}

@synthesize string = _string;
@synthesize runs = _runs;

static NSString *revenantCloseLine(NSString *line, NSUInteger **mapping, NSUInteger *mappingCount)
{
    NSUInteger length = line.length;
    NSUInteger start = 0;
    NSUInteger end = length;
    while (start < end && [line characterAtIndex:start] == ' ')
        start++;
    while (end > start && [line characterAtIndex:end - 1] == ' ')
        end--;
    NSMutableString *closed = [NSMutableString stringWithCapacity:end - start];
    NSMutableArray<NSNumber *> *from = [NSMutableArray arrayWithCapacity:end - start];
    BOOL afterSpace = NO;
    for (NSUInteger i = start; i < end; i++) {
        unichar c = [line characterAtIndex:i];
        if (c == ' ') {
            if (afterSpace)
                continue;
            afterSpace = YES;
        } else {
            afterSpace = NO;
        }
        [closed appendFormat:@"%C", c];
        [from addObject:@(i)];
    }
    *mappingCount = from.count;
    if (from.count > 0) {
        *mapping = malloc(sizeof(NSUInteger) * from.count);
        if (*mapping == NULL) {
            *mappingCount = 0;
            return nil;
        }
        for (NSUInteger i = 0; i < from.count; i++)
            (*mapping)[i] = [[from objectAtIndex:i] unsignedIntegerValue];
    }
    return closed;
}

+ (instancetype)layoutWithRuns:(NSArray<RevenantPDFTextRun *> *)drawnRuns
{
    if (drawnRuns == nil)
        return nil;
    RevenantPDFPageText *layout = [[RevenantPDFPageText alloc] init];
    NSArray<RevenantPDFTextRun *> *ordered = [drawnRuns sortedArrayWithOptions:NSSortStable
                                                        usingComparator:^NSComparisonResult(id a, id b) {
        RevenantPDFTextRun *left = a, *right = b;
        if (left.y > right.y)
            return NSOrderedAscending;
        if (left.y < right.y)
            return NSOrderedDescending;
        return NSOrderedSame;
    }];
    NSMutableString *text = [NSMutableString string];
    NSMutableArray<RevenantPDFTextRun *> *runs = [NSMutableArray arrayWithCapacity:ordered.count];
    NSMutableArray<NSNumber *> *breaks = [NSMutableArray array];
    NSMutableArray<NSNumber *> *charOffsets = [NSMutableArray array];
    NSMutableString *line = [NSMutableString string];
    NSMutableArray<RevenantPDFTextRun *> *lineRuns = [NSMutableArray array];
    CGFloat previousY = 0;
    BOOL first = YES;
    void (^closeLine)(void) = ^{
        NSUInteger *mapping = NULL;
        NSUInteger mappingCount = 0;
        NSString *closed = revenantCloseLine(line, &mapping, &mappingCount);
        NSUInteger lineStart = text.length;
        if (closed != nil)
            [text appendString:closed];
        for (RevenantPDFTextRun *run in lineRuns) {
            NSUInteger base = run.offset;
            run.offset = mappingCount > base && base != NSUIntegerMax ? lineStart + mapping[base]
                                                                     : lineStart;
            [runs addObject:run];
            NSUInteger length = run.text.length;
            for (NSUInteger i = 0; i < length; i++) {
                NSUInteger at = base + i;
                if (mappingCount > at && at != NSUIntegerMax)
                    [charOffsets addObject:@(lineStart + mapping[at])];
                else
                    [charOffsets addObject:@(NSNotFound)];            }
        }
        free(mapping);        [lineRuns removeAllObjects];
        [line setString:@""];
    };
    for (RevenantPDFTextRun *run in ordered) {
        if (run.text == nil || run.text.length == 0)
            continue;
        if (!first && run.y != previousY) {
            closeLine();
            [breaks addObject:@(text.length)];
            [text appendString:@"\n"];
        }
        run.offset = line.length;
        [line appendString:run.text];
        [lineRuns addObject:run];
        previousY = run.y;
        first = NO;
    }
    if (!first)
        closeLine();
    layout->_string = [text copy];
    layout->_runs = [runs copy];
    layout->_charOffsets = [charOffsets copy];
    layout->_breakCount = breaks.count;
    if (breaks.count > 0) {
        layout->_breaks = malloc(sizeof(NSUInteger) * breaks.count);
        if (layout->_breaks == NULL) {
            layout->_breakCount = 0;
        } else {
            for (NSUInteger i = 0; i < breaks.count; i++)
                layout->_breaks[i] = [[breaks objectAtIndex:i] unsignedIntegerValue];
        }
    }
    return layout;
}

- (void)dealloc
{
    free(_breaks);
}

- (NSUInteger)numberOfLines
{
    if (_string == nil || _string.length == 0)
        return 0;
    return _breakCount + 1;
}

- (NSRange)lineRangeAtIndex:(NSUInteger)index
{
    if (_string == nil || index >= [self numberOfLines])
        return NSMakeRange(NSNotFound, 0);
    NSUInteger start = 0;
    for (NSUInteger i = 0; i < index; i++)
        start = _breaks[i] + 1;
    NSUInteger end = index < _breakCount ? _breaks[index] + 1 : (NSUInteger)_string.length;
    return NSMakeRange(start, end - start);
}

- (NSArray<NSValue *> *)lineRangesForRange:(NSRange)range
{
    NSMutableArray<NSValue *> *answer = [NSMutableArray array];
    if (_string == nil || range.location >= _string.length || range.length == 0)
        return answer;
    for (NSUInteger i = 0; i < [self numberOfLines]; i++) {
        NSRange line = [self lineRangeAtIndex:i];
        if (line.location == NSNotFound)
            break;
        NSRange hit = NSIntersectionRange(line, range);
        if (hit.length > 0)
            [answer addObject:[NSValue valueWithRange:hit]];
    }
    return answer;
}

- (CGRect)boundsForRange:(NSRange)range
{
    if (_string == nil || range.location == NSNotFound || range.length == 0)
        return CGRectNull;
    NSUInteger first = range.location;
    NSUInteger last = NSMaxRange(range);
    CGRect answer = CGRectNull;
    NSUInteger at = 0;
    for (RevenantPDFTextRun *run in _runs) {
        NSUInteger count = run.text.length;
        for (NSUInteger i = 0; i < count && at < _charOffsets.count; i++, at++) {
            NSUInteger offset = [[_charOffsets objectAtIndex:at] unsignedIntegerValue];
            if (offset == NSNotFound || offset < first || offset >= last)
                continue;
            CGRect rect = [run rectAtIndex:i];
            if (CGRectIsNull(rect))
                continue;
            answer = CGRectIsNull(answer) ? rect : CGRectUnion(answer, rect);
        }
    }
    return answer;
}

- (NSString *)substringForRange:(NSRange)range
{
    if (_string == nil || range.location == NSNotFound || range.length == 0)
        return nil;
    if (range.location + range.length > _string.length)
        return nil;
    return [_string substringWithRange:range];
}

- (RevenantPDFTextRun *)runForOffset:(NSUInteger)offset
{
    if (_string == nil || offset >= _string.length)
        return nil;
    for (RevenantPDFTextRun *run in _runs) {
        if (offset >= run.offset && offset < run.offset + run.text.length)
            return run;
    }
    return nil;
}

@end

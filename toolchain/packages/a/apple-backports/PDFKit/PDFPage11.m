#import "RevenantPDFKit.h"
#import "PDFPageText11.h"
#include <ctype.h>

@interface PDFPage ()
- (CGPDFPageRef)revenant_CGPDFPage;
- (void)revenant_buildAnnotations;
- (RevenantPDFPageText *)revenant_textLayout;
@end

@implementation PDFPage {
    CGPDFPageRef _page;
    __weak PDFDocument *_document;
    CGPDFDocumentRef _documentRef;
    NSUInteger _index;
    NSArray *_annotations;
    RevenantPDFPageText *_layout;
}

@synthesize pageIndex = _index;
@dynamic label;
@dynamic numberOfCharacters;
@dynamic string;
@dynamic annotations;
@dynamic annotationCount;

- (NSString *)label
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)(_index + 1)];
}

- (NSUInteger)numberOfCharacters
{
    NSString *text = [self string];
    return text.length;
}

typedef struct {
    NSMutableString *text;
    NSMutableArray *runs;
    CGPDFPageRef page;
    NSUInteger shows;
    CGFloat x;
    CGFloat y;
    CGFloat size;
    CGFloat scaleX;
    CGFloat scaleY;
    CGFloat lineX;
    CGFloat lineY;
    CGFloat leading;
    CGFloat charSpacing;
    NSString *font;
    RevenantPDFFontMetrics *metrics;
} RevenantTextWalk;

static CGPDFDictionaryRef revenantFontDictionary(CGPDFPageRef page)
{
    if (page == NULL)
        return NULL;
    CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(page);
    if (dictionary == NULL)
        return NULL;
    CGPDFDictionaryRef resources = NULL;
    if (!CGPDFDictionaryGetDictionary(dictionary, "Resources", &resources) || resources == NULL)
        return NULL;
    CGPDFDictionaryRef fonts = NULL;
    if (!CGPDFDictionaryGetDictionary(resources, "Font", &fonts) || fonts == NULL)
        return NULL;
    return fonts;
}

static NSString *revenantTextForOperand(CGPDFStringRef operand, CFStringRef characters)
{
    const unsigned char *bytes = CGPDFStringGetBytePtr(operand);
    size_t length = CGPDFStringGetLength(operand);
    NSUInteger decoded = CFStringGetLength(characters);
    if (bytes == NULL || length == 0 || decoded == 0 || (size_t)decoded != length)
        return (__bridge NSString *)characters;
    if (length >= 2 && (unsigned char)bytes[0] == 0xFE && (unsigned char)bytes[1] == 0xFF)
        return (__bridge NSString *)characters;
    NSMutableString *answer = [NSMutableString stringWithCapacity:decoded];
    for (NSUInteger i = 0; i < decoded; i++) {
        unsigned char byte = (unsigned char)bytes[i];
        if (byte < 0x20 || byte == 0x7F)
            [answer appendFormat:@"%C", (unichar)0];
        else
            [answer appendFormat:@"%C", (unichar)CFStringGetCharacterAtIndex(characters, i)];
    }
    return answer;
}

static void revenantAppendOperand(CGPDFScannerRef scanner, RevenantTextWalk *walk, CGPDFStringRef operand)
{
    if (operand == NULL)
        return;
    CFStringRef characters = CGPDFStringCopyTextString(operand);
    if (characters == NULL)
        return;
    NSString *text = revenantTextForOperand(operand, characters);
    [walk->text appendString:text];
    walk->x = collectRun(walk->runs, text, walk->x, walk->y, walk->size * walk->scaleX,
                         walk->size * walk->scaleY, walk->font, walk->metrics, walk->charSpacing);
    CFRelease(characters);
}

static void revenantOpShowText(CGPDFScannerRef scanner, void *info)
{
    RevenantTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFStringRef operand = NULL;
    if (CGPDFScannerPopString(scanner, &operand))
        revenantAppendOperand(scanner, walk, operand);
    walk->shows++;
}

static void revenantOpShowTextArray(CGPDFScannerRef scanner, void *info)
{
    RevenantTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFArrayRef array = NULL;
    if (!CGPDFScannerPopArray(scanner, &array) || array == NULL)
        return;
    for (size_t i = 0; i < CGPDFArrayGetCount(array); i++) {
        CGPDFObjectRef element = NULL;
        if (!CGPDFArrayGetObject(array, i, &element) || element == NULL)
            continue;
        CGPDFObjectType kind = CGPDFObjectGetType(element);
        if (kind == kCGPDFObjectTypeString) {
            CGPDFStringRef operand = NULL;
            if (CGPDFObjectGetValue(element, kCGPDFObjectTypeString, &operand))
                revenantAppendOperand(scanner, walk, operand);
        }
        if (kind == kCGPDFObjectTypeInteger || kind == kCGPDFObjectTypeReal) {
            CGPDFReal adjustment = 0;
            if (CGPDFObjectGetValue(element, kCGPDFObjectTypeReal, &adjustment))
                walk->x -= (CGFloat)adjustment * walk->size * walk->scaleX / 1000.0;
        }
    }
    walk->shows++;
}

static void revenantOpTextMatrix(CGPDFScannerRef scanner, void *info)
{
    RevenantTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFReal a = 0, b = 0, c = 0, d = 0, e = 0, f = 0;
    if (CGPDFScannerPopNumber(scanner, &f) && CGPDFScannerPopNumber(scanner, &e) &&
        CGPDFScannerPopNumber(scanner, &d) && CGPDFScannerPopNumber(scanner, &c) &&
        CGPDFScannerPopNumber(scanner, &b) && CGPDFScannerPopNumber(scanner, &a)) {
        walk->x = (CGFloat)e;
        walk->y = (CGFloat)f;
        walk->scaleX = (CGFloat)a;
        walk->scaleY = (CGFloat)d;
        walk->lineX = (CGFloat)e;
        walk->lineY = (CGFloat)f;
    }
}

static void revenantMoveText(CGPDFScannerRef scanner, void *info, BOOL setLeading);

static void revenantOpMoveText(CGPDFScannerRef scanner, void *info)
{
    revenantMoveText(scanner, info, NO);
}

static void revenantOpMoveTextDelta(CGPDFScannerRef scanner, void *info)
{
    revenantMoveText(scanner, info, YES);
}

static void revenantMoveText(CGPDFScannerRef scanner, void *info, BOOL setLeading)
{
    RevenantTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFReal tx = 0, ty = 0;
    if (!CGPDFScannerPopNumber(scanner, &ty) || !CGPDFScannerPopNumber(scanner, &tx))
        return;
    walk->lineX += (CGFloat)tx;
    walk->lineY += (CGFloat)ty;
    walk->x = walk->lineX;
    walk->y = walk->lineY;
    if (setLeading)
        walk->leading = -(CGFloat)ty;
}

static void revenantOpNextLine(CGPDFScannerRef scanner, void *info)
{
    RevenantTextWalk *walk = info;
    if (walk == NULL)
        return;
    walk->lineY -= walk->leading;
    walk->x = walk->lineX;
    walk->y = walk->lineY;
}

static void revenantOpSetCharSpacing(CGPDFScannerRef scanner, void *info)
{
    RevenantTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFReal spacing = 0;
    if (CGPDFScannerPopNumber(scanner, &spacing))
        walk->charSpacing = (CGFloat)spacing;
}

static void revenantOpSetLeading(CGPDFScannerRef scanner, void *info)
{
    RevenantTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFReal leading = 0;
    if (CGPDFScannerPopNumber(scanner, &leading))
        walk->leading = (CGFloat)leading;
}

static void revenantOpBeginText(CGPDFScannerRef scanner, void *info)
{
    RevenantTextWalk *walk = info;
    if (walk == NULL)
        return;
    walk->x = 0;
    walk->y = 0;
    walk->scaleX = 1;
    walk->scaleY = 1;
    walk->lineX = 0;
    walk->lineY = 0;
}

static void revenantOpFontSize(CGPDFScannerRef scanner, void *info)
{
    RevenantTextWalk *walk = info;
    if (walk == NULL)
        return;
    CGPDFReal size = 0;
    if (!CGPDFScannerPopNumber(scanner, &size))
        return;
    walk->size = (CGFloat)size;
    const char *name = NULL;
    if (!CGPDFScannerPopName(scanner, &name) || name == NULL)
        return;
    walk->font = @(name);
    CGPDFDictionaryRef fonts = revenantFontDictionary(walk->page);
    CGPDFDictionaryRef fontDictionary = NULL;
    if (fonts != NULL)
        CGPDFDictionaryGetDictionary(fonts, name, &fontDictionary);
    walk->metrics = [RevenantPDFFontMetrics metricsWithFontDictionary:fontDictionary size:1];
}

static CGFloat collectRun(NSMutableArray *runs, NSString *text, CGFloat x, CGFloat y, CGFloat sizeX,
                          CGFloat sizeY, NSString *font, RevenantPDFFontMetrics *metrics,
                          CGFloat charSpacing)
{
    if (text == nil || text.length == 0)
        return x;
    RevenantPDFTextRun *run = [[RevenantPDFTextRun alloc] init];    run.text = text;
    run.x = x;
    run.y = y;
    run.size = sizeY;
    run.fontName = font;
    NSUInteger count = text.length;
    CGRect *rects = count > 0 ? malloc(sizeof(CGRect) * count) : NULL;
    if (rects != NULL) {
        CGFloat pen = x;
        CGFloat bottom = y + metrics.descent * sizeY;
        CGFloat spacing = charSpacing * sizeX;
        for (NSUInteger i = 0; i < count; i++) {
            CGFloat advance = [metrics advanceForCode:(int)[text characterAtIndex:i]] * sizeX;
            rects[i] = CGRectMake(pen, bottom, advance, sizeY);
            pen += advance + (i + 1 < count ? spacing : 0);
        }
        [run revenant_setGlyphRects:rects count:count];
        free(rects);
        [runs addObject:run];
        return pen + (count > 0 ? spacing : 0);
    }
    [runs addObject:run];
    return x;
}

typedef struct { CGFloat x; CGFloat y; CGFloat size; } RevenantTextState;

static RevenantPDFPageText *revenantScanPageText(CGPDFPageRef page, RevenantTextState *state)
{
    if (state != NULL) {
        state->x = 0;
        state->y = 0;
        state->size = 0;
    }
    if (page == NULL)
        return nil;
    CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(page);
    if (dictionary == NULL)
        return nil;
    CGPDFStreamRef stream = NULL;
    if (!CGPDFDictionaryGetStream(dictionary, "Contents", &stream) || stream == NULL)
        return nil;

    CFDataRef data = CGPDFStreamCopyData(stream, NULL);
    if (data == NULL)
        return nil;
    CFIndex streamLength = CFDataGetLength(data);
    if (streamLength <= 0) {
        CFRelease(data);
        return nil;
    }
    NSUInteger showCount = 0;
    {
        const char *bytes = (const char *)CFDataGetBytePtr(data);
        if (bytes != NULL) {
            for (CFIndex i = 0; i + 1 < streamLength; i++) {
                char c = bytes[i];
                if (c != 'T' && c != '\'' && c != '"')
                    continue;
                if (c == 'T') {
                    if (i + 2 < streamLength && (bytes[i + 1] == 'j' || bytes[i + 1] == 'J') &&
                        (i + 2 >= streamLength || !(isalnum((unsigned char)bytes[i + 2]) || bytes[i + 2] == '*')))
                        showCount++;
                } else {
                    if (i + 1 >= streamLength || !(isalnum((unsigned char)bytes[i + 1]) || bytes[i + 1] == '*'))
                        showCount++;
                }
            }
        }
    }
    CFRelease(data);

    CGPDFContentStreamRef content = CGPDFContentStreamCreateWithPage(page);
    if (content == NULL)
        return nil;

    NSMutableArray *runs = [NSMutableArray array];
    NSMutableString *text = [NSMutableString string];

    CGPDFOperatorTableRef table = CGPDFOperatorTableCreate();
    if (table == NULL) {
        CGPDFContentStreamRelease(content);
        return nil;
    }
    CGPDFScannerRef scanner = NULL;

    RevenantTextWalk *walk = malloc(sizeof(*walk));
    if (walk == NULL) {
        CGPDFScannerRelease(scanner);
        CGPDFOperatorTableRelease(table);
        CGPDFContentStreamRelease(content);
        return nil;
    }
    walk->text = text;
    walk->runs = runs;
    walk->page = page;
    walk->shows = 0;
    walk->x = 0;
    walk->y = 0;
    walk->size = 0;
    walk->scaleX = 1;
    walk->scaleY = 1;
    walk->lineX = 0;
    walk->lineY = 0;
    walk->leading = -1;
    walk->charSpacing = 0;
    walk->metrics = nil;
    CGPDFOperatorTableSetCallback(table, "Tj", revenantOpShowText);
    CGPDFOperatorTableSetCallback(table, "'", revenantOpShowText);
    CGPDFOperatorTableSetCallback(table, "\"", revenantOpShowText);
    CGPDFOperatorTableSetCallback(table, "TJ", revenantOpShowTextArray);
    CGPDFOperatorTableSetCallback(table, "Tm", revenantOpTextMatrix);
    CGPDFOperatorTableSetCallback(table, "Tf", revenantOpFontSize);
    CGPDFOperatorTableSetCallback(table, "Td", revenantOpMoveText);
    CGPDFOperatorTableSetCallback(table, "TD", revenantOpMoveTextDelta);
    CGPDFOperatorTableSetCallback(table, "T*", revenantOpNextLine);
    CGPDFOperatorTableSetCallback(table, "TL", revenantOpSetLeading);
    CGPDFOperatorTableSetCallback(table, "Tc", revenantOpSetCharSpacing);
    CGPDFOperatorTableSetCallback(table, "BT", revenantOpBeginText);

    scanner = CGPDFScannerCreate(content, table, walk);
    if (scanner == NULL) {
        walk->metrics = nil;
        free(walk);
        CGPDFOperatorTableRelease(table);
        CGPDFContentStreamRelease(content);
        return nil;
    }
    while (walk->shows < showCount && CGPDFScannerScan(scanner))
        ;
    BOOL exhausted = walk->shows < showCount;
    if (state != NULL) {
        state->x = walk->x;
        state->y = walk->y;
        state->size = walk->size;
    }
    walk->metrics = nil;
    free(walk);
    CGPDFScannerRelease(scanner);
    CGPDFOperatorTableRelease(table);
    CGPDFContentStreamRelease(content);
    if (exhausted) {
        return nil;
    }
    RevenantPDFPageText *layout = [RevenantPDFPageText layoutWithRuns:runs];
    if (layout.string.length == 0)
        return nil;
    return layout;
}

- (RevenantPDFPageText *)revenant_textLayout
{
    if (_layout == nil)
        _layout = revenantScanPageText(_page, NULL);
    return _layout;
}

- (NSString *)string
{
    if (_page == NULL)
        return nil;
    return [self revenant_textLayout].string;
}

- (NSArray *)annotations
{
    if (_annotations == nil)
        [self revenant_buildAnnotations];
    return _annotations != nil ? [_annotations copy] : @[];
}

- (void)revenant_buildAnnotations
{
    _annotations = nil;
    if (_page == NULL)
        return;
    CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(_page);
    if (dictionary == NULL) {
        _annotations = @[];
        return;
    }
    CGPDFArrayRef annots = NULL;
    if (!CGPDFDictionaryGetArray(dictionary, "Annots", &annots) || annots == NULL) {
        _annotations = @[];
        return;
    }
    size_t count = CGPDFArrayGetCount(annots);
    NSMutableArray *answer = [NSMutableArray arrayWithCapacity:count];
    for (size_t i = 0; i < count; i++) {
        CGPDFDictionaryRef annotation = NULL;
        if (!CGPDFArrayGetDictionary(annots, i, &annotation) || annotation == NULL)
            continue;
        CGPDFArrayRef rect = NULL;
        if (!CGPDFDictionaryGetArray(annotation, "Rect", &rect) || rect == NULL)
            continue;
        const char *subtype = NULL;
        if (CGPDFDictionaryGetName(annotation, "Subtype", &subtype) && subtype != NULL
            && strcmp(subtype, "Line") == 0) {
            CGPDFArrayRef endpoints = NULL;
            if (!CGPDFDictionaryGetArray(annotation, "L", &endpoints) || endpoints == NULL)
                continue;
        }
        if (subtype != NULL && strcmp(subtype, "Widget") == 0) {
            const char *fieldType = NULL;
            if (CGPDFDictionaryGetName(annotation, "FT", &fieldType) && fieldType != NULL
                && strcmp(fieldType, "Ch") == 0) {
                CGPDFArrayRef options = NULL;
                if (!CGPDFDictionaryGetArray(annotation, "Opt", &options) || options == NULL)
                    continue;
            }
        }
        PDFAnnotation *built = [[PDFAnnotation alloc] initWithRevenantDictionary:annotation onPage:self];
        if (built != nil)
            [answer addObject:built];
    }
    _annotations = answer;
}

- (NSUInteger)annotationCount
{
    return [self annotations].count;
}

- (instancetype)initWithCGPDFPage:(CGPDFPageRef)page document:(PDFDocument *)document index:(NSUInteger)index
{
    self = [super init];
    if (self == nil)
        return nil;
    if (page == NULL)
        return nil;
    CGPDFDocumentRef documentRef = [document revenant_CGPDFDocument];
    if (documentRef != NULL)
        CGPDFDocumentRetain(documentRef);
    _page = page;
    _document = document;
    _documentRef = documentRef;
    _index = index;
    return self;
}

- (void)dealloc
{
    _page = NULL;
    if (_documentRef != NULL)
        CGPDFDocumentRelease(_documentRef);
}

- (PDFDocument *)document
{
    return _document;
}

- (CGRect)boundsForBox:(CGPDFBox)box
{
    if (_page == NULL)
        return CGRectZero;
    return CGPDFPageGetBoxRect(_page, box);
}

- (CGRect)mediaBox
{
    return [self boundsForBox:kCGPDFMediaBox];
}

- (CGRect)cropBox
{
    return [self boundsForBox:kCGPDFCropBox];
}

- (NSInteger)rotation
{
    if (_page == NULL)
        return 0;
    CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(_page);
    if (dictionary == NULL)
        return 0;
    CGPDFInteger raw = 0;
    if (!CGPDFDictionaryGetInteger(dictionary, "Rotate", &raw))
        return 0;
    NSInteger degrees = (NSInteger)raw;
    return degrees == 0 ? 0 : (degrees % 360 + 360) % 360;
}

- (CGPDFPageRef)revenant_CGPDFPage
{
    return _page;
}

@end

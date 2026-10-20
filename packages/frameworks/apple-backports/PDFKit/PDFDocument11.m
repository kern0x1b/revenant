#import "RevenantPDFKit.h"
#import "PDFPageText11.h"

#import <dlfcn.h>

@interface PDFDocument ()
- (NSDictionary *)revenant_readAttributes;
@end

@implementation PDFDocument {
    NSMutableArray<PDFSelection *> *_lastFindResults;

    CGPDFDocumentRef _document;
    NSData *_data;
    NSURL *_url;
    NSDictionary *_attributes;
    NSMutableArray *_pages;
}

@dynamic pageCount;
@dynamic documentAttributes;

- (instancetype)revenant_setUpWithData:(NSData *)data
{
    if (data.length == 0)
        return nil;
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    if (provider == NULL)
        return nil;
    _document = CGPDFDocumentCreateWithProvider(provider);
    CGDataProviderRelease(provider);
    if (_document == NULL)
        return nil;
    _pages = [NSMutableArray array];
    _lastFindResults = [NSMutableArray array];
    _data = [data copy];
    _attributes = [self revenant_readAttributes];
    return self;
}

- (nullable instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _pages = [NSMutableArray array];
    _attributes = @{};
    return self;
}

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self == nil)
        return nil;
    if (![url isFileURL])
        return nil;
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (data == nil)
        return nil;
    _url = [url copy];
    return [self revenant_setUpWithData:data];
}

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self == nil)
        return nil;
    return [self revenant_setUpWithData:data];
}

+ (instancetype)revenant_documentWithCGPDFDocument:(CGPDFDocumentRef)document
{
    PDFDocument *made = [[self alloc] revenant_setUpWithData:nil];
    if (made == nil || document == NULL)
        return nil;
    CGPDFDocumentRetain(document);
    made->_document = document;
    if (made->_pages == nil)
        made->_pages = [NSMutableArray array];
    made->_attributes = [made revenant_readAttributes];
    return made;
}


- (NSDictionary *)revenant_readAttributes
{
    if (_document == NULL)
        return @{};
    CGPDFDictionaryRef info = CGPDFDocumentGetInfo(_document);
    if (info == NULL)
        return @{};
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSString *name in @[ @"Title", @"Author", @"Subject", @"Creator", @"Producer",
                              @"CreationDate", @"ModDate" ]) {
        CGPDFStringRef key = NULL;
        if (!CGPDFDictionaryGetString(info, [(NSString *)name UTF8String], &key) || key == NULL)
            continue;
        CFStringRef text = CGPDFStringCopyTextString(key);
        if (text == NULL)
            continue;
        NSString *value = (__bridge_transfer NSString *)text;
        if (value.length > 0)
            out[name] = value;
    }
    return out;
}

- (NSDictionary *)documentAttributes
{
    return _attributes;
}

- (id)documentAttribute:(NSString *)attributeName
{
    return _attributes[attributeName];
}

- (BOOL)isEncrypted
{
    return _document != NULL && CGPDFDocumentIsEncrypted(_document);
}

- (BOOL)isLocked
{
    return _document != NULL && CGPDFDocumentIsEncrypted(_document) && !CGPDFDocumentIsUnlocked(_document);
}

- (BOOL)unlockWithPassword:(NSString *)password
{
    if (![self isLocked])
        return YES;
    if (password == nil)
        return NO;
    if (!CGPDFDocumentUnlockWithPassword(_document, password.UTF8String))
        return NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:PDFDocumentDidUnlockNotification object:self];
    return YES;
}

- (BOOL)allowsCopying
{
    return YES;
}

- (NSURL *)documentURL
{
    return _url;
}

- (NSData *)dataRepresentation
{
    return _data;
}

- (NSUInteger)pageCount
{
    if (_document == NULL)
        return 0;
    return (NSUInteger)CGPDFDocumentGetNumberOfPages(_document);
}

- (nullable PDFPage *)pageAtIndex:(NSUInteger)index
{
    if (_document == NULL || index >= (NSUInteger)CGPDFDocumentGetNumberOfPages(_document))
        return nil;
    if (_pages.count > index)
        return [_pages objectAtIndex:index];
    CGPDFPageRef page = CGPDFDocumentGetPage(_document, (size_t)index + 1);
    if (page == NULL)
        return nil;
    PDFPage *carried = [[PDFPage alloc] initWithCGPDFPage:page document:self index:index];
    if (carried == nil)
        return nil;
    [_pages addObject:carried];
    return carried;
}


- (PDFOutline *)outlineRoot
{
    if (_document == NULL)
        return nil;
    CGPDFDictionaryRef catalog = CGPDFDocumentGetCatalog(_document);
    if (catalog == NULL)
        return nil;
    CGPDFDictionaryRef root = NULL;
    if (!CGPDFDictionaryGetDictionary(catalog, "Outlines", &root) || root == NULL)
        return nil;
    return [[PDFOutline alloc] initWithRevenantItem:root document:self parent:nil index:0];
}

static NSRange revenantRangeForMatch(NSRange match, NSString *text)
{
    NSRange range = match;
    NSUInteger after = NSMaxRange(match);
    if (after < text.length && [text characterAtIndex:after] == '\n')
        range.length += 1;
    return range;
}

static PDFSelection *revenantSelectionForMatch(PDFDocument *document, PDFPage *page, NSRange match,
                                             NSString *text)
{
    if (document == nil)
        return nil;
    PDFSelection *selection = [[PDFSelection alloc] initWithDocument:document];
    [selection revenant_addSpanOnPage:page range:revenantRangeForMatch(match, text)];
    return selection;
}

static NSArray<PDFSelection *> *revenantMatchesOnPage(PDFPage *page, NSString *needle,
                                                    NSStringCompareOptions options, NSUInteger from,
                                                    NSUInteger to)
{
    NSMutableArray<PDFSelection *> *answer = [NSMutableArray array];
    RevenantPDFPageText *layout = [page revenant_textLayout];
    NSString *text = layout.string;
    if (text == nil || needle == nil || needle.length == 0)
        return answer;
    if (from > text.length)
        from = text.length;
    if (to > text.length)
        to = text.length;
    if (from >= to)
        return answer;
    NSStringCompareOptions use = options & ~(NSStringCompareOptions)NSBackwardsSearch;
    NSRange search = NSMakeRange(from, to - from);
    NSRange hit = [text rangeOfString:needle options:use range:search];
    while (hit.location != NSNotFound) {
        PDFSelection *selection = revenantSelectionForMatch(page.document, page, hit, text);
        if (selection == nil)
            break;
        [answer addObject:selection];
        NSUInteger next = NSMaxRange(hit);
        if (next >= to)
            break;
        search = NSMakeRange(next, to - next);
        hit = [text rangeOfString:needle options:use range:search];
    }
    return answer;
}

- (NSArray<PDFSelection *> *)findString:(NSString *)string withOptions:(NSStringCompareOptions)options
{
    [_lastFindResults removeAllObjects];
    BOOL backwards = (options & NSBackwardsSearch) != 0;
    for (NSUInteger page = 0; page < self.pageCount; page++)
        [_lastFindResults addObjectsFromArray:revenantMatchesOnPage([self pageAtIndex:page], string, options,
                                                                 0, NSUIntegerMax)];
    if (backwards)
        [_lastFindResults setArray:[[_lastFindResults reverseObjectEnumerator] allObjects]];
    return _lastFindResults;
}

- (PDFSelection *)findString:(NSString *)string
              fromSelection:(PDFSelection *)selection
               withOptions:(NSStringCompareOptions)options
{
    if (string == nil || string.length == 0)
        return nil;
    BOOL backwards = (options & NSBackwardsSearch) != 0;
    PDFPage *startPage = nil;
    NSUInteger from = 0;
    NSUInteger to = NSUIntegerMax;
    if (selection == nil) {
        startPage = [self pageAtIndex:0];
        if (backwards)
            to = 0;
    } else {
        NSArray<PDFPage *> *pages = selection.pages;
        if (pages.count == 0)
            return nil;
        PDFPage *first = [pages firstObject];
        PDFPage *last = [pages lastObject];
        startPage = backwards ? first : last;
        RevenantPDFPageText *layout = [startPage revenant_textLayout];
        NSUInteger count = [selection numberOfTextRangesOnPage:startPage];
        NSRange range = [selection rangeAtIndex:backwards ? 0 : (count > 0 ? count - 1 : 0)
                                    onPage:startPage];
        if (backwards) {
            from = 0;
            to = range.location == NSNotFound ? 0 : range.location;
        } else {
            from = range.location == NSNotFound ? 0 : NSMaxRange(range);
            to = layout.string.length;
        }
    }
    NSUInteger first = startPage.pageIndex;
    for (; first < self.pageCount;
         first = backwards ? (first == 0 ? self.pageCount : first - 1) : first + 1) {
        PDFPage *page = [self pageAtIndex:first];
        NSArray<PDFSelection *> *matches = revenantMatchesOnPage(page, string, options, from, to);
        if (matches.count > 0)
        {
            PDFSelection *found = backwards ? [matches lastObject] : [matches firstObject];
            return [found copy];
        }
        from = 0;
        to = NSUIntegerMax;
    }
    return nil;
}

- (CGPDFDocumentRef)revenant_CGPDFDocument
{
    return _document;
}

@end

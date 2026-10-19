#import "CharonPDFKit.h"
#import "PDFPageText11.h"

#import <dlfcn.h>

// PDFDocument over the release's own CGPDFDocument.  Neither band carries PDFDocument
// (objc.inventory: not present on 6.1.3 nor on 4.3), so this is the port's own class; the state it
// keeps is a CGPDFDocument, and every answer below is that document read back through the release's
// own CoreGraphics - nothing is computed here that CoreGraphics can answer.

@interface PDFDocument ()
- (NSDictionary *)charon_readAttributes;
@end

@implementation PDFDocument {
    // The array the last -findString:withOptions: answered, because that array IS the document's: measured,
    // a second search on the same document replaces its contents, and a search on another document does not
    // touch it.  Empty until a search runs, which is what a document nobody has searched answers.
    NSMutableArray<PDFSelection *> *_lastFindResults;

    CGPDFDocumentRef _document;
    NSData *_data;
    NSURL *_url;
    NSDictionary *_attributes;
    // The pages this document handed out, so a page outliving the document is the DOCUMENT's
    // problem and not a released CGPDFDocument under a live page - the port's own pattern from
    // GCPhysicalInputProfile, which owns its elements.
    NSMutableArray *_pages;
}

// pageCount is readonly in the header and implemented here, not stored: it is the release's own
// CGPDFDocumentGetNumberOfPages read through the document.  @dynamic so no ivar is synthesized behind a
// method that never keeps one - the file's -Wobjc-missing-property-synthesis would otherwise have the
// port write an ivar it does not hold.
@dynamic pageCount;
// documentAttributes is the Info dictionary the port read once and keeps, not a stored ivar: @dynamic
// says so, rather than the file synthesizing one the port never writes to.
@dynamic documentAttributes;

// The one place a document is made.  This is an ORDINARY method, not an initializer: each of the two
// designated initializers calls [super init] itself - a designated initializer may invoke only a
// designated initializer on super, which is exactly what -Wobjc-designated-initializers was saying
// when this helper did it instead - and then comes here for the work.
- (instancetype)charon_setUpWithData:(NSData *)data
{
    if (data.length == 0)
        return nil;
    // CGPDFDocumentCreateWithData is a Catalyst-era entry; on iOS the release takes a data provider,
    // which is why this goes through CGDataProvider and not through a buffer it may not have.
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    if (provider == NULL)
        return nil;
    _document = CGPDFDocumentCreateWithProvider(provider);
    CGDataProviderRelease(provider);
    if (_document == NULL)
        return nil;
    _pages = [NSMutableArray array];
    // The array the search answers, which is the document's own and therefore made ONCE here: a search that
    // replaced it would answer a new array each time, and the host answers the same one every time.
    _lastFindResults = [NSMutableArray array];
    _data = [data copy];
    _attributes = [self charon_readAttributes];
    return self;
}

// -init is the third way the header's own comment names a document being made ("either the init
// method, initWithURL:, or initWithData:"), and it is the ONE that makes an empty document - which
// is what the host answers, measured on this machine:
//
//   [[PDFDocument alloc] init] -> an object  pageCount=0  document={}
//   [PDFDocument new]          -> an object  pageCount=0
//   -initWithData:nil           -> nil
//   -initWithURL:nil            -> nil
//
// So all three are designated initializers, each calling [super init] and none calling another, which
// is the shape -Wobjc-designated-initializers asks for: a designated initializer may invoke only a
// designated initializer on super.  The private setup below is an ORDINARY method for the same reason.
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
    // The data the URL names, read with Foundation, and then the one setup: a PDF the port cannot
    // open is nil rather than an empty document.
    self = [super init];
    if (self == nil)
        return nil;
    if (![url isFileURL])
        return nil;
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (data == nil)
        return nil;
    _url = [url copy];
    return [self charon_setUpWithData:data];
}

- (instancetype)initWithData:(NSData *)data
{
    self = [super init];
    if (self == nil)
        return nil;
    return [self charon_setUpWithData:data];
}

// The port's own way in over a CGPDFDocument it already holds.  A CLASS method, so it is not an
// initializer at all and the designated-initializer rules do not apply to it: as a method named
// init… it would have to be a third designated initializer or delegate to one, and neither is true of
// it.  Nothing outside this file calls it.
+ (instancetype)charon_documentWithCGPDFDocument:(CGPDFDocumentRef)document
{
    // A class method, so no initializer rule applies to it.  A class method cannot assign to self, so
    // the instance is built through a local and its ivars written directly - they are @protected in the
    // @implementation block, so this file may reach them.
    PDFDocument *made = [[self alloc] charon_setUpWithData:nil];
    if (made == nil || document == NULL)
        return nil;
    CGPDFDocumentRetain(document);
    made->_document = document;
    if (made->_pages == nil)
        made->_pages = [NSMutableArray array];
    made->_attributes = [made charon_readAttributes];
    return made;
}


// The document's Info dictionary, read through the release's own reader.  -charon_readAttributes: was
// declared in the class extension and CALLED by the setup with no definition anywhere, which is what
// killed the port-side binary on the first document, and -documentAttribute: was declared in the
// header with no implementation, which is what -Wincomplete-implementation reported.  Both are here.
- (NSDictionary *)charon_readAttributes
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
        // CGPDFStringCopyTextString is a Copy, and __bridge_transfer consumes it: no CFRelease beside.
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

// Whether the document carries an /Encrypt, and whether it is still locked, read through the release's own
// CoreGraphics reader.  CGPDFDocument has no accessor for the trailer, but it does have one for the
// encryption: CGPDFDocumentIsEncrypted and CGPDFDocumentIsUnlocked, both exported by the 6.1.3 cache
// (tools/image-exports.lua 6.1.3 armv7 CoreGraphics.framework/CoreGraphics CGPDFDocument).  An earlier version
// answered NO for both on the claim that the trailer was unreachable, which was true of the trailer and not of
// the question the members ask.
//
// The host answers a document with a user password isEncrypted YES and isLocked YES, and an owner-only
// document isEncrypted YES and isLocked NO, because it opens without a password (measured by
// tests/backports/host/pdfkit-encryption).
- (BOOL)isEncrypted
{
    return _document != NULL && CGPDFDocumentIsEncrypted(_document);
}

- (BOOL)isLocked
{
    return _document != NULL && CGPDFDocumentIsEncrypted(_document) && !CGPDFDocumentIsUnlocked(_document);
}

// Unlocks with a user password. The host answers YES for a document that is not locked at all, whatever
// password it is given, and posts nothing for it; for a locked one it answers YES only for the password that
// opens it, and posts PDFDocumentDidUnlockNotification once, on that transition. Measured on the host in
// both directions, including a wrong password, which answers NO and posts nothing.
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
    // YES, and always: the format's permissions are a key inside /Encrypt that no document without one
    // has, so a document with no /Encrypt carries no permission to refuse.  The host answers 1 on every
    // fixture, and this is the reading that agrees.
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

// The release's own count, read through the document.  @dynamic above silenced the compiler on this
// one - a @dynamic property with no body raises -respondsToSelector: nothing, and
// -Wobjc-incomplete-implementation says nothing either - which is how the body went missing without
// one word.  A port that keeps a document has a page count.
- (NSUInteger)pageCount
{
    if (_document == NULL)
        return 0;
    return (NSUInteger)CGPDFDocumentGetNumberOfPages(_document);
}

// The release's own page, inside the port's PDFPage.  An index at or past the count is nil, which is
// what the release's NULL says.  CGPDFDocumentGetPage hands back a page this document OWNS and no
// reference to it, so nothing is released here: the page holds it as a Get and owns only a reference to
// this document, and the document keeps the page.
// The page at an index, and the SAME OBJECT every time - measured on the host: two calls answer two
// equal pointers, and the differential needs it, because it finds a destination's page by asking the
// document for each of its pages and seeing which one is that object.  The port built a fresh PDFPage on
// every call, which is the same defect -[PDFPage annotations] had and is fixed the same way: the pages
// are built once, on first ask, and kept.  A document with no page at the index answers nil, which is
// what the release's own NULL says.
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
    // The count can only grow one at a time here, because every ask for an index below the count is
    // answered from the array above, so the array is filled in order and index is its last position.
    [_pages addObject:carried];
    return carried;
}


// -outlineRoot is the document's /Outlines tree: the root DICTIONARY of Table 8.2, which holds the /First
// of the top-level chain, wrapped in the PDFOutline that is that dictionary.  The root is an outline like
// any other - measured: it answers an empty -label because it carries no /Title, -numberOfChildren from
// its /First chain, -index 0, -parent nil and a -document - so it is built by the same constructor the
// items are.
//
// nil for a document whose catalog names no /Outlines, which is every fixture in this harness except the
// outline ones - measured, and a document with an /Outlines the host cannot use answers nil as well.
- (PDFOutline *)outlineRoot
{
    if (_document == NULL)
        return nil;
    // The CATALOG, through the release's own reader for it.  The first version of this walked UP from
    // page 1 through /Parent, because CGPDFDocumentGetCatalog looked absent - and it is not: it is at
    // CGPDFDocument.h:172, CG_AVAILABLE_STARTING(10.3, 2.0), and this SDK declares it.  The walk was
    // worse than unnecessary: it only ever worked because the same commit gave the root /Pages node a
    // /Parent, which a real PDF does not have, so on any real document -outlineRoot would have answered
    // nil.  That fixture change is reverted in this commit too.
    CGPDFDictionaryRef catalog = CGPDFDocumentGetCatalog(_document);
    if (catalog == NULL)
        return nil;
    CGPDFDictionaryRef root = NULL;
    if (!CGPDFDictionaryGetDictionary(catalog, "Outlines", &root) || root == NULL)
        return nil;
    return [[PDFOutline alloc] initWithCharonItem:root document:self parent:nil index:0];
}

// ---- find ---------------------------------------------------------------------------------------
//
// A search is the release's own substring search over the page's own text, which is the text -[PDFPage
// string] answers, so a selection's range is an offset into something the two sides already agree about.
// What is NOT the release's own is the extension: the host answers the match plus ONE character when the
// character after it is a line break, and nothing else - measured over the 136 rows of the fixture family
// facts/PDFKit/Selection11.md describes, and over the eight earlier observations that did not determine it.

// The match, extended.  ONE line-break character and nothing else: the host answers {7,4} for "one" on
// cgfixture-lines.pdf, whose fourth character is the newline the walk joins lines with, and {22,5} for
// "third", whose next character is a space and is not taken.  A NUL is not a line break either, which is
// what cgfixture-inline and cgfixture-tab measure - they answer {0,5} where the sixth character is one.
static NSRange charonRangeForMatch(NSRange match, NSString *text)
{
    NSRange range = match;
    NSUInteger after = NSMaxRange(match);
    if (after < text.length && [text characterAtIndex:after] == '\n')
        range.length += 1;
    return range;
}

// One match, as the selection the host answers.  A page whose walk was DISCARDED has no text and so holds
// no match, and the search stops there rather than answering a selection over nothing.
static PDFSelection *charonSelectionForMatch(PDFDocument *document, PDFPage *page, NSRange match,
                                             NSString *text)
{
    if (document == nil)
        return nil;
    PDFSelection *selection = [[PDFSelection alloc] initWithDocument:document];
    [selection charon_addSpanOnPage:page range:charonRangeForMatch(match, text)];
    return selection;
}

// The matches of ONE page inside [from, to), in the order the search finds them.  The search itself is the
// RELEASE'S OWN: -rangeOfString:options:range: is Foundation's substring search, and the options the header
// names - NSCaseInsensitiveSearch, NSLiteralSearch, NSBackwardsSearch - are its own.  A case-insensitive
// match answers the DOCUMENT's spelling and not the needle's, which falls out of searching the document's
// text and not the needle.
static NSArray<PDFSelection *> *charonMatchesOnPage(PDFPage *page, NSString *needle,
                                                    NSStringCompareOptions options, NSUInteger from,
                                                    NSUInteger to)
{
    NSMutableArray<PDFSelection *> *answer = [NSMutableArray array];
    CharonPDFPageText *layout = [page charon_textLayout];
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
        PDFSelection *selection = charonSelectionForMatch(page.document, page, hit, text);
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
    // THE ARRAY IS THE DOCUMENT'S OWN, and the next search on the document REPLACES its contents - measured:
    // a document searched for "alpha" answers an array of 3, and searching the same document for
    // "alpha alpha" afterwards leaves that same array object holding 1.  So it is held here, emptied at the
    // start of every search and answered as it stands: a caller that keeps the array across two searches of
    // one document sees the second search's answers in it, which is what the host does.
    [_lastFindResults removeAllObjects];
    BOOL backwards = (options & NSBackwardsSearch) != 0;
    for (NSUInteger page = 0; page < self.pageCount; page++)
        [_lastFindResults addObjectsFromArray:charonMatchesOnPage([self pageAtIndex:page], string, options,
                                                                 0, NSUIntegerMax)];
    // NSBackwardsSearch answers the SAME matches in the other order - measured, and the ranges themselves do
    // not change: "alpha" on cgfixture-words answers {31,5} {25,5} {5,5} and nothing else moves.  The
    // reversal is over the WHOLE answer and not over one page's matches, which is what the first version did
    // and what left a two-page document answering its matches in page order anyway.
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
        // A nil selection starts at the BEGINNING of the document, or at its end when the search runs
        // backwards - measured on a document nothing had been asked: {5,5} forward, {31,5} backwards, and a
        // search before them changes nothing.
        startPage = [self pageAtIndex:0];
        if (backwards)
            to = 0;
    } else {
        // the search begins after the last character of the selection, or before its first character when NSBackwardsSearch is specified (PDFDocument.h:274).
        NSArray<PDFPage *> *pages = selection.pages;
        if (pages.count == 0)
            return nil;
        PDFPage *first = [pages firstObject];
        PDFPage *last = [pages lastObject];
        startPage = backwards ? first : last;
        CharonPDFPageText *layout = [startPage charon_textLayout];
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
    // The search walks the pages from the one it starts on, in the direction it runs, and it CROSSES onto the
    // next page - measured: forward from page 1's "page" answers page 2's and backwards from page 1's answers
    // page 0's, while a NEEDLE never spans a page.
    // The page counter runs off the END of the document in the direction of travel, so the loop ends by its
    // own bound and not by a test inside: backwards from page 0 it steps to pageCount, which is past the end,
    // and forwards from the last page it steps to pageCount too.
    NSUInteger first = startPage.pageIndex;
    for (; first < self.pageCount;
         first = backwards ? (first == 0 ? self.pageCount : first - 1) : first + 1) {
        PDFPage *page = [self pageAtIndex:first];
        NSArray<PDFSelection *> *matches = charonMatchesOnPage(page, string, options, from, to);
        if (matches.count > 0)
        {
            // the LAST match going backwards and the FIRST going forwards, copied so the caller owns a
            // selection of its own rather than the one the search is about to replace
            PDFSelection *found = backwards ? [matches lastObject] : [matches firstObject];
            return [found copy];
        }
        // Onto the next page: the whole of it, in the direction of travel.
        from = 0;
        to = NSUIntegerMax;
    }
    // Off the end of the document in the direction of travel: "NULL if the end of the document is reached"
    // (PDFDocument.h:275).
    return nil;
}

// The port's own way at the CGPDFDocument underneath, which Apple's API does not expose: the page's
// initializer needs the document's ref so it can hold one of its own.  It was DECLARED in
// CharonPDFKit.h's CharonInternals category and never defined - so a page asked for its document
// raised -[PDFDocument charon_CGPDFDocument]: unrecognized selector, which is the harness crash.
// A declaration with no body is the same silent fake as a @dynamic property with none.
- (CGPDFDocumentRef)charon_CGPDFDocument
{
    return _document;
}

@end

#import "RevenantPDFKit.h"
#import "PDFPageText11.h"
#import "RevenantPDFCopy.h"

#import <dlfcn.h>
#import <objc/message.h>

static NSArray<PDFSelection *> *revenantMatchesOnPage(PDFPage *page, NSString *needle,
                                                    NSStringCompareOptions options, NSUInteger from,
                                                    NSUInteger to);

@interface PDFDocument ()
- (NSDictionary *)revenant_readAttributes;
- (NSMutableArray *)revenant_entries;
- (void)revenant_renumberFrom:(NSUInteger)start;
- (void)revenant_markModified;
@end

@implementation PDFDocument {
    NSMutableArray<PDFSelection *> *_lastFindResults;

    CGPDFDocumentRef _document;
    NSData *_data;
    NSURL *_url;
    NSDictionary *_attributes;
    NSMutableArray *_entries;
    NSObject *_findToken;
    BOOL _modified;
    NSMutableArray *_snapshots;
    CGPDFDocumentRef _snapshot;
}

@synthesize delegate = _delegate;

@dynamic pageCount;
@dynamic documentAttributes;
@dynamic documentRef;
@dynamic majorVersion;
@dynamic minorVersion;
@dynamic pageClass;

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
    _lastFindResults = [NSMutableArray array];
    _snapshots = [NSMutableArray array];
    _data = [data copy];
    _attributes = [self revenant_readAttributes];
    [self revenant_loadEntries];
    return self;
}

- (nullable instancetype)init
{
    self = [super init];
    if (self == nil)
        return nil;
    _entries = [NSMutableArray array];
    _snapshots = [NSMutableArray array];
    _lastFindResults = [NSMutableArray array];
    _attributes = @{};
    return self;
}

- (void)dealloc
{
    if (_document != NULL)
        CGPDFDocumentRelease(_document);
}

- (void)revenant_loadEntries
{
    NSUInteger count = _document != NULL ? (NSUInteger)CGPDFDocumentGetNumberOfPages(_document) : 0;
    _entries = [NSMutableArray arrayWithCapacity:count];
    for (NSUInteger index = 0; index < count; index++)
        [_entries addObject:[NSNull null]];
}

- (NSMutableArray *)revenant_entries
{
    for (NSUInteger index = 0; index < _entries.count; index++) {
        if (_entries[index] != [NSNull null])
            continue;
        CGPDFPageRef page = CGPDFDocumentGetPage(_document, (size_t)index + 1);
        PDFPage *carried = page != NULL ? [[PDFPage alloc] initWithCGPDFPage:page document:self index:index] : nil;
        if (carried == nil)
            [NSException raise:NSInternalInconsistencyException format:@"page %lu of the document cannot be read", (unsigned long)index];
        _entries[index] = carried;
    }
    return _entries;
}

- (void)revenant_renumberFrom:(NSUInteger)start
{
    for (NSUInteger index = start; index < _entries.count; index++) {
        PDFPage *page = _entries[index];
        if (page.document == self)
            [page revenant_setDocument:self index:index];
    }
}

- (void)revenant_markModified
{
    _modified = YES;
    _snapshot = NULL;
}

- (void)revenant_pageDidChange
{
    [self revenant_markModified];
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
    if (document == NULL)
        return nil;
    PDFDocument *made = [[self alloc] init];
    if (made == nil)
        return nil;
    CGPDFDocumentRetain(document);
    made->_document = document;
    made->_attributes = [made revenant_readAttributes];
    [made revenant_loadEntries];
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
    for (NSString *name in @[ @"Title", @"Author", @"Subject", @"Creator", @"Producer", @"CreationDate", @"ModDate", @"Keywords" ]) {
        CGPDFStringRef key = NULL;
        if (!CGPDFDictionaryGetString(info, [(NSString *)name UTF8String], &key) || key == NULL)
            continue;
        CFStringRef text = CGPDFStringCopyTextString(key);
        if (text == NULL)
            continue;
        NSString *value = (__bridge_transfer NSString *)text;
        if (value.length == 0)
            continue;
        if ([name isEqualToString:@"CreationDate"] || [name isEqualToString:@"ModDate"]) {
            NSDate *date = RevenantPDFDateFromString(value);
            if (date != nil)
                out[name] = date;
        } else if ([name isEqualToString:@"Keywords"]) {
            NSMutableArray *keywords = [NSMutableArray array];
            for (NSString *piece in [value componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@",;"]]) {
                NSString *keyword = [piece stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (keyword.length > 0)
                    [keywords addObject:keyword];
            }
            if (keywords.count > 0)
                out[name] = keywords;
        } else {
            out[name] = value;
        }
    }
    return out;
}

- (NSDictionary *)documentAttributes
{
    return _attributes;
}

- (void)setDocumentAttributes:(NSDictionary *)attributes
{
    _attributes = [attributes copy] ?: @{};
    [self revenant_markModified];
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
    if (!_modified)
        [self revenant_loadEntries];
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

- (NSDictionary *)revenant_infoDictionary
{
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    for (NSString *key in @[ PDFDocumentTitleAttribute, PDFDocumentAuthorAttribute, PDFDocumentSubjectAttribute, PDFDocumentCreatorAttribute,
                             PDFDocumentProducerAttribute ]) {
        NSString *value = _attributes[key];
        if ([value isKindOfClass:[NSString class]] && value.length > 0)
            info[key] = value;
    }
    id keywords = _attributes[PDFDocumentKeywordsAttribute];
    if ([keywords isKindOfClass:[NSArray class]])
        keywords = [keywords componentsJoinedByString:@", "];
    if ([keywords isKindOfClass:[NSString class]] && [keywords length] > 0)
        info[PDFDocumentKeywordsAttribute] = keywords;
    NSDate *now = [NSDate date];
    NSDate *created = _attributes[PDFDocumentCreationDateAttribute];
    info[PDFDocumentCreationDateAttribute] = [created isKindOfClass:[NSDate class]] ? created : now;
    info[PDFDocumentModificationDateAttribute] = now;
    return info;
}

- (void)revenant_post:(NSString *)name pageIndex:(NSUInteger)index
{
    NSDictionary *userInfo = index == NSNotFound ? nil : @{PDFDocumentPageIndexKey: @(index)};
    [[NSNotificationCenter defaultCenter] postNotificationName:name object:self userInfo:userInfo];
}

- (NSData *)revenant_assembleWithOwner:(NSString *)owner user:(NSString *)user permissions:(uint32_t)permissions notify:(BOOL)notify
{
    NSArray *pages = [self revenant_entries];
    if (pages.count == 0)
        return nil;
    NSMutableArray *entries = [NSMutableArray arrayWithCapacity:pages.count];
    for (PDFPage *page in pages) {
        CGPDFPageRef source = page.pageRef;
        if (source == NULL)
            return nil;
        [entries addObject:[RevenantPDFPageEntry entryWithPage:source boxes:[page revenant_boxes]]];
    }
    if (notify)
        [self revenant_post:PDFDocumentDidBeginWriteNotification pageIndex:NSNotFound];
    NSData *data = RevenantPDFAssemble(entries, [self revenant_infoDictionary], owner, user, permissions, ^(NSUInteger index, BOOL finished) {
        if (notify)
            [self revenant_post:finished ? PDFDocumentDidEndPageWriteNotification : PDFDocumentDidBeginPageWriteNotification pageIndex:index];
    });
    if (notify)
        [self revenant_post:PDFDocumentDidEndWriteNotification pageIndex:NSNotFound];
    return data;
}

- (NSData *)dataRepresentation
{
    return [self dataRepresentationWithOptions:@{}];
}

- (NSData *)dataRepresentationWithOptions:(NSDictionary *)options
{
    NSString *owner = options[PDFDocumentOwnerPasswordOption];
    if (![owner isKindOfClass:[NSString class]])
        owner = nil;
    NSString *user = options[PDFDocumentUserPasswordOption];
    if (![user isKindOfClass:[NSString class]])
        user = nil;
    if (!_modified && _data != nil && owner.length == 0)
        return _data;
    NSNumber *granted = options[PDFDocumentAccessPermissionsOption];
    uint32_t permissions = RevenantPDFPermissionBits([granted isKindOfClass:[NSNumber class]] ? granted.unsignedIntegerValue : NSUIntegerMax);
    return [self revenant_assembleWithOwner:owner user:user permissions:permissions notify:YES];
}

- (BOOL)writeToFile:(NSString *)path
{
    return [self writeToFile:path withOptions:nil];
}

- (BOOL)writeToFile:(NSString *)path withOptions:(NSDictionary *)options
{
    if (path.length == 0)
        return NO;
    return [self writeToURL:[NSURL fileURLWithPath:path] withOptions:options];
}

- (BOOL)writeToURL:(NSURL *)url
{
    return [self writeToURL:url withOptions:nil];
}

- (BOOL)writeToURL:(NSURL *)url withOptions:(NSDictionary *)options
{
    if (![url isFileURL])
        return NO;
    NSData *data = [self dataRepresentationWithOptions:options ?: @{}];
    if (data == nil)
        return NO;
    return [data writeToURL:url options:NSDataWritingAtomic error:NULL];
}

- (CGPDFDocumentRef)documentRef
{
    if (!_modified && _document != NULL)
        return _document;
    if (_snapshot != NULL)
        return _snapshot;
    NSData *data = [self revenant_assembleWithOwner:nil user:nil permissions:0 notify:NO];
    CGDataProviderRef provider = data != nil ? CGDataProviderCreateWithCFData((__bridge CFDataRef)data) : NULL;
    CGPDFDocumentRef made = provider != NULL ? CGPDFDocumentCreateWithProvider(provider) : NULL;
    CGDataProviderRelease(provider);
    if (made == NULL)
        return NULL;
    [_snapshots addObject:(__bridge id)made];
    CGPDFDocumentRelease(made);
    _snapshot = made;
    return made;
}

- (NSInteger)revenant_versionPart:(BOOL)major
{
    CGPDFDocumentRef source = _modified ? NULL : _document;
    if (source == NULL)
        return 0;
    int majorVersion = 0;
    int minorVersion = 0;
    CGPDFDocumentGetVersion(source, &majorVersion, &minorVersion);
    return major ? majorVersion : minorVersion;
}

- (NSInteger)majorVersion
{
    return [self revenant_versionPart:YES];
}

- (NSInteger)minorVersion
{
    return [self revenant_versionPart:NO];
}

- (Class)pageClass
{
    return [PDFPage class];
}

- (id)copyWithZone:(NSZone *)zone
{
    PDFDocument *copy = [[[self class] allocWithZone:zone] init];
    if (copy == nil)
        return nil;
    copy->_document = _document != NULL ? CGPDFDocumentRetain(_document) : NULL;
    copy->_data = _data;
    copy->_url = _url;
    copy->_attributes = _attributes;
    copy->_modified = _modified;
    for (PDFPage *page in [self revenant_entries]) {
        PDFPage *duplicate = [page copy];
        if (duplicate == nil)
            continue;
        [copy->_entries addObject:duplicate];
        [duplicate revenant_setDocument:copy index:copy->_entries.count - 1];
    }
    return copy;
}

- (NSUInteger)pageCount
{
    return _entries.count;
}

- (nullable PDFPage *)pageAtIndex:(NSUInteger)index
{
    if (index >= _entries.count)
        return nil;
    id entry = _entries[index];
    if (entry != [NSNull null])
        return entry;
    CGPDFPageRef page = CGPDFDocumentGetPage(_document, (size_t)index + 1);
    if (page == NULL)
        return nil;
    PDFPage *carried = [[PDFPage alloc] initWithCGPDFPage:page document:self index:index];
    if (carried == nil)
        return nil;
    _entries[index] = carried;
    return carried;
}

- (NSUInteger)indexForPage:(PDFPage *)page
{
    if (page == nil)
        return NSNotFound;
    for (NSUInteger index = 0; index < _entries.count; index++) {
        if (_entries[index] == page)
            return index;
    }
    return NSNotFound;
}

- (void)insertPage:(PDFPage *)page atIndex:(NSUInteger)index
{
    if (page == nil)
        [NSException raise:NSInvalidArgumentException format:@"-[PDFDocument insertPage:atIndex:]: page is nil"];
    NSMutableArray *entries = [self revenant_entries];
    if (index > entries.count)
        [NSException raise:NSRangeException format:@"-[PDFDocument insertPage:atIndex:]: index %lu beyond bounds for a document of %lu pages", (unsigned long)index, (unsigned long)entries.count];
    [entries insertObject:page atIndex:index];
    [page revenant_setDocument:self index:index];
    [self revenant_renumberFrom:index + 1];
    [self revenant_markModified];
}

- (void)removePageAtIndex:(NSUInteger)index
{
    NSMutableArray *entries = [self revenant_entries];
    if (index >= entries.count)
        return;
    PDFPage *page = entries[index];
    [entries removeObjectAtIndex:index];
    if (page.document == self && [self indexForPage:page] == NSNotFound)
        [page revenant_setDocument:nil index:0];
    [self revenant_renumberFrom:index];
    [self revenant_markModified];
}

- (void)exchangePageAtIndex:(NSUInteger)indexA withPageAtIndex:(NSUInteger)indexB
{
    NSMutableArray *entries = [self revenant_entries];
    if (indexA >= entries.count || indexB >= entries.count || indexA == indexB)
        return;
    [entries exchangeObjectAtIndex:indexA withObjectAtIndex:indexB];
    [self revenant_renumberFrom:MIN(indexA, indexB)];
    [self revenant_markModified];
}

- (BOOL)isFinding
{
    return _findToken != nil;
}

- (void)revenant_notify:(NSString *)name selector:(SEL)selector userInfo:(NSDictionary *)userInfo
{
    NSNotification *notification = [NSNotification notificationWithName:name object:self userInfo:userInfo];
    id delegate = _delegate;
    if ([delegate respondsToSelector:selector])
        ((void (*)(id, SEL, NSNotification *))objc_msgSend)(delegate, selector, notification);
    [[NSNotificationCenter defaultCenter] postNotification:notification];
}

- (void)revenant_findOnPage:(NSUInteger)index string:(NSString *)string options:(NSStringCompareOptions)options token:(NSObject *)token
{
    if (_findToken != token)
        return;
    if (index >= self.pageCount) {
        _findToken = nil;
        [self revenant_notify:PDFDocumentDidEndFindNotification selector:@selector(documentDidEndDocumentFind:) userInfo:nil];
        return;
    }
    NSDictionary *pageInfo = @{PDFDocumentPageIndexKey: @(index)};
    [self revenant_notify:PDFDocumentDidBeginPageFindNotification selector:@selector(documentDidBeginPageFind:) userInfo:pageInfo];
    for (PDFSelection *match in revenantMatchesOnPage([self pageAtIndex:index], string, options, 0, NSUIntegerMax)) {
        if (_findToken != token)
            return;
        [self revenant_notify:PDFDocumentDidFindMatchNotification selector:@selector(documentDidFindMatch:) userInfo:@{PDFDocumentFoundSelectionKey: match}];
        id delegate = _delegate;
        if ([delegate respondsToSelector:@selector(didMatchString:)])
            ((void (*)(id, SEL, PDFSelection *))objc_msgSend)(delegate, @selector(didMatchString:), match);
    }
    if (_findToken != token)
        return;
    [self revenant_notify:PDFDocumentDidEndPageFindNotification selector:@selector(documentDidEndPageFind:) userInfo:pageInfo];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self revenant_findOnPage:index + 1 string:string options:options token:token];
    });
}

- (void)beginFindString:(NSString *)string withOptions:(NSStringCompareOptions)options
{
    [self cancelFindString];
    NSObject *token = [[NSObject alloc] init];
    _findToken = token;
    [self revenant_notify:PDFDocumentDidBeginFindNotification selector:@selector(documentDidBeginDocumentFind:) userInfo:nil];
    NSString *needle = [string copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self revenant_findOnPage:needle.length > 0 ? 0 : NSUIntegerMax string:needle options:options token:token];
    });
}

- (void)cancelFindString
{
    _findToken = nil;
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

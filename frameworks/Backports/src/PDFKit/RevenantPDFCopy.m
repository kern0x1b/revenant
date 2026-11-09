#import "RevenantPDFCopy.h"

static NSString *revenantName(const char *name)
{
    return [NSString stringWithCString:name encoding:NSISOLatin1StringEncoding] ?: @"";
}

static NSArray *revenantRectArray(CGRect rect)
{
    return @[ @(rect.origin.x), @(rect.origin.y), @(CGRectGetMaxX(rect)), @(CGRectGetMaxY(rect)) ];
}

@interface RevenantPDFCopier ()
- (void)collectEntriesOf:(CGPDFDictionaryRef)dictionary into:(NSMutableDictionary *)entries skipping:(NSSet *)skipped;
- (nullable id)convertValue:(CGPDFObjectRef)value;
- (nullable NSArray *)convertArray:(CGPDFArrayRef)array;
- (nullable id)referenceForDictionary:(CGPDFDictionaryRef)dictionary;
- (nullable id)referenceForStream:(CGPDFStreamRef)stream;
@end

typedef struct {
    void *copier;
    void *entries;
    void *skipped;
} RevenantCopyContext;

@implementation RevenantPDFCopier {
    RevenantPDFWriter *_writer;
    NSMutableDictionary<NSValue *, id> *_memo;
    NSMutableDictionary<NSValue *, RevenantPDFReference *> *_pages;
    NSUInteger _depth;
}

@synthesize failed = _failed;

- (instancetype)initWithWriter:(RevenantPDFWriter *)writer
{
    self = [super init];
    if (self == nil)
        return nil;
    _writer = writer;
    _memo = [NSMutableDictionary dictionary];
    _pages = [NSMutableDictionary dictionary];
    return self;
}

- (void)registerPage:(CGPDFPageRef)page reference:(RevenantPDFReference *)reference
{
    _pages[[NSValue valueWithPointer:CGPDFPageGetDictionary(page)]] = reference;
}

static void revenantCollect(const char *key, CGPDFObjectRef value, void *info)
{
    RevenantCopyContext *context = info;
    NSString *name = revenantName(key);
    NSSet *skipped = (__bridge NSSet *)context->skipped;
    if ([skipped containsObject:name])
        return;
    RevenantPDFCopier *copier = (__bridge RevenantPDFCopier *)context->copier;
    NSMutableDictionary *entries = (__bridge NSMutableDictionary *)context->entries;
    id copied = [copier convertValue:value];
    if (copied != nil)
        entries[name] = copied;
}

- (void)collectEntriesOf:(CGPDFDictionaryRef)dictionary into:(NSMutableDictionary *)entries skipping:(NSSet *)skipped
{
    RevenantCopyContext context = {(__bridge void *)self, (__bridge void *)entries, (__bridge void *)skipped};
    CGPDFDictionaryApplyFunction(dictionary, revenantCollect, &context);
}

- (id)convertValue:(CGPDFObjectRef)value
{
    switch (CGPDFObjectGetType(value)) {
        case kCGPDFObjectTypeNull:
            return [NSNull null];
        case kCGPDFObjectTypeBoolean: {
            CGPDFBoolean flag = 0;
            CGPDFObjectGetValue(value, kCGPDFObjectTypeBoolean, &flag);
            return @(flag != 0);
        }
        case kCGPDFObjectTypeInteger: {
            CGPDFInteger integer = 0;
            CGPDFObjectGetValue(value, kCGPDFObjectTypeInteger, &integer);
            return @((long long)integer);
        }
        case kCGPDFObjectTypeReal: {
            CGPDFReal real = 0;
            CGPDFObjectGetValue(value, kCGPDFObjectTypeReal, &real);
            return @((double)real);
        }
        case kCGPDFObjectTypeName: {
            const char *name = NULL;
            CGPDFObjectGetValue(value, kCGPDFObjectTypeName, &name);
            return [RevenantPDFName name:revenantName(name ?: "")];
        }
        case kCGPDFObjectTypeString: {
            CGPDFStringRef string = NULL;
            CGPDFObjectGetValue(value, kCGPDFObjectTypeString, &string);
            return [NSData dataWithBytes:CGPDFStringGetBytePtr(string) length:CGPDFStringGetLength(string)];
        }
        case kCGPDFObjectTypeArray: {
            CGPDFArrayRef array = NULL;
            CGPDFObjectGetValue(value, kCGPDFObjectTypeArray, &array);
            return [self convertArray:array];
        }
        case kCGPDFObjectTypeDictionary: {
            CGPDFDictionaryRef dictionary = NULL;
            CGPDFObjectGetValue(value, kCGPDFObjectTypeDictionary, &dictionary);
            return [self referenceForDictionary:dictionary];
        }
        case kCGPDFObjectTypeStream: {
            CGPDFStreamRef stream = NULL;
            CGPDFObjectGetValue(value, kCGPDFObjectTypeStream, &stream);
            return [self referenceForStream:stream];
        }
    }
    return nil;
}

- (NSArray *)convertArray:(CGPDFArrayRef)array
{
    size_t count = CGPDFArrayGetCount(array);
    NSMutableArray *copied = [NSMutableArray arrayWithCapacity:count];
    for (size_t index = 0; index < count; index++) {
        CGPDFObjectRef element = NULL;
        if (!CGPDFArrayGetObject(array, index, &element) || element == NULL)
            continue;
        id converted = [self convertValue:element];
        if (converted == nil) {
            if (index == 0)
                return nil;
            continue;
        }
        [copied addObject:converted];
    }
    return copied;
}

- (id)referenceForDictionary:(CGPDFDictionaryRef)dictionary
{
    NSValue *key = [NSValue valueWithPointer:dictionary];
    RevenantPDFReference *page = _pages[key];
    if (page != nil)
        return page;
    id known = _memo[key];
    if (known != nil)
        return known;
    const char *type = NULL;
    if (CGPDFDictionaryGetName(dictionary, "Type", &type) && type != NULL && strcmp(type, "Page") == 0)
        return nil;
    if (_depth > 256) {
        _failed = YES;
        return nil;
    }
    RevenantPDFReference *reference = [_writer reserve];
    _memo[key] = reference;
    _depth++;
    NSMutableDictionary *entries = [NSMutableDictionary dictionary];
    [self collectEntriesOf:dictionary into:entries skipping:[NSSet set]];
    _depth--;
    id object = entries;
    RevenantPDFName *subtype = entries[@"S"];
    if ([subtype isKindOfClass:[RevenantPDFName class]] && [subtype.value isEqualToString:@"GoTo"] && entries[@"D"] == nil)
        object = [NSNull null];
    [_writer setObject:object forReference:reference];
    return reference;
}

- (id)referenceForStream:(CGPDFStreamRef)stream
{
    NSValue *key = [NSValue valueWithPointer:stream];
    id known = _memo[key];
    if (known != nil)
        return known;
    if (_depth > 256) {
        _failed = YES;
        return nil;
    }
    CGPDFDataFormat format = CGPDFDataFormatRaw;
    CFDataRef copied = CGPDFStreamCopyData(stream, &format);
    if (copied == NULL) {
        _failed = YES;
        return nil;
    }
    NSData *data = (__bridge_transfer NSData *)copied;
    RevenantPDFReference *reference = [_writer reserve];
    _memo[key] = reference;
    _depth++;
    NSMutableDictionary *entries = [NSMutableDictionary dictionary];
    NSSet *skipped = [NSSet setWithObjects:@"Length", @"Filter", @"DecodeParms", @"DL", @"F", @"FFilter", @"FDecodeParms", nil];
    [self collectEntriesOf:CGPDFStreamGetDictionary(stream) into:entries skipping:skipped];
    _depth--;
    RevenantPDFStream *built;
    if (format == CGPDFDataFormatJPEGEncoded) {
        entries[@"Filter"] = [RevenantPDFName name:@"DCTDecode"];
        built = [RevenantPDFStream streamWithDictionary:entries data:data];
    } else if (format == CGPDFDataFormatJPEG2000) {
        entries[@"Filter"] = [RevenantPDFName name:@"JPXDecode"];
        built = [RevenantPDFStream streamWithDictionary:entries data:data];
    } else {
        built = [RevenantPDFStream deflatedStreamWithDictionary:entries data:data];
    }
    [_writer setObject:built forReference:reference];
    return reference;
}

- (CGPDFObjectRef)inheritedValue:(const char *)key from:(CGPDFDictionaryRef)dictionary
{
    NSUInteger guard = 0;
    while (dictionary != NULL && guard++ < 64) {
        CGPDFObjectRef value = NULL;
        if (CGPDFDictionaryGetObject(dictionary, key, &value) && value != NULL)
            return value;
        CGPDFDictionaryRef parent = NULL;
        if (!CGPDFDictionaryGetDictionary(dictionary, "Parent", &parent))
            break;
        dictionary = parent;
    }
    return NULL;
}

- (void)copyPage:(CGPDFPageRef)page
       intoReference:(RevenantPDFReference *)reference
              parent:(RevenantPDFReference *)parent
               boxes:(RevenantPDFPageBoxes)boxes
{
    CGPDFDictionaryRef dictionary = CGPDFPageGetDictionary(page);
    NSMutableDictionary *entries = [NSMutableDictionary dictionary];
    NSSet *skipped = [NSSet setWithObjects:@"Parent", @"Type", @"MediaBox", @"CropBox", @"BleedBox", @"TrimBox", @"ArtBox", @"Rotate",
                                           @"B", @"StructParents", @"Resources", nil];
    _depth++;
    [self collectEntriesOf:dictionary into:entries skipping:skipped];
    CGPDFObjectRef resources = [self inheritedValue:"Resources" from:dictionary];
    if (resources != NULL) {
        id copied = [self convertValue:resources];
        if (copied != nil)
            entries[@"Resources"] = copied;
    }
    _depth--;
    entries[@"Type"] = [RevenantPDFName name:@"Page"];
    entries[@"Parent"] = parent;
    entries[@"MediaBox"] = revenantRectArray(boxes.media);
    entries[@"CropBox"] = revenantRectArray(boxes.crop);
    if (!CGRectEqualToRect(boxes.bleed, boxes.crop))
        entries[@"BleedBox"] = revenantRectArray(boxes.bleed);
    if (!CGRectEqualToRect(boxes.trim, boxes.crop))
        entries[@"TrimBox"] = revenantRectArray(boxes.trim);
    if (!CGRectEqualToRect(boxes.art, boxes.crop))
        entries[@"ArtBox"] = revenantRectArray(boxes.art);
    if (boxes.rotation != 0)
        entries[@"Rotate"] = @(boxes.rotation);
    [_writer setObject:entries forReference:reference];
}

@end

@implementation RevenantPDFPageEntry

@synthesize page = _page;
@synthesize boxes = _boxes;

+ (instancetype)entryWithPage:(CGPDFPageRef)page boxes:(RevenantPDFPageBoxes)boxes
{
    RevenantPDFPageEntry *entry = [[RevenantPDFPageEntry alloc] init];
    entry->_page = page;
    entry->_boxes = boxes;
    return entry;
}

@end

NSData *RevenantPDFAssemble(NSArray<RevenantPDFPageEntry *> *pages, NSDictionary<NSString *, id> *info, NSString *owner, NSString *user,
                            uint32_t permissions, void (^step)(NSUInteger index, BOOL finished))
{
    RevenantPDFWriter *writer = owner.length > 0 ? [[RevenantPDFWriter alloc] initEncryptedWithOwnerPassword:owner userPassword:user
                                                                                                permissions:permissions]
                                                 : [[RevenantPDFWriter alloc] init];
    RevenantPDFCopier *copier = [[RevenantPDFCopier alloc] initWithWriter:writer];
    RevenantPDFReference *tree = [writer reserve];
    NSMutableArray<RevenantPDFReference *> *references = [NSMutableArray arrayWithCapacity:pages.count];
    for (RevenantPDFPageEntry *entry in pages) {
        RevenantPDFReference *reference = [writer reserve];
        [copier registerPage:entry.page reference:reference];
        [references addObject:reference];
    }
    for (NSUInteger index = 0; index < pages.count; index++) {
        if (step != nil)
            step(index, NO);
        [copier copyPage:pages[index].page intoReference:references[index] parent:tree boxes:pages[index].boxes];
        if (step != nil)
            step(index, YES);
    }
    if (copier.failed)
        return nil;
    RevenantPDFReference *catalog = [writer addCatalogWithPages:tree kids:references];
    RevenantPDFReference *details = info.count > 0 ? [writer add:info] : nil;
    return [writer dataWithRoot:catalog info:details];
}

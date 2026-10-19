#import <UIKit/UIKit.h>

typedef struct {
    const uint8_t *bytes;
    size_t length;
} CharonSpan;

static uint32_t be32(CharonSpan span, size_t offset)
{
    if (offset + 4 > span.length)
        return 0;
    return (uint32_t)span.bytes[offset] << 24 | (uint32_t)span.bytes[offset + 1] << 16 | (uint32_t)span.bytes[offset + 2] << 8 | span.bytes[offset + 3];
}

static uint16_t be16(CharonSpan span, size_t offset)
{
    if (offset + 2 > span.length)
        return 0;
    return (uint16_t)(span.bytes[offset] << 8 | span.bytes[offset + 1]);
}

static uint32_t le32(CharonSpan span, size_t offset)
{
    if (offset + 4 > span.length)
        return 0;
    return (uint32_t)span.bytes[offset] | (uint32_t)span.bytes[offset + 1] << 8 | (uint32_t)span.bytes[offset + 2] << 16 | (uint32_t)span.bytes[offset + 3] << 24;
}

static uint16_t le16(CharonSpan span, size_t offset)
{
    if (offset + 2 > span.length)
        return 0;
    return (uint16_t)(span.bytes[offset] | span.bytes[offset + 1] << 8);
}

static const uint32_t CharonCatalogIdentifier = 17;
static const uint32_t CharonCatalogIdiom = 15;
static const uint32_t CharonCatalogScale = 12;

@interface CharonAssetCatalog : NSObject
+ (instancetype)catalogAtPath:(NSString *)path;
- (NSData *)dataNamed:(NSString *)name typeIdentifier:(NSString **)type;
@end

@implementation CharonAssetCatalog {
    NSData *_file;
    CharonSpan _span;
    uint32_t _blockCount;
    NSMutableDictionary<NSString *, NSNumber *> *_variables;
    NSMutableArray<NSNumber *> *_keyFormat;
}

+ (instancetype)catalogAtPath:(NSString *)path
{
    static NSMutableDictionary *catalogs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        catalogs = [NSMutableDictionary dictionary];
    });
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:NULL];
    NSString *key = [NSString stringWithFormat:@"%@|%@|%@", path, attributes[NSFileModificationDate], attributes[NSFileSize]];
    @synchronized(catalogs) {
        CharonAssetCatalog *catalog = catalogs[key];
        if (!catalog) {
            catalog = [[self alloc] initWithPath:path];
            if (catalog)
                catalogs[key] = catalog;
        }
        return catalog;
    }
}

- (instancetype)initWithPath:(NSString *)path
{
    self = [super init];
    if (!self)
        return nil;
    _file = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:NULL];
    _span = (CharonSpan){_file.bytes, _file.length};
    if (_span.length < 32 || memcmp(_span.bytes, "BOMStore", 8))
        return nil;
    _blockCount = be32(_span, 12);
    _variables = [NSMutableDictionary dictionary];
    size_t variables = be32(_span, 24), length = be32(_span, 28);
    if (variables + length > _span.length)
        return nil;
    uint32_t count = be32(_span, variables);
    size_t cursor = variables + 4;
    for (uint32_t index = 0; index < count && cursor + 5 <= variables + length; index++) {
        uint32_t block = be32(_span, cursor);
        size_t nameLength = _span.bytes[cursor + 4];
        if (cursor + 5 + nameLength > _span.length)
            break;
        NSString *name = [[NSString alloc] initWithBytes:_span.bytes + cursor + 5 length:nameLength encoding:NSUTF8StringEncoding];
        if (name)
            _variables[name] = @(block);
        cursor += 5 + nameLength;
    }
    _keyFormat = [NSMutableArray array];
    CharonSpan format = [self block:[_variables[@"KEYFORMAT"] unsignedIntValue]];
    if (format.length >= 12 && !memcmp(format.bytes, "tmfk", 4)) {
        uint32_t attributes = le32(format, 8);
        for (uint32_t index = 0; index < attributes && 12 + 4 * (index + 1) <= format.length; index++)
            [_keyFormat addObject:@(le32(format, 12 + 4 * index))];
    }
    return _variables[@"FACETKEYS"] && _variables[@"RENDITIONS"] ? self : nil;
}

- (CharonSpan)block:(uint32_t)index
{
    size_t table = be32(_span, 16);
    size_t entries = be32(_span, table);
    if (index >= entries || table + 4 + 8 * (size_t)(index + 1) > _span.length)
        return (CharonSpan){NULL, 0};
    size_t address = be32(_span, table + 4 + 8 * (size_t)index), length = be32(_span, table + 8 + 8 * (size_t)index);
    if (address > _span.length || length > _span.length - address)
        return (CharonSpan){NULL, 0};
    return (CharonSpan){_span.bytes + address, length};
}

- (void)enumerateTree:(uint32_t)variable usingBlock:(BOOL (^)(CharonSpan value, CharonSpan key))block
{
    CharonSpan tree = [self block:variable];
    if (tree.length < 20 || memcmp(tree.bytes, "tree", 4))
        return;
    CharonSpan node = [self block:be32(tree, 8)];
    for (int depth = 0; depth < 32 && node.length >= 12 && !be16(node, 0); depth++) {
        if (be16(node, 2) == 0)
            return;
        node = [self block:be32(node, 12)];
    }
    for (int hops = 0; hops < 1000000 && node.length >= 12 && be16(node, 0); hops++) {
        uint16_t count = be16(node, 2);
        for (uint16_t index = 0; index < count && 12 + 8 * (size_t)(index + 1) <= node.length; index++) {
            CharonSpan value = [self block:be32(node, 12 + 8 * (size_t)index)];
            CharonSpan key = [self block:be32(node, 16 + 8 * (size_t)index)];
            if (!block(value, key))
                return;
        }
        uint32_t next = be32(node, 4);
        if (!next)
            return;
        node = [self block:next];
    }
}

- (NSData *)dataNamed:(NSString *)name typeIdentifier:(NSString **)type
{
    NSData *wanted = [name dataUsingEncoding:NSUTF8StringEncoding];
    __block NSNumber *identifier = nil;
    [self enumerateTree:[_variables[@"FACETKEYS"] unsignedIntValue] usingBlock:^BOOL(CharonSpan token, CharonSpan key) {
        if (key.length != wanted.length || memcmp(key.bytes, wanted.bytes, key.length))
            return YES;
        uint16_t attributes = le16(token, 4);
        for (uint16_t index = 0; index < attributes && 6 + 4 * (size_t)(index + 1) <= token.length; index++)
            if (le16(token, 6 + 4 * (size_t)index) == CharonCatalogIdentifier)
                identifier = @(le16(token, 8 + 4 * (size_t)index));
        return NO;
    }];
    NSUInteger position = [_keyFormat indexOfObject:@(CharonCatalogIdentifier)];
    if (!identifier || position == NSNotFound)
        return nil;
    NSUInteger idiomPosition = [_keyFormat indexOfObject:@(CharonCatalogIdiom)], scalePosition = [_keyFormat indexOfObject:@(CharonCatalogScale)];
    uint16_t idiom = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? 2 : 1;
    uint16_t scale = (uint16_t)[UIScreen mainScreen].scale;
    __block CharonSpan best = {NULL, 0};
    __block int bestScore = -1;
    [self enumerateTree:[_variables[@"RENDITIONS"] unsignedIntValue] usingBlock:^BOOL(CharonSpan value, CharonSpan key) {
        if (key.length < 2 * (position + 1) || le16(key, 2 * position) != identifier.unsignedShortValue)
            return YES;
        int score = 1;
        if (idiomPosition != NSNotFound && key.length >= 2 * (idiomPosition + 1)) {
            uint16_t held = le16(key, 2 * idiomPosition);
            score += held == idiom ? 4 : (held == 0 ? 2 : 0);
            if (held != idiom && held != 0)
                score = 0;
        }
        if (score && scalePosition != NSNotFound && key.length >= 2 * (scalePosition + 1)) {
            uint16_t held = le16(key, 2 * scalePosition);
            score += held == scale ? 2 : 0;
        }
        if (score > bestScore) {
            bestScore = score;
            best = value;
        }
        return YES;
    }];
    if (!best.bytes || best.length < 32 + 8 + 128 + 16 || memcmp(best.bytes, "ISTC", 4))
        return nil;
    size_t listing = 32 + 8 + 128;
    size_t tlvLength = le32(best, listing);
    size_t start = listing + 16;
    if (start + tlvLength > best.length)
        return nil;
    if (type) {
        size_t cursor = start;
        while (cursor + 8 <= start + tlvLength) {
            uint32_t tag = le32(best, cursor), length = le32(best, cursor + 4);
            if (cursor + 8 + length > start + tlvLength)
                break;
            if (tag == 0x3ed && length > 8) {
                size_t textLength = length - 8;
                const char *text = (const char *)best.bytes + cursor + 16;
                size_t actual = strnlen(text, textLength);
                *type = [[NSString alloc] initWithBytes:text length:actual encoding:NSUTF8StringEncoding];
            }
            cursor += 8 + length;
        }
    }
    size_t payload = start + tlvLength;
    if (payload + 12 > best.length || memcmp(best.bytes + payload, "DWAR", 4))
        return nil;
    uint32_t compression = le32(best, payload + 4), length = le32(best, payload + 8);
    if (compression != 0 || payload + 12 + length > best.length)
        return nil;
    return [NSData dataWithBytes:best.bytes + payload + 12 length:length];
}

@end

@implementation NSDataAsset {
    NSString *_name;
    NSData *_data;
    NSString *_typeIdentifier;
}

- (instancetype)initWithName:(NSString *)name
{
    return [self initWithName:name bundle:[NSBundle mainBundle]];
}

- (instancetype)initWithName:(NSString *)name bundle:(NSBundle *)bundle
{
    if (!name)
        [NSException raise:NSInternalInconsistencyException format:@"You cannot create an instance of NSDataAsset with a nil name."];
    NSString *path = [bundle pathForResource:@"Assets" ofType:@"car"];
    CharonAssetCatalog *catalog = path ? [CharonAssetCatalog catalogAtPath:path] : nil;
    NSString *type = nil;
    NSData *data = name.length ? [catalog dataNamed:name typeIdentifier:&type] : nil;
    if (!data)
        return nil;
    self = [super init];
    if (self) {
        _name = [name copy];
        _data = data;
        _typeIdentifier = type ?: @"public.data";
    }
    return self;
}

- (NSString *)name
{
    return _name;
}

- (NSData *)data
{
    return _data;
}

- (NSString *)typeIdentifier
{
    return _typeIdentifier;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p> name:'%@' typeIdentifier='%@' data=%p (length=%lu)", [self class], self, _name, _typeIdentifier, _data, (unsigned long)_data.length];
}

@end

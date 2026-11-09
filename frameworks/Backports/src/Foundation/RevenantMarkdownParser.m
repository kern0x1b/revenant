#import "RevenantMarkdownParser.h"
#import "RevenantMarkdownEntities.h"

@implementation RevenantMarkdownNode
@end

@interface RevenantMarkdownTree () {
@public
    NSMutableArray *_pool;
}
@property (nonatomic, readwrite) RevenantMarkdownNode *root;
@end

@implementation RevenantMarkdownTree
@synthesize root = _root;
@end

static const NSInteger RVMTabStop = 4;
static const NSInteger RVMCodeIndent = 4;

static inline BOOL RVMIsLineEnd(unichar c)
{
    return c == '\n' || c == '\r';
}

static inline BOOL RVMIsSpaceOrTab(unichar c)
{
    return c == ' ' || c == '\t';
}

static inline BOOL RVMIsSpace(unichar c)
{
    return c == ' ' || (c >= 9 && c <= 13);
}

static inline BOOL RVMIsDigit(unichar c)
{
    return c >= '0' && c <= '9';
}

static inline BOOL RVMIsAlpha(unichar c)
{
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
}

static inline BOOL RVMIsAlnum(unichar c)
{
    return RVMIsDigit(c) || RVMIsAlpha(c);
}

static inline BOOL RVMIsHexDigit(unichar c)
{
    return RVMIsDigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

static inline BOOL RVMIsPunct(unichar c)
{
    return (c >= 33 && c <= 47) || (c >= 58 && c <= 64) || (c >= 91 && c <= 96) || (c >= 123 && c <= 126);
}

static inline unichar RVMLower(unichar c)
{
    return (c >= 'A' && c <= 'Z') ? (unichar)(c + 32) : c;
}

static BOOL RVMIsUnicodeSpace(uint32_t c)
{
    return c == 9 || c == 10 || c == 12 || c == 13 || c == 32 || c == 160 || c == 5760 || (c >= 8192 && c <= 8202) || c == 8239 || c == 8287 || c == 12288;
}

static BOOL RVMIsUnicodePunctuation(uint32_t c)
{
    if (c < 128)
        return RVMIsPunct((unichar)c);
    return [[NSCharacterSet punctuationCharacterSet] longCharacterIsMember:c];
}

static inline unichar RVMPeek(NSString *line, NSInteger index)
{
    NSInteger length = (NSInteger)line.length;
    if (index < length)
        return [line characterAtIndex:(NSUInteger)index];
    return index == length ? '\n' : 0;
}

static NSString *RVMString(const unichar *s, NSUInteger from, NSUInteger to)
{
    if (to <= from)
        return @"";
    return [NSString stringWithCharacters:s + from length:to - from];
}

static NSString *RVMTrimmed(NSString *text)
{
    NSUInteger from = 0, to = text.length;
    while (from < to && RVMIsSpace([text characterAtIndex:from]))
        from++;
    while (to > from && RVMIsSpace([text characterAtIndex:to - 1]))
        to--;
    return [text substringWithRange:NSMakeRange(from, to - from)];
}

static BOOL RVMIsBlank(NSString *text)
{
    for (NSUInteger i = 0; i < text.length; i++)
        if (!RVMIsSpace([text characterAtIndex:i]))
            return NO;
    return YES;
}

static void RVMAppendCodePoint(NSMutableString *out, uint32_t cp)
{
    if (cp < 0x10000) {
        unichar c = (unichar)cp;
        [out appendString:[NSString stringWithCharacters:&c length:1]];
    } else {
        cp -= 0x10000;
        unichar pair[2] = {(unichar)(0xD800 + (cp >> 10)), (unichar)(0xDC00 + (cp & 0x3FF))};
        [out appendString:[NSString stringWithCharacters:pair length:2]];
    }
}

static NSUInteger RVMDecodeEntity(const unichar *s, NSUInteger size, NSMutableString *out)
{
    NSUInteger i = 0;
    if (size >= 3 && s[0] == '#') {
        uint32_t codepoint = 0;
        NSUInteger digits = 0;
        if (RVMIsDigit(s[1])) {
            for (i = 1; i < size && RVMIsDigit(s[i]); i++) {
                codepoint = codepoint * 10 + (uint32_t)(s[i] - '0');
                if (codepoint >= 0x110000)
                    codepoint = 0x110000;
            }
            digits = i - 1;
        } else if (s[1] == 'x' || s[1] == 'X') {
            for (i = 2; i < size && RVMIsHexDigit(s[i]); i++) {
                unichar c = s[i];
                uint32_t value = RVMIsDigit(c) ? (uint32_t)(c - '0') : (uint32_t)((c | 32) - 'a' + 10);
                codepoint = codepoint * 16 + value;
                if (codepoint >= 0x110000)
                    codepoint = 0x110000;
            }
            digits = i - 2;
        }
        if (digits >= 1 && digits <= 8 && i < size && s[i] == ';') {
            if (codepoint == 0 || (codepoint >= 0xD800 && codepoint < 0xE000) || codepoint >= 0x110000)
                codepoint = 0xFFFD;
            RVMAppendCodePoint(out, codepoint);
            return i + 1;
        }
        return 0;
    }
    NSUInteger limit = size > 32 ? 32 : size;
    for (i = 2; i < limit; i++) {
        if (s[i] == ' ')
            break;
        if (s[i] == ';') {
            char name[40];
            BOOL ascii = YES;
            for (NSUInteger k = 0; k < i; k++) {
                if (s[k] > 127) {
                    ascii = NO;
                    break;
                }
                name[k] = (char)s[k];
            }
            if (!ascii)
                break;
            const RevenantMarkdownEntity *entity = RevenantMarkdownEntityNamed(name, i);
            if (entity) {
                RVMAppendCodePoint(out, entity->first);
                if (entity->second)
                    RVMAppendCodePoint(out, entity->second);
                return i + 1;
            }
            break;
        }
    }
    return 0;
}

static NSString *RVMUnescapeEntities(NSString *text)
{
    NSUInteger length = text.length;
    if ([text rangeOfString:@"&" options:NSLiteralSearch].location == NSNotFound)
        return text;
    unichar *buffer = (unichar *)malloc((length + 1) * sizeof(unichar));
    [text getCharacters:buffer range:NSMakeRange(0, length)];
    NSMutableString *out = [NSMutableString stringWithCapacity:length];
    NSUInteger i = 0, run = 0;
    while (i < length) {
        if (buffer[i] == '&') {
            NSMutableString *decoded = [NSMutableString string];
            NSUInteger used = RVMDecodeEntity(buffer + i + 1, length - i - 1, decoded);
            if (used) {
                [out appendString:RVMString(buffer, run, i)];
                [out appendString:decoded];
                i += used + 1;
                run = i;
                continue;
            }
        }
        i++;
    }
    [out appendString:RVMString(buffer, run, length)];
    free(buffer);
    return out;
}

static NSString *RVMNulString(void)
{
    unichar nul = 0;
    return [NSString stringWithCharacters:&nul length:1];
}

static NSString *RVMUnescapeBackslashes(NSString *text)
{
    if ([text rangeOfString:@"\\" options:NSLiteralSearch].location == NSNotFound)
        return text;
    NSMutableString *out = [NSMutableString stringWithCapacity:text.length];
    NSUInteger length = text.length;
    for (NSUInteger i = 0; i < length; i++) {
        unichar c = [text characterAtIndex:i];
        if (c == '\\' && i + 1 < length && RVMIsPunct([text characterAtIndex:i + 1])) {
            i++;
            c = [text characterAtIndex:i];
        }
        [out appendString:[NSString stringWithCharacters:&c length:1]];
    }
    return out;
}

static NSString *RVMCleanURL(NSString *raw)
{
    NSString *url = RVMTrimmed(raw);
    if (!url.length)
        return @"";
    if (url.length >= 2 && [url characterAtIndex:0] == '<' && [url characterAtIndex:url.length - 1] == '>')
        url = [url substringWithRange:NSMakeRange(1, url.length - 2)];
    return RVMUnescapeBackslashes(RVMUnescapeEntities(url));
}

static NSString *RVMCleanTitle(NSString *raw)
{
    if (!raw.length)
        return @"";
    unichar first = [raw characterAtIndex:0], last = [raw characterAtIndex:raw.length - 1];
    NSString *body = raw;
    if (raw.length >= 2 && ((first == '\'' && last == '\'') || (first == '(' && last == ')') || (first == '"' && last == '"')))
        body = [raw substringWithRange:NSMakeRange(1, raw.length - 2)];
    return RVMUnescapeBackslashes(RVMUnescapeEntities(body));
}

static NSString *RVMNormalizeLabel(NSString *label)
{
    NSString *trimmed = RVMTrimmed(label);
    NSMutableString *collapsed = [NSMutableString stringWithCapacity:trimmed.length];
    BOOL pending = NO;
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (RVMIsSpace(c)) {
            pending = YES;
            continue;
        }
        if (pending && collapsed.length)
            [collapsed appendString:@" "];
        pending = NO;
        [collapsed appendString:[NSString stringWithCharacters:&c length:1]];
    }
    return [collapsed stringByFoldingWithOptions:NSCaseInsensitiveSearch locale:nil];
}

static RevenantMarkdownNode *RVMNew(NSMutableArray *pool, RevenantMarkdownKind kind)
{
    RevenantMarkdownNode *node = [[RevenantMarkdownNode alloc] init];
    node->kind = kind;
    [pool addObject:node];
    return node;
}

static void RVMUnlink(RevenantMarkdownNode *node)
{
    if (node->previous)
        node->previous->next = node->next;
    else if (node->parent)
        node->parent->firstChild = node->next;
    if (node->next)
        node->next->previous = node->previous;
    else if (node->parent)
        node->parent->lastChild = node->previous;
    node->parent = nil;
    node->previous = nil;
    node->next = nil;
}

static void RVMAppend(RevenantMarkdownNode *parent, RevenantMarkdownNode *child)
{
    RVMUnlink(child);
    child->parent = parent;
    if (parent->lastChild) {
        parent->lastChild->next = child;
        child->previous = parent->lastChild;
    } else {
        parent->firstChild = child;
        child->previous = nil;
    }
    parent->lastChild = child;
}

static void RVMInsertAfter(RevenantMarkdownNode *node, RevenantMarkdownNode *sibling)
{
    RVMUnlink(sibling);
    sibling->parent = node->parent;
    sibling->previous = node;
    sibling->next = node->next;
    if (node->next)
        node->next->previous = sibling;
    else if (node->parent)
        node->parent->lastChild = sibling;
    node->next = sibling;
}

static void RVMInsertBefore(RevenantMarkdownNode *node, RevenantMarkdownNode *sibling)
{
    RVMUnlink(sibling);
    sibling->parent = node->parent;
    sibling->next = node;
    sibling->previous = node->previous;
    if (node->previous)
        node->previous->next = sibling;
    else if (node->parent)
        node->parent->firstChild = sibling;
    node->previous = sibling;
}

#pragma mark - inline scanners

static NSUInteger RVMScanTagName(const unichar *s, NSUInteger n, NSUInteger i)
{
    if (i >= n || !RVMIsAlpha(s[i]))
        return i;
    i++;
    while (i < n && (RVMIsAlnum(s[i]) || s[i] == '-'))
        i++;
    return i;
}

static inline BOOL RVMIsTagSpace(unichar c)
{
    return c == ' ' || c == '\t' || c == '\v' || c == '\f' || c == '\r' || c == '\n';
}

static NSUInteger RVMSkipTagSpace(const unichar *s, NSUInteger n, NSUInteger i)
{
    while (i < n && RVMIsTagSpace(s[i]))
        i++;
    return i;
}

static BOOL RVMScanAttribute(const unichar *s, NSUInteger n, NSUInteger *at)
{
    NSUInteger i = *at;
    NSUInteger spaces = RVMSkipTagSpace(s, n, i);
    if (spaces == i)
        return NO;
    i = spaces;
    if (i >= n || !(RVMIsAlpha(s[i]) || s[i] == '_' || s[i] == ':'))
        return NO;
    i++;
    while (i < n && (RVMIsAlnum(s[i]) || s[i] == ':' || s[i] == '.' || s[i] == '_' || s[i] == '-'))
        i++;
    NSUInteger j = RVMSkipTagSpace(s, n, i);
    if (j < n && s[j] == '=') {
        j = RVMSkipTagSpace(s, n, j + 1);
        if (j < n && (s[j] == '\'' || s[j] == '"')) {
            unichar quote = s[j];
            NSUInteger k = j + 1;
            while (k < n && s[k] != quote && s[k] != 0)
                k++;
            if (k < n && s[k] == quote) {
                *at = k + 1;
                return YES;
            }
        } else {
            NSUInteger k = j;
            while (k < n && s[k] > 32 && s[k] != '"' && s[k] != '\'' && s[k] != '=' && s[k] != '<' && s[k] != '>' && s[k] != '`')
                k++;
            if (k > j) {
                *at = k;
                return YES;
            }
        }
    }
    *at = i;
    return YES;
}

static BOOL RVMScanOpenTag(const unichar *s, NSUInteger n, NSUInteger i, NSUInteger *end)
{
    NSUInteger j = RVMScanTagName(s, n, i);
    if (j == i)
        return NO;
    NSUInteger at = j;
    while (RVMScanAttribute(s, n, &at))
        ;
    at = RVMSkipTagSpace(s, n, at);
    if (at < n && s[at] == '/')
        at++;
    if (at < n && s[at] == '>') {
        *end = at + 1;
        return YES;
    }
    return NO;
}

static BOOL RVMScanCloseTag(const unichar *s, NSUInteger n, NSUInteger i, NSUInteger *end)
{
    if (i >= n || s[i] != '/')
        return NO;
    NSUInteger j = RVMScanTagName(s, n, i + 1);
    if (j == i + 1)
        return NO;
    j = RVMSkipTagSpace(s, n, j);
    if (j < n && s[j] == '>') {
        *end = j + 1;
        return YES;
    }
    return NO;
}

static BOOL RVMScanHTMLComment(const unichar *s, NSUInteger n, NSUInteger i, NSUInteger *end)
{
    if (i + 2 >= n || s[i] != '!' || s[i + 1] != '-' || s[i + 2] != '-')
        return NO;
    NSUInteger p = i + 3;
    if (p < n && s[p] == '>') {
        *end = p + 1;
        return YES;
    }
    if (p + 1 < n && s[p] == '-' && s[p + 1] == '>') {
        *end = p + 2;
        return YES;
    }
    NSUInteger span = n - p + 1;
    unsigned char *visited = (unsigned char *)calloc(span, 1);
    NSUInteger *stack = (NSUInteger *)malloc(span * 3 * sizeof(NSUInteger) + sizeof(NSUInteger));
    NSUInteger top = 0, best = 0;
    stack[top++] = p;
    while (top) {
        NSUInteger q = stack[--top];
        if (q > n || visited[q - p])
            continue;
        visited[q - p] = 1;
        if (q + 2 < n && s[q] == '-' && s[q + 1] == '-' && s[q + 2] == '>' && q + 3 > best)
            best = q + 3;
        if (q >= n)
            continue;
        if (s[q] != '-') {
            stack[top++] = q + 1;
        } else {
            if (q + 1 < n && s[q + 1] != '-')
                stack[top++] = q + 2;
            if (q + 2 < n && s[q + 1] == '-' && s[q + 2] != '>')
                stack[top++] = q + 3;
        }
    }
    free(visited);
    free(stack);
    if (!best)
        return NO;
    *end = best;
    return YES;
}

static BOOL RVMScanHTMLTag(const unichar *s, NSUInteger n, NSUInteger i, NSUInteger *end)
{
    if (i >= n)
        return NO;
    if (RVMScanOpenTag(s, n, i, end) || RVMScanCloseTag(s, n, i, end) || RVMScanHTMLComment(s, n, i, end))
        return YES;
    if (s[i] == '?') {
        for (NSUInteger k = i + 1; k + 1 < n + 0; k++) {
            if (s[k] == 0)
                return NO;
            if (s[k] == '?' && s[k + 1] == '>') {
                *end = k + 2;
                return YES;
            }
        }
        return NO;
    }
    if (s[i] == '!') {
        NSUInteger k = i + 1;
        if (k + 6 < n && s[k] == '[' && s[k + 1] == 'C' && s[k + 2] == 'D' && s[k + 3] == 'A' && s[k + 4] == 'T' && s[k + 5] == 'A' && s[k + 6] == '[') {
            NSUInteger brackets = 0;
            for (k = k + 7; k < n; k++) {
                unichar c = s[k];
                if (c == 0)
                    return NO;
                if (brackets == 2 && c == '>') {
                    *end = k + 1;
                    return YES;
                }
                brackets = (c == ']' && brackets < 2) ? brackets + 1 : 0;
            }
            return NO;
        }
        NSUInteger letters = 0;
        while (k < n && s[k] >= 'A' && s[k] <= 'Z') {
            k++;
            letters++;
        }
        if (!letters)
            return NO;
        NSUInteger spaces = RVMSkipTagSpace(s, n, k);
        if (spaces == k)
            return NO;
        k = spaces;
        while (k < n && s[k] != '>' && s[k] != 0)
            k++;
        if (k < n && s[k] == '>') {
            *end = k + 1;
            return YES;
        }
    }
    return NO;
}

static BOOL RVMScanAutolinkURI(const unichar *s, NSUInteger n, NSUInteger i, NSUInteger *end)
{
    if (i >= n || !RVMIsAlpha(s[i]))
        return NO;
    NSUInteger k = i + 1;
    while (k < n && (RVMIsAlnum(s[k]) || s[k] == '.' || s[k] == '+' || s[k] == '-'))
        k++;
    NSUInteger length = k - i;
    if (length < 2 || length > 32 || k >= n || s[k] != ':')
        return NO;
    k++;
    while (k < n && s[k] > 32 && s[k] != '<' && s[k] != '>')
        k++;
    if (k < n && s[k] == '>') {
        *end = k;
        return YES;
    }
    return NO;
}

static BOOL RVMIsEmailLocal(unichar c)
{
    return RVMIsAlnum(c) || (c < 128 && strchr(".!#$%&'*+/=?^_`{|}~-", (int)c) != NULL && c != 0);
}

static BOOL RVMScanDomainLabel(const unichar *s, NSUInteger n, NSUInteger *at)
{
    NSUInteger i = *at;
    if (i >= n || !RVMIsAlnum(s[i]))
        return NO;
    NSUInteger last = i;
    NSUInteger k = i + 1;
    while (k < n && k - i < 63 && (RVMIsAlnum(s[k]) || s[k] == '-')) {
        if (RVMIsAlnum(s[k]))
            last = k;
        k++;
    }
    *at = last + 1;
    return YES;
}

static BOOL RVMScanAutolinkEmail(const unichar *s, NSUInteger n, NSUInteger i, NSUInteger *end)
{
    NSUInteger k = i;
    while (k < n && RVMIsEmailLocal(s[k]))
        k++;
    if (k == i || k >= n || s[k] != '@')
        return NO;
    k++;
    if (!RVMScanDomainLabel(s, n, &k))
        return NO;
    while (k < n && s[k] == '.') {
        NSUInteger at = k + 1;
        if (!RVMScanDomainLabel(s, n, &at))
            break;
        k = at;
    }
    if (k < n && s[k] == '>') {
        *end = k;
        return YES;
    }
    return NO;
}

#pragma mark - inline parser

@interface RVMDelimiter : NSObject {
@public
    __unsafe_unretained RVMDelimiter *previous;
    __unsafe_unretained RVMDelimiter *next;
    __unsafe_unretained RevenantMarkdownNode *node;
    NSUInteger position;
    NSUInteger length;
    unichar character;
    BOOL canOpen;
    BOOL canClose;
}
@end

@implementation RVMDelimiter
@end

@interface RVMBracket : NSObject {
@public
    __unsafe_unretained RVMBracket *previous;
    __unsafe_unretained RevenantMarkdownNode *node;
    __unsafe_unretained RVMDelimiter *previousDelimiter;
    NSUInteger position;
    BOOL image;
    BOOL caret;
    BOOL bracketAfter;
}
@end

@implementation RVMBracket
@end

@interface RVMReferences : NSObject {
@public
    NSMutableDictionary *table;
}
@end

@implementation RVMReferences
- (instancetype)init
{
    self = [super init];
    table = [NSMutableDictionary dictionary];
    return self;
}
@end

@interface RVMInlineParser : NSObject {
    NSMutableArray *_pool;
    RVMReferences *_references;
    NSMutableArray *_keep;
    NSMutableData *_data;
    unichar *_s;
    NSUInteger _len;
    NSUInteger _pos;
    RVMDelimiter *_lastDelimiter;
    RVMBracket *_lastBracket;
    BOOL _inlineOnly;
    BOOL _scannedBackticks;
    BOOL _noLinkOpeners;
    BOOL _commentBroken;
    NSUInteger _backticks[256];
}
- (instancetype)initWithPool:(NSMutableArray *)pool references:(RVMReferences *)references inlineOnly:(BOOL)inlineOnly;
- (void)parse:(NSString *)string into:(RevenantMarkdownNode *)parent;
- (BOOL)parseReferenceIn:(NSString *)string consumed:(NSUInteger *)consumed;
@end

static NSUInteger RVMScanSpaces(const unichar *s, NSUInteger n, NSUInteger i)
{
    while (i < n && (s[i] == ' ' || s[i] == '\t' || s[i] == '\v' || s[i] == '\f' || s[i] == '\r' || s[i] == '\n'))
        i++;
    return i;
}

static NSUInteger RVMScanSpnl(const unichar *s, NSUInteger n, NSUInteger i)
{
    while (i < n && (s[i] == ' ' || s[i] == '\t'))
        i++;
    BOOL lineEnd = NO;
    if (i < n && s[i] == '\r') {
        i++;
        lineEnd = YES;
    }
    if (i < n && s[i] == '\n') {
        i++;
        lineEnd = YES;
    }
    if (lineEnd)
        while (i < n && (s[i] == ' ' || s[i] == '\t'))
            i++;
    return i;
}

static BOOL RVMStartsReference(NSString *text)
{
    if (!text.length)
        return NO;
    unichar first = [text characterAtIndex:0];
    return first == '[' || (first == '^' && text.length > 1 && [text characterAtIndex:1] == '[');
}

@implementation RVMInlineParser

- (instancetype)initWithPool:(NSMutableArray *)pool references:(RVMReferences *)references inlineOnly:(BOOL)inlineOnly
{
    self = [super init];
    if (!self)
        return nil;
    _pool = pool;
    _references = references;
    _keep = [NSMutableArray array];
    _inlineOnly = inlineOnly;
    return self;
}

- (void)load:(NSString *)string
{
    _len = string.length;
    _data = [NSMutableData dataWithLength:(_len + 1) * sizeof(unichar)];
    _s = (unichar *)_data.mutableBytes;
    [string getCharacters:_s range:NSMakeRange(0, _len)];
    _pos = 0;
    _lastDelimiter = nil;
    _lastBracket = nil;
    _noLinkOpeners = NO;
    _commentBroken = NO;
    _scannedBackticks = NO;
}

- (unichar)peek
{
    return _pos < _len ? _s[_pos] : 0;
}

- (unichar)peekAt:(NSUInteger)index
{
    return index < _len ? _s[index] : 0;
}

- (RevenantMarkdownNode *)textNode:(NSString *)text
{
    RevenantMarkdownNode *node = RVMNew(_pool, RevenantMarkdownText);
    node->literal = text;
    return node;
}

- (RevenantMarkdownNode *)textFrom:(NSUInteger)from to:(NSUInteger)to
{
    return [self textNode:RVMString(_s, from, to)];
}

- (void)pushDelimiter:(unichar)c canOpen:(BOOL)canOpen canClose:(BOOL)canClose node:(RevenantMarkdownNode *)node
{
    RVMDelimiter *delimiter = [[RVMDelimiter alloc] init];
    [_keep addObject:delimiter];
    delimiter->character = c;
    delimiter->canOpen = canOpen;
    delimiter->canClose = canClose;
    delimiter->node = node;
    delimiter->previous = _lastDelimiter;
    delimiter->next = nil;
    delimiter->position = _pos;
    delimiter->length = node->literal.length;
    if (_lastDelimiter)
        _lastDelimiter->next = delimiter;
    _lastDelimiter = delimiter;
}

- (void)removeDelimiter:(RVMDelimiter *)delimiter
{
    if (delimiter->next)
        delimiter->next->previous = delimiter->previous;
    if (delimiter->previous)
        delimiter->previous->next = delimiter->next;
    if (delimiter == _lastDelimiter)
        _lastDelimiter = delimiter->previous;
}

- (void)pushBracket:(RevenantMarkdownNode *)node image:(BOOL)image
{
    [self pushBracket:node image:image caret:NO];
}

- (void)pushBracket:(RevenantMarkdownNode *)node image:(BOOL)image caret:(BOOL)caret
{
    RVMBracket *bracket = [[RVMBracket alloc] init];
    [_keep addObject:bracket];
    if (_lastBracket)
        _lastBracket->bracketAfter = YES;
    bracket->node = node;
    bracket->image = image;
    bracket->caret = caret;
    if (!image)
        _noLinkOpeners = NO;
    bracket->bracketAfter = NO;
    bracket->previousDelimiter = _lastDelimiter;
    bracket->previous = _lastBracket;
    bracket->position = _pos;
    _lastBracket = bracket;
}

- (void)popBracket
{
    if (_lastBracket)
        _lastBracket = _lastBracket->previous;
}

- (uint32_t)codePointBefore:(NSUInteger)index
{
    if (index == 0)
        return 10;
    unichar c = _s[index - 1];
    if (c >= 0xDC00 && c <= 0xDFFF && index >= 2 && _s[index - 2] >= 0xD800 && _s[index - 2] <= 0xDBFF)
        return 0x10000 + (((uint32_t)_s[index - 2] - 0xD800) << 10) + ((uint32_t)c - 0xDC00);
    return c;
}

- (uint32_t)codePointAfter:(NSUInteger)index
{
    if (index >= _len)
        return 10;
    unichar c = _s[index];
    if (c >= 0xD800 && c <= 0xDBFF && index + 1 < _len && _s[index + 1] >= 0xDC00 && _s[index + 1] <= 0xDFFF)
        return 0x10000 + (((uint32_t)c - 0xD800) << 10) + ((uint32_t)_s[index + 1] - 0xDC00);
    return c;
}

- (NSUInteger)scanDelimiters:(unichar)c canOpen:(BOOL *)canOpen canClose:(BOOL *)canClose left:(BOOL *)leftOut right:(BOOL *)rightOut
{
    NSUInteger count = 0;
    BOOL skipsTilde = c != '~';
    NSUInteger beforeAt = _pos;
    while (skipsTilde && beforeAt > 0 && _s[beforeAt - 1] == '~')
        beforeAt--;
    uint32_t before = [self codePointBefore:beforeAt];
    while ([self peek] == c) {
        count++;
        _pos++;
    }
    NSUInteger afterAt = _pos;
    while (skipsTilde && afterAt < _len && _s[afterAt] == '~')
        afterAt++;
    uint32_t after = [self codePointAfter:afterAt];
    BOOL afterSpace = RVMIsUnicodeSpace(after), beforeSpace = RVMIsUnicodeSpace(before);
    BOOL afterPunct = RVMIsUnicodePunctuation(after), beforePunct = RVMIsUnicodePunctuation(before);
    BOOL left = count > 0 && !afterSpace && !(afterPunct && !beforeSpace && !beforePunct);
    BOOL right = count > 0 && !beforeSpace && !(beforePunct && !afterSpace && !afterPunct);
    if (c == '_') {
        *canOpen = left && (!right || beforePunct);
        *canClose = right && (!left || afterPunct);
    } else {
        *canOpen = left;
        *canClose = right;
    }
    if (leftOut)
        *leftOut = left;
    if (rightOut)
        *rightOut = right;
    return count;
}

- (RevenantMarkdownNode *)handleDelimiter:(unichar)c
{
    BOOL canOpen, canClose;
    NSUInteger count = [self scanDelimiters:c canOpen:&canOpen canClose:&canClose left:NULL right:NULL];
    RevenantMarkdownNode *node = [self textFrom:_pos - count to:_pos];
    if (canOpen || canClose)
        [self pushDelimiter:c canOpen:canOpen canClose:canClose node:node];
    return node;
}

- (RevenantMarkdownNode *)handleTilde
{
    BOOL left, right, ignoredOpen, ignoredClose;
    NSUInteger count = [self scanDelimiters:'~' canOpen:&ignoredOpen canClose:&ignoredClose left:&left right:&right];
    RevenantMarkdownNode *node = [self textFrom:_pos - count to:_pos];
    if ((left || right) && (count == 2 || count == 1))
        [self pushDelimiter:'~' canOpen:left canClose:right node:node];
    return node;
}

- (RVMDelimiter *)insertEmphasisOpener:(RVMDelimiter *)opener closer:(RVMDelimiter *)closer
{
    RevenantMarkdownNode *openerNode = opener->node, *closerNode = closer->node;
    NSUInteger openerChars = openerNode->literal.length, closerChars = closerNode->literal.length, use;
    if (closerChars < 3 || openerChars < 3)
        use = closerChars <= openerChars ? closerChars : openerChars;
    else
        use = closerChars % 2 == 0 ? 2 : 1;
    openerChars -= use;
    closerChars -= use;
    openerNode->literal = [openerNode->literal substringToIndex:openerChars];
    closerNode->literal = [closerNode->literal substringToIndex:closerChars];
    RVMDelimiter *delimiter = closer->previous;
    while (delimiter && delimiter != opener) {
        RVMDelimiter *previous = delimiter->previous;
        [self removeDelimiter:delimiter];
        delimiter = previous;
    }
    RevenantMarkdownNode *emphasis = RVMNew(_pool, use == 1 ? RevenantMarkdownEmphasis : RevenantMarkdownStrong);
    RevenantMarkdownNode *between = openerNode->next;
    while (between && between != closerNode) {
        RevenantMarkdownNode *following = between->next;
        RVMAppend(emphasis, between);
        between = following;
    }
    RVMInsertAfter(openerNode, emphasis);
    if (openerChars == 0) {
        RVMUnlink(openerNode);
        [self removeDelimiter:opener];
    }
    if (closerChars == 0) {
        RVMUnlink(closerNode);
        RVMDelimiter *following = closer->next;
        [self removeDelimiter:closer];
        closer = following;
    }
    return closer;
}

- (RVMDelimiter *)insertStrikethroughOpener:(RVMDelimiter *)opener closer:(RVMDelimiter *)closer
{
    RVMDelimiter *result = closer->next;
    RevenantMarkdownNode *openerNode = opener->node, *closerNode = closer->node;
    if (openerNode->literal.length == closerNode->literal.length) {
        RevenantMarkdownNode *between = openerNode->next;
        while (between && between != closerNode) {
            RevenantMarkdownNode *following = between->next;
            RVMAppend(openerNode, between);
            between = following;
        }
        openerNode->kind = RevenantMarkdownStrikethrough;
        openerNode->literal = nil;
        RVMUnlink(closerNode);
    }
    RVMDelimiter *delimiter = closer;
    while (delimiter && delimiter != opener) {
        RVMDelimiter *previous = delimiter->previous;
        [self removeDelimiter:delimiter];
        delimiter = previous;
    }
    [self removeDelimiter:opener];
    return result;
}

- (void)processEmphasisBottom:(RVMDelimiter *)stackBottom
{
    RVMDelimiter *closer = _lastDelimiter;
    NSInteger bottoms[3][128];
    for (int i = 0; i < 3; i++)
        for (int j = 0; j < 128; j++)
            bottoms[i][j] = -1;
    while (closer && closer->previous != stackBottom)
        closer = closer->previous;
    while (closer) {
        if (closer->canClose) {
            RVMDelimiter *opener = closer->previous;
            BOOL found = NO;
            NSInteger limit = bottoms[closer->length % 3][closer->character];
            while (opener && opener != stackBottom && (NSInteger)opener->position >= limit) {
                if (opener->canOpen && opener->character == closer->character) {
                    if (!(closer->canOpen || opener->canClose) || closer->length % 3 == 0 || (opener->length + closer->length) % 3 != 0) {
                        found = YES;
                        break;
                    }
                }
                opener = opener->previous;
            }
            RVMDelimiter *oldCloser = closer;
            if (closer->character == '*' || closer->character == '_') {
                closer = found ? [self insertEmphasisOpener:opener closer:closer] : closer->next;
            } else {
                closer = found ? [self insertStrikethroughOpener:opener closer:closer] : closer->next;
            }
            if (!found) {
                bottoms[oldCloser->length % 3][oldCloser->character] = (NSInteger)oldCloser->position;
                if (!oldCloser->canOpen)
                    [self removeDelimiter:oldCloser];
            }
        } else {
            closer = closer->next;
        }
    }
    while (_lastDelimiter && _lastDelimiter != stackBottom)
        [self removeDelimiter:_lastDelimiter];
}

- (RevenantMarkdownNode *)handleBackticksInto:(RevenantMarkdownNode *)parent
{
    NSUInteger open = 0;
    while ([self peek] == '`') {
        open++;
        _pos++;
    }
    NSUInteger startPos = _pos;
    NSUInteger endPos = 0;
    if (open <= 255) {
        if (!(_scannedBackticks && _backticks[open] != 0 && _backticks[open] <= _pos)) {
            BOOL found = NO;
            while (!found) {
                while (_pos < _len && _s[_pos] != '`')
                    _pos++;
                if (_pos >= _len)
                    break;
                NSUInteger ticks = 0;
                while ([self peek] == '`') {
                    ticks++;
                    _pos++;
                }
                if (ticks <= 255)
                    _backticks[ticks] = _pos - ticks;
                if (ticks == open) {
                    endPos = _pos;
                    found = YES;
                }
            }
            if (!found) {
                if (!_scannedBackticks) {
                    memset(_backticks, 0, sizeof(_backticks));
                }
                _scannedBackticks = YES;
                _backticks[open] = _len + 1;
            }
        }
    }
    if (endPos == 0) {
        _pos = startPos;
        return [self textFrom:startPos - open to:startPos];
    }
    NSUInteger contentEnd = endPos - open;
    NSUInteger count = contentEnd - startPos;
    unichar *buffer = (unichar *)malloc((count + 1) * sizeof(unichar));
    memcpy(buffer, _s + startPos, count * sizeof(unichar));
    NSUInteger w = 0;
    BOOL nonSpace = NO;
    for (NSUInteger r = 0; r < count; r++) {
        unichar c = buffer[r];
        if (c == '\r') {
            if (r + 1 >= count || buffer[r + 1] != '\n')
                buffer[w++] = ' ';
        } else if (c == '\n') {
            buffer[w++] = ' ';
        } else {
            buffer[w++] = c;
        }
        if (buffer[r] != ' ')
            nonSpace = YES;
    }
    NSString *code;
    if (nonSpace && w >= 2 && buffer[0] == ' ' && buffer[w - 1] == ' ')
        code = RVMString(buffer, 1, w - 1);
    else
        code = RVMString(buffer, 0, w);
    free(buffer);
    RevenantMarkdownNode *node = RVMNew(_pool, RevenantMarkdownCode);
    node->literal = code;
    _pos = endPos;
    return node;
}

- (RevenantMarkdownNode *)handleBackslash
{
    _pos++;
    unichar next = [self peek];
    if (_pos < _len && RVMIsPunct(next)) {
        _pos++;
        return [self textFrom:_pos - 1 to:_pos];
    }
    if (_pos < _len && RVMIsLineEnd(next)) {
        if ([self peek] == '\r')
            _pos++;
        if ([self peek] == '\n')
            _pos++;
        return RVMNew(_pool, RevenantMarkdownLineBreak);
    }
    return [self textNode:@"\\"];
}

- (RevenantMarkdownNode *)handleEntity
{
    _pos++;
    NSMutableString *decoded = [NSMutableString string];
    NSUInteger used = RVMDecodeEntity(_s + _pos, _len - _pos, decoded);
    if (used) {
        _pos += used;
        return [self textNode:decoded];
    }
    return [self textNode:@"&"];
}

- (RevenantMarkdownNode *)makeAutolinkText:(NSString *)text url:(NSString *)url
{
    RevenantMarkdownNode *link = RVMNew(_pool, RevenantMarkdownLink);
    link->destination = url;
    link->title = @"";
    RVMAppend(link, [self textNode:text]);
    return link;
}

- (RevenantMarkdownNode *)handlePointyBrace
{
    _pos++;
    NSUInteger end;
    if (RVMScanAutolinkURI(_s, _len, _pos, &end)) {
        NSString *text = RVMString(_s, _pos, end);
        _pos = end + 1;
        NSString *clean = RVMUnescapeEntities(RVMTrimmed(text));
        return [self makeAutolinkText:clean url:clean];
    }
    if (RVMScanAutolinkEmail(_s, _len, _pos, &end)) {
        NSString *text = RVMString(_s, _pos, end);
        _pos = end + 1;
        NSString *clean = RVMUnescapeEntities(RVMTrimmed(text));
        return [self makeAutolinkText:clean url:[@"mailto:" stringByAppendingString:clean]];
    }
    BOOL bang = _pos < _len && _s[_pos] == '!';
    BOOL commentStart = bang && _pos + 2 < _len && _s[_pos + 1] == '-' && _s[_pos + 2] == '-';
    BOOL blocked = bang && _commentBroken;
    if (!blocked && RVMScanHTMLTag(_s, _len, _pos, &end)) {
        RevenantMarkdownNode *node = RVMNew(_pool, RevenantMarkdownHTMLInline);
        node->literal = RVMString(_s, _pos - 1, end);
        _pos = end;
        return node;
    }
    if (commentStart)
        _commentBroken = YES;
    return [self textNode:@"<"];
}

- (RevenantMarkdownNode *)handleNewline
{
    NSUInteger newlinePos = _pos;
    if ([self peek] == '\r')
        _pos++;
    if ([self peek] == '\n')
        _pos++;
    while ([self peek] == ' ' || [self peek] == '\t')
        _pos++;
    if (newlinePos > 1 && _s[newlinePos - 1] == ' ' && _s[newlinePos - 2] == ' ')
        return RVMNew(_pool, RevenantMarkdownLineBreak);
    return RVMNew(_pool, RevenantMarkdownSoftBreak);
}

- (NSUInteger)scanLinkLabel:(NSString **)label
{
    NSUInteger startPos = _pos;
    if ([self peek] != '[')
        return 0;
    _pos++;
    NSUInteger length = 0;
    unichar c;
    while ((c = [self peek]) && c != '[' && c != ']') {
        if (c == '\\') {
            _pos++;
            length++;
            if (RVMIsPunct([self peek])) {
                _pos++;
                length++;
            }
        } else {
            _pos++;
            length++;
        }
        if (length > 1000) {
            _pos = startPos;
            return 0;
        }
    }
    if (c == ']') {
        *label = RVMTrimmed(RVMString(_s, startPos + 1, _pos));
        _pos++;
        return 1;
    }
    _pos = startPos;
    return 0;
}

- (BOOL)scanLinkURLAt:(NSUInteger)offset result:(NSString **)result consumed:(NSInteger *)consumed
{
    NSUInteger i = offset;
    if (i < _len && _s[i] == '<') {
        i++;
        while (i < _len) {
            if (_s[i] == '>') {
                i++;
                break;
            } else if (_s[i] == '\\') {
                i += 2;
            } else if (_s[i] == '\n' || _s[i] == '<') {
                return NO;
            } else {
                i++;
            }
        }
        if (i >= _len)
            return NO;
        *result = RVMString(_s, offset + 1, i - 1);
        *consumed = (NSInteger)(i - offset);
        return YES;
    }
    NSUInteger depth = 0;
    while (i < _len) {
        if (_s[i] == '\\' && i + 1 < _len && RVMIsPunct(_s[i + 1])) {
            i += 2;
        } else if (_s[i] == '(') {
            depth++;
            i++;
            if (depth > 32)
                return NO;
        } else if (_s[i] == ')') {
            if (depth == 0)
                break;
            depth--;
            i++;
        } else if (RVMIsSpace(_s[i])) {
            if (i == offset)
                return NO;
            break;
        } else {
            i++;
        }
    }
    if (i >= _len)
        return NO;
    *result = RVMString(_s, offset, i);
    *consumed = (NSInteger)(i - offset);
    return YES;
}

- (NSUInteger)scanLinkTitleAt:(NSUInteger)offset
{
    if (offset >= _len)
        return 0;
    unichar open = _s[offset], close;
    if (open == '"' || open == '\'')
        close = open;
    else if (open == '(')
        close = ')';
    else
        return 0;
    NSUInteger best = 0;
    for (NSUInteger i = offset + 1; i < _len; i++) {
        unichar c = _s[i];
        if (c == 0)
            break;
        if (c == close) {
            best = i + 1 - offset;
            if (_s[i - 1] != '\\')
                break;
        } else if (open == '(' && c == '(' && _s[i - 1] != '\\') {
            break;
        }
    }
    return best;
}

- (NSUInteger)scanAttributeGroupAt:(NSUInteger)offset
{
    NSUInteger depth = 0;
    NSUInteger i = offset;
    while (i < _len) {
        unichar c = _s[i];
        if (c == '\\' && i + 1 < _len) {
            i += 2;
            continue;
        }
        if (c == '(') {
            depth++;
        } else if (c == ')') {
            depth--;
            if (depth == 0)
                return i + 1;
        }
        i++;
    }
    return 0;
}

- (RevenantMarkdownNode *)closeCaret:(RVMBracket *)opener
{
    BOOL matched = NO;
    if ([self peek] == '(') {
        NSUInteger end = [self scanAttributeGroupAt:_pos];
        if (end != 0) {
            _pos = end;
            matched = YES;
        }
    }
    NSUInteger afterGroup = _pos;
    if ([self peek] == '[') {
        NSString *label = @"";
        if ([self scanLinkLabel:&label] == 0)
            _pos = afterGroup;
    }
    if (matched) {
        RevenantMarkdownNode *group = RVMNew(_pool, RevenantMarkdownAttributed);
        RevenantMarkdownNode *between = opener->node->next;
        RVMInsertBefore(opener->node, group);
        while (between) {
            RevenantMarkdownNode *following = between->next;
            RVMAppend(group, between);
            between = following;
        }
        RVMUnlink(opener->node);
        [self processEmphasisBottom:opener->previousDelimiter];
        [self popBracket];
        return nil;
    }
    [self popBracket];
    return [self textNode:@"]"];
}

- (RevenantMarkdownNode *)handleCloseBracket
{
    _pos++;
    NSUInteger initial = _pos;
    RVMBracket *opener = _lastBracket;
    if (!opener)
        return [self textNode:@"]"];
    if (opener->caret)
        return [self closeCaret:opener];
    if (!opener->image && _noLinkOpeners) {
        [self popBracket];
        return [self textNode:@"]"];
    }
    BOOL image = opener->image;
    NSString *url = nil, *title = nil;
    BOOL matched = NO;
    if ([self peek] == '(') {
        NSUInteger afterSpaces = RVMScanSpaces(_s, _len, _pos + 1);
        NSString *urlChunk = nil;
        NSInteger used = 0;
        if ([self scanLinkURLAt:afterSpaces result:&urlChunk consumed:&used]) {
            NSUInteger endURL = afterSpaces + (NSUInteger)used;
            NSUInteger startTitle = RVMScanSpaces(_s, _len, endURL);
            NSUInteger endTitle = startTitle == endURL ? startTitle : startTitle + [self scanLinkTitleAt:startTitle];
            NSUInteger endAll = RVMScanSpaces(_s, _len, endTitle);
            if (endAll < _len && _s[endAll] == ')') {
                _pos = endAll + 1;
                url = RVMCleanURL(urlChunk);
                title = startTitle == endTitle ? @"" : RVMCleanTitle(RVMString(_s, startTitle, endTitle));
                matched = YES;
            }
        }
    }
    if (!matched) {
        NSString *label = @"";
        BOOL foundLabel = [self scanLinkLabel:&label] != 0;
        if (!foundLabel)
            _pos = initial;
        if ((!foundLabel || label.length == 0) && !opener->bracketAfter) {
            label = RVMString(_s, opener->position, initial - 1);
            foundLabel = YES;
        }
        if (foundLabel) {
            NSArray *reference = _references->table[RVMNormalizeLabel(label)];
            if (reference.count) {
                url = reference[0];
                title = reference[1];
                matched = YES;
            }
        }
    }
    if (!matched) {
        [self popBracket];
        _pos = initial;
        return [self textNode:@"]"];
    }
    RevenantMarkdownNode *node = RVMNew(_pool, image ? RevenantMarkdownImage : RevenantMarkdownLink);
    node->destination = url;
    node->title = title;
    RevenantMarkdownNode *between = opener->node->next;
    RVMInsertBefore(opener->node, node);
    while (between) {
        RevenantMarkdownNode *following = between->next;
        RVMAppend(node, between);
        between = following;
    }
    RVMUnlink(opener->node);
    [self processEmphasisBottom:opener->previousDelimiter];
    [self popBracket];
    if (!image)
        _noLinkOpeners = YES;
    return nil;
}

- (BOOL)isSpecial:(unichar)c
{
    switch (c) {
    case '\r': case '\n': case '`': case '\\': case '&': case '<': case '[': case ']': case '!': case '*': case '_': case '~':
    case ':': case 'w': case '^':
        return YES;
    default:
        return NO;
    }
}

- (void)parseOneInto:(RevenantMarkdownNode *)parent
{
    unichar c = _s[_pos];
    RevenantMarkdownNode *node = nil;
    switch (c) {
    case '\r':
    case '\n':
        if (_inlineOnly) {
            NSUInteger start = _pos;
            if (c == '\r' && [self peekAt:_pos + 1] == '\n')
                _pos++;
            _pos++;
            node = [self textFrom:start to:_pos];
        } else {
            node = [self handleNewline];
        }
        break;
    case '`':
        node = [self handleBackticksInto:parent];
        break;
    case '\\':
        node = [self handleBackslash];
        break;
    case '&':
        node = [self handleEntity];
        break;
    case '<':
        node = [self handlePointyBrace];
        break;
    case '*':
    case '_':
        node = [self handleDelimiter:c];
        break;
    case '~':
        node = [self handleTilde];
        break;
    case '[':
        _pos++;
        node = [self textNode:@"["];
        [self pushBracket:node image:NO];
        break;
    case ']':
        node = [self handleCloseBracket];
        break;
    case '^':
        _pos++;
        if ([self peek] == '[') {
            _pos++;
            node = [self textNode:@"^["];
            [self pushBracket:node image:YES caret:YES];
        } else {
            node = [self textNode:@"^"];
        }
        break;
    case '!':
        _pos++;
        if ([self peek] == '[' && [self peekAt:_pos + 1] != '^') {
            _pos++;
            node = [self textNode:@"!["];
            [self pushBracket:node image:YES];
        } else {
            node = [self textNode:@"!"];
        }
        break;
    default: {
        if (c == ':' || c == 'w') {
            node = [self handleAutolink:c parent:parent];
            if (node)
                break;
        }
        NSUInteger end = _pos + 1;
        while (end < _len && ![self isSpecial:_s[end]])
            end++;
        NSUInteger from = _pos;
        _pos = end;
        if (!_inlineOnly && _pos < _len && RVMIsLineEnd(_s[_pos])) {
            while (end > from && RVMIsSpace(_s[end - 1]))
                end--;
        }
        node = [self textFrom:from to:end];
        break;
    }
    }
    if (node)
        RVMAppend(parent, node);
}

- (void)parse:(NSString *)string into:(RevenantMarkdownNode *)parent
{
    [self load:string];
    if (!_inlineOnly) {
        while (_len > 0 && RVMIsSpace(_s[_len - 1]))
            _len--;
    }
    while (_pos < _len)
        [self parseOneInto:parent];
    [self processEmphasisBottom:nil];
    _lastBracket = nil;
    [self consolidate:parent];
    [self autolinkEmailsIn:parent];
    [self consolidate:parent];
}

- (void)consolidate:(RevenantMarkdownNode *)node
{
    RevenantMarkdownNode *child = node->firstChild;
    while (child) {
        if (child->kind == RevenantMarkdownText) {
            RevenantMarkdownNode *following = child->next;
            NSMutableString *merged = nil;
            while (following && following->kind == RevenantMarkdownText) {
                if (!merged)
                    merged = [child->literal mutableCopy];
                [merged appendString:following->literal];
                RevenantMarkdownNode *after = following->next;
                RVMUnlink(following);
                following = after;
            }
            if (merged)
                child->literal = merged;
        } else if (child->firstChild) {
            [self consolidate:child];
        }
        child = child->next;
    }
}

- (BOOL)parseReferenceIn:(NSString *)string consumed:(NSUInteger *)consumed
{
    [self load:string];
    BOOL caret = _len > 1 && _s[0] == '^' && _s[1] == '[';
    if (caret)
        _pos = 1;
    NSString *label = @"";
    if (![self scanLinkLabel:&label] || label.length == 0)
        return NO;
    if (caret && RVMNormalizeLabel(label).length == 0)
        return NO;
    if ([self peek] != ':')
        return NO;
    _pos++;
    _pos = RVMScanSpnl(_s, _len, _pos);
    if (caret) {
        if (_pos >= _len || _s[_pos] == '\r' || _s[_pos] == '\n')
            return NO;
        while (_pos < _len && _s[_pos] != '\r' && _s[_pos] != '\n')
            _pos++;
        if (_pos < _len && _s[_pos] == '\r')
            _pos++;
        if (_pos < _len && _s[_pos] == '\n')
            _pos++;
        NSString *blocked = RVMNormalizeLabel(label);
        if (!_references->table[blocked])
            _references->table[blocked] = @[];
        *consumed = _pos;
        return YES;
    }
    NSString *urlChunk = nil;
    NSInteger used = 0;
    if (![self scanLinkURLAt:_pos result:&urlChunk consumed:&used])
        return NO;
    _pos += (NSUInteger)used;
    NSUInteger beforeTitle = _pos;
    _pos = RVMScanSpnl(_s, _len, _pos);
    NSUInteger titleLength = _pos == beforeTitle ? 0 : [self scanLinkTitleAt:_pos];
    NSString *title = @"";
    if (titleLength) {
        title = RVMString(_s, _pos, _pos + titleLength);
        _pos += titleLength;
    } else {
        _pos = beforeTitle;
    }
    while (_pos < _len && (_s[_pos] == ' ' || _s[_pos] == '\t'))
        _pos++;
    BOOL lineEnd = NO;
    if (_pos >= _len) {
        lineEnd = YES;
    } else if (_s[_pos] == '\r' || _s[_pos] == '\n') {
        if (_s[_pos] == '\r')
            _pos++;
        if (_pos < _len && _s[_pos] == '\n')
            _pos++;
        lineEnd = YES;
    }
    if (!lineEnd) {
        if (!titleLength)
            return NO;
        _pos = beforeTitle;
        while (_pos < _len && (_s[_pos] == ' ' || _s[_pos] == '\t'))
            _pos++;
        if (_pos >= _len) {
        } else if (_s[_pos] == '\r' || _s[_pos] == '\n') {
            if (_s[_pos] == '\r')
                _pos++;
            if (_pos < _len && _s[_pos] == '\n')
                _pos++;
        } else {
            return NO;
        }
    }
    NSString *key = RVMNormalizeLabel(label);
    if (!_references->table[key])
        _references->table[key] = @[RVMCleanURL(urlChunk), RVMCleanTitle(title)];
    *consumed = _pos;
    return YES;
}

#pragma mark autolink extension

- (NSUInteger)checkDomain:(const unichar *)data size:(NSUInteger)size allowShort:(BOOL)allowShort
{
    NSUInteger i, np = 0, underscore1 = 0, underscore2 = 0;
    for (i = 1; i + 1 < size; i++) {
        if (data[i] == '\\' && i + 2 < size)
            i++;
        if (data[i] == '_') {
            underscore2++;
        } else if (data[i] == '.') {
            underscore1 = underscore2;
            underscore2 = 0;
            np++;
        } else if (!RVMIsAlnum(data[i]) && data[i] != '-') {
            break;
        }
    }
    if (underscore1 > 0 || underscore2 > 0)
        return 0;
    if (allowShort)
        return i;
    return np ? i : 0;
}

- (NSUInteger)autolinkDelimiter:(const unichar *)data end:(NSUInteger)linkEnd
{
    for (NSUInteger i = 0; i < linkEnd; i++) {
        if (data[i] == '<') {
            linkEnd = i;
            break;
        }
    }
    while (linkEnd > 0) {
        unichar close = data[linkEnd - 1];
        unichar open = close == ')' ? '(' : 0;
        if (close < 128 && strchr("?!.,:*_~'\"", (int)close) != NULL && close != 0) {
            linkEnd--;
        } else if (close == ';') {
            NSUInteger newEnd = linkEnd >= 2 ? linkEnd - 2 : 0;
            while (newEnd > 0 && RVMIsAlpha(data[newEnd]))
                newEnd--;
            if (newEnd + 2 < linkEnd && data[newEnd] == '&')
                linkEnd = newEnd;
            else
                linkEnd--;
        } else if (open != 0) {
            NSUInteger closing = 0, opening = 0;
            for (NSUInteger i = 0; i < linkEnd; i++) {
                if (data[i] == open)
                    opening++;
                else if (data[i] == close)
                    closing++;
            }
            if (closing <= opening)
                break;
            linkEnd--;
        } else {
            break;
        }
    }
    return linkEnd;
}

- (RevenantMarkdownNode *)linkNodeText:(NSString *)text url:(NSString *)url
{
    RevenantMarkdownNode *link = RVMNew(_pool, RevenantMarkdownLink);
    link->destination = url;
    link->title = @"";
    RVMAppend(link, [self textNode:text]);
    return link;
}

- (BOOL)inBracket
{
    for (RVMBracket *bracket = _lastBracket; bracket; bracket = bracket->previous)
        if (!bracket->caret)
            return YES;
    return NO;
}

- (BOOL)isSafeScheme:(const unichar *)data size:(NSUInteger)size
{
    static const char *const schemes[] = {"http://", "https://", "ftp://"};
    for (int k = 0; k < 3; k++) {
        const char *scheme = schemes[k];
        size_t length = strlen(scheme);
        if (size <= length)
            continue;
        BOOL same = YES;
        for (size_t j = 0; j < length; j++) {
            if (RVMLower(data[j]) != (unichar)scheme[j]) {
                same = NO;
                break;
            }
        }
        if (!same)
            continue;
        uint32_t first = data[length];
        if (first >= 0xD800 && first <= 0xDBFF && size > length + 1 && data[length + 1] >= 0xDC00 && data[length + 1] <= 0xDFFF)
            first = 0x10000 + ((first - 0xD800) << 10) + ((uint32_t)data[length + 1] - 0xDC00);
        if (first < 128)
            return RVMIsAlnum((unichar)first);
        return !RVMIsUnicodeSpace(first) && !RVMIsUnicodePunctuation(first);
    }
    return NO;
}

- (void)unput:(NSUInteger)count from:(RevenantMarkdownNode *)parent
{
    RevenantMarkdownNode *node = parent->lastChild;
    while (count > 0 && node && node->kind == RevenantMarkdownText) {
        NSUInteger length = node->literal.length;
        if (length <= count) {
            count -= length;
            node->literal = @"";
        } else {
            node->literal = [node->literal substringToIndex:length - count];
            count = 0;
        }
        node = node->previous;
    }
}

- (RevenantMarkdownNode *)matchURLIn:(RevenantMarkdownNode *)parent
{
    const unichar *data = _s + _pos;
    NSUInteger size = _len - _pos;
    NSUInteger maxRewind = _pos;
    if (size < 4 || data[1] != '/' || data[2] != '/')
        return nil;
    NSUInteger rewind = 0;
    while (rewind < maxRewind && RVMIsAlpha(data[-(NSInteger)rewind - 1]))
        rewind++;
    if (![self isSafeScheme:data - rewind size:size + rewind])
        return nil;
    NSUInteger linkEnd = 3;
    NSUInteger domain = [self checkDomain:data + linkEnd size:size - linkEnd allowShort:YES];
    if (domain == 0)
        return nil;
    linkEnd += domain;
    while (linkEnd < size && !RVMIsSpace(data[linkEnd]) && data[linkEnd] != '<')
        linkEnd++;
    linkEnd = [self autolinkDelimiter:data end:linkEnd];
    if (linkEnd == 0)
        return nil;
    NSString *text = RVMString(_s, maxRewind - rewind, maxRewind + linkEnd);
    _pos = maxRewind + linkEnd;
    [self unput:rewind from:parent];
    return [self linkNodeText:text url:text];
}

- (RevenantMarkdownNode *)matchWWWIn:(RevenantMarkdownNode *)parent
{
    const unichar *data = _s + _pos;
    NSUInteger size = _len - _pos;
    NSUInteger maxRewind = _pos;
    if (maxRewind > 0) {
        unichar before = data[-1];
        if (!(before == '*' || before == '_' || before == '~' || before == '(') && !RVMIsSpace(before))
            return nil;
    }
    if (size < 4 || data[0] != 'w' || data[1] != 'w' || data[2] != 'w' || data[3] != '.')
        return nil;
    NSUInteger linkEnd = [self checkDomain:data size:size allowShort:NO];
    if (linkEnd == 0)
        return nil;
    while (linkEnd < size && !RVMIsSpace(data[linkEnd]) && data[linkEnd] != '<')
        linkEnd++;
    linkEnd = [self autolinkDelimiter:data end:linkEnd];
    if (linkEnd == 0)
        return nil;
    NSString *text = RVMString(_s, maxRewind, maxRewind + linkEnd);
    _pos = maxRewind + linkEnd;
    return [self linkNodeText:text url:[@"http://" stringByAppendingString:text]];
}

static BOOL RVMProtocolEndsAt(const unichar *base, NSUInteger colon, const char *protocol)
{
    NSUInteger length = strlen(protocol);
    if (colon + 1 < length)
        return NO;
    NSUInteger start = colon + 1 - length;
    for (NSUInteger j = 0; j < length; j++)
        if (base[start + j] != (unichar)protocol[j])
            return NO;
    return start == 0 || !RVMIsAlnum(base[start - 1]);
}

- (void)autolinkEmailsInText:(RevenantMarkdownNode *)text
{
    NSUInteger offset = 0;
    NSUInteger np = 0;
    NSUInteger regionEnd = 0;
    BOOL withProtocol = NO, xmpp = NO;
    while (text) {
        NSString *literal = text->literal;
        NSUInteger size = literal.length;
        if (offset >= size)
            return;
        unichar *all = (unichar *)malloc((size + 1) * sizeof(unichar));
        [literal getCharacters:all range:NSMakeRange(0, size)];
        const unichar *base = all + offset;
        NSUInteger remaining = size - offset;
        NSUInteger at = 0;
        while (at < remaining && base[at] != '@')
            at++;
        if (at >= remaining) {
            free(all);
            return;
        }
        NSUInteger absolute = offset + at;
        NSUInteger window = offset;
        if (absolute >= regionEnd) {
            np = 0;
            withProtocol = NO;
            xmpp = NO;
            if (regionEnd > window)
                window = regionEnd;
        }
        base = all + window;
        const unichar *data = all + absolute;
        NSUInteger dataSize = size - absolute;
        NSUInteger maxRewind = absolute - window;
        NSUInteger rewind = 0;
        for (; rewind < maxRewind; rewind++) {
            unichar c = data[-(NSInteger)rewind - 1];
            if (RVMIsAlnum(c) || c == '.' || c == '+' || c == '-' || c == '_')
                continue;
            if (c == ':') {
                NSUInteger colon = maxRewind - rewind - 1;
                if (RVMProtocolEndsAt(base, colon, "mailto:")) {
                    withProtocol = YES;
                    continue;
                }
                if (RVMProtocolEndsAt(base, colon, "xmpp:")) {
                    withProtocol = YES;
                    xmpp = YES;
                    continue;
                }
            }
            break;
        }
        BOOL matched = NO;
        NSUInteger linkEnd = 0, scanEnd = 0;
        if (rewind != 0) {
            NSUInteger nb = 0;
            for (linkEnd = 0; linkEnd < dataSize; linkEnd++) {
                unichar c = data[linkEnd];
                if (RVMIsAlnum(c))
                    continue;
                if (c == '@')
                    nb++;
                else if (c == '.' && linkEnd + 1 < dataSize && RVMIsAlnum(data[linkEnd + 1]))
                    np++;
                else if (!(c == '/' && xmpp) && c != '-' && c != '_')
                    break;
            }
            scanEnd = linkEnd;
            if (!(linkEnd < 2 || nb != 1 || np == 0 || (!RVMIsAlpha(data[linkEnd - 1]) && data[linkEnd - 1] != '.'))) {
                linkEnd = [self autolinkDelimiter:data end:linkEnd];
                matched = linkEnd != 0;
            }
        }
        if (!matched) {
            regionEnd = absolute + scanEnd;
            offset += at + 1;
            free(all);
            continue;
        }
        NSString *address = RVMString(all, absolute - rewind, absolute + linkEnd);
        NSString *head = [literal substringToIndex:absolute - rewind];
        NSString *tail = [literal substringFromIndex:absolute + linkEnd];
        free(all);
        NSString *destination = withProtocol ? address : [@"mailto:" stringByAppendingString:address];
        np = 0;
        withProtocol = NO;
        xmpp = NO;
        regionEnd = 0;
        RevenantMarkdownNode *link = [self linkNodeText:address url:destination];
        text->literal = head;
        RVMInsertAfter(text, link);
        if (!tail.length)
            return;
        RevenantMarkdownNode *rest = [self textNode:tail];
        RVMInsertAfter(link, rest);
        text = rest;
        offset = 0;
    }
}

- (void)autolinkEmailsIn:(RevenantMarkdownNode *)node
{
    RevenantMarkdownNode *child = node->firstChild;
    while (child) {
        RevenantMarkdownNode *following = child->next;
        if (child->kind == RevenantMarkdownText)
            [self autolinkEmailsInText:child];
        else if (child->kind != RevenantMarkdownLink && child->firstChild)
            [self autolinkEmailsIn:child];
        child = following;
    }
}

- (RevenantMarkdownNode *)handleAutolink:(unichar)c parent:(RevenantMarkdownNode *)parent
{
    if ([self inBracket])
        return nil;
    if (c == ':')
        return [self matchURLIn:parent];
    return [self matchWWWIn:parent];
}

@end

#pragma mark - table rows

typedef struct {
    NSMutableArray *cells;
    NSUInteger paragraphOffset;
} RVMTableRow;

static NSUInteger RVMTableCellEnd(const unichar *s, NSUInteger len, NSUInteger offset)
{
    if (offset >= len || s[offset] != '|')
        return 0;
    NSUInteger i = offset + 1;
    while (i < len && (s[i] == ' ' || s[i] == '\t' || s[i] == '\v' || s[i] == '\f'))
        i++;
    return i - offset;
}

static NSUInteger RVMTableCell(const unichar *s, NSUInteger len, NSUInteger offset)
{
    NSUInteger i = offset;
    while (i < len) {
        unichar c = s[i];
        if (c == '\\' && i + 1 < len && RVMIsPunct(s[i + 1])) {
            i += 2;
        } else if (c != 0 && c != '|' && c != '\r' && c != '\n') {
            i++;
        } else {
            break;
        }
    }
    return i - offset;
}

static NSUInteger RVMTableRowEnd(const unichar *s, NSUInteger len, NSUInteger offset)
{
    NSUInteger i = offset;
    while (i < len && (s[i] == ' ' || s[i] == '\t' || s[i] == '\v' || s[i] == '\f'))
        i++;
    if (i < len && s[i] == '\r')
        i++;
    if (i < len && s[i] == '\n')
        i++;
    else if (i == offset || (i > offset && s[i - 1] != '\r' && s[i - 1] != '\n'))
        return 0;
    return i - offset;
}

static NSString *RVMUnescapePipes(const unichar *s, NSUInteger from, NSUInteger count)
{
    NSMutableString *out = [NSMutableString stringWithCapacity:count];
    for (NSUInteger r = 0; r < count; r++) {
        unichar c = s[from + r];
        if (c == '\\' && r + 1 < count && s[from + r + 1] == '|') {
            r++;
            c = '|';
        }
        [out appendString:[NSString stringWithCharacters:&c length:1]];
    }
    return RVMTrimmed(out);
}

static BOOL RVMTableRowFromString(const unichar *s, NSUInteger len, RVMTableRow *row)
{
    row->cells = [NSMutableArray array];
    row->paragraphOffset = 0;
    BOOL expectMore = YES;
    NSUInteger offset = RVMTableCellEnd(s, len, 0);
    while (offset < len && expectMore) {
        NSUInteger cellMatched = RVMTableCell(s, len, offset);
        NSUInteger pipeMatched = RVMTableCellEnd(s, len, offset + cellMatched);
        if (cellMatched || pipeMatched)
            [row->cells addObject:RVMUnescapePipes(s, offset, cellMatched)];
        offset += cellMatched + pipeMatched;
        if (pipeMatched) {
            expectMore = YES;
        } else {
            NSUInteger rowEnd = RVMTableRowEnd(s, len, offset);
            offset += rowEnd;
            if (rowEnd && offset != len) {
                row->paragraphOffset = offset;
                [row->cells removeAllObjects];
                offset += RVMTableCellEnd(s, len, offset);
                expectMore = YES;
            } else {
                expectMore = NO;
            }
        }
    }
    if (offset != len || row->cells.count == 0) {
        row->cells = nil;
        return NO;
    }
    return YES;
}

static BOOL RVMScanTableStart(NSString *line, NSInteger from)
{
    NSUInteger n = line.length;
    NSUInteger i = (NSUInteger)from;
    if (i < n && [line characterAtIndex:i] == '|')
        i++;
    BOOL first = YES;
    while (YES) {
        while (i < n && RVMIsSpaceOrTab([line characterAtIndex:i]))
            i++;
        if (i < n && [line characterAtIndex:i] == ':')
            i++;
        NSUInteger dashes = 0;
        while (i < n && [line characterAtIndex:i] == '-') {
            i++;
            dashes++;
        }
        if (!dashes)
            return NO;
        if (i < n && [line characterAtIndex:i] == ':')
            i++;
        while (i < n && RVMIsSpaceOrTab([line characterAtIndex:i]))
            i++;
        first = NO;
        if (i < n && [line characterAtIndex:i] == '|') {
            NSUInteger save = i;
            i++;
            NSUInteger look = i;
            while (look < n && RVMIsSpaceOrTab([line characterAtIndex:look]))
                look++;
            if (look >= n)
                return YES;
            (void)save;
            continue;
        }
        break;
    }
    (void)first;
    return i >= n;
}

#pragma mark - block parser

@interface RVMBlockParser : NSObject {
    NSMutableArray *_pool;
    RVMReferences *_references;
    RevenantMarkdownNode *_root;
    RevenantMarkdownNode *_current;
    NSString *_line;
    NSInteger _lineNumber;
    NSInteger _offset;
    NSInteger _column;
    NSInteger _firstNonspace;
    NSInteger _firstNonspaceColumn;
    NSInteger _indent;
    BOOL _blank;
    BOOL _partiallyConsumedTab;
}
- (instancetype)initWithPool:(NSMutableArray *)pool references:(RVMReferences *)references;
- (RevenantMarkdownNode *)parse:(NSString *)source;
@end

static BOOL RVMCanContain(RevenantMarkdownNode *parent, RevenantMarkdownKind child)
{
    switch (parent->kind) {
    case RevenantMarkdownDocument:
    case RevenantMarkdownBlockQuote:
    case RevenantMarkdownItem:
        return child != RevenantMarkdownItem && child != RevenantMarkdownTableRow && child != RevenantMarkdownTableCell;
    case RevenantMarkdownList:
        return child == RevenantMarkdownItem;
    case RevenantMarkdownTable:
        return child == RevenantMarkdownTableRow;
    case RevenantMarkdownTableRow:
        return child == RevenantMarkdownTableCell;
    default:
        return NO;
    }
}

static BOOL RVMAcceptsLines(RevenantMarkdownKind kind)
{
    return kind == RevenantMarkdownParagraph || kind == RevenantMarkdownHeading || kind == RevenantMarkdownCodeBlock || kind == RevenantMarkdownHTMLBlock;
}

static NSString *const RVMBlockTags[] = {
    @"address", @"article", @"aside", @"base", @"basefont", @"blockquote", @"body", @"caption", @"center", @"col", @"colgroup",
    @"dd", @"details", @"dialog", @"dir", @"div", @"dl", @"dt", @"fieldset", @"figcaption", @"figure", @"footer", @"form",
    @"frame", @"frameset", @"h1", @"h2", @"h3", @"h4", @"h5", @"h6", @"head", @"header", @"hr", @"html", @"iframe", @"legend",
    @"li", @"link", @"main", @"menu", @"menuitem", @"nav", @"noframes", @"ol", @"optgroup", @"option", @"p", @"param",
    @"section", @"source", @"summary", @"table", @"tbody", @"td", @"tfoot", @"th", @"thead", @"title", @"tr", @"track", @"ul",
};

static BOOL RVMHasPrefixCI(const unichar *s, NSUInteger n, const char *prefix)
{
    size_t length = strlen(prefix);
    if (n < length)
        return NO;
    for (size_t i = 0; i < length; i++)
        if (RVMLower(s[i]) != (unichar)prefix[i])
            return NO;
    return YES;
}

static NSInteger RVMHTMLBlockStart(NSString *line, NSInteger from, BOOL allowSeven)
{
    NSUInteger n = line.length;
    if ((NSUInteger)from >= n)
        return 0;
    unichar *s = (unichar *)malloc((n + 1) * sizeof(unichar));
    [line getCharacters:s range:NSMakeRange(0, n)];
    const unichar *t = s + from;
    NSUInteger m = n - (NSUInteger)from;
    NSInteger type = 0;
    if (t[0] == '<') {
        const char *firsts[] = {"<script", "<pre", "<style"};
        for (int k = 0; k < 3 && !type; k++) {
            size_t length = strlen(firsts[k]);
            if (RVMHasPrefixCI(t, m, firsts[k])) {
                unichar after = m > length ? t[length] : '\n';
                if (after == ' ' || after == '\t' || after == '\v' || after == '\f' || after == '>' || after == '\n' || after == '\r' || m == length)
                    type = 1;
            }
        }
        if (!type && m >= 4 && t[1] == '!' && t[2] == '-' && t[3] == '-')
            type = 2;
        if (!type && m >= 2 && t[1] == '?')
            type = 3;
        if (!type && m >= 3 && t[1] == '!' && t[2] >= 'A' && t[2] <= 'Z')
            type = 4;
        if (!type && m >= 9 && t[1] == '!' && t[2] == '[' && t[3] == 'C' && t[4] == 'D' && t[5] == 'A' && t[6] == 'T' && t[7] == 'A' && t[8] == '[')
            type = 5;
        if (!type) {
            NSUInteger i = 1;
            if (i < m && t[i] == '/')
                i++;
            NSUInteger nameStart = i;
            while (i < m && RVMIsAlnum(t[i]))
                i++;
            if (i > nameStart) {
                NSString *name = [[NSString stringWithCharacters:t + nameStart length:i - nameStart] lowercaseString];
                BOOL known = NO;
                for (size_t k = 0; k < sizeof(RVMBlockTags) / sizeof(RVMBlockTags[0]); k++) {
                    if ([RVMBlockTags[k] isEqualToString:name]) {
                        known = YES;
                        break;
                    }
                }
                if (known) {
                    if (i >= m || t[i] == ' ' || t[i] == '\t' || t[i] == '\v' || t[i] == '\f' || t[i] == '>' || (t[i] == '/' && i + 1 < m && t[i + 1] == '>'))
                        type = 6;
                }
            }
        }
        if (!type && allowSeven) {
            NSUInteger end = 0;
            if (RVMScanOpenTag(t, m, 1, &end) || RVMScanCloseTag(t, m, 1, &end)) {
                NSUInteger k = end;
                while (k < m && (t[k] == ' ' || t[k] == '\t' || t[k] == '\v' || t[k] == '\f'))
                    k++;
                if (k >= m)
                    type = 7;
            }
        }
    }
    free(s);
    return type;
}

static BOOL RVMContainsCI(NSString *haystack, const char *needle)
{
    NSUInteger length = strlen(needle), size = haystack.length;
    if (length > size)
        return NO;
    for (NSUInteger i = 0; i + length <= size; i++) {
        NSUInteger j = 0;
        for (; j < length; j++) {
            unichar c = [haystack characterAtIndex:i + j];
            if (c >= 'A' && c <= 'Z')
                c += 32;
            if (c != (unichar)needle[j])
                break;
        }
        if (j == length)
            return YES;
    }
    return NO;
}

static BOOL RVMHTMLBlockEnds(NSInteger type, NSString *line, NSInteger from)
{
    if ((NSUInteger)from > line.length)
        return NO;
    NSString *rest = [line substringFromIndex:(NSUInteger)from];
    switch (type) {
    case 1:
        return RVMContainsCI(rest, "</script>") || RVMContainsCI(rest, "</pre>") || RVMContainsCI(rest, "</style>");
    case 2:
        return RVMContainsCI(rest, "-->");
    case 3:
        return RVMContainsCI(rest, "?>");
    case 4:
        return RVMContainsCI(rest, ">");
    case 5:
        return RVMContainsCI(rest, "]]>");
    default:
        return NO;
    }
}

@implementation RVMBlockParser

- (instancetype)initWithPool:(NSMutableArray *)pool references:(RVMReferences *)references
{
    self = [super init];
    if (!self)
        return nil;
    _pool = pool;
    _references = references;
    return self;
}

- (void)findFirstNonspace
{
    _firstNonspace = _offset;
    _firstNonspaceColumn = _column;
    NSInteger charsToTab = RVMTabStop - (_column % RVMTabStop);
    unichar c;
    while ((c = RVMPeek(_line, _firstNonspace))) {
        if (c == ' ') {
            _firstNonspace++;
            _firstNonspaceColumn++;
            charsToTab--;
            if (charsToTab == 0)
                charsToTab = RVMTabStop;
        } else if (c == '\t') {
            _firstNonspace++;
            _firstNonspaceColumn += charsToTab;
            charsToTab = RVMTabStop;
        } else {
            break;
        }
    }
    _indent = _firstNonspaceColumn - _column;
    _blank = RVMIsLineEnd(RVMPeek(_line, _firstNonspace));
}

- (void)advance:(NSInteger)count columns:(BOOL)columns
{
    unichar c;
    while (count > 0 && (c = RVMPeek(_line, _offset))) {
        if (c == '\t') {
            NSInteger charsToTab = RVMTabStop - (_column % RVMTabStop);
            if (columns) {
                _partiallyConsumedTab = charsToTab > count;
                NSInteger charsToAdvance = charsToTab > count ? count : charsToTab;
                _column += charsToAdvance;
                _offset += _partiallyConsumedTab ? 0 : 1;
                count -= charsToAdvance;
            } else {
                _partiallyConsumedTab = NO;
                _column += charsToTab;
                _offset += 1;
                count -= 1;
            }
        } else {
            _partiallyConsumedTab = NO;
            _offset += 1;
            _column += 1;
            count -= 1;
        }
    }
}

- (void)addLineTo:(RevenantMarkdownNode *)node
{
    if (_partiallyConsumedTab) {
        _offset += 1;
        NSInteger charsToTab = RVMTabStop - (_column % RVMTabStop);
        for (NSInteger i = 0; i < charsToTab; i++)
            [node->content appendString:@" "];
    }
    if ((NSUInteger)_offset < _line.length)
        [node->content appendString:[_line substringFromIndex:(NSUInteger)_offset]];
    [node->content appendString:@"\n"];
}

- (BOOL)resolveReferencesIn:(RevenantMarkdownNode *)block
{
    NSString *text = block->content;
    RVMInlineParser *inlines = [[RVMInlineParser alloc] initWithPool:_pool references:_references inlineOnly:NO];
    while (RVMStartsReference(text)) {
        NSUInteger used = 0;
        if (![inlines parseReferenceIn:text consumed:&used] || used == 0)
            break;
        text = [text substringFromIndex:used];
    }
    block->content = [text mutableCopy];
    return !RVMIsBlank(block->content);
}

- (RevenantMarkdownNode *)finalize:(RevenantMarkdownNode *)block
{
    RevenantMarkdownNode *parent = block->parent;
    block->open = NO;
    switch (block->kind) {
    case RevenantMarkdownParagraph:
        if (![self resolveReferencesIn:block])
            RVMUnlink(block);
        break;
    case RevenantMarkdownCodeBlock: {
        NSString *text = block->content;
        if (!block->fenced) {
            NSMutableString *trimmed = [text mutableCopy];
            NSInteger last = (NSInteger)trimmed.length - 1;
            while (last >= 0) {
                unichar c = [trimmed characterAtIndex:(NSUInteger)last];
                if (c != ' ' && c != '\t' && !RVMIsLineEnd(c))
                    break;
                last--;
            }
            if (last < 0) {
                [trimmed setString:@""];
            } else {
                NSRange newline = [trimmed rangeOfString:@"\n" options:NSLiteralSearch range:NSMakeRange((NSUInteger)last, trimmed.length - (NSUInteger)last)];
                if (newline.location != NSNotFound)
                    [trimmed deleteCharactersInRange:NSMakeRange(newline.location, trimmed.length - newline.location)];
            }
            [trimmed appendString:@"\n"];
            block->literal = trimmed;
        } else {
            NSUInteger pos = 0;
            while (pos < text.length && !RVMIsLineEnd([text characterAtIndex:pos]))
                pos++;
            NSString *firstLine = [text substringToIndex:pos];
            block->info = RVMTrimmed(RVMUnescapeBackslashes(RVMUnescapeEntities(RVMTrimmed(firstLine))));
            if (pos < text.length && [text characterAtIndex:pos] == '\r')
                pos++;
            if (pos < text.length && [text characterAtIndex:pos] == '\n')
                pos++;
            block->literal = [text substringFromIndex:pos];
        }
        break;
    }
    case RevenantMarkdownHTMLBlock:
        block->literal = [block->content copy];
        break;
    default:
        break;
    }
    return parent;
}

- (RevenantMarkdownNode *)addChild:(RevenantMarkdownKind)kind under:(RevenantMarkdownNode *)parent
{
    while (!RVMCanContain(parent, kind))
        parent = [self finalize:parent];
    RevenantMarkdownNode *child = RVMNew(_pool, kind);
    child->open = YES;
    child->line = _lineNumber;
    child->content = [NSMutableString string];
    RVMAppend(parent, child);
    return child;
}

- (BOOL)lastChildIsOpen:(RevenantMarkdownNode *)node
{
    return node->lastChild && node->lastChild->open;
}

- (BOOL)tableRowMatchesLine
{
    NSString *rest = [_line substringFromIndex:MIN((NSUInteger)_firstNonspace, _line.length)];
    NSString *withNewline = [rest stringByAppendingString:@"\n"];
    NSUInteger n = withNewline.length;
    unichar *s = (unichar *)malloc((n + 1) * sizeof(unichar));
    [withNewline getCharacters:s range:NSMakeRange(0, n)];
    RVMTableRow row;
    BOOL ok = RVMTableRowFromString(s, n, &row) && row.cells.count > 0;
    free(s);
    return ok;
}

- (BOOL)blockQuotePrefix
{
    if (_indent <= 3 && RVMPeek(_line, _firstNonspace) == '>') {
        [self advance:_firstNonspace + 1 - _offset columns:NO];
        if (RVMIsSpaceOrTab(RVMPeek(_line, _offset)))
            [self advance:1 columns:YES];
        return YES;
    }
    return NO;
}

- (BOOL)itemPrefix:(RevenantMarkdownNode *)container
{
    if (_indent >= container->markerOffset + container->padding) {
        [self advance:container->markerOffset + container->padding columns:YES];
        return YES;
    }
    if (_blank && container->firstChild) {
        [self advance:_firstNonspace - _offset columns:NO];
        return YES;
    }
    return NO;
}

- (NSInteger)closeFenceLength
{
    return 0;
}

- (BOOL)codeBlockPrefix:(RevenantMarkdownNode *)container shouldContinue:(BOOL *)shouldContinue
{
    if (!container->fenced) {
        if (_indent >= RVMCodeIndent) {
            [self advance:RVMCodeIndent columns:YES];
            return YES;
        }
        if (_blank) {
            [self advance:_firstNonspace - _offset columns:NO];
            return YES;
        }
        return NO;
    }
    NSInteger matched = 0;
    if (_indent <= 3 && RVMPeek(_line, _firstNonspace) == container->fenceChar) {
        NSInteger i = _firstNonspace;
        while (RVMPeek(_line, i) == container->fenceChar)
            i++;
        NSInteger run = i - _firstNonspace;
        while (RVMIsSpaceOrTab(RVMPeek(_line, i)))
            i++;
        if (run >= 3 && RVMIsLineEnd(RVMPeek(_line, i)))
            matched = run;
    }
    if (matched >= container->fenceLength) {
        *shouldContinue = NO;
        [self advance:matched columns:NO];
        _current = [self finalize:container];
        return NO;
    }
    NSInteger i = container->fenceOffset;
    while (i > 0 && RVMIsSpaceOrTab(RVMPeek(_line, _offset))) {
        [self advance:1 columns:YES];
        i--;
    }
    return YES;
}

- (BOOL)htmlBlockPrefix:(RevenantMarkdownNode *)container
{
    if (container->htmlType >= 1 && container->htmlType <= 5)
        return YES;
    return !_blank;
}

- (RevenantMarkdownNode *)checkOpenBlocks:(BOOL *)allMatched shouldContinue:(BOOL *)shouldContinue
{
    *allMatched = NO;
    *shouldContinue = YES;
    RevenantMarkdownNode *container = _root;
    while ([self lastChildIsOpen:container]) {
        container = container->lastChild;
        [self findFirstNonspace];
        BOOL matched = YES;
        switch (container->kind) {
        case RevenantMarkdownBlockQuote:
            matched = [self blockQuotePrefix];
            break;
        case RevenantMarkdownItem:
            matched = [self itemPrefix:container];
            break;
        case RevenantMarkdownCodeBlock:
            matched = [self codeBlockPrefix:container shouldContinue:shouldContinue];
            break;
        case RevenantMarkdownHeading:
            matched = NO;
            break;
        case RevenantMarkdownHTMLBlock:
            matched = [self htmlBlockPrefix:container];
            break;
        case RevenantMarkdownParagraph:
            matched = !_blank;
            break;
        case RevenantMarkdownTable:
            matched = [self tableRowMatchesLine];
            break;
        case RevenantMarkdownTableRow:
        case RevenantMarkdownTableCell:
            matched = NO;
            break;
        default:
            break;
        }
        if (!matched) {
            container = container->parent;
            if (!*shouldContinue)
                return nil;
            return container;
        }
    }
    *allMatched = YES;
    return *shouldContinue ? container : nil;
}

- (BOOL)thematicBreakAt:(NSInteger)offset
{
    unichar c = RVMPeek(_line, offset);
    if (c != '*' && c != '_' && c != '-')
        return NO;
    unichar mark = c;
    NSInteger count = 1, i = offset + 1;
    while ((c = RVMPeek(_line, i))) {
        if (c == mark)
            count++;
        else if (c != ' ' && c != '\t')
            break;
        i++;
    }
    return count >= 3 && RVMIsLineEnd(c);
}

- (NSInteger)atxHeadingLevelAt:(NSInteger)offset matched:(NSInteger *)matched
{
    NSInteger i = offset, level = 0;
    while (RVMPeek(_line, i) == '#' && level < 7) {
        level++;
        i++;
    }
    if (level < 1 || level > 6)
        return 0;
    unichar c = RVMPeek(_line, i);
    if (c == ' ' || c == '\t') {
        while (RVMIsSpaceOrTab(RVMPeek(_line, i)))
            i++;
    } else if (!RVMIsLineEnd(c)) {
        return 0;
    }
    *matched = i - offset;
    return level;
}

- (NSInteger)openFenceLengthAt:(NSInteger)offset fenceChar:(unichar *)fenceChar
{
    unichar c = RVMPeek(_line, offset);
    if (c != '`' && c != '~')
        return 0;
    NSInteger i = offset;
    while (RVMPeek(_line, i) == c)
        i++;
    NSInteger run = i - offset;
    if (run < 3)
        return 0;
    if (c == '`') {
        for (NSInteger k = i; (NSUInteger)k < _line.length; k++)
            if ([_line characterAtIndex:(NSUInteger)k] == '`')
                return 0;
    }
    *fenceChar = c;
    return run;
}

- (NSInteger)setextLevelAt:(NSInteger)offset
{
    unichar c = RVMPeek(_line, offset);
    if (c != '=' && c != '-')
        return 0;
    NSInteger i = offset;
    while (RVMPeek(_line, i) == c)
        i++;
    while (RVMIsSpaceOrTab(RVMPeek(_line, i)))
        i++;
    if (!RVMIsLineEnd(RVMPeek(_line, i)))
        return 0;
    return c == '=' ? 1 : 2;
}

- (BOOL)parseListMarkerAt:(NSInteger)offset interruptsParagraph:(BOOL)interrupts into:(RevenantMarkdownNode *)data matched:(NSInteger *)matched
{
    NSInteger pos = offset;
    unichar c = RVMPeek(_line, pos);
    if (c == '*' || c == '-' || c == '+') {
        pos++;
        if (!RVMIsSpace(RVMPeek(_line, pos)))
            return NO;
        if (interrupts) {
            NSInteger i = pos;
            while (RVMIsSpaceOrTab(RVMPeek(_line, i)))
                i++;
            if (RVMPeek(_line, i) == '\n')
                return NO;
        }
        data->ordered = NO;
        data->marker = c;
        data->start = 0;
    } else if (RVMIsDigit(c)) {
        NSInteger start = 0, digits = 0;
        do {
            start = start * 10 + (RVMPeek(_line, pos) - '0');
            pos++;
            digits++;
        } while (digits < 9 && RVMIsDigit(RVMPeek(_line, pos)));
        if (interrupts && start != 1)
            return NO;
        c = RVMPeek(_line, pos);
        if (c != '.' && c != ')')
            return NO;
        pos++;
        if (!RVMIsSpace(RVMPeek(_line, pos)))
            return NO;
        if (interrupts) {
            NSInteger i = pos;
            while (RVMIsSpaceOrTab(RVMPeek(_line, i)))
                i++;
            if (RVMIsLineEnd(RVMPeek(_line, i)))
                return NO;
        }
        data->ordered = YES;
        data->marker = c;
        data->start = start;
    } else {
        return NO;
    }
    *matched = pos - offset;
    return YES;
}

- (void)openNewBlocks:(RevenantMarkdownNode **)containerRef allMatched:(BOOL)allMatched
{
    RevenantMarkdownNode *container = *containerRef;
    BOOL maybeLazy = _current->kind == RevenantMarkdownParagraph;
    RevenantMarkdownKind containerKind = container->kind;
    while (containerKind != RevenantMarkdownCodeBlock && containerKind != RevenantMarkdownHTMLBlock) {
        [self findFirstNonspace];
        BOOL indented = _indent >= RVMCodeIndent;
        NSInteger matched = 0, level = 0;
        unichar fenceChar = 0;
        if (!indented && RVMPeek(_line, _firstNonspace) == '>') {
            NSInteger quoteStart = _firstNonspace;
            [self advance:_firstNonspace + 1 - _offset columns:NO];
            if (RVMIsSpaceOrTab(RVMPeek(_line, _offset)))
                [self advance:1 columns:YES];
            container = [self addChild:RevenantMarkdownBlockQuote under:container];
            (void)quoteStart;
        } else if (!indented && (level = [self atxHeadingLevelAt:_firstNonspace matched:&matched]) > 0) {
            [self advance:_firstNonspace + matched - _offset columns:NO];
            container = [self addChild:RevenantMarkdownHeading under:container];
            container->level = level;
        } else if (!indented && (matched = [self openFenceLengthAt:_firstNonspace fenceChar:&fenceChar]) > 0) {
            container = [self addChild:RevenantMarkdownCodeBlock under:container];
            container->fenced = YES;
            container->fenceChar = fenceChar;
            container->fenceLength = matched;
            container->fenceOffset = _firstNonspace - _offset;
            [self advance:_firstNonspace + matched - _offset columns:NO];
        } else if (!indented && ((matched = RVMHTMLBlockStart(_line, _firstNonspace, NO)) > 0
                                 || (containerKind != RevenantMarkdownParagraph && (matched = RVMHTMLBlockStart(_line, _firstNonspace, YES)) > 0))) {
            container = [self addChild:RevenantMarkdownHTMLBlock under:container];
            container->htmlType = matched;
        } else if (!indented && containerKind == RevenantMarkdownParagraph && (level = [self setextLevelAt:_firstNonspace]) > 0) {
            BOOL hasContent = [self resolveReferencesIn:container];
            if (hasContent) {
                container->kind = RevenantMarkdownHeading;
                container->level = level;
                [self advance:(NSInteger)_line.length + 1 - _offset - 1 columns:NO];
            }
        } else if (!indented && !(containerKind == RevenantMarkdownParagraph && !allMatched) && [self thematicBreakAt:_firstNonspace]) {
            container = [self addChild:RevenantMarkdownThematicBreak under:container];
            [self advance:(NSInteger)_line.length + 1 - _offset - 1 columns:NO];
        } else if ((!indented || containerKind == RevenantMarkdownList) && _indent < 4 && ({
                       RevenantMarkdownNode *probe = RVMNew(_pool, RevenantMarkdownItem);
                       BOOL ok = [self parseListMarkerAt:_firstNonspace interruptsParagraph:container->kind == RevenantMarkdownParagraph into:probe matched:&matched];
                       if (ok) {
                           container = [self openListItem:probe matched:matched under:container];
                       }
                       ok;
                   })) {
        } else if (indented && !maybeLazy && !_blank) {
            [self advance:RVMCodeIndent columns:YES];
            container = [self addChild:RevenantMarkdownCodeBlock under:container];
            container->fenced = NO;
        } else {
            RevenantMarkdownNode *opened = nil;
            if (!indented && containerKind == RevenantMarkdownParagraph) {
                opened = [self tryOpenTableHeader:container];
            } else if (!indented && containerKind == RevenantMarkdownTable) {
                opened = [self tryOpenTableRow:container];
            }
            if (!opened)
                break;
            container = opened;
        }
        if (RVMAcceptsLines(container->kind))
            break;
        containerKind = container->kind;
        maybeLazy = NO;
    }
    *containerRef = container;
}

- (RevenantMarkdownNode *)openListItem:(RevenantMarkdownNode *)data matched:(NSInteger)matched under:(RevenantMarkdownNode *)container
{
    [self advance:_firstNonspace + matched - _offset columns:NO];
    BOOL savedTab = _partiallyConsumedTab;
    NSInteger savedOffset = _offset, savedColumn = _column;
    while (_column - savedColumn <= 5 && RVMIsSpaceOrTab(RVMPeek(_line, _offset)))
        [self advance:1 columns:YES];
    NSInteger spaces = _column - savedColumn;
    if (spaces >= 5 || spaces < 1 || RVMIsLineEnd(RVMPeek(_line, _offset))) {
        data->padding = matched + 1;
        _offset = savedOffset;
        _column = savedColumn;
        _partiallyConsumedTab = savedTab;
        if (spaces > 0)
            [self advance:1 columns:YES];
    } else {
        data->padding = matched + spaces;
    }
    data->markerOffset = _indent;
    BOOL listMatches = container->kind == RevenantMarkdownList && container->ordered == data->ordered && container->marker == data->marker;
    if (!listMatches) {
        RevenantMarkdownNode *list = [self addChild:RevenantMarkdownList under:container];
        list->ordered = data->ordered;
        list->marker = data->marker;
        list->start = data->start;
        container = list;
    }
    RevenantMarkdownNode *item = [self addChild:RevenantMarkdownItem under:container];
    item->ordered = data->ordered;
    item->marker = data->marker;
    item->start = data->start;
    item->padding = data->padding;
    item->markerOffset = data->markerOffset;
    return item;
}

- (RevenantMarkdownNode *)tryOpenTableHeader:(RevenantMarkdownNode *)paragraph
{
    if (paragraph->tableFailed || !RVMScanTableStart(_line, _firstNonspace))
        return nil;
    NSString *markerText = [[_line substringFromIndex:(NSUInteger)_firstNonspace] stringByAppendingString:@"\n"];
    NSUInteger markerLength = markerText.length;
    unichar *markerChars = (unichar *)malloc((markerLength + 1) * sizeof(unichar));
    [markerText getCharacters:markerChars range:NSMakeRange(0, markerLength)];
    RVMTableRow marker;
    BOOL markerOK = RVMTableRowFromString(markerChars, markerLength, &marker);
    free(markerChars);
    if (!markerOK) {
        paragraph->tableFailed = YES;
        return nil;
    }
    NSString *content = paragraph->content;
    NSUInteger length = content.length;
    unichar *chars = (unichar *)malloc((length + 1) * sizeof(unichar));
    [content getCharacters:chars range:NSMakeRange(0, length)];
    RVMTableRow header;
    BOOL headerOK = RVMTableRowFromString(chars, length, &header);
    free(chars);
    if (!headerOK || header.cells.count != marker.cells.count) {
        paragraph->tableFailed = YES;
        return nil;
    }
    NSMutableArray *alignments = [NSMutableArray array];
    for (NSString *cell in marker.cells) {
        BOOL left = cell.length && [cell characterAtIndex:0] == ':', right = cell.length && [cell characterAtIndex:cell.length - 1] == ':';
        [alignments addObject:@(left && right ? 1 : right ? 2 : 0)];
    }
    RevenantMarkdownNode *table;
    if (header.paragraphOffset > 0) {
        NSString *before = [content substringToIndex:header.paragraphOffset];
        RevenantMarkdownNode *leading = RVMNew(_pool, RevenantMarkdownParagraph);
        leading->content = [before mutableCopy];
        leading->line = paragraph->line;
        RVMInsertBefore(paragraph, leading);
        paragraph->kind = RevenantMarkdownTable;
        paragraph->content = [NSMutableString string];
        table = paragraph;
    } else {
        paragraph->kind = RevenantMarkdownTable;
        paragraph->content = [NSMutableString string];
        table = paragraph;
    }
    table->alignments = alignments;
    table->columnCount = (NSInteger)header.cells.count;
    RevenantMarkdownNode *row = [self addChild:RevenantMarkdownTableRow under:table];
    row->header = YES;
    for (NSUInteger i = 0; i < header.cells.count && i < (NSUInteger)table->columnCount; i++) {
        RevenantMarkdownNode *cell = [self addChild:RevenantMarkdownTableCell under:row];
        cell->content = [header.cells[i] mutableCopy];
        cell->open = NO;
    }
    row->open = NO;
    [self advance:(NSInteger)_line.length - _offset columns:NO];
    return table;
}

- (RevenantMarkdownNode *)tryOpenTableRow:(RevenantMarkdownNode *)table
{
    if (_blank)
        return nil;
    NSString *withNewline = [[_line substringFromIndex:MIN((NSUInteger)_firstNonspace, _line.length)] stringByAppendingString:@"\n"];
    NSUInteger n = withNewline.length;
    unichar *s = (unichar *)malloc((n + 1) * sizeof(unichar));
    [withNewline getCharacters:s range:NSMakeRange(0, n)];
    RVMTableRow parsed;
    BOOL ok = RVMTableRowFromString(s, n, &parsed);
    free(s);
    if (!ok)
        return nil;
    RevenantMarkdownNode *row = [self addChild:RevenantMarkdownTableRow under:table];
    NSUInteger i = 0;
    for (; i < parsed.cells.count && i < (NSUInteger)table->columnCount; i++) {
        RevenantMarkdownNode *cell = [self addChild:RevenantMarkdownTableCell under:row];
        cell->content = [parsed.cells[i] mutableCopy];
        cell->open = NO;
    }
    for (; i < (NSUInteger)table->columnCount; i++) {
        RevenantMarkdownNode *cell = [self addChild:RevenantMarkdownTableCell under:row];
        cell->content = [NSMutableString string];
        cell->open = NO;
    }
    [self advance:(NSInteger)_line.length - _offset columns:NO];
    row->open = YES;
    return row;
}

- (void)setLastLineBlank:(RevenantMarkdownNode *)node value:(BOOL)value
{
    node->lastLineBlank = value;
}

- (void)addTextToContainer:(RevenantMarkdownNode *)container lastMatched:(RevenantMarkdownNode *)lastMatched
{
    [self findFirstNonspace];
    if (_blank && container->lastChild)
        container->lastChild->lastLineBlank = YES;
    RevenantMarkdownKind kind = container->kind;
    container->lastLineBlank = _blank && kind != RevenantMarkdownBlockQuote && kind != RevenantMarkdownHeading && kind != RevenantMarkdownThematicBreak
        && !(kind == RevenantMarkdownCodeBlock && container->fenced)
        && !(kind == RevenantMarkdownItem && !container->firstChild && container->line == _lineNumber);
    for (RevenantMarkdownNode *up = container->parent; up; up = up->parent)
        up->lastLineBlank = NO;
    if (_current != lastMatched && container == lastMatched && !_blank && _current->kind == RevenantMarkdownParagraph) {
        [self addLineTo:_current];
        return;
    }
    while (_current != lastMatched)
        _current = [self finalize:_current];
    if (kind == RevenantMarkdownCodeBlock) {
        [self addLineTo:container];
    } else if (kind == RevenantMarkdownHTMLBlock) {
        [self addLineTo:container];
        if (container->htmlType >= 1 && container->htmlType <= 5 && RVMHTMLBlockEnds(container->htmlType, _line, _firstNonspace))
            container = [self finalize:container];
    } else if (_blank) {
    } else if (RVMAcceptsLines(kind)) {
        if (kind == RevenantMarkdownHeading && !container->fenced) {
            [self chopHeading:container];
        }
        [self advance:_firstNonspace - _offset columns:NO];
        [self addLineTo:container];
    } else {
        container = [self addChild:RevenantMarkdownParagraph under:container];
        [self advance:_firstNonspace - _offset columns:NO];
        [self addLineTo:container];
    }
    _current = container;
}

- (void)chopHeading:(RevenantMarkdownNode *)heading
{
    NSInteger from = _firstNonspace;
    NSString *rest = (NSUInteger)from < _line.length ? [_line substringFromIndex:(NSUInteger)from] : @"";
    NSMutableString *text = [rest mutableCopy];
    while (text.length && RVMIsSpace([text characterAtIndex:text.length - 1]))
        [text deleteCharactersInRange:NSMakeRange(text.length - 1, 1)];
    NSInteger n = (NSInteger)text.length - 1, original = n;
    while (n >= 0 && [text characterAtIndex:(NSUInteger)n] == '#')
        n--;
    if (n != original && n >= 0 && ([text characterAtIndex:(NSUInteger)n] == ' ' || [text characterAtIndex:(NSUInteger)n] == '\t')) {
        [text deleteCharactersInRange:NSMakeRange((NSUInteger)n, text.length - (NSUInteger)n)];
        while (text.length && RVMIsSpace([text characterAtIndex:text.length - 1]))
            [text deleteCharactersInRange:NSMakeRange(text.length - 1, 1)];
    } else if (n == -1 && original >= 0) {
        [text setString:@""];
    }
    [heading->content appendString:text];
    _offset = (NSInteger)_line.length;
    _partiallyConsumedTab = NO;
    heading->literal = @"atx";
}

- (void)incorporateLine:(NSString *)line
{
    _line = line;
    _lineNumber++;
    _offset = 0;
    _column = 0;
    _blank = NO;
    _partiallyConsumedTab = NO;
    BOOL allMatched, shouldContinue;
    RevenantMarkdownNode *container = [self checkOpenBlocks:&allMatched shouldContinue:&shouldContinue];
    if (!container)
        return;
    RevenantMarkdownNode *lastMatched = container;
    RevenantMarkdownNode *before = _current;
    [self openNewBlocks:&container allMatched:allMatched];
    if (before == _current || YES)
        [self addTextToContainer:container lastMatched:lastMatched];
}

- (void)parseInlinesIn:(RevenantMarkdownNode *)node
{
    for (RevenantMarkdownNode *child = node->firstChild; child; child = child->next) {
        if (child->kind == RevenantMarkdownParagraph || child->kind == RevenantMarkdownHeading || child->kind == RevenantMarkdownTableCell) {
            RVMInlineParser *inlines = [[RVMInlineParser alloc] initWithPool:_pool references:_references inlineOnly:NO];
            NSString *text = child->content;
            if (child->kind == RevenantMarkdownTableCell)
                text = RVMTrimmed(text);
            [inlines parse:text into:child];
        } else if (child->firstChild) {
            [self parseInlinesIn:child];
        }
    }
}

- (RevenantMarkdownNode *)parse:(NSString *)source
{
    _root = RVMNew(_pool, RevenantMarkdownDocument);
    _root->open = YES;
    _root->content = [NSMutableString string];
    _current = _root;
    _lineNumber = 0;
    NSString *text = source;
    if (text.length && [text characterAtIndex:0] == 0xFEFF)
        text = [text substringFromIndex:1];
    text = [text stringByReplacingOccurrencesOfString:RVMNulString() withString:@"\uFFFD" options:NSLiteralSearch range:NSMakeRange(0, text.length)];
    NSUInteger length = text.length, start = 0;
    BOOL endedWithNewline = NO;
    while (start <= length) {
        NSUInteger at = start;
        while (at < length && [text characterAtIndex:at] != '\n' && [text characterAtIndex:at] != '\r')
            at++;
        if (at >= length) {
            if (start < length)
                [self incorporateLine:[text substringWithRange:NSMakeRange(start, at - start)]];
            break;
        }
        [self incorporateLine:[text substringWithRange:NSMakeRange(start, at - start)]];
        if ([text characterAtIndex:at] == '\r' && at + 1 < length && [text characterAtIndex:at + 1] == '\n')
            at++;
        start = at + 1;
        endedWithNewline = start >= length;
        if (endedWithNewline)
            break;
    }
    while (_current != _root)
        _current = [self finalize:_current];
    [self finalize:_root];
    [self parseInlinesIn:_root];
    return _root;
}

@end

RevenantMarkdownTree *RevenantMarkdownParseDocument(NSString *source)
{
    RevenantMarkdownTree *tree = [[RevenantMarkdownTree alloc] init];
    tree->_pool = [NSMutableArray array];
    RVMReferences *references = [[RVMReferences alloc] init];
    RVMBlockParser *parser = [[RVMBlockParser alloc] initWithPool:tree->_pool references:references];
    tree.root = [parser parse:source];
    return tree;
}

RevenantMarkdownTree *RevenantMarkdownParseInlineOnly(NSString *source)
{
    RevenantMarkdownTree *tree = [[RevenantMarkdownTree alloc] init];
    tree->_pool = [NSMutableArray array];
    RevenantMarkdownNode *root = RVMNew(tree->_pool, RevenantMarkdownDocument);
    RevenantMarkdownNode *paragraph = RVMNew(tree->_pool, RevenantMarkdownParagraph);
    RVMAppend(root, paragraph);
    RVMReferences *references = [[RVMReferences alloc] init];
    NSString *text = source.length && [source characterAtIndex:0] == 0xFEFF ? [source substringFromIndex:1] : source;
    text = [text stringByReplacingOccurrencesOfString:RVMNulString() withString:@"\uFFFD" options:NSLiteralSearch range:NSMakeRange(0, text.length)];
    text = [text stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, text.length)];
    text = [text stringByReplacingOccurrencesOfString:@"\r" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, text.length)];
    RVMInlineParser *definitions = [[RVMInlineParser alloc] initWithPool:tree->_pool references:references inlineOnly:NO];
    while (RVMStartsReference(text)) {
        NSUInteger used = 0;
        if (![definitions parseReferenceIn:text consumed:&used] || used == 0)
            break;
        text = [text substringFromIndex:used];
    }
    if (text.length) {
        RVMInlineParser *inlines = [[RVMInlineParser alloc] initWithPool:tree->_pool references:references inlineOnly:YES];
        [inlines parse:text into:paragraph];
    }
    tree.root = root;
    return tree;
}

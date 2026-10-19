#import <CoreSpotlight/CoreSpotlight.h>
#import <objc/runtime.h>
#import "CharonSpotlightStore.h"

typedef BOOL (^CharonSearchPredicate)(CSSearchableItem *item);

static BOOL CharonSearchGlob(NSString *pattern, NSString *text)
{
    NSArray<NSString *> *parts = [pattern componentsSeparatedByString:@"*"];
    if (parts.count == 1)
        return [text isEqualToString:pattern];
    NSString *first = parts.firstObject;
    NSString *last = parts.lastObject;
    if (first.length > 0 && ![text hasPrefix:first])
        return NO;
    NSUInteger position = first.length;
    for (NSUInteger k = 1; k + 1 < parts.count; k++) {
        NSString *part = parts[k];
        if (part.length == 0)
            continue;
        NSRange found = [text rangeOfString:part options:NSLiteralSearch range:NSMakeRange(position, text.length - position)];
        if (found.location == NSNotFound)
            return NO;
        position = NSMaxRange(found);
    }
    return text.length >= position + last.length && (last.length == 0 || [text hasSuffix:last]);
}

static NSString *CharonSearchAttribute(CSSearchableItem *item, NSString *name)
{
    if (!class_getProperty([CSSearchableItemAttributeSet class], name.UTF8String))
        return nil;
    id value = [item.attributeSet valueForKey:name];
    return [value isKindOfClass:[NSString class]] ? value : nil;
}

static NSArray<NSArray<NSString *> *> *CharonSearchTokens(NSString *query)
{
    NSMutableArray<NSArray<NSString *> *> *tokens = [NSMutableArray array];
    NSUInteger i = 0, n = query.length;
    while (i < n) {
        unichar c = [query characterAtIndex:i];
        unichar next = i + 1 < n ? [query characterAtIndex:i + 1] : 0;
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
            i++;
        } else if (c == '(' || c == ')') {
            [tokens addObject:@[c == '(' ? @"(" : @")", @""]];
            i++;
        } else if ((c == '=' || c == '!') && next == '=') {
            [tokens addObject:@[c == '=' ? @"==" : @"!=", @""]];
            i += 2;
        } else if ((c == '&' || c == '|') && next == c) {
            [tokens addObject:@[c == '&' ? @"&&" : @"||", @""]];
            i += 2;
        } else if (c == '"') {
            NSRange close = [query rangeOfString:@"\"" options:NSLiteralSearch range:NSMakeRange(i + 1, n - i - 1)];
            NSUInteger end = close.location == NSNotFound ? n : close.location;
            [tokens addObject:@[@"str", [query substringWithRange:NSMakeRange(i + 1, end - i - 1)]]];
            i = close.location == NSNotFound ? n : NSMaxRange(close);
        } else if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_') {
            NSUInteger start = i;
            while (i < n) {
                unichar d = [query characterAtIndex:i];
                if (!((d >= 'a' && d <= 'z') || (d >= 'A' && d <= 'Z') || (d >= '0' && d <= '9') || d == '_'))
                    break;
                i++;
            }
            [tokens addObject:@[@"id", [query substringWithRange:NSMakeRange(start, i - start)]]];
        } else {
            return nil;
        }
    }
    return tokens;
}

@interface CharonSearchParser : NSObject
- (instancetype)initWithTokens:(NSArray<NSArray<NSString *> *> *)tokens;
- (CharonSearchPredicate)parse;
@end

@implementation CharonSearchParser
{
    NSArray<NSArray<NSString *> *> *_tokens;
    NSUInteger _position;
    BOOL _failed;
}

- (instancetype)initWithTokens:(NSArray<NSArray<NSString *> *> *)tokens
{
    if ((self = [super init])) {
        _tokens = tokens;
    }
    return self;
}

- (NSString *)peekKind
{
    return _position < _tokens.count ? _tokens[_position][0] : @"end";
}

- (NSString *)takeKind:(NSString *)kind
{
    if (![[self peekKind] isEqualToString:kind]) {
        _failed = YES;
        return nil;
    }
    return _tokens[_position++][1];
}

- (CharonSearchPredicate)parse
{
    CharonSearchPredicate predicate = [self parseOr];
    if (_failed || _position != _tokens.count)
        return nil;
    return predicate;
}

- (CharonSearchPredicate)parseOr
{
    CharonSearchPredicate left = [self parseAnd];
    while (!_failed && [[self peekKind] isEqualToString:@"||"]) {
        [self takeKind:@"||"];
        CharonSearchPredicate l = left, r = [self parseAnd];
        left = ^BOOL(CSSearchableItem *item) { return l(item) || r(item); };
    }
    return left;
}

- (CharonSearchPredicate)parseAnd
{
    CharonSearchPredicate left = [self parsePrimary];
    while (!_failed && [[self peekKind] isEqualToString:@"&&"]) {
        [self takeKind:@"&&"];
        CharonSearchPredicate l = left, r = [self parsePrimary];
        left = ^BOOL(CSSearchableItem *item) { return l(item) && r(item); };
    }
    return left;
}

- (CharonSearchPredicate)parsePrimary
{
    if ([[self peekKind] isEqualToString:@"("]) {
        [self takeKind:@"("];
        CharonSearchPredicate inner = [self parseOr];
        [self takeKind:@")"];
        return inner;
    }
    return [self parseComparison];
}

- (CharonSearchPredicate)parseComparison
{
    NSString *name = [self takeKind:@"id"];
    NSString *op = [self peekKind];
    if (![op isEqualToString:@"=="] && ![op isEqualToString:@"!="]) {
        _failed = YES;
        return nil;
    }
    [self takeKind:op];
    NSString *pattern = [self takeKind:@"str"];
    if (_failed || !name || !pattern)
        return nil;
    BOOL equal = [op isEqualToString:@"=="];
    return ^BOOL(CSSearchableItem *item) {
        NSString *value = CharonSearchAttribute(item, name);
        BOOL matches = value != nil && CharonSearchGlob(pattern, value);
        return equal ? matches : !matches;
    };
}

@end

static CSSearchableItem *CharonSearchFetchedCopy(CSSearchableItem *item, NSArray<NSString *> *attributes)
{
    CSSearchableItemAttributeSet *set = [[CSSearchableItemAttributeSet alloc] initWithItemContentType:@"public.item"];
    [set setValue:nil forKey:@"contentType"];
    for (NSString *name in attributes) {
        if (!class_getProperty([CSSearchableItemAttributeSet class], name.UTF8String))
            continue;
        id value = [item.attributeSet valueForKey:name];
        if (value)
            [set setValue:value forKey:name];
    }
    return [[CSSearchableItem alloc] initWithUniqueIdentifier:item.uniqueIdentifier domainIdentifier:item.domainIdentifier attributeSet:set];
}

@implementation CSSearchQuery
{
    NSString *_queryString;
    NSArray<NSString *> *_fetchAttributes;
    NSUInteger _foundItemCount;
    BOOL _cancelled;
}

@synthesize foundItemsHandler = _foundItemsHandler;
@synthesize completionHandler = _completionHandler;
@synthesize foundItemCount = _foundItemCount;
@synthesize protectionClasses = _protectionClasses;

- (instancetype)initWithQueryString:(NSString *)queryString queryContext:(CSSearchQueryContext *)queryContext
{
    if ((self = [super init])) {
        _queryString = [queryString copy];
        _fetchAttributes = queryContext.fetchAttributes ?: @[];
    }
    return self;
}

- (instancetype)initWithQueryString:(NSString *)queryString attributes:(NSArray<NSString *> *)attributes
{
    if ((self = [self initWithQueryString:queryString queryContext:nil])) {
        _fetchAttributes = attributes ?: @[];
    }
    return self;
}

- (BOOL)isCancelled
{
    @synchronized (self) {
        return _cancelled;
    }
}

- (void)cancel
{
    @synchronized (self) {
        _cancelled = YES;
    }
}

- (void)start
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        NSMutableArray<CSSearchableItem *> *found = [NSMutableArray array];
        CharonSearchPredicate predicate = nil;
        if (_queryString.length == 0) {
            predicate = ^BOOL(CSSearchableItem *item) { return YES; };
        } else {
            NSArray<NSArray<NSString *> *> *tokens = CharonSearchTokens(_queryString);
            predicate = tokens ? [[[CharonSearchParser alloc] initWithTokens:tokens] parse] : nil;
            if (!predicate)
                error = [NSError errorWithDomain:CSSearchQueryErrorDomain code:CSSearchQueryErrorCodeInvalidQuery userInfo:nil];
        }
        if (predicate && !self.isCancelled) {
            for (CSSearchableItem *item in CharonSpotlightDefaultItems()) {
                if (predicate(item))
                    [found addObject:CharonSearchFetchedCopy(item, _fetchAttributes)];
            }
        }
        if (!error && self.isCancelled)
            error = [NSError errorWithDomain:CSSearchQueryErrorDomain code:CSSearchQueryErrorCodeCancelled userInfo:nil];
        if (error)
            found = [NSMutableArray array];
        _foundItemCount = found.count;
        if (found.count > 0 && self.foundItemsHandler)
            self.foundItemsHandler(found);
        if (self.completionHandler)
            self.completionHandler(error);
    });
}

@end

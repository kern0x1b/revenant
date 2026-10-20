#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - the options class

@implementation NSAttributedStringMarkdownParsingOptions

- (instancetype)init
{
    return [super init];
}

- (id)copyWithZone:(NSZone *)zone
{
    NSAttributedStringMarkdownParsingOptions *copy = [[[self class] allocWithZone:zone] init];
    copy.allowsExtendedAttributes = self.allowsExtendedAttributes;
    copy.interpretedSyntax = self.interpretedSyntax;
    copy.failurePolicy = self.failurePolicy;
    copy.languageCode = self.languageCode;
    copy.appliesSourcePositionAttributes = self.appliesSourcePositionAttributes;
    return copy;
}

- (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:self.allowsExtendedAttributes forKey:@"allowsExtendedAttributes"];
    [coder encodeInteger:self.interpretedSyntax forKey:@"interpretedSyntax"];
    [coder encodeInteger:self.failurePolicy forKey:@"failurePolicy"];
    [coder encodeObject:self.languageCode forKey:@"languageCode"];
    [coder encodeBool:self.appliesSourcePositionAttributes forKey:@"appliesSourcePositionAttributes"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super init];
    if (!self)
        return nil;
    _allowsExtendedAttributes = [coder decodeBoolForKey:@"allowsExtendedAttributes"];
    _interpretedSyntax = [coder decodeIntegerForKey:@"interpretedSyntax"];
    _failurePolicy = [coder decodeIntegerForKey:@"failurePolicy"];
    _languageCode = [[coder decodeObjectForKey:@"languageCode"] copy];
    _appliesSourcePositionAttributes = [coder decodeBoolForKey:@"appliesSourcePositionAttributes"];
    return self;
}

@end

#pragma mark - the document

typedef NS_ENUM(NSInteger, RevenantMarkdownKind) {
    RevenantMarkdownParagraph,
    RevenantMarkdownHeader,
    RevenantMarkdownCodeBlock,
    RevenantMarkdownThematicBreak,
    RevenantMarkdownBlockQuote,
    RevenantMarkdownList,
    RevenantMarkdownTable,
};

typedef struct {
    NSUInteger start;
    NSUInteger end;
    NSUInteger indent;
    RevenantMarkdownKind kind;
    NSInteger level;
    BOOL ordered;
    NSString *language;
    NSPresentationIntent *intent;
    NSMutableArray *children;
} RevenantMarkdownBlock;

static BOOL RevenantMarkdownBlank(NSString *line)
{
    for (NSUInteger i = 0; i < line.length; i++)
        if (![[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[line characterAtIndex:i]])
            return NO;
    return YES;
}

static NSUInteger RevenantMarkdownIndent(NSString *line)
{
    NSUInteger columns = 0, limit = line.length;
    for (NSUInteger i = 0; i < limit; i++) {
        unichar c = [line characterAtIndex:i];
        if (c == ' ')
            columns++;
        else if (c == '\t')
            columns += 4 - columns % 4;
        else
            return columns;
    }
    return columns;
}

static NSString *RevenantMarkdownTrimmed(NSString *line)
{
    return [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL RevenantMarkdownThematic(NSString *trimmed)
{
    if (trimmed.length < 3)
        return NO;
    unichar first = [trimmed characterAtIndex:0];
    if (first != '*' && first != '-' && first != '_')
        return NO;
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (c != first && c != ' ' && c != '\t')
            return NO;
    }
    return YES;
}

static BOOL RevenantMarkdownFence(NSString *trimmed, unichar *fence, NSUInteger *count, NSString **info)
{
    NSUInteger length = trimmed.length, run = 0;
    unichar first = length ? [trimmed characterAtIndex:0] : 0;
    if (first != '`' && first != '~')
        return NO;
    while (run < length && [trimmed characterAtIndex:run] == first)
        run++;
    if (run < 3)
        return NO;
    if (fence)
        *fence = first;
    if (count)
        *count = run;
    if (info)
        *info = [[trimmed substringFromIndex:run] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return YES;
}

static NSInteger RevenantMarkdownHeading(NSString *trimmed, NSString **text)
{
    NSUInteger level = 0, length = trimmed.length, start;
    while (level < length && level < 6 && [trimmed characterAtIndex:level] == '#')
        level++;
    if (!level || level >= length)
        return 0;
    if ([trimmed characterAtIndex:level] != ' ' && [trimmed characterAtIndex:level] != '\t')
        return 0;
    start = level;
    while (start < length && [trimmed characterAtIndex:start] == ' ')
        start++;
    NSString *tail = [trimmed substringFromIndex:start];
    NSMutableString *body = [tail mutableCopy];
    while (body.length && [body characterAtIndex:body.length - 1] == '#')
        [body deleteCharactersInRange:NSMakeRange(body.length - 1, 1)];
    if (text)
        *text = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    return (NSInteger)level;
}

static BOOL RevenantMarkdownBullet(NSString *trimmed, BOOL *ordered, NSUInteger *width)
{
    unichar first = trimmed.length ? [trimmed characterAtIndex:0] : 0;
    if ((first == '-' || first == '*' || first == '+') && trimmed.length > 1
        && ([trimmed characterAtIndex:1] == ' ' || [trimmed characterAtIndex:1] == '\t')) {
        *ordered = NO;
        *width = 2;
        return YES;
    }
    NSUInteger digits = 0;
    while (digits < trimmed.length && [trimmed characterAtIndex:digits] >= '0' && [trimmed characterAtIndex:digits] <= '9')
        digits++;
    if (digits && digits + 1 < trimmed.length && ([trimmed characterAtIndex:digits] == '.' || [trimmed characterAtIndex:digits] == ')')
        && ([trimmed characterAtIndex:digits + 1] == ' ' || [trimmed characterAtIndex:digits + 1] == '\t')) {
        *ordered = YES;
        *width = digits + 2;
        return YES;
    }
    return NO;
}

static BOOL RevenantMarkdownDivider(NSString *trimmed)
{
    if (trimmed.length < 1 || [trimmed characterAtIndex:0] != '|')
        return NO;
    NSUInteger pipes = 0;
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (c == '|')
            pipes++;
        else if (c != '-' && c != ':' && c != ' ' && c != '\t')
            return NO;
    }
    return pipes >= 2;
}

static NSArray *RevenantMarkdownCells(NSString *line, NSArray **alignments)
{
    NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray *cells = [NSMutableArray array];
    NSMutableArray *found = [NSMutableArray array];
    if ([trimmed hasPrefix:@"|"])
        trimmed = [trimmed substringFromIndex:1];
    if ([trimmed hasSuffix:@"|"])
        trimmed = [trimmed substringToIndex:trimmed.length - 1];
    NSMutableString *cell = [NSMutableString string];
    for (NSUInteger i = 0; i < trimmed.length; i++) {
        unichar c = [trimmed characterAtIndex:i];
        if (c == '\\' && i + 1 < trimmed.length) {
            [cell appendFormat:@"%C", [trimmed characterAtIndex:i + 1]];
            i++;
            continue;
        }
        if (c == '|') {
            NSString *finished = RevenantMarkdownTrimmed(cell);
            [cells addObject:finished];
            [cell setString:@""];
            continue;
        }
        [cell appendFormat:@"%C", c];
    }
    {
        NSString *last = RevenantMarkdownTrimmed(cell);
        [cells addObject:last];
    }
    if (alignments) {
        for (NSString *one in cells) {
            BOOL left = [one hasPrefix:@":"], right = [one hasSuffix:@":"];
            [found addObject:@(left && right ? 1 : right ? 2 : 0)];
        }
        *alignments = found;
    }
    return cells;
}

#pragma mark - the parser

@interface RevenantMarkdownParser : NSObject {
    NSAttributedStringMarkdownParsingOptions *_options;
    NSURL *_baseURL;
    NSInteger _identity;
    NSMutableAttributedString *_result;
    NSString *_language;
}
- (id)initWithOptions:(NSAttributedStringMarkdownParsingOptions *)options baseURL:(NSURL *)baseURL;
- (NSAttributedString *)parse:(NSString *)markdown;
@end

@implementation RevenantMarkdownParser

- (id)initWithOptions:(NSAttributedStringMarkdownParsingOptions *)options baseURL:(NSURL *)baseURL
{
    self = [super init];
    if (!self)
        return nil;
    _options = options;
    _baseURL = baseURL;
    _language = [options.languageCode copy];
    return self;
}

- (NSInteger)nextIdentity
{
    return ++_identity;
}

- (BOOL)carriesIntents
{
    return _options.interpretedSyntax == NSAttributedStringMarkdownInterpretedSyntaxFull;
}

- (BOOL)keepsSourceSpacing
{
    return _options.interpretedSyntax == NSAttributedStringMarkdownInterpretedSyntaxInlineOnlyPreservingWhitespace;
}

- (NSDictionary *)blockAttributes:(NSPresentationIntent *)intent span:(NSUInteger)span extra:(NSDictionary *)extra
{
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    if ([self carriesIntents] && intent)
        attributes[NSPresentationIntentAttributeName] = intent;
    if (span)
        attributes[NSInlinePresentationIntentAttributeName] = @(span);
    if (extra)
        [attributes addEntriesFromDictionary:extra];
    if (_language)
        attributes[NSLanguageIdentifierAttributeName] = _language;
    return attributes;
}

#pragma mark the span spans

static NSString *const RevenantMarkdownLinkKey = @"NSLink";

- (NSURL *)urlFor:(NSString *)text
{
    if (!text.length)
        return nil;
    if (!_baseURL)
        return [NSURL URLWithString:text];
    return [NSURL URLWithString:text relativeToURL:_baseURL];
}

- (NSString *)targetIn:(NSString *)body
{
    NSString *trimmed = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSRange quote = [trimmed rangeOfString:@" \""];
    if (quote.location != NSNotFound)
        trimmed = [trimmed substringToIndex:quote.location];
    return RevenantMarkdownTrimmed(trimmed);
}

- (void)appendInline:(NSString *)text
               from:(NSUInteger)start
                 to:(NSUInteger)end
            intent:(NSPresentationIntent *)intent
            span:(NSUInteger)span
             extra:(NSDictionary *)extra
{
    if (end <= start)
        return;
    NSString *piece = [text substringWithRange:NSMakeRange(start, end - start)];
    [_result appendAttributedString:[[NSAttributedString alloc] initWithString:piece
                                                                     attributes:[self blockAttributes:intent
                                                                                            span:span
                                                                                             extra:extra]]];
}

static NSUInteger RevenantMarkdownBracketEnd(NSString *text, NSUInteger start, unichar open, unichar close, NSUInteger limit)
{
    NSUInteger depth = 0, index = start;
    while (index < limit) {
        unichar c = [text characterAtIndex:index];
        if (c == '\\') {
            index += 2;
            continue;
        }
        if (c == open)
            depth++;
        else if (c == close && !--depth)
            return index;
        index++;
    }
    return NSNotFound;
}

static NSUInteger RevenantMarkdownMarkerEnd(NSString *text, NSUInteger start, unichar mark, NSUInteger runLength, NSUInteger limit)
{
    NSUInteger index = start;
    while (index < limit) {
        unichar c = [text characterAtIndex:index];
        if (c == '\\') {
            index += 2;
            continue;
        }
        if (c == mark) {
            NSUInteger here = 0;
            while (index + here < limit && [text characterAtIndex:index + here] == mark)
                here++;
            if (here == runLength && index > start)
                return index;
            index += here;
            continue;
        }
        index++;
    }
    return NSNotFound;
}

static BOOL RevenantMarkdownParenEnd(NSString *text, NSUInteger body, NSUInteger limit, NSUInteger *at)
{
    NSUInteger depth = 1, index = body;
    while (index < limit) {
        unichar c = [text characterAtIndex:index];
        if (c == '\\') {
            index += 2;
            continue;
        }
        if (c == '(')
            depth++;
        else if (c == ')' && !--depth) {
            *at = index;
            return YES;
        }
        index++;
    }
    return NO;
}

- (BOOL)parseMarkerIn:(NSString *)text
               index:(NSUInteger *)index
               plain:(NSUInteger *)plain
               limit:(NSUInteger)limit
              intent:(NSPresentationIntent *)intent
{
    unichar c = [text characterAtIndex:*index];
    NSUInteger run = 0, runLength, close, inner, innerEnd, value;
    if (c == '~') {
        if (*index + 1 >= limit || [text characterAtIndex:*index + 1] != '~')
            return NO;
    }
    while (*index + run < limit && [text characterAtIndex:*index + run] == c)
        run++;
    runLength = run >= 2 ? 2 : 1;
    if (c == '~' && runLength != 2)
        return NO;
    value = c == '~' ? NSInlinePresentationIntentStrikethrough
          : runLength == 2 ? NSInlinePresentationIntentStronglyEmphasized
                           : NSInlinePresentationIntentEmphasized;
    close = RevenantMarkdownMarkerEnd(text, *index + runLength, c, runLength, limit);
    if (close == NSNotFound || close == *index + runLength)
        return NO;
    inner = *index + runLength;
    innerEnd = close;
    [self appendInline:text from:*plain to:*index intent:intent span:0 extra:nil];
    [self parseInlines:text from:inner to:innerEnd intent:intent];
    [_result addAttribute:NSInlinePresentationIntentAttributeName
                   value:@(value)
                   range:NSMakeRange(_result.length - (innerEnd - inner), innerEnd - inner)];
    *index = close + runLength;
    *plain = *index;
    return YES;
}

- (void)parseInlines:(NSString *)text
               from:(NSUInteger)start
                 to:(NSUInteger)end
            intent:(NSPresentationIntent *)intent
{
    NSUInteger index = start, plain = start, limit = end;
    while (index < limit) {
        unichar c = [text characterAtIndex:index];
        if (c == '\n' || c == '\r') {
            NSUInteger at = index, after = index + 1, spaces, cut;
            BOOL backslash, hard;
            if (c == '\r' && after < limit && [text characterAtIndex:after] == '\n')
                after++;
            spaces = at;
            while (spaces > plain && [text characterAtIndex:spaces - 1] == ' ')
                spaces--;
            backslash = spaces > plain && [text characterAtIndex:spaces - 1] == '\\';
            cut = backslash ? spaces - 1 : spaces;
            hard = backslash || at - spaces >= 2;
            [self appendInline:text from:plain to:cut intent:intent span:0 extra:nil];
            [_result appendAttributedString:
                [[NSAttributedString alloc] initWithString:hard ? @"\n" : ([self keepsSourceSpacing] ? @"\n" : @" ")
                                               attributes:[self blockAttributes:intent
                                                                  span:hard ? NSInlinePresentationIntentLineBreak
                                                                             : NSInlinePresentationIntentSoftBreak
                                                                   extra:nil]]];
            index = after;
            plain = index;
            continue;
        }
        if (c == '\\' && index + 1 < limit) {
            [self appendInline:text from:plain to:index intent:intent span:0 extra:nil];
            [_result appendAttributedString:
                [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C", [text characterAtIndex:index + 1]]
                                               attributes:[self blockAttributes:intent span:0 extra:nil]]];
            index += 2;
            plain = index;
            continue;
        }
        if (c == '`') {
            NSUInteger run = 0, close = index, search, found = NSNotFound, here;
            while (close < limit && [text characterAtIndex:close] == '`')
                run++, close++;
            for (search = close; search < limit;) {
                if ([text characterAtIndex:search] == '`') {
                    here = 0;
                    while (search + here < limit && [text characterAtIndex:search + here] == '`')
                        here++;
                    if (here == run && search > close) {
                        found = search;
                        break;
                    }
                    search += here;
                    continue;
                }
                if ([text characterAtIndex:search] == '\n')
                    break;
                search++;
            }
            if (found != NSNotFound) {
                NSString *code = [text substringWithRange:NSMakeRange(close, found - close)];
                while (code.length && ([code characterAtIndex:0] == ' ' || [code characterAtIndex:0] == '\n'))
                    code = [code substringFromIndex:1];
                while (code.length && ([code characterAtIndex:code.length - 1] == ' ' || [code characterAtIndex:code.length - 1] == '\n'))
                    code = [code substringToIndex:code.length - 1];
                [self appendInline:text from:plain to:index intent:intent span:0 extra:nil];
                [_result appendAttributedString:
                    [[NSAttributedString alloc] initWithString:code
                                                   attributes:[self blockAttributes:intent
                                                                      span:NSInlinePresentationIntentCode
                                                                       extra:nil]]];
                index = found + run;
                plain = index;
                continue;
            }
            index = close;
            continue;
        }
        if (c == '*' || c == '_' || c == '~') {
            if ([self parseMarkerIn:text index:&index plain:&plain limit:limit intent:intent])
                continue;
        }
        if (c == '!' && index + 1 < limit && [text characterAtIndex:index + 1] == '[') {
            NSUInteger close = RevenantMarkdownBracketEnd(text, index + 1, '[', ']', limit), at;
            if (close != NSNotFound && close + 1 < limit && [text characterAtIndex:close + 1] == '('
                && RevenantMarkdownParenEnd(text, close + 2, limit, &at)) {
                NSURL *url = [self urlFor:[self targetIn:[text substringWithRange:NSMakeRange(close + 2, at - close - 2)]]];
                if (url) {
                    [self appendInline:text from:plain to:index intent:intent span:0 extra:nil];
                    [self parseInlines:text from:index + 2 to:close intent:intent];
                    [_result addAttribute:NSImageURLAttributeName
                                   value:url
                                   range:NSMakeRange(_result.length - (close - index - 2), close - index - 2)];
                    index = at + 1;
                    plain = index;
                    continue;
                }
            }
            index++;
            continue;
        }
        if (c == '[') {
            NSUInteger close = RevenantMarkdownBracketEnd(text, index, '[', ']', limit), at;
            if (close != NSNotFound && close + 1 < limit && [text characterAtIndex:close + 1] == '('
                && RevenantMarkdownParenEnd(text, close + 2, limit, &at)) {
                NSURL *url = [self urlFor:[self targetIn:[text substringWithRange:NSMakeRange(close + 2, at - close - 2)]]];
                if (url) {
                    [self appendInline:text from:plain to:index intent:intent span:0 extra:nil];
                    [self parseInlines:text from:index + 1 to:close intent:intent];
                    [_result addAttribute:RevenantMarkdownLinkKey
                                   value:url
                                   range:NSMakeRange(_result.length - (close - index - 1), close - index - 1)];
                    index = at + 1;
                    plain = index;
                    continue;
                }
            }
            index++;
            continue;
        }
        if (c == '<') {
            NSUInteger close = index + 1;
            NSString *inside;
            NSURL *url;
            while (close < limit) {
                unichar d = [text characterAtIndex:close];
                if (d == '>' || d == '<' || d == ' ' || d == '\n')
                    break;
                close++;
            }
            inside = close < limit && [text characterAtIndex:close] == '>' ? [text substringWithRange:NSMakeRange(index + 1, close - index - 1)] : nil;
            url = inside ? [self urlFor:inside] : nil;
            if (url && ([inside hasPrefix:@"http://"] || [inside hasPrefix:@"https://"] || [inside hasPrefix:@"mailto:"])) {
                [self appendInline:text from:plain to:index intent:intent span:0 extra:nil];
                [_result appendAttributedString:
                    [[NSAttributedString alloc] initWithString:inside
                                                   attributes:[self blockAttributes:intent
                                                                      span:0
                                                                       extra:@{RevenantMarkdownLinkKey: url}]]];
                index = close + 1;
                plain = index;
                continue;
            }
            index++;
            continue;
        }
        index++;
    }
    [self appendInline:text from:plain to:limit intent:intent span:0 extra:nil];
}


#pragma mark - the blocks

- (NSArray *)linesOf:(NSString *)markdown
{
    NSMutableArray *lines = [NSMutableArray array];
    NSUInteger start = 0, length = markdown.length;
    while (start <= length) {
        NSUInteger at = start;
        while (at < length && [markdown characterAtIndex:at] != '\n' && [markdown characterAtIndex:at] != '\r')
            at++;
        [lines addObject:[markdown substringWithRange:NSMakeRange(start, at - start)]];
        if (at >= length)
            break;
        if ([markdown characterAtIndex:at] == '\r' && at + 1 < length && [markdown characterAtIndex:at + 1] == '\n')
            at++;
        start = at + 1;
    }
    return lines;
}

- (void)parseLines:(NSArray *)lines
              from:(NSUInteger)start
                to:(NSUInteger)end
           parent:(NSPresentationIntent *)parent
            item:(NSPresentationIntent *)item
{
    NSUInteger at = start;
    NSMutableString *paragraph = [NSMutableString string];
    #define RevenantFlushParagraph() do { \
        if (paragraph.length) { \
            NSPresentationIntent *intent = [NSPresentationIntent paragraphIntentWithIdentity:[self nextIdentity] nestedInsideIntent:item ?: parent]; \
            [self parseInlines:paragraph from:0 to:paragraph.length intent:intent]; \
            [paragraph setString:@""]; \
        } \
    } while (0)
    while (at < end) {
        NSString *line = [lines objectAtIndex:at];
        NSString *trimmed = RevenantMarkdownTrimmed(line);
        NSUInteger indent = RevenantMarkdownIndent(line);
        unichar fence;
        NSUInteger fenceCount;
        NSString *info;
        NSString *headerText;
        NSInteger level;
        BOOL ordered, bullet;
        NSUInteger bulletWidth;
        if (!trimmed.length) {
            RevenantFlushParagraph();
            at++;
            continue;
        }
        if (RevenantMarkdownThematic(trimmed)) {
            RevenantFlushParagraph();
            NSPresentationIntent *intent = [NSPresentationIntent thematicBreakIntentWithIdentity:[self nextIdentity]
                                                                            nestedInsideIntent:parent];
            [_result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u2E3B"
                                                                           attributes:[self blockAttributes:intent
                                                                                              span:0
                                                                                               extra:nil]]];
            at++;
            continue;
        }
        level = RevenantMarkdownHeading(trimmed, &headerText);
        if (level) {
            RevenantFlushParagraph();
            NSPresentationIntent *intent = [NSPresentationIntent headerIntentWithIdentity:[self nextIdentity]
                                                                                     level:level
                                                                        nestedInsideIntent:parent];
            [self parseInlines:headerText from:0 to:headerText.length intent:intent];
            at++;
            continue;
        }
        if (RevenantMarkdownFence(trimmed, &fence, &fenceCount, &info)) {
            RevenantFlushParagraph();
            NSPresentationIntent *intent = [NSPresentationIntent codeBlockIntentWithIdentity:[self nextIdentity]
                                                                             languageHint:info.length ? info : nil
                                                                          nestedInsideIntent:parent];
            NSMutableString *code = [NSMutableString string];
            NSUInteger body = at + 1, closing = end;
            while (body < end) {
                NSString *candidate = RevenantMarkdownTrimmed([lines objectAtIndex:body]);
                NSUInteger run = 0;
                while (run < candidate.length && [candidate characterAtIndex:run] == fence)
                    run++;
                if (run >= fenceCount && RevenantMarkdownTrimmed([candidate substringFromIndex:run]).length == 0) {
                    closing = body;
                    break;
                }
                [code appendFormat:@"%@\n", [lines objectAtIndex:body]];
                body++;
            }
            [_result appendAttributedString:[[NSAttributedString alloc] initWithString:code
                                                                           attributes:[self blockAttributes:intent
                                                                                              span:0
                                                                                               extra:nil]]];
            at = closing + 1;
            continue;
        }
        if (indent >= 4) {
            RevenantFlushParagraph();
            NSPresentationIntent *intent = [NSPresentationIntent codeBlockIntentWithIdentity:[self nextIdentity]
                                                                             languageHint:nil
                                                                          nestedInsideIntent:parent];
            NSMutableString *code = [NSMutableString string];
            while (at < end) {
                NSString *candidate = [lines objectAtIndex:at];
                if (RevenantMarkdownBlank(candidate))
                    break;
                if (RevenantMarkdownIndent(candidate) < 4)
                    break;
                [code appendFormat:@"%@\n", [candidate substringFromIndex:4]];
                at++;
            }
            [_result appendAttributedString:[[NSAttributedString alloc] initWithString:code
                                                                           attributes:[self blockAttributes:intent
                                                                                              span:0
                                                                                               extra:nil]]];
            continue;
        }
        if ([trimmed characterAtIndex:0] == '>') {
            RevenantFlushParagraph();
            NSPresentationIntent *intent = [NSPresentationIntent blockQuoteIntentWithIdentity:[self nextIdentity]
                                                                           nestedInsideIntent:parent];
            NSMutableArray *inner = [NSMutableArray array];
            NSUInteger body = at, last = at;
            while (body < end) {
                NSString *candidate = RevenantMarkdownTrimmed([lines objectAtIndex:body]);
                if (!candidate.length || [candidate characterAtIndex:0] != '>')
                    break;
                [inner addObject:[[candidate substringFromIndex:1] stringByTrimmingCharactersInSet:
                                  [NSCharacterSet whitespaceCharacterSet]]];
                last = body;
                body++;
            }
            [self parseLines:inner from:0 to:inner.count parent:intent item:nil];
            at = last + 1;
            continue;
        }
        if ([trimmed hasPrefix:@"|"] && at + 1 < end && RevenantMarkdownDivider(RevenantMarkdownTrimmed([lines objectAtIndex:at + 1]))) {
            RevenantFlushParagraph();
            NSArray<NSNumber *> *alignments = nil;
            NSArray *header = RevenantMarkdownCells(line, &alignments);
            NSMutableArray *rows = [NSMutableArray array];
            NSUInteger body = at + 2;
            NSPresentationIntent *table = [NSPresentationIntent tableIntentWithIdentity:[self nextIdentity]
                                                                          columnCount:header.count
                                                                           alignments:alignments
                                                                  nestedInsideIntent:parent];
            NSPresentationIntent *headerRow = [NSPresentationIntent tableHeaderRowIntentWithIdentity:[self nextIdentity]
                                                                                  nestedInsideIntent:table];
            NSUInteger column;
            for (column = 0; column < header.count; column++) {
                NSPresentationIntent *cell = [NSPresentationIntent tableCellIntentWithIdentity:[self nextIdentity]
                                                                                      column:(NSInteger)column
                                                                               nestedInsideIntent:headerRow];
                [self parseInlines:[header objectAtIndex:column] from:0 to:[[header objectAtIndex:column] length] intent:cell];
            }
            while (body < end) {
                NSString *candidate = RevenantMarkdownTrimmed([lines objectAtIndex:body]);
                if (![candidate hasPrefix:@"|"])
                    break;
                [rows addObject:RevenantMarkdownCells([lines objectAtIndex:body], NULL)];
                body++;
            }
            for (NSUInteger row = 0; row < rows.count; row++) {
                NSArray *cells = [rows objectAtIndex:row];
                NSPresentationIntent *rowIntent = [NSPresentationIntent tableRowIntentWithIdentity:[self nextIdentity]
                                                                                             row:(NSInteger)row + 1
                                                                               nestedInsideIntent:table];
                for (column = 0; column < cells.count; column++) {
                    NSPresentationIntent *cell = [NSPresentationIntent tableCellIntentWithIdentity:[self nextIdentity]
                                                                                          column:(NSInteger)column
                                                                                   nestedInsideIntent:rowIntent];
                    NSString *text = [cells objectAtIndex:column];
                    [self parseInlines:text from:0 to:text.length intent:cell];
                }
            }
            at = body;
            continue;
        }
        bullet = RevenantMarkdownBullet(trimmed, &ordered, &bulletWidth);
        if (bullet) {
            RevenantFlushParagraph();
            NSPresentationIntent *list = ordered
                ? [NSPresentationIntent orderedListIntentWithIdentity:[self nextIdentity] nestedInsideIntent:parent]
                : [NSPresentationIntent unorderedListIntentWithIdentity:[self nextIdentity] nestedInsideIntent:parent];
            {
                NSUInteger item = 0, body = at;
                while (body < end) {
                    NSString *candidate = [lines objectAtIndex:body];
                    NSString *candidateTrimmed = RevenantMarkdownTrimmed(candidate);
                    BOOL candidateOrdered, isItem;
                    NSUInteger candidateWidth, candidateIndent = RevenantMarkdownIndent(candidate);
                    NSPresentationIntent *itemIntent;
                    NSMutableArray *inner = [NSMutableArray array];
                    if (!candidateTrimmed.length) {
                        NSUInteger look = body + 1;
                        if (look >= end)
                            break;
                        isItem = RevenantMarkdownBullet(RevenantMarkdownTrimmed([lines objectAtIndex:look]), &candidateOrdered, &candidateWidth)
                                 && candidateOrdered == ordered && RevenantMarkdownIndent([lines objectAtIndex:look]) == candidateIndent;
                        if (!isItem)
                            break;
                        body++;
                        continue;
                    }
                    isItem = RevenantMarkdownBullet(candidateTrimmed, &candidateOrdered, &candidateWidth)
                             && candidateOrdered == ordered && candidateIndent == indent;
                    if (!isItem && item)
                        break;
                    if (!isItem)
                        break;
                    itemIntent = [NSPresentationIntent listItemIntentWithIdentity:[self nextIdentity]
                                                                            ordinal:(NSInteger)++item
                                                                   nestedInsideIntent:list];
                    [inner addObject:[candidateTrimmed substringFromIndex:candidateWidth]];
                    body++;
                    while (body < end) {
                        NSString *next = [lines objectAtIndex:body];
                        NSString *nextTrimmed = RevenantMarkdownTrimmed(next);
                        BOOL nextOrdered, nextIsItem;
                        NSUInteger nextWidth;
                        nextIsItem = RevenantMarkdownBullet(nextTrimmed, &nextOrdered, &nextWidth)
                                     && nextOrdered == ordered && RevenantMarkdownIndent(next) == indent;
                        if (nextIsItem)
                            break;
                        if (!nextTrimmed.length)
                            break;
                        if (RevenantMarkdownIndent(next) > indent) {
                            [inner addObject:[next substringFromIndex:MIN(indent + candidateWidth, next.length)]];
                            body++;
                            continue;
                        }
                        if (RevenantMarkdownThematic(nextTrimmed) || RevenantMarkdownHeading(nextTrimmed, NULL)
                            || [nextTrimmed characterAtIndex:0] == '>' || RevenantMarkdownFence(nextTrimmed, NULL, NULL, NULL))
                            break;
                        [inner addObject:nextTrimmed];
                        body++;
                    }
                    [self parseLines:inner from:0 to:inner.count parent:nil item:itemIntent];
                }
                at = body > at ? body : at + 1;
            }
            continue;
        }
        if (paragraph.length)
            [paragraph appendString:@"\n"];
        [paragraph appendString:trimmed];
        at++;
    }
    RevenantFlushParagraph();
    #undef RevenantFlushParagraph
}

- (NSAttributedString *)parse:(NSString *)markdown
{
    _result = [[NSMutableAttributedString alloc] init];
    _identity = 0;
    if (markdown.length) {
        NSArray *lines = [self linesOf:markdown];
        [self parseLines:lines from:0 to:lines.count parent:nil item:nil];
    }
    return _result;
}

@end

#pragma mark - the three initialisers

static NSError *RevenantMarkdownError(NSInteger code, NSString *reason)
{
    return [NSError errorWithDomain:NSCocoaErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: reason ?: @"The data could not be read."}];
}

@implementation NSAttributedString (RevenantMarkdown15)

- (instancetype)initWithMarkdown:(NSData *)markdown
                        options:(NSAttributedStringMarkdownParsingOptions *)options
                        baseURL:(NSURL *)baseURL
                         error:(NSError **)error
{
    NSString *text = nil;
    if (markdown)
        text = [[NSString alloc] initWithData:markdown encoding:NSUTF8StringEncoding];
    if (!text) {
        if (error)
            *error = RevenantMarkdownError(NSFileReadUnknownError, @"The data is not text in UTF-8.");
        return nil;
    }
    return [self initWithMarkdownString:text options:options baseURL:baseURL error:error];
}

- (instancetype)initWithMarkdownString:(NSString *)markdownString
                                options:(NSAttributedStringMarkdownParsingOptions *)options
                                baseURL:(NSURL *)baseURL
                                 error:(NSError **)error
{
    if (!markdownString) {
        if (error)
            *error = RevenantMarkdownError(NSFileReadUnknownError, @"The Markdown string is nil.");
        return nil;
    }
    RevenantMarkdownParser *parser = [[RevenantMarkdownParser alloc] initWithOptions:options baseURL:baseURL];
    return [self initWithAttributedString:[parser parse:markdownString]];
}

- (instancetype)initWithContentsOfMarkdownFileAtURL:(NSURL *)markdownFile
                                            options:(NSAttributedStringMarkdownParsingOptions *)options
                                            baseURL:(NSURL *)baseURL
                                              error:(NSError **)error
{
    NSString *text = nil;
    NSError *read = nil;
    if (markdownFile)
        text = [NSString stringWithContentsOfURL:markdownFile encoding:NSUTF8StringEncoding error:&read];
    if (!text) {
        if (error)
            *error = read ?: RevenantMarkdownError(NSFileReadNoSuchFileError, @"The Markdown file could not be read.");
        return nil;
    }
    return [self initWithMarkdownString:text options:options baseURL:baseURL error:error];
}

@end

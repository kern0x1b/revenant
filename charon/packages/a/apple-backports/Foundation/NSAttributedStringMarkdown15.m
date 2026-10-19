#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/* The Markdown of iOS 15.0: the parsing options class and the three initialisers that read a document.

   The release's own answer is a tree of NSPresentationIntent, one per block, hanging off the block that
   holds it, and the span spans carry NSInlinePresentationIntentAttributeName beside it. What the system's
   own Foundation does with a document, measured by tests/backports/host/attributed15/run.sh where the
   port's parser and the system's are one process and every document is compared run for run:

     a heading is a header intent with its level, a paragraph a paragraph intent, a fenced or indented
     code block a code block intent with the info string as its language hint, "***" a thematic break
     intent and the two-em dash U+2E3B as its text, "> " a block quote intent with a paragraph inside
     it, a list a list intent with an item intent per entry carrying its ordinal from 1;
     the identities are numbered from 1 in document order, a container before the things it holds;
     a link carries NSLinkAttributeName with its URL resolved against the baseURL, an image
     NSImageURLAttributeName likewise, and a table is a table intent with its column count and the
     alignments of its header, a header row intent, a row intent per body row from 1 and a cell intent
     per cell with its column from 0 - the cells of a row follow one another with nothing between them;
     the span spans are NSInlinePresentationIntent: emphasized 1, strongly 2, code 4, strikethrough 32,
     a soft break 64 and a hard break 128, and the extended syntax is interpreted with the default
     options even though allowsExtendedAttributes answers NO.

   The key a link's URL rides under is the release's own string and not the C name that spells it, and
   this object carries that string under a name of its own. NSLinkAttributeName is declared in UIKit's
   copy of NSAttributedString.h and in no Foundation header, the 16.4 SDK exports it from UIKit and not
   from Foundation, and the device carries it in UIFoundation: read out of the armv7 dyld cache of
   6.1.3 itself, /System/Library/PrivateFrameworks/UIFoundation.framework/UIFoundation holds
   _NSLinkAttributeName among its external defined symbols, and its __TEXT,__cstring holds the family
   NSFontName NSFontSize NSFontTrait NSBaselineOffset NSAttachment NSLink NSCharacterShape - one string
   per attribute name, and the link's is NSLink and not NSLinkAttributeName.

   So the name is the release's and this library must not define it: a second definition of a data
   symbol the device already exports is a collision in a flat namespace. The Foundation library links
   Foundation, CoreFoundation and SystemConfiguration and nothing that carries the name, which is why
   a reference to it does not link here while the device has it all the same, and which is why the
   string is taken instead. The string is what an attributed string holds and what a caller reads back
   through the release's own NSLinkAttributeName, so carrying it is what makes the round trip answer.
   The shape is NSBundleResourceRequest.m's charon_manifest_tags_key - an Apple string under a name of
   our own - and the reason is the one NSLanguageIdentifierAttributeName already has here: for this
   key the name is not the value.

   What the port does not carry, measured and named rather than faked: NSListItemDelimiterAttributeName,
   which the system puts on a list item's run and which the SDK this port builds against (iPhoneOS16.5)
   does not declare, so the item's run carries its intent and not the delimiter. A
   NSAttributedStringMarkdownSourcePosition, which is 16.0 and not this release's, is carried in
   Foundation/NSAttributedStringMarkdownSourcePosition.m. The block kinds and
   the span spans above are what facts/Foundation/AttributedStrings15.md and the differential's own
   cases cover. */

#pragma mark - the options class

/* The options class whole, and no @interface beside it: the SDK this port builds against declares it
   with its five properties, and a redeclaration is a duplicate definition the gate fails on. What the
   class does is a copy of five values and a keyed archive of the same five - the keys are the SDK's own
   property names, read out of an archive the system's own class wrote. */
@implementation NSAttributedStringMarkdownParsingOptions

/* -init is the SDK's own declaration and NSObject's answer: an options object with everything at the
   default, which is measured - allowsExtendedAttributes NO, interpretedSyntax full, failurePolicy
   return the error, languageCode nil and appliesSourcePositionAttributes NO - and which is why the
   defaults are answered by allocation and not written out here. */

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

/* One block of the tree, with the text that belongs to it and the intent that names it. The tree is built
   in one pass over the lines, so a container's intent exists before the blocks it holds ask for it and
   the identities come out in document order without a second numbering pass. */
typedef NS_ENUM(NSInteger, CharonMarkdownKind) {
    CharonMarkdownParagraph,
    CharonMarkdownHeader,
    CharonMarkdownCodeBlock,
    CharonMarkdownThematicBreak,
    CharonMarkdownBlockQuote,
    CharonMarkdownList,
    CharonMarkdownTable,
};

typedef struct {
    NSUInteger start;          /* the first line of the block */
    NSUInteger end;            /* one past its last line */
    NSUInteger indent;         /* the columns of block structure above it */
    CharonMarkdownKind kind;
    NSInteger level;           /* a heading's level */
    BOOL ordered;              /* a list's */
    NSString *language;        /* a code block's info string, its language hint */
    NSPresentationIntent *intent;
    NSMutableArray *children;  /* the blocks it holds, each an NSValue of a CharonMarkdownBlock pointer */
} CharonMarkdownBlock;

static BOOL CharonMarkdownBlank(NSString *line)
{
    for (NSUInteger i = 0; i < line.length; i++)
        if (![[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[line characterAtIndex:i]])
            return NO;
    return YES;
}

/* The columns of leading spaces, a tab counting as the next multiple of four, which is what the release
   counts and what makes a tab-indented fence a fence. */
static NSUInteger CharonMarkdownIndent(NSString *line)
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

static NSString *CharonMarkdownTrimmed(NSString *line)
{
    return [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

static BOOL CharonMarkdownThematic(NSString *trimmed)
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

static BOOL CharonMarkdownFence(NSString *trimmed, unichar *fence, NSUInteger *count, NSString **info)
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

static NSInteger CharonMarkdownHeading(NSString *trimmed, NSString **text)
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

/* A list marker at the head of a line: the bullet, or an ordered number with its delimiter. */
static BOOL CharonMarkdownBullet(NSString *trimmed, BOOL *ordered, NSUInteger *width)
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

static BOOL CharonMarkdownDivider(NSString *trimmed)
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

static NSArray *CharonMarkdownCells(NSString *line, NSArray **alignments)
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
            /* A C call is not written inside a message's argument: [receiver addObject:[f(x)]] reads as a
               cast to the compiler, so the value is named first. The tree's own files hoist every one. */
            NSString *finished = CharonMarkdownTrimmed(cell);
            [cells addObject:finished];
            [cell setString:@""];
            continue;
        }
        [cell appendFormat:@"%C", c];
    }
    {
        NSString *last = CharonMarkdownTrimmed(cell);
        [cells addObject:last];
    }
    if (alignments) {
        /* The alignment is the one the divider declares, as the number the intent carries: 0 left, 1
           centre, 2 right, which is NSTextAlignment's own enumeration. The name of the enumeration is
           UIKit's on iOS and this file is Foundation's, and the intent takes an NSNumber either way.
           A table of "| - | - |" answers "left,left" on both sides, measured. */
        for (NSString *one in cells) {
            BOOL left = [one hasPrefix:@":"], right = [one hasSuffix:@":"];
            [found addObject:@(left && right ? 1 : right ? 2 : 0)];
        }
        *alignments = found;
    }
    return cells;
}

#pragma mark - the parser

@interface CharonMarkdownParser : NSObject {
    NSAttributedStringMarkdownParsingOptions *_options;
    NSURL *_baseURL;
    NSInteger _identity;
    NSMutableAttributedString *_result;
    NSString *_language;
}
- (id)initWithOptions:(NSAttributedStringMarkdownParsingOptions *)options baseURL:(NSURL *)baseURL;
- (NSAttributedString *)parse:(NSString *)markdown;
@end

@implementation CharonMarkdownParser

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

/* The one option that keeps the source's own spacing between two lines; the other two collapse it to a
   single separator space, which is what the release does with the default options (measured). */
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

/* The key a link's URL rides under, which is the release's own "NSLink" and not the C name that spells
   it. Why the name is not taken and where the string was read is at the head of this file. */
static NSString *const CharonMarkdownLinkKey = @"NSLink";

- (NSURL *)urlFor:(NSString *)text
{
    if (!text.length)
        return nil;
    if (!_baseURL)
        return [NSURL URLWithString:text];
    return [NSURL URLWithString:text relativeToURL:_baseURL];
}

/* The link or image destination: everything up to whitespace is the target and the rest, in quotes, is
   the title, which no attribute carries and which is dropped the way the release drops it. */
- (NSString *)targetIn:(NSString *)body
{
    NSString *trimmed = [body stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSRange quote = [trimmed rangeOfString:@" \""];
    if (quote.location != NSNotFound)
        trimmed = [trimmed substringToIndex:quote.location];
    return CharonMarkdownTrimmed(trimmed);
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

/* Where a bracketed run opened at `start` is closed, counting the nesting so a link inside a link's
   text is one run. Links nest ("[a [b](c)](d)"), so the depth is counted and not the first bracket
   taken, and an escaped bracket is not one. */
static NSUInteger CharonMarkdownBracketEnd(NSString *text, NSUInteger start, unichar open, unichar close, NSUInteger limit)
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

/* Where a run of `runLength` copies of a marker opened at `start` is closed, the way emphasis and the
   extended strikethrough close: an escaped marker is not one, and a run of a different length is not
   this one's. */
static NSUInteger CharonMarkdownMarkerEnd(NSString *text, NSUInteger start, unichar mark, NSUInteger runLength, NSUInteger limit)
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

/* Where a link or image destination opened after a `(` at `body` is closed. */
static BOOL CharonMarkdownParenEnd(NSString *text, NSUInteger body, NSUInteger limit, NSUInteger *at)
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

/* One emphasis-like span, and whether there was one: the character and how many copies of it open the
   span decide the value, so "*x*" is 1, "**x**" and "__x__" are 2 and "~~x~~" is 32. A marker that opens
   nothing - a lone "*", or a "~~" with no closing pair - is text, and the scan moves on by the run it
   did see so a following character is not skipped. */
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
    close = CharonMarkdownMarkerEnd(text, *index + runLength, c, runLength, limit);
    if (close == NSNotFound || close == *index + runLength)
        return NO;
    inner = *index + runLength;
    innerEnd = close;
    [self appendInline:text from:*plain to:*index intent:intent span:0 extra:nil];
    [self parseInlines:text from:inner to:innerEnd intent:intent];
    /* the span is one attribute over the runs inside it, which keep their own block intent and the
       nested spans among them */
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
        /* A hard break is two spaces or a backslash at the end of a line and a soft break is the newline
           itself. Neither the spaces nor the backslash is text: the release's own drops them, and a run
           that kept them would carry the break's marker as characters. */
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
            /* A soft break is one separator space and not the newline, measured: "one\ntwo" answers
               "one two" with a run of one space carrying NSInlinePresentationIntentSoftBreak. The
               options' own InlineOnlyPreservingWhitespace is the one that keeps the source's spacing,
               and there the newline is what the source has. A hard break is a line break in the answer
               either way. */
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
        /* a backslash escape: the escaped character is text and the backslash is not */
        if (c == '\\' && index + 1 < limit) {
            [self appendInline:text from:plain to:index intent:intent span:0 extra:nil];
            [_result appendAttributedString:
                [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%C", [text characterAtIndex:index + 1]]
                                               attributes:[self blockAttributes:intent span:0 extra:nil]]];
            index += 2;
            plain = index;
            continue;
        }
        /* a code span: the shortest run of backticks, closed by a run of the same length, with one space
           stripped from each end of the content the way the release strips it */
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
        /* emphasis and strong emphasis, and the extended strikethrough, which differ only in the
           character and in how many copies of it open the span */
        if (c == '*' || c == '_' || c == '~') {
            if ([self parseMarkerIn:text index:&index plain:&plain limit:limit intent:intent])
                continue;
        }
        /* an image: its alt text is text and the run carries NSImageURLAttributeName */
        if (c == '!' && index + 1 < limit && [text characterAtIndex:index + 1] == '[') {
            NSUInteger close = CharonMarkdownBracketEnd(text, index + 1, '[', ']', limit), at;
            if (close != NSNotFound && close + 1 < limit && [text characterAtIndex:close + 1] == '('
                && CharonMarkdownParenEnd(text, close + 2, limit, &at)) {
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
        /* a link */
        if (c == '[') {
            NSUInteger close = CharonMarkdownBracketEnd(text, index, '[', ']', limit), at;
            if (close != NSNotFound && close + 1 < limit && [text characterAtIndex:close + 1] == '('
                && CharonMarkdownParenEnd(text, close + 2, limit, &at)) {
                NSURL *url = [self urlFor:[self targetIn:[text substringWithRange:NSMakeRange(close + 2, at - close - 2)]]];
                if (url) {
                    [self appendInline:text from:plain to:index intent:intent span:0 extra:nil];
                    [self parseInlines:text from:index + 1 to:close intent:intent];
                    [_result addAttribute:CharonMarkdownLinkKey
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
        /* an autolink: <https://example.com> is a link whose text is its own address */
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
                                                                       extra:@{CharonMarkdownLinkKey: url}]]];
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

/* The lines of a document, split once. A line keeps its own trailing newline so a paragraph's text can
   be handed to the span pass with the breaks it really has. */
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
    /* a paragraph ends at the first line that starts another block, so the text is only handed on once
       the block that follows it is known */
    #define CharonFlushParagraph() do { \
        if (paragraph.length) { \
            NSPresentationIntent *intent = [NSPresentationIntent paragraphIntentWithIdentity:[self nextIdentity] nestedInsideIntent:item ?: parent]; \
            [self parseInlines:paragraph from:0 to:paragraph.length intent:intent]; \
            [paragraph setString:@""]; \
        } \
    } while (0)
    while (at < end) {
        NSString *line = [lines objectAtIndex:at];
        NSString *trimmed = CharonMarkdownTrimmed(line);
        NSUInteger indent = CharonMarkdownIndent(line);
        unichar fence;
        NSUInteger fenceCount;
        NSString *info;
        NSString *headerText;
        NSInteger level;
        BOOL ordered, bullet;
        NSUInteger bulletWidth;
        if (!trimmed.length) {
            CharonFlushParagraph();
            at++;
            continue;
        }
        /* a thematic break: three or more of one marker and nothing else, which is a paragraph's "---"
           only when it is a whole line of its own */
        if (CharonMarkdownThematic(trimmed)) {
            CharonFlushParagraph();
            NSPresentationIntent *intent = [NSPresentationIntent thematicBreakIntentWithIdentity:[self nextIdentity]
                                                                            nestedInsideIntent:parent];
            /* the release's own text for a break is the two-em dash and not three asterisks */
            [_result appendAttributedString:[[NSAttributedString alloc] initWithString:@"\u2E3B"
                                                                           attributes:[self blockAttributes:intent
                                                                                              span:0
                                                                                               extra:nil]]];
            at++;
            continue;
        }
        level = CharonMarkdownHeading(trimmed, &headerText);
        if (level) {
            CharonFlushParagraph();
            NSPresentationIntent *intent = [NSPresentationIntent headerIntentWithIdentity:[self nextIdentity]
                                                                                     level:level
                                                                        nestedInsideIntent:parent];
            [self parseInlines:headerText from:0 to:headerText.length intent:intent];
            at++;
            continue;
        }
        if (CharonMarkdownFence(trimmed, &fence, &fenceCount, &info)) {
            CharonFlushParagraph();
            NSPresentationIntent *intent = [NSPresentationIntent codeBlockIntentWithIdentity:[self nextIdentity]
                                                                             languageHint:info.length ? info : nil
                                                                          nestedInsideIntent:parent];
            NSMutableString *code = [NSMutableString string];
            NSUInteger body = at + 1, closing = end;
            while (body < end) {
                NSString *candidate = CharonMarkdownTrimmed([lines objectAtIndex:body]);
                NSUInteger run = 0;
                while (run < candidate.length && [candidate characterAtIndex:run] == fence)
                    run++;
                if (run >= fenceCount && CharonMarkdownTrimmed([candidate substringFromIndex:run]).length == 0) {
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
            CharonFlushParagraph();
            NSPresentationIntent *intent = [NSPresentationIntent codeBlockIntentWithIdentity:[self nextIdentity]
                                                                             languageHint:nil
                                                                          nestedInsideIntent:parent];
            NSMutableString *code = [NSMutableString string];
            while (at < end) {
                NSString *candidate = [lines objectAtIndex:at];
                if (CharonMarkdownBlank(candidate))
                    break;
                if (CharonMarkdownIndent(candidate) < 4)
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
            CharonFlushParagraph();
            NSPresentationIntent *intent = [NSPresentationIntent blockQuoteIntentWithIdentity:[self nextIdentity]
                                                                           nestedInsideIntent:parent];
            NSMutableArray *inner = [NSMutableArray array];
            NSUInteger body = at, last = at;
            while (body < end) {
                NSString *candidate = CharonMarkdownTrimmed([lines objectAtIndex:body]);
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
        /* a table: a divider line under a header line, and the divider is what makes it one */
        if ([trimmed hasPrefix:@"|"] && at + 1 < end && CharonMarkdownDivider(CharonMarkdownTrimmed([lines objectAtIndex:at + 1]))) {
            CharonFlushParagraph();
            NSArray<NSNumber *> *alignments = nil;
            NSArray *header = CharonMarkdownCells(line, &alignments);
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
                NSString *candidate = CharonMarkdownTrimmed([lines objectAtIndex:body]);
                if (![candidate hasPrefix:@"|"])
                    break;
                [rows addObject:CharonMarkdownCells([lines objectAtIndex:body], NULL)];
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
        bullet = CharonMarkdownBullet(trimmed, &ordered, &bulletWidth);
        if (bullet) {
            CharonFlushParagraph();
            NSPresentationIntent *list = ordered
                ? [NSPresentationIntent orderedListIntentWithIdentity:[self nextIdentity] nestedInsideIntent:parent]
                : [NSPresentationIntent unorderedListIntentWithIdentity:[self nextIdentity] nestedInsideIntent:parent];
            /* the items of one list are the consecutive lines that open with the same kind of marker at
               the same indent, and a blank line or a line of other text ends it the way the release
               ends it */
            {
                NSUInteger item = 0, body = at;
                while (body < end) {
                    NSString *candidate = [lines objectAtIndex:body];
                    NSString *candidateTrimmed = CharonMarkdownTrimmed(candidate);
                    BOOL candidateOrdered, isItem;
                    NSUInteger candidateWidth, candidateIndent = CharonMarkdownIndent(candidate);
                    NSPresentationIntent *itemIntent;
                    NSMutableArray *inner = [NSMutableArray array];
                    if (!candidateTrimmed.length) {
                        /* a blank line ends the list unless the line after it is an item of it */
                        NSUInteger look = body + 1;
                        if (look >= end)
                            break;
                        isItem = CharonMarkdownBullet(CharonMarkdownTrimmed([lines objectAtIndex:look]), &candidateOrdered, &candidateWidth)
                                 && candidateOrdered == ordered && CharonMarkdownIndent([lines objectAtIndex:look]) == candidateIndent;
                        if (!isItem)
                            break;
                        body++;
                        continue;
                    }
                    isItem = CharonMarkdownBullet(candidateTrimmed, &candidateOrdered, &candidateWidth)
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
                    /* a continuation line is one indented to the item's content, and a lazy paragraph
                       line is one that is not a block of its own */
                    while (body < end) {
                        NSString *next = [lines objectAtIndex:body];
                        NSString *nextTrimmed = CharonMarkdownTrimmed(next);
                        BOOL nextOrdered, nextIsItem;
                        NSUInteger nextWidth;
                        /* a line that opens the next item of this same list ends this one: without that
                           every entry would be one paragraph and the list would have an intent of its own
                           per entry, which is not the shape the release numbers them in (measured). */
                        nextIsItem = CharonMarkdownBullet(nextTrimmed, &nextOrdered, &nextWidth)
                                     && nextOrdered == ordered && CharonMarkdownIndent(next) == indent;
                        if (nextIsItem)
                            break;
                        if (!nextTrimmed.length)
                            break;
                        if (CharonMarkdownIndent(next) > indent) {
                            [inner addObject:[next substringFromIndex:MIN(indent + candidateWidth, next.length)]];
                            body++;
                            continue;
                        }
                        if (CharonMarkdownThematic(nextTrimmed) || CharonMarkdownHeading(nextTrimmed, NULL)
                            || [nextTrimmed characterAtIndex:0] == '>' || CharonMarkdownFence(nextTrimmed, NULL, NULL, NULL))
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
        /* anything else is a paragraph line, and a blank line or a block of its own ends it */
        if (paragraph.length)
            [paragraph appendString:@"\n"];
        [paragraph appendString:trimmed];
        at++;
    }
    CharonFlushParagraph();
    #undef CharonFlushParagraph
}

/* The document, whole. The result is built once, in document order, so the intents' identities come out
   numbered from 1 with a container before the things it holds - which is the order the release numbers
   them in, measured. */
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

/* The three ways a document arrives: a file, data, a string. All three read the same parser and answer
   the same string; they differ only in where the bytes come from and in what an unreadable one says.

   A document that cannot be read or decoded is a refusal, and the refusal is the release's own shape: nil
   and an NSError under NSURLErrorDomain / NSFileReadUnknownError, which is what
   -[NSString initWithContentsOfFile:encoding:error:] answers for bytes that are not text. The options'
   failurePolicy decides what happens instead: NSAttributedStringMarkdownParsingFailureReturnPartially
   ParsedIfPossible keeps the text that was read, and the default returns the error. */
static NSError *CharonMarkdownError(NSInteger code, NSString *reason)
{
    /* The release's own shape for a document it cannot read: NSCocoaErrorDomain and
       NSFileReadUnknownError, which is what -[NSString initWithContentsOfFile:encoding:error:] answers
       for bytes that are not text. A file that cannot be opened answers the reader's own error instead,
       passed through rather than rebuilt. */
    return [NSError errorWithDomain:NSCocoaErrorDomain
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: reason ?: @"The data could not be read."}];
}

@implementation NSAttributedString (CharonMarkdown15)

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
            *error = CharonMarkdownError(NSFileReadUnknownError, @"The data is not text in UTF-8.");
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
            *error = CharonMarkdownError(NSFileReadUnknownError, @"The Markdown string is nil.");
        return nil;
    }
    CharonMarkdownParser *parser = [[CharonMarkdownParser alloc] initWithOptions:options baseURL:baseURL];
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
            *error = read ?: CharonMarkdownError(NSFileReadNoSuchFileError, @"The Markdown file could not be read.");
        return nil;
    }
    return [self initWithMarkdownString:text options:options baseURL:baseURL error:error];
}

@end

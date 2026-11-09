#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "RevenantMarkdownParser.h"
#import "RevenantURLParser.h"

#pragma mark - the options class

@implementation NSAttributedStringMarkdownParsingOptions

@synthesize allowsExtendedAttributes = _allowsExtendedAttributes;
@synthesize interpretedSyntax = _interpretedSyntax;
@synthesize failurePolicy = _failurePolicy;
@synthesize languageCode = _languageCode;
@synthesize appliesSourcePositionAttributes = _appliesSourcePositionAttributes;

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

#pragma mark - the emitter

static NSString *const RevenantMarkdownLinkKey = @"NSLink";
static NSString *const RevenantMarkdownAlternateKey = @"NSAlternateDescription";
static NSString *const RevenantMarkdownDelimiterKey = @"NSListItemDelimiter";
static const NSUInteger RevenantMarkdownInlineHTML = 1 << 8;
static const NSUInteger RevenantMarkdownBlockHTML = 1 << 9;

@interface RevenantMarkdownEmitter : NSObject {
    NSAttributedStringMarkdownParsingOptions *_options;
    NSURL *_baseURL;
    NSInteger _identity;
    NSMutableAttributedString *_result;
    NSString *_language;
    NSUInteger _mask;
}
- (id)initWithOptions:(NSAttributedStringMarkdownParsingOptions *)options baseURL:(NSURL *)baseURL;
- (NSAttributedString *)emit:(NSString *)markdown;
@end

static NSString *RevenantMarkdownCString(NSString *text)
{
    return text.length && [text characterAtIndex:0] == 0xFEFF ? [text substringFromIndex:1] : text;
}

static BOOL RevenantMarkdownPlatformEncodesURLs(void)
{
    static BOOL encodes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        encodes = [NSURL URLWithString:@"a b"] != nil;
    });
    return encodes;
}

@implementation RevenantMarkdownEmitter

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

- (NSURL *)resolve:(NSString *)text
{
    return _baseURL ? [NSURL URLWithString:text relativeToURL:_baseURL] : [NSURL URLWithString:text];
}

- (NSURL *)urlFor:(NSString *)text
{
    if (!text.length)
        return nil;
    if (RevenantMarkdownPlatformEncodesURLs())
        return [self resolve:text];
    return revenant_url_reference(text, _baseURL);
}

- (void)append:(NSString *)text base:(NSDictionary *)base mask:(NSUInteger)mask extra:(NSDictionary *)extra
{
    if (!text.length)
        return;
    NSMutableDictionary *attributes = [base mutableCopy];
    if (_mask | mask)
        attributes[NSInlinePresentationIntentAttributeName] = @(_mask | mask);
    if (extra)
        [attributes addEntriesFromDictionary:extra];
    if (_language)
        attributes[NSLanguageIdentifierAttributeName] = _language;
    [_result appendAttributedString:[[NSAttributedString alloc] initWithString:text attributes:attributes]];
}

- (NSDictionary *)baseFor:(NSPresentationIntent *)intent delimiter:(NSString *)delimiter
{
    NSMutableDictionary *base = [NSMutableDictionary dictionary];
    if ([self carriesIntents] && intent)
        base[NSPresentationIntentAttributeName] = intent;
    if (delimiter)
        base[RevenantMarkdownDelimiterKey] = delimiter;
    return base;
}

- (void)flatten:(RevenantMarkdownNode *)node into:(NSMutableString *)text
{
    for (RevenantMarkdownNode *child = node->firstChild; child; child = child->next) {
        switch (child->kind) {
        case RevenantMarkdownText:
        case RevenantMarkdownCode:
        case RevenantMarkdownHTMLInline:
            [text appendString:RevenantMarkdownCString(child->literal) ?: @""];
            break;
        case RevenantMarkdownSoftBreak:
        case RevenantMarkdownLineBreak:
            break;
        default:
            [self flatten:child into:text];
            break;
        }
    }
}

- (void)emitSpan:(RevenantMarkdownNode *)node flag:(NSUInteger)flag base:(NSDictionary *)base extra:(NSDictionary *)extra
{
    _mask |= flag;
    [self emitInlines:node base:base mask:0 extra:extra];
    _mask &= ~flag;
}

- (void)emitInlines:(RevenantMarkdownNode *)parent base:(NSDictionary *)base mask:(NSUInteger)mask extra:(NSDictionary *)extra
{
    for (RevenantMarkdownNode *node = parent->firstChild; node; node = node->next) {
        switch (node->kind) {
        case RevenantMarkdownText:
            [self append:RevenantMarkdownCString(node->literal) base:base mask:mask extra:extra];
            break;
        case RevenantMarkdownSoftBreak:
            [self append:@" " base:base mask:mask | NSInlinePresentationIntentSoftBreak extra:extra];
            break;
        case RevenantMarkdownLineBreak:
            [self append:@"\n" base:base mask:mask | NSInlinePresentationIntentLineBreak extra:extra];
            break;
        case RevenantMarkdownCode:
            [self append:RevenantMarkdownCString(node->literal) base:base mask:mask | NSInlinePresentationIntentCode extra:extra];
            break;
        case RevenantMarkdownHTMLInline:
            [self append:node->literal base:base mask:mask | RevenantMarkdownInlineHTML extra:extra];
            break;
        case RevenantMarkdownEmphasis:
            [self emitSpan:node flag:NSInlinePresentationIntentEmphasized base:base extra:extra];
            break;
        case RevenantMarkdownStrong:
            [self emitSpan:node flag:NSInlinePresentationIntentStronglyEmphasized base:base extra:extra];
            break;
        case RevenantMarkdownStrikethrough:
            [self emitSpan:node flag:NSInlinePresentationIntentStrikethrough base:base extra:extra];
            break;
        case RevenantMarkdownLink:
        case RevenantMarkdownImage: {
            BOOL image = node->kind == RevenantMarkdownImage;
            NSMutableString *flat = [NSMutableString string];
            [self flatten:node into:flat];
            NSMutableDictionary *merged = extra ? [extra mutableCopy] : [NSMutableDictionary dictionary];
            NSURL *url = [self urlFor:RevenantMarkdownCString(node->destination)];
            if (url)
                merged[image ? NSImageURLAttributeName : RevenantMarkdownLinkKey] = url;
            NSString *title = RevenantMarkdownCString(node->title);
            if (title.length)
                merged[RevenantMarkdownAlternateKey] = title;
            if (image && !flat.length)
                [flat setString:@"\uFFFC"];
            [self append:flat base:base mask:mask extra:merged];
            break;
        }
        default:
            [self emitInlines:node base:base mask:mask extra:extra];
            break;
        }
    }
}

- (void)emitBlocks:(RevenantMarkdownNode *)parent intent:(NSPresentationIntent *)parentIntent delimiter:(NSString *)delimiter
{
    for (RevenantMarkdownNode *node = parent->firstChild; node; node = node->next) {
        switch (node->kind) {
        case RevenantMarkdownBlockQuote: {
            NSPresentationIntent *intent = [NSPresentationIntent blockQuoteIntentWithIdentity:[self nextIdentity] nestedInsideIntent:parentIntent];
            [self emitBlocks:node intent:intent delimiter:delimiter];
            break;
        }
        case RevenantMarkdownList: {
            NSPresentationIntent *list = node->ordered
                ? [NSPresentationIntent orderedListIntentWithIdentity:[self nextIdentity] nestedInsideIntent:parentIntent]
                : [NSPresentationIntent unorderedListIntentWithIdentity:[self nextIdentity] nestedInsideIntent:parentIntent];
            NSInteger ordinal = node->ordered ? node->start : 1;
            NSString *mark = [NSString stringWithCharacters:&node->marker length:1];
            for (RevenantMarkdownNode *item = node->firstChild; item; item = item->next, ordinal++) {
                NSPresentationIntent *itemIntent = [NSPresentationIntent listItemIntentWithIdentity:[self nextIdentity] ordinal:ordinal nestedInsideIntent:list];
                [self emitBlocks:item intent:itemIntent delimiter:mark];
            }
            break;
        }
        case RevenantMarkdownItem:
            [self emitBlocks:node intent:parentIntent delimiter:delimiter];
            break;
        case RevenantMarkdownCodeBlock: {
            NSString *info = RevenantMarkdownCString(node->info);
            NSString *hint = info.length ? info : nil;
            NSPresentationIntent *intent = [NSPresentationIntent codeBlockIntentWithIdentity:[self nextIdentity] languageHint:hint nestedInsideIntent:parentIntent];
            [self append:RevenantMarkdownCString(node->literal) base:[self baseFor:intent delimiter:delimiter] mask:0 extra:nil];
            break;
        }
        case RevenantMarkdownHTMLBlock:
            [self append:node->literal base:[self baseFor:parentIntent delimiter:delimiter] mask:RevenantMarkdownBlockHTML extra:nil];
            break;
        case RevenantMarkdownParagraph: {
            NSPresentationIntent *intent = [NSPresentationIntent paragraphIntentWithIdentity:[self nextIdentity] nestedInsideIntent:parentIntent];
            [self emitInlines:node base:[self baseFor:intent delimiter:delimiter] mask:0 extra:nil];
            break;
        }
        case RevenantMarkdownHeading: {
            NSPresentationIntent *intent = [NSPresentationIntent headerIntentWithIdentity:[self nextIdentity] level:node->level nestedInsideIntent:parentIntent];
            [self emitInlines:node base:[self baseFor:intent delimiter:delimiter] mask:0 extra:nil];
            break;
        }
        case RevenantMarkdownThematicBreak: {
            NSPresentationIntent *intent = [NSPresentationIntent thematicBreakIntentWithIdentity:[self nextIdentity] nestedInsideIntent:parentIntent];
            [self append:@"\u2E3B" base:[self baseFor:intent delimiter:delimiter] mask:0 extra:nil];
            break;
        }
        case RevenantMarkdownTable: {
            NSPresentationIntent *table = [NSPresentationIntent tableIntentWithIdentity:[self nextIdentity]
                                                                            columnCount:(NSUInteger)node->columnCount
                                                                             alignments:node->alignments
                                                                    nestedInsideIntent:parentIntent];
            NSInteger row = 0;
            for (RevenantMarkdownNode *line = node->firstChild; line; line = line->next, row++) {
                NSPresentationIntent *rowIntent = line->header
                    ? [NSPresentationIntent tableHeaderRowIntentWithIdentity:[self nextIdentity] nestedInsideIntent:table]
                    : [NSPresentationIntent tableRowIntentWithIdentity:[self nextIdentity] row:row nestedInsideIntent:table];
                NSInteger column = 0;
                for (RevenantMarkdownNode *cell = line->firstChild; cell; cell = cell->next, column++) {
                    NSPresentationIntent *cellIntent = [NSPresentationIntent tableCellIntentWithIdentity:[self nextIdentity] column:column nestedInsideIntent:rowIntent];
                    [self emitInlines:cell base:[self baseFor:cellIntent delimiter:delimiter] mask:0 extra:nil];
                }
            }
            break;
        }
        default:
            break;
        }
    }
}

- (NSAttributedString *)emit:(NSString *)markdown
{
    _result = [[NSMutableAttributedString alloc] init];
    _identity = 0;
    _mask = 0;
    if (!markdown.length)
        return _result;
    if ([self carriesIntents]) {
        RevenantMarkdownTree *tree = RevenantMarkdownParseDocument(markdown);
        [self emitBlocks:tree.root intent:nil delimiter:nil];
    } else {
        RevenantMarkdownTree *tree = RevenantMarkdownParseInlineOnly(markdown);
        [self emitInlines:tree.root->firstChild base:@{} mask:0 extra:nil];
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

static NSString *RevenantMarkdownDecode(NSData *data)
{
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    NSUInteger length = data.length, marks = 0;
    while (length >= marks * 3 + 3 && bytes[marks * 3] == 0xEF && bytes[marks * 3 + 1] == 0xBB && bytes[marks * 3 + 2] == 0xBF)
        marks++;
    NSString *body = [[NSString alloc] initWithBytes:bytes + marks * 3 length:length - marks * 3 encoding:NSUTF8StringEncoding];
    if (!body || !marks)
        return body;
    NSMutableString *text = [NSMutableString stringWithCapacity:marks + body.length];
    for (NSUInteger i = 0; i < marks; i++)
        [text appendFormat:@"%C", (unichar)0xFEFF];
    [text appendString:body];
    return text;
}

@implementation NSAttributedString (RevenantMarkdown15)

- (instancetype)initWithMarkdown:(NSData *)markdown
                        options:(NSAttributedStringMarkdownParsingOptions *)options
                        baseURL:(NSURL *)baseURL
                         error:(NSError **)error
{
    NSString *text = nil;
    if (markdown)
        text = RevenantMarkdownDecode(markdown);
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
    RevenantMarkdownEmitter *emitter = [[RevenantMarkdownEmitter alloc] initWithOptions:options baseURL:baseURL];
    return [self initWithAttributedString:[emitter emit:markdownString]];
}

- (instancetype)initWithContentsOfMarkdownFileAtURL:(NSURL *)markdownFile
                                            options:(NSAttributedStringMarkdownParsingOptions *)options
                                            baseURL:(NSURL *)baseURL
                                              error:(NSError **)error
{
    NSString *text = nil;
    NSError *read = nil;
    if (markdownFile) {
        NSData *data = [NSData dataWithContentsOfURL:markdownFile options:0 error:&read];
        if (data) {
            text = RevenantMarkdownDecode(data);
            if (!text)
                read = RevenantMarkdownError(NSFileReadInapplicableStringEncodingError, @"The file is not text in UTF-8.");
        }
    }
    if (!text) {
        if (error)
            *error = read ?: RevenantMarkdownError(NSFileReadNoSuchFileError, @"The Markdown file could not be read.");
        return nil;
    }
    return [self initWithMarkdownString:text options:options baseURL:baseURL error:error];
}

@end

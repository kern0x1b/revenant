#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

/* NSPresentationIntent (iOS 15.0) over the port's release.

   The class is a value: a kind, the identity the document gives it, its place in a tree of intents
   and the few numbers its kind carries. It is immutable, so the state is one object kept beside
   the instance -- the SDK's declaration carries no ivar block and the armv7 ABI has nowhere to add
   one. The rules, the archive keys, the indentation and the equality are the host's own, read out
   of it through tests/backports/host/presentationintent; facts/Foundation/NSPresentationIntent.md
   carries the measurements. */

/* The state of one intent. Private to this file, and the only class here that is not Apple's. */
@interface CharonPresentationIntentState : NSObject
@property NSInteger intentKind;
@property NSInteger identity;
@property NSPresentationIntent *parentIntent;
@property NSInteger ordinal;
@property NSInteger columnCount;
@property NSArray<NSNumber *> *columnAlignments;
@property NSInteger headerLevel;
@property NSInteger column;
@property NSInteger row;
@property NSString *languageHint;
@end

@implementation CharonPresentationIntentState

/* The port's own build refuses an implicitly synthesised property (-Wobjc-missing-property-synthesis),
   so each one is synthesised here by name rather than left to the compiler. */
@synthesize intentKind = _intentKind;
@synthesize identity = _identity;
@synthesize parentIntent = _parentIntent;
@synthesize ordinal = _ordinal;
@synthesize columnCount = _columnCount;
@synthesize columnAlignments = _columnAlignments;
@synthesize headerLevel = _headerLevel;
@synthesize column = _column;
@synthesize row = _row;
@synthesize languageHint = _languageHint;

@end

static char CharonPresentationIntentStateKey;

/* A list item and a block quote are the two kinds that hold a span of the document, and a span adds
   one level to everything under it. A paragraph and a thematic break are the two that answer 0
   whatever holds them -- the text of a list item is not indented inside it -- and so does anything
   with nothing above it. Measured over every chain of one, two and three kinds and over runs up to
   six spans on the host, through tests/backports/host/presentationintent. */
static BOOL charon_is_span(NSInteger kind)
{
    return kind == NSPresentationIntentKindListItem || kind == NSPresentationIntentKindBlockQuote;
}

static NSInteger charon_indentation_level(NSPresentationIntent *intent)
{
    /* The level is a step per span from the root down, so the chain is walked up once into a buffer
       and read back down: a chain as deep as an archive can nest costs memory, not stack. */
    NSUInteger capacity = 16, count = 0;
    NSPresentationIntent *__unsafe_unretained *chain = (NSPresentationIntent *__unsafe_unretained *)malloc(capacity * sizeof(*chain));
    if (!chain)
        return 0;
    for (NSPresentationIntent *node = intent; node;) {
        CharonPresentationIntentState *state = objc_getAssociatedObject(node, &CharonPresentationIntentStateKey);
        if (!state)
            break;
        if (count == capacity) {
            NSUInteger grown = capacity * 2;
            NSPresentationIntent *__unsafe_unretained *bigger = (NSPresentationIntent *__unsafe_unretained *)realloc(chain, grown * sizeof(*chain));
            if (!bigger) {
                free(chain);
                return 0;
            }
            chain = bigger;
            capacity = grown;
        }
        chain[count++] = node;
        node = state.parentIntent;
    }
    NSInteger level = 0;
    for (NSUInteger index = count; index-- > 0;) {
        /* The root of the chain is the one intent with nothing above it to be indented under. */
        if (index + 1 == count)
            continue;
        CharonPresentationIntentState *state = objc_getAssociatedObject(chain[index], &CharonPresentationIntentStateKey);
        NSInteger kind = state.intentKind;
        if (kind == NSPresentationIntentKindParagraph || kind == NSPresentationIntentKindThematicBreak)
            level = 0;
        else if (charon_is_span(kind))
            level += 1;
    }
    free(chain);
    return level;
}

static CharonPresentationIntentState *charon_state(NSPresentationIntent *intent)
{
    return objc_getAssociatedObject(intent, &CharonPresentationIntentStateKey);
}

static NSPresentationIntent *charon_intent(NSPresentationIntentKind kind, NSInteger identity, NSPresentationIntent *parent)
{
    NSPresentationIntent *intent = [NSPresentationIntent alloc];
    /* -init is NS_UNAVAILABLE in the SDK's own header, which is right: an intent is only ever made
       by the twelve factories. What -init would run is the superclass's, and NSObject's only
       returns self -- so that is what runs here, through the superclass's own dispatch. */
    struct objc_super super = { .receiver = intent, .super_class = [NSObject class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&super, @selector(init));
    CharonPresentationIntentState *state = [[CharonPresentationIntentState alloc] init];
    state.intentKind = kind;
    state.identity = identity;
    state.parentIntent = parent;
    state.ordinal = 0;
    state.columnCount = 0;
    state.headerLevel = 0;
    state.column = 0;
    state.row = 0;
    state.languageHint = nil;
    state.columnAlignments = nil;
    objc_setAssociatedObject(intent, &CharonPresentationIntentStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return intent;
}

@implementation NSPresentationIntent

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (NSPresentationIntent *)paragraphIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return charon_intent(NSPresentationIntentKindParagraph, identity, parent);
}

+ (NSPresentationIntent *)headerIntentWithIdentity:(NSInteger)identity level:(NSInteger)level nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = charon_intent(NSPresentationIntentKindHeader, identity, parent);
    charon_state(intent).headerLevel = level;
    return intent;
}

+ (NSPresentationIntent *)codeBlockIntentWithIdentity:(NSInteger)identity languageHint:(NSString *)languageHint nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = charon_intent(NSPresentationIntentKindCodeBlock, identity, parent);
    charon_state(intent).languageHint = [languageHint copy];
    return intent;
}

+ (NSPresentationIntent *)thematicBreakIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return charon_intent(NSPresentationIntentKindThematicBreak, identity, parent);
}

+ (NSPresentationIntent *)orderedListIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return charon_intent(NSPresentationIntentKindOrderedList, identity, parent);
}

+ (NSPresentationIntent *)unorderedListIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return charon_intent(NSPresentationIntentKindUnorderedList, identity, parent);
}

+ (NSPresentationIntent *)listItemIntentWithIdentity:(NSInteger)identity ordinal:(NSInteger)ordinal nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = charon_intent(NSPresentationIntentKindListItem, identity, parent);
    charon_state(intent).ordinal = ordinal;
    return intent;
}

+ (NSPresentationIntent *)blockQuoteIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return charon_intent(NSPresentationIntentKindBlockQuote, identity, parent);
}

+ (NSPresentationIntent *)tableIntentWithIdentity:(NSInteger)identity columnCount:(NSInteger)columnCount alignments:(NSArray<NSNumber *> *)alignments nestedInsideIntent:(NSPresentationIntent *)parent
{
    if ((NSInteger)alignments.count != columnCount)
        [NSException raise:NSInvalidArgumentException
                    format:@"*** +[NSPresentationIntent tableIntentWithIdentity:columnCount:alignments:nestedInsideIntent:]: column count does not match count of alignments"];
    NSPresentationIntent *intent = charon_intent(NSPresentationIntentKindTable, identity, parent);
    charon_state(intent).columnCount = columnCount;
    charon_state(intent).columnAlignments = [alignments copy];
    return intent;
}

+ (NSPresentationIntent *)tableHeaderRowIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return charon_intent(NSPresentationIntentKindTableHeaderRow, identity, parent);
}

+ (NSPresentationIntent *)tableRowIntentWithIdentity:(NSInteger)identity row:(NSInteger)row nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = charon_intent(NSPresentationIntentKindTableRow, identity, parent);
    charon_state(intent).row = row;
    return intent;
}

+ (NSPresentationIntent *)tableCellIntentWithIdentity:(NSInteger)identity column:(NSInteger)column nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = charon_intent(NSPresentationIntentKindTableCell, identity, parent);
    charon_state(intent).column = column;
    return intent;
}

- (NSPresentationIntentKind)intentKind
{
    return (NSPresentationIntentKind)charon_state(self).intentKind;
}

- (NSPresentationIntent *)parentIntent
{
    return charon_state(self).parentIntent;
}

- (NSInteger)identity
{
    return charon_state(self).identity;
}

- (NSInteger)ordinal
{
    return charon_state(self).ordinal;
}

- (NSArray<NSNumber *> *)columnAlignments
{
    return charon_state(self).columnAlignments;
}

- (NSInteger)columnCount
{
    return charon_state(self).columnCount;
}

- (NSInteger)headerLevel
{
    return charon_state(self).headerLevel;
}

- (NSString *)languageHint
{
    return charon_state(self).languageHint;
}

- (NSInteger)column
{
    return charon_state(self).column;
}

- (NSInteger)row
{
    return charon_state(self).row;
}

- (NSInteger)indentationLevel
{
    return charon_indentation_level(self);
}

- (id)copyWithZone:(NSZone *)zone
{
    /* The state is immutable once the factory has built it, so a copy shares it. */
    return self;
}

- (BOOL)isEqualToPresentationIntentIgnoringIdentity:(NSPresentationIntent *)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[NSPresentationIntent class]])
        return NO;
    CharonPresentationIntentState *mine = charon_state(self), *theirs = charon_state(other);
    if (!mine || !theirs)
        return NO;
    if (mine.intentKind != theirs.intentKind || mine.ordinal != theirs.ordinal || mine.column != theirs.column ||
        mine.row != theirs.row || mine.columnCount != theirs.columnCount || mine.headerLevel != theirs.headerLevel)
        return NO;
    if (mine.languageHint != theirs.languageHint && ![mine.languageHint isEqualToString:theirs.languageHint])
        return NO;
    if (mine.columnAlignments != theirs.columnAlignments && ![mine.columnAlignments isEqualToArray:theirs.columnAlignments])
        return NO;
    /* The parent is compared the same way, so two intents under equal parents are equal and the
       comparison reaches up the tree. Measured: an intent under a paragraph and one under a block
       quote are neither equal nor equivalent; two under equal paragraphs are. */
    NSPresentationIntent *myParent = mine.parentIntent, *theirParent = theirs.parentIntent;
    if (myParent == theirParent)
        return YES;
    if (!myParent || !theirParent)
        return NO;
    return [myParent isEquivalentToPresentationIntent:theirParent];
}

- (BOOL)isEquivalentToPresentationIntent:(NSPresentationIntent *)other
{
    if (other == self)
        return YES;
    if (![other isKindOfClass:[NSPresentationIntent class]])
        return NO;
    CharonPresentationIntentState *mine = charon_state(self), *theirs = charon_state(other);
    if (mine.identity != theirs.identity)
        return NO;
    return [self isEqualToPresentationIntentIgnoringIdentity:other];
}

- (BOOL)isEqual:(id)object
{
    if (object == self)
        return YES;
    if (![object isKindOfClass:[NSPresentationIntent class]])
        return NO;
    return [self isEquivalentToPresentationIntent:object];
}

/* A mixing of everything two equal intents share, so that equal intents hash equal -- which is the
   whole of what -hash owes. The host's own numbers are a private mixing of the same fields and are
   not part of the API; facts/Foundation/NSPresentationIntent.md says so. */
- (NSUInteger)hash
{
    CharonPresentationIntentState *state = charon_state(self);
    NSUInteger hash = (NSUInteger)state.intentKind * 31 + (NSUInteger)state.identity;
    hash = hash * 31 + (NSUInteger)state.ordinal;
    hash = hash * 31 + (NSUInteger)state.headerLevel;
    hash = hash * 31 + (NSUInteger)state.columnCount;
    hash = hash * 31 + (NSUInteger)state.row;
    hash = hash * 31 + (NSUInteger)state.column;
    hash = hash * 31 + state.languageHint.hash;
    for (NSNumber *alignment in state.columnAlignments)
        hash = hash * 31 + alignment.hash;
    NSPresentationIntent *parent = state.parentIntent;
    hash = hash * 31 + (parent ? (parent.intentKind * 31 + parent.identity) : 0);
    return hash;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSPresentationIntent cannot be encoded by non-keyed archivers"];
        return;
    }
    CharonPresentationIntentState *state = charon_state(self);
    [coder encodeInteger:state.intentKind forKey:@"NS.intentKind"];
    [coder encodeInteger:state.identity forKey:@"NS.identity"];
    [coder encodeInteger:state.ordinal forKey:@"NS.ordinal"];
    [coder encodeInteger:state.columnCount forKey:@"NS.columnCount"];
    [coder encodeObject:state.columnAlignments forKey:@"NS.columnAlignments"];
    [coder encodeInteger:state.headerLevel forKey:@"NS.headerLevel"];
    [coder encodeObject:state.languageHint forKey:@"NS.languageHint"];
    [coder encodeInteger:state.row forKey:@"NS.row"];
    [coder encodeInteger:state.column forKey:@"NS.column"];
    [coder encodeInteger:self.indentationLevel forKey:@"NS.indentationLevel"];
    [coder encodeObject:state.parentIntent forKey:@"NS.parentIntent"];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if (!coder.allowsKeyedCoding) {
        [NSException raise:NSInvalidArgumentException format:@"NSPresentationIntent cannot be decoded by non-keyed archivers"];
        return nil;
    }
    self = [super init];
    if (!self)
        return nil;
    CharonPresentationIntentState *state = [[CharonPresentationIntentState alloc] init];
    state.intentKind = [coder decodeIntegerForKey:@"NS.intentKind"];
    state.identity = [coder decodeIntegerForKey:@"NS.identity"];
    state.ordinal = [coder decodeIntegerForKey:@"NS.ordinal"];
    state.columnCount = [coder decodeIntegerForKey:@"NS.columnCount"];
    state.columnAlignments = [coder decodeObjectOfClass:[NSArray class] forKey:@"NS.columnAlignments"];
    state.headerLevel = [coder decodeIntegerForKey:@"NS.headerLevel"];
    state.languageHint = [coder decodeObjectOfClass:[NSString class] forKey:@"NS.languageHint"];
    state.row = [coder decodeIntegerForKey:@"NS.row"];
    state.column = [coder decodeIntegerForKey:@"NS.column"];
    state.parentIntent = [coder decodeObjectOfClass:[NSPresentationIntent class] forKey:@"NS.parentIntent"];
    objc_setAssociatedObject(self, &CharonPresentationIntentStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (NSString *)description
{
    CharonPresentationIntentState *state = charon_state(self);
    return [NSString stringWithFormat:@"<%@: %p identity %ld kind %ld ordinal %ld level %ld>",
            NSStringFromClass([self class]), self, (long)state.identity, (long)state.intentKind,
            (long)state.ordinal, (long)self.indentationLevel];
}

@end

#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import "../revenant_alias.h"

@interface RevenantPresentationIntentState : NSObject
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

@implementation RevenantPresentationIntentState

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

static char RevenantPresentationIntentStateKey;

static BOOL revenant_is_span(NSInteger kind)
{
    return kind == NSPresentationIntentKindListItem || kind == NSPresentationIntentKindBlockQuote;
}

static NSInteger revenant_indentation_level(id intent)
{
    NSUInteger capacity = 16, count = 0;
    NSPresentationIntent *__unsafe_unretained *chain = (NSPresentationIntent *__unsafe_unretained *)malloc(capacity * sizeof(*chain));
    if (!chain)
        return 0;
    for (NSPresentationIntent *node = intent; node;) {
        RevenantPresentationIntentState *state = objc_getAssociatedObject(node, &RevenantPresentationIntentStateKey);
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
        if (index + 1 == count)
            continue;
        RevenantPresentationIntentState *state = objc_getAssociatedObject(chain[index], &RevenantPresentationIntentStateKey);
        NSInteger kind = state.intentKind;
        if (kind == NSPresentationIntentKindParagraph || kind == NSPresentationIntentKindThematicBreak)
            level = 0;
        else if (revenant_is_span(kind))
            level += 1;
    }
    free(chain);
    return level;
}

static RevenantPresentationIntentState *revenant_state(id intent)
{
    return objc_getAssociatedObject(intent, &RevenantPresentationIntentStateKey);
}

static NSPresentationIntent *revenant_intent(NSPresentationIntentKind kind, NSInteger identity, id parent)
{
    NSPresentationIntent *intent = [NSPresentationIntent alloc];
    struct objc_super super = { .receiver = intent, .super_class = [NSObject class] };
    ((void (*)(struct objc_super *, SEL))objc_msgSendSuper)(&super, @selector(init));
    RevenantPresentationIntentState *state = [[RevenantPresentationIntentState alloc] init];
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
    objc_setAssociatedObject(intent, &RevenantPresentationIntentStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return intent;
}

REVENANT_ALIAS(NSPresentationIntent)

@implementation REVENANT_ALIAS_CLASS(NSPresentationIntent) (RevenantBackport)

+ (BOOL)supportsSecureCoding
{
    return YES;
}

+ (NSPresentationIntent *)paragraphIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return revenant_intent(NSPresentationIntentKindParagraph, identity, parent);
}

+ (NSPresentationIntent *)headerIntentWithIdentity:(NSInteger)identity level:(NSInteger)level nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = revenant_intent(NSPresentationIntentKindHeader, identity, parent);
    revenant_state(intent).headerLevel = level;
    return intent;
}

+ (NSPresentationIntent *)codeBlockIntentWithIdentity:(NSInteger)identity languageHint:(NSString *)languageHint nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = revenant_intent(NSPresentationIntentKindCodeBlock, identity, parent);
    revenant_state(intent).languageHint = [languageHint copy];
    return intent;
}

+ (NSPresentationIntent *)thematicBreakIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return revenant_intent(NSPresentationIntentKindThematicBreak, identity, parent);
}

+ (NSPresentationIntent *)orderedListIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return revenant_intent(NSPresentationIntentKindOrderedList, identity, parent);
}

+ (NSPresentationIntent *)unorderedListIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return revenant_intent(NSPresentationIntentKindUnorderedList, identity, parent);
}

+ (NSPresentationIntent *)listItemIntentWithIdentity:(NSInteger)identity ordinal:(NSInteger)ordinal nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = revenant_intent(NSPresentationIntentKindListItem, identity, parent);
    revenant_state(intent).ordinal = ordinal;
    return intent;
}

+ (NSPresentationIntent *)blockQuoteIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return revenant_intent(NSPresentationIntentKindBlockQuote, identity, parent);
}

+ (NSPresentationIntent *)tableIntentWithIdentity:(NSInteger)identity columnCount:(NSInteger)columnCount alignments:(NSArray<NSNumber *> *)alignments nestedInsideIntent:(NSPresentationIntent *)parent
{
    if ((NSInteger)alignments.count != columnCount)
        [NSException raise:NSInvalidArgumentException
                    format:@"*** +[NSPresentationIntent tableIntentWithIdentity:columnCount:alignments:nestedInsideIntent:]: column count does not match count of alignments"];
    NSPresentationIntent *intent = revenant_intent(NSPresentationIntentKindTable, identity, parent);
    revenant_state(intent).columnCount = columnCount;
    revenant_state(intent).columnAlignments = [alignments copy];
    return intent;
}

+ (NSPresentationIntent *)tableHeaderRowIntentWithIdentity:(NSInteger)identity nestedInsideIntent:(NSPresentationIntent *)parent
{
    return revenant_intent(NSPresentationIntentKindTableHeaderRow, identity, parent);
}

+ (NSPresentationIntent *)tableRowIntentWithIdentity:(NSInteger)identity row:(NSInteger)row nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = revenant_intent(NSPresentationIntentKindTableRow, identity, parent);
    revenant_state(intent).row = row;
    return intent;
}

+ (NSPresentationIntent *)tableCellIntentWithIdentity:(NSInteger)identity column:(NSInteger)column nestedInsideIntent:(NSPresentationIntent *)parent
{
    NSPresentationIntent *intent = revenant_intent(NSPresentationIntentKindTableCell, identity, parent);
    revenant_state(intent).column = column;
    return intent;
}

- (NSPresentationIntentKind)intentKind
{
    return (NSPresentationIntentKind)revenant_state(self).intentKind;
}

- (NSPresentationIntent *)parentIntent
{
    return revenant_state(self).parentIntent;
}

- (NSInteger)identity
{
    return revenant_state(self).identity;
}

- (NSInteger)ordinal
{
    return revenant_state(self).ordinal;
}

- (NSArray<NSNumber *> *)columnAlignments
{
    return revenant_state(self).columnAlignments;
}

- (NSInteger)columnCount
{
    return revenant_state(self).columnCount;
}

- (NSInteger)headerLevel
{
    return revenant_state(self).headerLevel;
}

- (NSString *)languageHint
{
    return revenant_state(self).languageHint;
}

- (NSInteger)column
{
    return revenant_state(self).column;
}

- (NSInteger)row
{
    return revenant_state(self).row;
}

- (NSInteger)indentationLevel
{
    return revenant_indentation_level(self);
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (BOOL)isEqualToPresentationIntentIgnoringIdentity:(NSPresentationIntent *)other
{
    if ((id)other == self)
        return YES;
    if (![other isKindOfClass:[NSPresentationIntent class]])
        return NO;
    RevenantPresentationIntentState *mine = revenant_state(self), *theirs = revenant_state(other);
    if (!mine || !theirs)
        return NO;
    if (mine.intentKind != theirs.intentKind || mine.ordinal != theirs.ordinal || mine.column != theirs.column ||
        mine.row != theirs.row || mine.columnCount != theirs.columnCount || mine.headerLevel != theirs.headerLevel)
        return NO;
    if (mine.languageHint != theirs.languageHint && ![mine.languageHint isEqualToString:theirs.languageHint])
        return NO;
    if (mine.columnAlignments != theirs.columnAlignments && ![mine.columnAlignments isEqualToArray:theirs.columnAlignments])
        return NO;
    NSPresentationIntent *myParent = mine.parentIntent, *theirParent = theirs.parentIntent;
    if (myParent == theirParent)
        return YES;
    if (!myParent || !theirParent)
        return NO;
    return [myParent isEquivalentToPresentationIntent:theirParent];
}

- (BOOL)isEquivalentToPresentationIntent:(NSPresentationIntent *)other
{
    if ((id)other == self)
        return YES;
    if (![other isKindOfClass:[NSPresentationIntent class]])
        return NO;
    RevenantPresentationIntentState *mine = revenant_state(self), *theirs = revenant_state(other);
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

- (NSUInteger)hash
{
    RevenantPresentationIntentState *state = revenant_state(self);
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
    RevenantPresentationIntentState *state = revenant_state(self);
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
    RevenantPresentationIntentState *state = [[RevenantPresentationIntentState alloc] init];
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
    objc_setAssociatedObject(self, &RevenantPresentationIntentStateKey, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (NSString *)description
{
    RevenantPresentationIntentState *state = revenant_state(self);
    return [NSString stringWithFormat:@"<%@: %p identity %ld kind %ld ordinal %ld level %ld>",
            NSStringFromClass([self class]), self, (long)state.identity, (long)state.intentKind,
            (long)state.ordinal, (long)self.indentationLevel];
}

@end

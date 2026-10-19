// NSTextContentManager: the root of TextKit 2's object network. It holds the layout managers, the primary one,
// the editing transaction, and the record of what each edit did - and the parts of it that are about the
// document's contents are the concrete subclass's, which is NSTextContentStorage. What the header declares is
// NSTextContentManager.h of SDK 26.2; what the host's own UIKit answers is in facts/UIKit/NSTextContent15.md.
//
// The manager is the one object that holds the rest: an array of NSTextLayoutManager, of which one is the
// primary - the one the user is interacting with and therefore the one that may edit. Everything here is either
// that bookkeeping or the transaction, and the transaction is the interesting part: it nests, the outermost one
// is what -hasEditingTransaction reports, and leaving it is what sends the synchronisation the two flags ask
// for. The header says a synchronisation asked for inside a transaction should block, or fail if it is
// synchronous; the host does neither - it asks nothing of the caller and raises nothing (M11) - and the port does
// neither either, which is the divergence M11 records rather than corrects.

#import <UIKit/UIKit.h>

@implementation NSTextContentManager {
    // The layout managers, and the transactions as a depth rather than a list: what a nested transaction has to
    // know is how deep it is, and the depth is what the outermost one acts on.
    NSMutableArray<NSTextLayoutManager *> *_textLayoutManagers;
    NSUInteger _transactionDepth;
    // What each edit did, in the order it was recorded, for the layout managers to read when they synchronise.
    NSMutableArray<NSArray *> *_editActions;
    // The one the user is interacting with, which is the one that may edit. Strong, because the header says the
    // manager holds the network: a primary that the manager did not hold would not be the one editing.
    NSTextLayoutManager *_primaryTextLayoutManager;
}

// The getter is written out as well as the setter, because a property with a user-defined setter cannot have a
// synthesized one and the header does not ask for atomicity that a manager's primary does not need.
- (NSTextLayoutManager *)primaryTextLayoutManager
{
    return _primaryTextLayoutManager;
}

@synthesize delegate = _delegate;
@synthesize automaticallySynchronizesTextLayoutManagers = _automaticallySynchronizesTextLayoutManagers;
@synthesize automaticallySynchronizesToBackingStore = _automaticallySynchronizesToBackingStore;

- (instancetype)init
{
    if ((self = [super init])) {
        _textLayoutManagers = [NSMutableArray array];
        _editActions = [NSMutableArray array];
        // The header's own defaults: the layout managers are synchronised when the outermost transaction ends,
        // and the backing store is not.
        _automaticallySynchronizesTextLayoutManagers = YES;
        _automaticallySynchronizesToBackingStore = NO;
    }
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    if ((self = [super init])) {
        _textLayoutManagers = [NSMutableArray array];
        _editActions = [NSMutableArray array];
        _automaticallySynchronizesTextLayoutManagers =
            [coder containsValueForKey:@"automaticallySynchronizesTextLayoutManagers"]
                ? [coder decodeBoolForKey:@"automaticallySynchronizesTextLayoutManagers"]
                : YES;
        _automaticallySynchronizesToBackingStore = [coder decodeBoolForKey:@"automaticallySynchronizesToBackingStore"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    [coder encodeBool:_automaticallySynchronizesTextLayoutManagers forKey:@"automaticallySynchronizesTextLayoutManagers"];
    [coder encodeBool:_automaticallySynchronizesToBackingStore forKey:@"automaticallySynchronizesToBackingStore"];
}

#pragma mark - Layout managers

- (NSArray<NSTextLayoutManager *> *)textLayoutManagers
{
    return [_textLayoutManagers copy];
}

- (void)addTextLayoutManager:(NSTextLayoutManager *)textLayoutManager
{
    if (!textLayoutManager || [_textLayoutManagers containsObject:textLayoutManager])
        return;
    [_textLayoutManagers addObject:textLayoutManager];
    // The first one added is the primary unless something else has been set, which is the header's own reading
    // of a manager with a user interacting through it.
    if (!_primaryTextLayoutManager)
        _primaryTextLayoutManager = textLayoutManager;
}

- (void)removeTextLayoutManager:(NSTextLayoutManager *)textLayoutManager
{
    if (!textLayoutManager || ![_textLayoutManagers containsObject:textLayoutManager])
        return;
    [_textLayoutManagers removeObject:textLayoutManager];
    // A primary that is gone is nil, and not the next one: the header says setting a layout manager that is not
    // in the list resets it to nil, and removal is the same statement about a manager that is no longer there.
    if (_primaryTextLayoutManager == textLayoutManager)
        _primaryTextLayoutManager = nil;
}

// The getter is the synthesized one; the setter is written out because the header gives it three rules: a
// manager that is not in the list resets it to nil, pending edits are synchronized before it moves, and the
// operation is synchronous.
- (void)setPrimaryTextLayoutManager:(NSTextLayoutManager *)primaryTextLayoutManager
{
    if (primaryTextLayoutManager && ![_textLayoutManagers containsObject:primaryTextLayoutManager]) {
        _primaryTextLayoutManager = nil;
        return;
    }
    if (_primaryTextLayoutManager == primaryTextLayoutManager)
        return;
    // The header: pending edits are synchronised before the primary moves, and the operation is synchronous.
    if (_transactionDepth == 0)
        [self synchronizeTextLayoutManagers:nil];
    _primaryTextLayoutManager = primaryTextLayoutManager;
}

#pragma mark - Elements

// The three the element provider declares, which the concrete subclass - NSTextContentStorage - is what gives
// an answer to. The abstract manager holds no document, so it answers the only way a document that is not there
// can be answered: no range, no elements, and nothing to replace. The protocol types documentRange nonnull,
// which is a statement about a concrete manager, and the divergence is recorded rather than papered over with a
// range over a location of no document.
- (NSTextRange *)documentRange
{
    return nil;
}

- (id<NSTextLocation>)enumerateTextElementsFromLocation:(id<NSTextLocation>)textLocation
                                                options:(NSTextContentManagerEnumerationOptions)options
                                             usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextElement *element))block
{
    // The header's return is the edge the enumeration reached, and an enumeration of a document that is not there
    // reached nothing, so there is no edge to return.
    return nil;
}

- (void)replaceContentsInRange:(NSTextRange *)range withTextElements:(NSArray<NSTextElement *> *)textElements
{
}

- (NSArray<NSTextElement *> *)textElementsForRange:(NSTextRange *)range
{
    if (!range)
        return @[];
    // The header says it is the elements intersecting the range, in sequence, and that it can return a set that
    // does not fill the range when the range is not synchronously available. The concrete subclass enumerates
    // from the range's start; the base class has no contents of its own, so it answers none.
    return @[];
}

#pragma mark - Transactions

- (BOOL)hasEditingTransaction
{
    return _transactionDepth > 0;
}

- (void)performEditingTransactionUsingBlock:(void (NS_NOESCAPE ^)(void))transaction
{
    if (!transaction)
        return;
    BOOL outermost = _transactionDepth == 0;
    _transactionDepth++;
    @try {
        transaction();
    } @finally {
        // The depth comes back down whatever the transaction did, including raising: a transaction that raised
        // halfway is still a transaction that was entered, and leaving -hasEditingTransaction YES for ever
        // because of it would block every synchronisation from then on.
        _transactionDepth--;
        if (outermost && _transactionDepth == 0)
            [self charon_finish_outermost_transaction];
    }
}

// What leaving the outermost transaction does: the two synchronisations the flags ask for, in the header's
// order, the layout managers first and then the backing store, and the record of what the transaction did goes
// with them, because a layout manager that is synchronised has to be told what was edited.
- (void)charon_finish_outermost_transaction
{
    if (_automaticallySynchronizesTextLayoutManagers)
        [self synchronizeTextLayoutManagers:nil];
    if (_automaticallySynchronizesToBackingStore)
        [self synchronizeToBackingStore:nil];
    [_editActions removeAllObjects];
}

- (void)recordEditActionInRange:(NSTextRange *)originalTextRange newTextRange:(NSTextRange *)newTextRange
{
    // An edit action is a pair of ranges, and a record with one of them missing is not an edit action: the host
    // raises NSInvalidArgumentException for it, so this does the same rather than quietly recording nothing.
    if (!originalTextRange || !newTextRange) {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@ records an edit action with %@ and %@", NSStringFromClass([self class]),
                           originalTextRange ? @"a range" : @"no range", newTextRange ? @"a range" : @"no range"];
        return;
    }
    [_editActions addObject:@[ originalTextRange, newTextRange ]];
}

// The synchronisation the layout managers are asked for. The header says it blocks, or fails when synchronous,
// while there is an active transaction; the host answers neither - it asks nothing of the caller and raises
// nothing, measured (M11) - so this does the same, and the divergence is recorded rather than corrected. A
// caller that synchronises inside its own transaction gets that transaction's own state back, which is what the
// host gives it.
- (void)synchronizeTextLayoutManagers:(void (^)(NSError *_Nullable error))completionHandler
{
    // The base class has no backing store to synchronize, so there is nothing to report either way.
    if (completionHandler)
        completionHandler(nil);
}

- (void)synchronizeToBackingStore:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(nil);
}

// The host's own text for a manager, which is the class and the address and nothing else, measured. A description
// that says more than the system's is a difference a caller reading a log would have to know about, so this says
// what the system says and the state is read through the properties.
- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>", NSStringFromClass([self class]), self];
}

@end

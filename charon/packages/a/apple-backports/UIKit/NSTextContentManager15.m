#import <UIKit/UIKit.h>

@implementation NSTextContentManager {
    NSMutableArray<NSTextLayoutManager *> *_textLayoutManagers;
    NSUInteger _transactionDepth;
    NSMutableArray<NSArray *> *_editActions;
    NSTextLayoutManager *_primaryTextLayoutManager;
}

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
    if (!_primaryTextLayoutManager)
        _primaryTextLayoutManager = textLayoutManager;
}

- (void)removeTextLayoutManager:(NSTextLayoutManager *)textLayoutManager
{
    if (!textLayoutManager || ![_textLayoutManagers containsObject:textLayoutManager])
        return;
    [_textLayoutManagers removeObject:textLayoutManager];
    if (_primaryTextLayoutManager == textLayoutManager)
        _primaryTextLayoutManager = nil;
}

- (void)setPrimaryTextLayoutManager:(NSTextLayoutManager *)primaryTextLayoutManager
{
    if (primaryTextLayoutManager && ![_textLayoutManagers containsObject:primaryTextLayoutManager]) {
        _primaryTextLayoutManager = nil;
        return;
    }
    if (_primaryTextLayoutManager == primaryTextLayoutManager)
        return;
    if (_transactionDepth == 0)
        [self synchronizeTextLayoutManagers:nil];
    _primaryTextLayoutManager = primaryTextLayoutManager;
}

#pragma mark - Elements

- (NSTextRange *)documentRange
{
    return nil;
}

- (id<NSTextLocation>)enumerateTextElementsFromLocation:(id<NSTextLocation>)textLocation
                                                options:(NSTextContentManagerEnumerationOptions)options
                                             usingBlock:(BOOL (NS_NOESCAPE ^)(NSTextElement *element))block
{
    return nil;
}

- (void)replaceContentsInRange:(NSTextRange *)range withTextElements:(NSArray<NSTextElement *> *)textElements
{
}

- (NSArray<NSTextElement *> *)textElementsForRange:(NSTextRange *)range
{
    if (!range)
        return @[];
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
        _transactionDepth--;
        if (outermost && _transactionDepth == 0)
            [self charon_finish_outermost_transaction];
    }
}

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
    if (!originalTextRange || !newTextRange) {
        [NSException raise:NSInvalidArgumentException
                    format:@"%@ records an edit action with %@ and %@", NSStringFromClass([self class]),
                           originalTextRange ? @"a range" : @"no range", newTextRange ? @"a range" : @"no range"];
        return;
    }
    [_editActions addObject:@[ originalTextRange, newTextRange ]];
}

- (void)synchronizeTextLayoutManagers:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(nil);
}

- (void)synchronizeToBackingStore:(void (^)(NSError *_Nullable error))completionHandler
{
    if (completionHandler)
        completionHandler(nil);
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: %p>", NSStringFromClass([self class]), self];
}

@end

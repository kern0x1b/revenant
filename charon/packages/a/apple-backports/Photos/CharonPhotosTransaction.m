#import "CharonPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

// Photos applies a change block as one unit, so a request may name an object another request of the block creates, in
// whichever order the block made them. A change writes what it makes in charon_commit; what relates it to another
// object (an album's assets) waits for charon_commitRelations, which runs once every change of the block has committed.
@protocol CharonPhotosChange <NSObject>
- (BOOL)charon_validate:(NSError **)error;
- (BOOL)charon_commit:(NSError **)error;
@optional
- (BOOL)charon_commitRelations:(NSError **)error;
@end

static NSString *const CharonPhotosTransactionKey = @"space.kern0x1b.photos.transaction";

@implementation CharonPhotosTransaction {
    NSMutableArray *_changes;
    NSString *_refusal;
}

+ (CharonPhotosTransaction *)current
{
    return [NSThread currentThread].threadDictionary[CharonPhotosTransactionKey];
}

+ (CharonPhotosTransaction *)begin
{
    CharonPhotosTransaction *transaction = [[self alloc] init];
    transaction->_changes = [NSMutableArray array];
    [NSThread currentThread].threadDictionary[CharonPhotosTransactionKey] = transaction;
    return transaction;
}

+ (void)end
{
    [[NSThread currentThread].threadDictionary removeObjectForKey:CharonPhotosTransactionKey];
}

- (void)addChange:(id)change
{
    [_changes addObject:change];
}

- (NSArray *)changes
{
    return _changes;
}

- (void)refuseWithReason:(NSString *)reason
{
    _refusal = _refusal ?: reason;
}

- (BOOL)commit:(NSError **)error
{
    ALAuthorizationStatus status = [ALAssetsLibrary authorizationStatus];
    if (status == ALAuthorizationStatusDenied || status == ALAuthorizationStatusRestricted) {
        if (error)
            *error = [CharonPhotosStore errorWithCode:status == ALAuthorizationStatusDenied ? PHPhotosErrorAccessUserDenied : PHPhotosErrorAccessRestricted
                                               reason:@"the application is not allowed to change the photo library"];
        return NO;
    }
    if (_refusal) {
        if (error)
            *error = [CharonPhotosStore errorWithCode:PHPhotosErrorChangeNotSupported reason:_refusal];
        return NO;
    }
    for (id<CharonPhotosChange> change in _changes) {
        if (![change charon_validate:error])
            return NO;
    }
    for (id<CharonPhotosChange> change in _changes) {
        if (![change charon_commit:error])
            return NO;
    }
    for (id<CharonPhotosChange> change in _changes) {
        if ([change respondsToSelector:@selector(charon_commitRelations:)] && ![change charon_commitRelations:error])
            return NO;
    }
    return YES;
}

+ (BOOL)runAndWait:(dispatch_block_t)changes error:(NSError **)error
{
    CharonPhotosTransaction *transaction = [self begin];
    @try {
        changes();
    } @finally {
        [self end];
    }
    return [transaction commit:error];
}

+ (void)run:(dispatch_block_t)changes then:(void (^)(BOOL success, NSError *error))completion
{
    dispatch_block_t kept = [changes copy];
    void (^handler)(BOOL, NSError *) = [completion copy];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        BOOL success = [self runAndWait:kept error:&error];
        if (handler)
            handler(success, success ? nil : error);
    });
}

@end

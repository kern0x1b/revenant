#import "RevenantPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

@protocol RevenantPhotosChange <NSObject>
- (BOOL)revenant_validate:(NSError **)error;
- (BOOL)revenant_commit:(NSError **)error;
@optional
- (BOOL)revenant_commitRelations:(NSError **)error;
@end

static NSString *const RevenantPhotosTransactionKey = @"space.kern0x1b.photos.transaction";

@implementation RevenantPhotosTransaction {
    NSMutableArray *_changes;
    NSString *_refusal;
}

+ (RevenantPhotosTransaction *)current
{
    return [NSThread currentThread].threadDictionary[RevenantPhotosTransactionKey];
}

+ (RevenantPhotosTransaction *)begin
{
    RevenantPhotosTransaction *transaction = [[self alloc] init];
    transaction->_changes = [NSMutableArray array];
    [NSThread currentThread].threadDictionary[RevenantPhotosTransactionKey] = transaction;
    return transaction;
}

+ (void)end
{
    [[NSThread currentThread].threadDictionary removeObjectForKey:RevenantPhotosTransactionKey];
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
            *error = [RevenantPhotosStore errorWithCode:status == ALAuthorizationStatusDenied ? PHPhotosErrorAccessUserDenied : PHPhotosErrorAccessRestricted
                                               reason:@"the application is not allowed to change the photo library"];
        return NO;
    }
    if (_refusal) {
        if (error)
            *error = [RevenantPhotosStore errorWithCode:PHPhotosErrorChangeNotSupported reason:_refusal];
        return NO;
    }
    for (id<RevenantPhotosChange> change in _changes) {
        if (![change revenant_validate:error])
            return NO;
    }
    for (id<RevenantPhotosChange> change in _changes) {
        if (![change revenant_commit:error])
            return NO;
    }
    for (id<RevenantPhotosChange> change in _changes) {
        if ([change respondsToSelector:@selector(revenant_commitRelations:)] && ![change revenant_commitRelations:error])
            return NO;
    }
    return YES;
}

+ (BOOL)runAndWait:(dispatch_block_t)changes error:(NSError **)error
{
    RevenantPhotosTransaction *transaction = [self begin];
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

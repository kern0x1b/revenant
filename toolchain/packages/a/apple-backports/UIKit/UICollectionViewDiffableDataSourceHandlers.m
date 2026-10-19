#import "CharonDiffable.h"

#pragma clang diagnostic ignored "-Wobjc-property-implementation"

@implementation UICollectionViewDiffableDataSourceReorderingHandlers {
@private
    BOOL (^_canReorderItemHandler)(id);
    void (^_willReorderHandler)(NSDiffableDataSourceTransaction<id, id> *);
    void (^_didReorderHandler)(NSDiffableDataSourceTransaction<id, id> *);
}

- (BOOL (^)(id))canReorderItemHandler
{
    return _canReorderItemHandler;
}

- (void)setCanReorderItemHandler:(BOOL (^)(id))handler
{
    _canReorderItemHandler = [handler copy];
}

- (void (^)(NSDiffableDataSourceTransaction<id, id> *))willReorderHandler
{
    return _willReorderHandler;
}

- (void)setWillReorderHandler:(void (^)(NSDiffableDataSourceTransaction<id, id> *))handler
{
    _willReorderHandler = [handler copy];
}

- (void (^)(NSDiffableDataSourceTransaction<id, id> *))didReorderHandler
{
    return _didReorderHandler;
}

- (void)setDidReorderHandler:(void (^)(NSDiffableDataSourceTransaction<id, id> *))handler
{
    _didReorderHandler = [handler copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    UICollectionViewDiffableDataSourceReorderingHandlers *copy = [[[self class] allocWithZone:zone] init];
    copy.canReorderItemHandler = _canReorderItemHandler;
    copy.willReorderHandler = _willReorderHandler;
    copy.didReorderHandler = _didReorderHandler;
    return copy;
}

@end

@implementation UICollectionViewDiffableDataSourceSectionSnapshotHandlers {
@private
    BOOL (^_shouldExpandItemHandler)(id);
    void (^_willExpandItemHandler)(id);
    BOOL (^_shouldCollapseItemHandler)(id);
    void (^_willCollapseItemHandler)(id);
    NSDiffableDataSourceSectionSnapshot<id> *(^_snapshotForExpandingParentItemHandler)(id, NSDiffableDataSourceSectionSnapshot<id> *);
}

- (BOOL (^)(id))shouldExpandItemHandler
{
    return _shouldExpandItemHandler;
}

- (void)setShouldExpandItemHandler:(BOOL (^)(id))handler
{
    _shouldExpandItemHandler = [handler copy];
}

- (void (^)(id))willExpandItemHandler
{
    return _willExpandItemHandler;
}

- (void)setWillExpandItemHandler:(void (^)(id))handler
{
    _willExpandItemHandler = [handler copy];
}

- (BOOL (^)(id))shouldCollapseItemHandler
{
    return _shouldCollapseItemHandler;
}

- (void)setShouldCollapseItemHandler:(BOOL (^)(id))handler
{
    _shouldCollapseItemHandler = [handler copy];
}

- (void (^)(id))willCollapseItemHandler
{
    return _willCollapseItemHandler;
}

- (void)setWillCollapseItemHandler:(void (^)(id))handler
{
    _willCollapseItemHandler = [handler copy];
}

- (NSDiffableDataSourceSectionSnapshot<id> *(^)(id, NSDiffableDataSourceSectionSnapshot<id> *))snapshotForExpandingParentItemHandler
{
    return _snapshotForExpandingParentItemHandler;
}

- (void)setSnapshotForExpandingParentItemHandler:(NSDiffableDataSourceSectionSnapshot<id> *(^)(id, NSDiffableDataSourceSectionSnapshot<id> *))handler
{
    _snapshotForExpandingParentItemHandler = [handler copy];
}

- (id)copyWithZone:(NSZone *)zone
{
    UICollectionViewDiffableDataSourceSectionSnapshotHandlers *copy = [[[self class] allocWithZone:zone] init];
    copy.shouldExpandItemHandler = _shouldExpandItemHandler;
    copy.willExpandItemHandler = _willExpandItemHandler;
    copy.shouldCollapseItemHandler = _shouldCollapseItemHandler;
    copy.willCollapseItemHandler = _willCollapseItemHandler;
    copy.snapshotForExpandingParentItemHandler = _snapshotForExpandingParentItemHandler;
    return copy;
}

@end

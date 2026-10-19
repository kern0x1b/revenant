#import "CharonPhotos.h"

#pragma clang diagnostic ignored "-Wobjc-missing-property-synthesis"

#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation PHFetchOptions

- (instancetype)init
{
    self = [super init];
    if (self)
        self.wantsIncrementalChangeDetails = YES;
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    PHFetchOptions *copy = [[[self class] allocWithZone:zone] init];
    copy.predicate = self.predicate;
    copy.sortDescriptors = self.sortDescriptors;
    copy.includeHiddenAssets = self.includeHiddenAssets;
    copy.includeAllBurstAssets = self.includeAllBurstAssets;
    copy.includeAssetSourceTypes = self.includeAssetSourceTypes;
    copy.fetchLimit = self.fetchLimit;
    copy.wantsIncrementalChangeDetails = self.wantsIncrementalChangeDetails;
    return copy;
}

- (NSArray *)charon_apply:(NSArray *)objects
{
    NSArray *chosen = self.predicate ? [objects filteredArrayUsingPredicate:self.predicate] : objects;
    if (self.sortDescriptors.count)
        chosen = [chosen sortedArrayUsingDescriptors:self.sortDescriptors];
    if (self.fetchLimit && chosen.count > self.fetchLimit)
        chosen = [chosen subarrayWithRange:NSMakeRange(0, self.fetchLimit)];
    return chosen;
}

@end

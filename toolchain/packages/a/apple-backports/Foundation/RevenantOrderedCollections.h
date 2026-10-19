#import <Foundation/Foundation.h>

@interface NSOrderedCollectionDifference (RevenantOrderedCollections)
- (void)revenant_setInsertions:(NSArray *)insertions removals:(NSArray *)removals;
- (instancetype)revenant_initWithInsertions:(NSArray *)insertions removals:(NSArray *)removals __attribute__((objc_method_family(init)));
@end

@interface NSArray (RevenantOrderedCollections)
- (NSOrderedCollectionDifference *)revenant_differenceFromArray:(NSArray *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options usingEquivalenceTest:(BOOL (NS_NOESCAPE ^)(id, id))block;
- (NSOrderedCollectionDifference *)revenant_differenceFromArray:(NSArray *)old removed:(NSArray *)removals inserted:(NSArray *)insertions options:(NSOrderedCollectionDifferenceCalculationOptions)options;
@end

@interface NSOrderedSet (RevenantOrderedCollections)
- (NSOrderedCollectionDifference *)revenant_differenceFromOrderedSet:(NSOrderedSet *)other options:(NSOrderedCollectionDifferenceCalculationOptions)options;
@end

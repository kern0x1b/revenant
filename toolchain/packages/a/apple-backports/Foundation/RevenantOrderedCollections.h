#import <Foundation/Foundation.h>

@interface NSOrderedCollectionDifference (CharonOrderedCollections)
- (void)charon_setInsertions:(NSArray *)insertions removals:(NSArray *)removals;
- (instancetype)charon_initWithInsertions:(NSArray *)insertions removals:(NSArray *)removals __attribute__((objc_method_family(init)));
@end

@interface NSArray (CharonOrderedCollections)
- (NSOrderedCollectionDifference *)charon_differenceFromArray:(NSArray *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options usingEquivalenceTest:(BOOL (NS_NOESCAPE ^)(id, id))block;
- (NSOrderedCollectionDifference *)charon_differenceFromArray:(NSArray *)old removed:(NSArray *)removals inserted:(NSArray *)insertions options:(NSOrderedCollectionDifferenceCalculationOptions)options;
@end

@interface NSOrderedSet (CharonOrderedCollections)
- (NSOrderedCollectionDifference *)charon_differenceFromOrderedSet:(NSOrderedSet *)other options:(NSOrderedCollectionDifferenceCalculationOptions)options;
@end

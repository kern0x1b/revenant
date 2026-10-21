#import <Foundation/Foundation.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

@implementation NSMetadataQuery (RevenantEnumerate7)

- (void)enumerateResultsUsingBlock:(void (NS_NOESCAPE ^)(id result, NSUInteger idx, BOOL *stop))block
{
    [self enumerateResultsWithOptions:0 usingBlock:block];
}

- (void)enumerateResultsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(id result, NSUInteger idx, BOOL *stop))block
{
    NSArray *results = [self results];
    NSUInteger count = results.count;
    BOOL stop = NO;
    for (NSUInteger step = 0; step < count && !stop; step++) {
        NSUInteger idx = (opts & NSEnumerationReverse) ? count - 1 - step : step;
        block([results objectAtIndex:idx], idx, &stop);
    }
}

@end

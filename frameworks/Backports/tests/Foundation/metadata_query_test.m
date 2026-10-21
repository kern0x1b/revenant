#import "check.h"

@interface RevenantFixedQuery : NSMetadataQuery
@end

@implementation RevenantFixedQuery

- (NSArray *)results
{
    return @[@"a", @"b", @"c"];
}

@end

static NSString *revenant_collect(NSEnumerationOptions options, NSUInteger stopAt, BOOL *indicesMatch)
{
    RevenantFixedQuery *query = [[RevenantFixedQuery alloc] init];
    NSMutableString *seen = [NSMutableString string];
    *indicesMatch = YES;
    [query enumerateResultsWithOptions:options usingBlock:^(id result, NSUInteger idx, BOOL *stop) {
        [seen appendString:result];
        if (![result isEqualToString:[@"abc" substringWithRange:NSMakeRange(idx, 1)]])
            *indicesMatch = NO;
        if (idx == stopAt)
            *stop = YES;
    }];
    return seen;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    BOOL indices = NO;
    NSString *forward = revenant_collect(0, NSNotFound, &indices);
    revenant_expect_string("enumerate forward order", forward, revenant_negative ? @"cba" : @"abc");
    revenant_check(indices, "enumerate forward indices", @"an index did not match its result");
    revenant_expect_string("enumerate reverse order", revenant_collect(NSEnumerationReverse, NSNotFound, &indices), @"cba");
    revenant_check(indices, "enumerate reverse indices", @"an index did not match its result");
    revenant_expect_string("enumerate stops when asked", revenant_collect(0, 1, &indices), @"ab");

    RevenantFixedQuery *query = [[RevenantFixedQuery alloc] init];
    __block NSUInteger calls = 0;
    [query enumerateResultsUsingBlock:^(id result, NSUInteger idx, BOOL *stop) {
        calls++;
    }];
    revenant_check(calls == 3, "enumerate without options visits every result", [NSString stringWithFormat:@"%lu calls", (unsigned long)calls]);
    return revenant_finish();
}

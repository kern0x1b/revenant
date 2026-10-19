#import <Foundation/Foundation.h>


@implementation NSURLComponents (CharonPercentEncodedQueryItems)

- (NSArray *)percentEncodedQueryItems
{
    NSString *query = self.percentEncodedQuery;
    if (!query)
        return nil;
    if (!query.length)
        return @[];
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *pair in [query componentsSeparatedByString:@"&"]) {
        NSRange equals = [pair rangeOfString:@"="];
        if (equals.location == NSNotFound)
            [items addObject:[NSURLQueryItem queryItemWithName:pair value:nil]];
        else
            [items addObject:[NSURLQueryItem queryItemWithName:[pair substringToIndex:equals.location]
                                                         value:[pair substringFromIndex:NSMaxRange(equals)]]];
    }
    return [items copy];
}

- (void)setPercentEncodedQueryItems:(NSArray *)percentEncodedQueryItems
{
    if (!percentEncodedQueryItems) {
        self.percentEncodedQuery = nil;
        return;
    }
    NSMutableArray *pairs = [NSMutableArray arrayWithCapacity:percentEncodedQueryItems.count];
    for (NSURLQueryItem *item in percentEncodedQueryItems)
        [pairs addObject:item.value ? [NSString stringWithFormat:@"%@=%@", item.name, item.value] : item.name];
    self.percentEncodedQuery = [pairs componentsJoinedByString:@"&"];
}

@end

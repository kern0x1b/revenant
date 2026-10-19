#import <Foundation/Foundation.h>

static NSString *revenant_query_decode(NSString *string)
{
    NSString *decoded = [string stringByRemovingPercentEncoding];
    return decoded ? decoded : @"";
}

static NSString *revenant_query_encode(NSString *string)
{
    static NSCharacterSet *allowed;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableCharacterSet *set = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];
        [set removeCharactersInString:@"&="];
        allowed = [set copy];
    });
    NSString *encoded = [string stringByAddingPercentEncodingWithAllowedCharacters:allowed];
    return encoded ? encoded : @"";
}

@implementation NSURLComponents (RevenantQueryItems)

- (NSArray *)queryItems
{
    NSString *query = self.percentEncodedQuery;
    if (!query)
        return nil;
    if (!query.length)
        return @[];
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *pair in [query componentsSeparatedByString:@"&"]) {
        NSRange equals = [pair rangeOfString:@"="];
        if (equals.location == NSNotFound) {
            [items addObject:[NSURLQueryItem queryItemWithName:revenant_query_decode(pair) value:nil]];
        } else {
            NSString *name = revenant_query_decode([pair substringToIndex:equals.location]);
            NSString *value = [[pair substringFromIndex:NSMaxRange(equals)] stringByRemovingPercentEncoding];
            [items addObject:[NSURLQueryItem queryItemWithName:name value:value]];
        }
    }
    return [items copy];
}

- (void)setQueryItems:(NSArray *)queryItems
{
    if (!queryItems) {
        self.percentEncodedQuery = nil;
        return;
    }
    NSMutableArray *pairs = [NSMutableArray arrayWithCapacity:queryItems.count];
    for (NSURLQueryItem *item in queryItems) {
        NSString *name = revenant_query_encode(item.name);
        [pairs addObject:item.value ? [NSString stringWithFormat:@"%@=%@", name, revenant_query_encode(item.value)] : name];
    }
    self.percentEncodedQuery = [pairs componentsJoinedByString:@"&"];
}

@end

#import "../app/revenant_check.h"

REVENANT_CASE(foundation_url_components)
{
    NSURLComponents *built = [[NSURLComponents alloc] init];
    built.scheme = @"https";
    built.host = @"example.org";
    built.path = @"/search";
    built.queryItems = @[[NSURLQueryItem queryItemWithName:@"q" value:@"a b&c"],
                         [NSURLQueryItem queryItemWithName:@"lang" value:@"uk"]];
    NSString *string = built.string;
    revenant_expect_string(@"NSURLComponents builds the percent-encoded string", string,
                           negative ? @"https://example.org/search?q=a%20b%20c&lang=uk"
                                    : @"https://example.org/search?q=a%20b%26c&lang=uk");

    NSURLComponents *parsed = [NSURLComponents componentsWithString:string];
    NSArray *items = parsed.queryItems;
    revenant_expect_integer(@"the parsed string has both query items", items.count, negative ? 3 : 2);
    NSString *name = items.count > 0 ? [[items objectAtIndex:0] name] : @"";
    NSString *value = items.count > 0 ? [[items objectAtIndex:0] value] : @"";
    revenant_expect_string(@"the first query item name survives the round trip", name, @"q");
    revenant_expect_string(@"the first query item value is decoded", value, negative ? @"a b&d" : @"a b&c");
}

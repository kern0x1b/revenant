#import "../app/revenant_check.h"

REVENANT_CASE(flat_class_launch)
{
    NSURLComponents *components = [[NSURLComponents alloc] init];
    components.scheme = @"https";
    components.host = @"example.org";
    revenant_expect_string(@"the flat-class reference binds and reads back the host it was given", components.host,
                           negative ? @"example.com" : @"example.org");
}

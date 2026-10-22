#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSError *first = [NSError errorWithDomain:@"first" code:1 userInfo:nil];
    NSError *second = [NSError errorWithDomain:@"second" code:2 userInfo:nil];
    NSError *third = [NSError errorWithDomain:@"third" code:3 userInfo:nil];
    NSError *none = [NSError errorWithDomain:@"none" code:0 userInfo:nil];
    revenant_check([none underlyingErrors].count == 0, "an error without underlying errors has an empty list", @"not empty");
    NSError *single = [NSError errorWithDomain:@"outer" code:4 userInfo:@{NSUnderlyingErrorKey: first}];
    revenant_check([[single underlyingErrors] isEqualToArray:@[first]], "the single underlying error is listed", [NSString stringWithFormat:@"%@", [single underlyingErrors]]);
    NSError *multiple = [NSError errorWithDomain:@"outer" code:5 userInfo:@{NSMultipleUnderlyingErrorsKey: @[second, third]}];
    revenant_check([[multiple underlyingErrors] isEqualToArray:@[second, third]], "the multiple underlying errors are listed", [NSString stringWithFormat:@"%@", [multiple underlyingErrors]]);
    NSError *both = [NSError errorWithDomain:@"outer" code:6 userInfo:@{NSUnderlyingErrorKey: first, NSMultipleUnderlyingErrorsKey: @[second, third]}];
    NSArray *expected = revenant_negative ? @[second, third, first] : @[first, second, third];
    revenant_check([[both underlyingErrors] isEqualToArray:expected], "both keys are listed, the single one first", [NSString stringWithFormat:@"%@", [both underlyingErrors]]);
    revenant_expect_string("the multiple key has its documented value", NSMultipleUnderlyingErrorsKey, @"NSMultipleUnderlyingErrorsKey");
    return revenant_finish();
}

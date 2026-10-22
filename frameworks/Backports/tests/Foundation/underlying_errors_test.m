#import "check.h"

static NSArray *revenant_underlying(NSError *error)
{
    return REVENANT_IMP(NSError, @selector(underlyingErrors), NSArray *(*)(id, SEL))(error, @selector(underlyingErrors));
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSError *first = [NSError errorWithDomain:@"first" code:1 userInfo:nil];
    NSError *second = [NSError errorWithDomain:@"second" code:2 userInfo:nil];
    NSError *third = [NSError errorWithDomain:@"third" code:3 userInfo:nil];
    NSError *none = [NSError errorWithDomain:@"none" code:0 userInfo:nil];
    revenant_check(revenant_underlying(none).count == 0, "an error without underlying errors has an empty list", @"not empty");
    NSError *single = [NSError errorWithDomain:@"outer" code:4 userInfo:@{NSUnderlyingErrorKey: first}];
    revenant_check([revenant_underlying(single) isEqualToArray:@[first]], "the single underlying error is listed", [NSString stringWithFormat:@"%@", revenant_underlying(single)]);
    NSError *multiple = [NSError errorWithDomain:@"outer" code:5 userInfo:@{NSMultipleUnderlyingErrorsKey: @[second, third]}];
    revenant_check([revenant_underlying(multiple) isEqualToArray:@[second, third]], "the multiple underlying errors are listed", [NSString stringWithFormat:@"%@", revenant_underlying(multiple)]);
    NSError *both = [NSError errorWithDomain:@"outer" code:6 userInfo:@{NSUnderlyingErrorKey: first, NSMultipleUnderlyingErrorsKey: @[second, third]}];
    NSArray *expected = revenant_negative ? @[second, third, first] : @[first, second, third];
    revenant_check([revenant_underlying(both) isEqualToArray:expected], "both keys are listed, the single one first", [NSString stringWithFormat:@"%@", revenant_underlying(both)]);
    NSError *mixed = [NSError errorWithDomain:@"outer" code:7 userInfo:@{NSMultipleUnderlyingErrorsKey: @[second, @"not an error"]}];
    revenant_check([revenant_underlying(mixed) isEqualToArray:@[second]], "a value that is not an error is skipped", [NSString stringWithFormat:@"%@", revenant_underlying(mixed)]);
    revenant_expect_string("the multiple key has its documented value", NSMultipleUnderlyingErrorsKey, @"NSMultipleUnderlyingErrorsKey");
    return revenant_finish();
}

#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSTextCheckingResult *result = [NSTextCheckingResult correctionCheckingResultWithRange:NSMakeRange(1, 3) replacementString:@"x" alternativeStrings:@[@"y", @"z"]];
    revenant_check(result != nil, "correction result with alternatives exists", @"nil");
    revenant_expect_string("correction result keeps its replacement", result.replacementString, revenant_negative ? @"q" : @"x");
    revenant_check(NSEqualRanges(result.range, NSMakeRange(1, 3)), "correction result keeps its range", @"range differs");
    revenant_check(result.resultType == NSTextCheckingTypeCorrection, "correction result has the correction type", @"other type");
    NSTextCheckingResult *plain = [NSTextCheckingResult correctionCheckingResultWithRange:NSMakeRange(0, 1) replacementString:@"q"];
    revenant_check(plain.alternativeStrings == nil, "correction result without alternatives has none", [NSString stringWithFormat:@"%@", plain.alternativeStrings]);
    return revenant_finish();
}

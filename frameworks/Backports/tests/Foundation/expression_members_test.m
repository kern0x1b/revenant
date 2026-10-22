#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSExpression *anyKey = [NSExpression expressionForAnyKey];
    revenant_check(anyKey != nil && anyKey.expressionType == (revenant_negative ? NSConstantValueExpressionType : NSAnyKeyExpressionType), "an any key expression has the any key type", [NSString stringWithFormat:@"%lu", (unsigned long)anyKey.expressionType]);
    revenant_expect_string("an any key expression prints as ANYKEY", anyKey.description, @"ANYKEY");
    NSExpression *constant = [NSExpression expressionForConstantValue:@1];
    BOOL raisedTrue = NO, raisedFalse = NO;
    @try {
        (void)constant.trueExpression;
    } @catch (NSException *exception) {
        raisedTrue = [exception.name isEqualToString:NSInvalidArgumentException];
    }
    @try {
        (void)constant.falseExpression;
    } @catch (NSException *exception) {
        raisedFalse = [exception.name isEqualToString:NSInvalidArgumentException];
    }
    revenant_check(raisedTrue, "the true expression of a constant raises an invalid argument exception", @"no exception");
    revenant_check(raisedFalse, "the false expression of a constant raises an invalid argument exception", @"no exception");
    NSPredicate *predicate = [NSPredicate predicateWithValue:YES];
    NSExpression *yes = [NSExpression expressionForConstantValue:@"yes"];
    NSExpression *no = [NSExpression expressionForConstantValue:@"no"];
    NSExpression *conditional = [NSExpression expressionForConditional:predicate trueExpression:yes falseExpression:no];
    revenant_check([conditional.trueExpression isEqual:yes] && [conditional.falseExpression isEqual:no], "a conditional expression keeps its branches", @"branches differ");
    return revenant_finish();
}

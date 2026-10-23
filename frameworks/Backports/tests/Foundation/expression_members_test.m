#import "check.h"

static BOOL revenant_raises(NSExpression *expression, SEL selector)
{
    @try {
        REVENANT_IMP(NSExpression, selector, id (*)(id, SEL))(expression, selector);
    } @catch (NSException *exception) {
        return [exception.name isEqualToString:NSInvalidArgumentException];
    }
    return NO;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSExpression *anyKey = REVENANT_CLASS_IMP(NSExpression, @selector(expressionForAnyKey), NSExpression *(*)(id, SEL))([NSExpression class], @selector(expressionForAnyKey));
    revenant_check(anyKey != nil && anyKey.expressionType == (revenant_negative ? NSConstantValueExpressionType : NSAnyKeyExpressionType), "an any key expression has the any key type", [NSString stringWithFormat:@"%lu", (unsigned long)anyKey.expressionType]);
    revenant_expect_string("an any key expression prints as ANYKEY", anyKey.description, @"ANYKEY");
    NSExpression *constant = [NSExpression expressionForConstantValue:@1];
    revenant_check(revenant_raises(constant, @selector(trueExpression)), "the true expression of a constant raises an invalid argument exception", @"no exception");
    revenant_check(revenant_raises(constant, @selector(falseExpression)), "the false expression of a constant raises an invalid argument exception", @"no exception");
    NSPredicate *predicate = [NSPredicate predicateWithValue:YES];
    NSExpression *yes = [NSExpression expressionForConstantValue:@"yes"];
    NSExpression *no = [NSExpression expressionForConstantValue:@"no"];
    NSExpression *conditional = [NSExpression expressionForConditional:predicate trueExpression:yes falseExpression:no];
    revenant_check([conditional.trueExpression isEqual:yes] && [conditional.falseExpression isEqual:no], "a conditional expression keeps its branches", @"branches differ");
    return revenant_finish();
}

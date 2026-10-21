#import "check.h"

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSExpression *expression = [NSExpression expressionForConstantValue:@7];
    [expression allowEvaluation];
    id value = [expression expressionValueWithObject:nil context:nil];
    NSNumber *expected = revenant_negative ? @8 : @7;
    revenant_check([value isEqual:expected], "allowEvaluation leaves the expression evaluable", [NSString stringWithFormat:@"%@", value]);
    return revenant_finish();
}

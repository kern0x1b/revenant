#import "check.h"
#include <stdarg.h>

static NSString *revenant_validated_list(NSString *format, NSString *specifiers, NSError **error, ...)
{
    va_list arguments;
    va_start(arguments, error);
    NSString *made = [[NSString alloc] initWithValidatedFormat:format validFormatSpecifiers:specifiers arguments:arguments error:error];
    va_end(arguments);
    return made;
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    NSError *error = nil;
    NSString *fromList = revenant_validated_list(@"%@ is %d", @"%@%d", &error, @"x", 3);
    NSString *expected = revenant_negative ? @"x is 4" : @"x is 3";
    revenant_expect_string("validated format from a va_list renders the arguments", fromList, expected);
    NSString *fromVarargs = [NSString stringWithValidatedFormat:@"%@ is %d" validFormatSpecifiers:@"%@%d" error:&error, @"x", 3];
    revenant_expect_string("the va_list form matches the varargs form", fromList, fromVarargs);
    return revenant_finish();
}

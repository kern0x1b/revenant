#import <Foundation/Foundation.h>
#import "RevenantTightening.h"
#import "check.h"

static void expect_fit(const char *name, double width, double available, double pointSize, NSUInteger gaps, BOOL expected)
{
    double kern = 99;
    BOOL fits = revenant_tightening_kern(width, available, pointSize, gaps, &kern);
    revenant_check(fits == expected, name, [NSString stringWithFormat:@"the tightening is %d, not %d", fits, expected]);
    if (fits)
        revenant_check(fabs(width + kern * (double)gaps - available) < 1e-9, name, @"the tightened width is not the available width");
    if (!fits)
        revenant_check(kern == 0, name, [NSString stringWithFormat:@"a refused tightening sets the kern to %g", kern]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);

    expect_fit("text that fits is not tightened", 90, 100, 17, 9, NO);
    expect_fit("text exactly as wide as the line is not tightened", 100, 100, 17, 9, NO);
    expect_fit("a small overflow is tightened to the line", 100, 98, 17, 10, revenant_negative ? NO : YES);
    expect_fit("an overflow over the cap is refused, so it truncates", 100, 90, 17, 9, NO);
    expect_fit("an overflow at the cap is tightened", 100, 95, 10, 10, YES);
    expect_fit("one character over the cap is refused", 100, 94.9, 10, 10, NO);
    expect_fit("a single character has no gap to tighten", 100, 98, 17, 0, NO);
    expect_fit("a zero point size has no cap", 100, 98, 0, 10, NO);

    return revenant_finish();
}

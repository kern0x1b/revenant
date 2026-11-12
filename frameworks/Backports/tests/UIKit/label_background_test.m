#import <Foundation/Foundation.h>
#import "RevenantLabelBackground.h"
#import "check.h"

static void expect(const char *name, const CGFloat *components, size_t count, BOOL expected)
{
    BOOL seen = RevenantLabelBackgroundIsDefaultWhite(components, count);
    revenant_check(seen == expected, name, [NSString stringWithFormat:@"%d is not %d", seen, expected]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        CGFloat grayWhite[] = {1, 1};
        CGFloat rgbWhite[] = {1, 1, 1, 1};
        CGFloat grey[] = {0.94, 1};
        CGFloat halfWhite[] = {1, 0.5};
        CGFloat clear[] = {0, 0};
        CGFloat black[] = {0, 1};
        CGFloat pink[] = {1, 0.9, 1, 1};
        CGFloat rgbHalf[] = {1, 1, 1, 0.5};
        CGFloat odd[] = {1, 1, 1};

        expect("the default is a gray white at full alpha", grayWhite, 2, revenant_negative ? NO : YES);
        expect("an RGB white at full alpha is the same default", rgbWhite, 4, YES);
        expect("a light grey is the app's", grey, 2, NO);
        expect("a translucent white is the app's", halfWhite, 2, NO);
        expect("a translucent RGB white is the app's", rgbHalf, 4, NO);
        expect("clear is the app's", clear, 2, NO);
        expect("black is the app's", black, 2, NO);
        expect("a tinted white is the app's", pink, 4, NO);
        expect("three components are no colour space of UIKit", odd, 3, NO);
        expect("no components, no default", NULL, 0, NO);
        expect("an empty list, no default", grayWhite, 0, NO);
    }
    return revenant_finish();
}

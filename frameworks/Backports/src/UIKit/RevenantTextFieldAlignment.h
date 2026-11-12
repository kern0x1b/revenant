#import <Foundation/Foundation.h>

// A UITextField made in code has UIControlContentVerticalAlignmentTop (1) on iOS 6 and UIControlContentVerticalAlignmentCenter (0) on
// iOS 7 and later. In a field taller than its text (Telegram's search pill is 48 points high) the text rides at the top, above the
// baseline of the placeholder and of the icon beside it. This gives the alignment the field should start with: the later default
// in place of the top default, and any other value an application set (bottom, fill, center) unchanged.
long RevenantTextFieldInitialAlignment(long current);

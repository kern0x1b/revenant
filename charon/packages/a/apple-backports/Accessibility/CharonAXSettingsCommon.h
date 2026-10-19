//
//  CharonAXSettingsCommon.h
//  Accessibility
//
//  One sentence every settings function of this library answers with, and the one place the number
//  behind it lives.
//
//  The release this port carries holds no accessibility preference of any of these kinds. That is
//  measured, not assumed: the whole Accessibility surface it holds is 310 AX-prefixed exports of one
//  library, every one of them an AXS or kAXS preference name, and none of them a preference about
//  motion, a blinking or insertion cursor, horizontal text layout, borders or a slider alternative.
//  The measurement, its control and its output are in
//  tests/backports/settings/axs-census.lua and in facts/Accessibility/Accessibility.md.
//
//  So a function that reads one of those preferences answers NO, and its answer cannot change in the
//  life of a process - which is what its own header says of one of them, and what the measurement says of
//  all five. A notification that announces such a change is therefore never posted, and the constants are
//  carried so that a caller can name one, not so that it can be waited on.
//

#import <Foundation/Foundation.h>

// The measured answer, and the one number every one of these functions answers. A function, and not a
// macro, so that the value is one place in the library and not five copies of a literal.
static inline BOOL CharonAXSettingIsOffOnThisRelease(void)
{
    return NO;
}

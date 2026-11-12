#import <Foundation/Foundation.h>
#import "RevenantKeyboardSwitch.h"
#import "check.h"

static const long TypeDefault = 0;
static const long TypePhonePad = 5;

static CGRect screen(void)
{
    return CGRectMake(0, 0, 320, 480);
}

static CGRect keyboard(void)
{
    return CGRectMake(0, 264, 320, 216);
}

static void expect(BOOL value, const char *name, BOOL expected)
{
    revenant_check(value == expected, name, [NSString stringWithFormat:@"%d is not %d", value, expected]);
}

int main(int argc, char **argv)
{
    revenant_read_arguments(argc, argv);
    @autoreleasepool {
        RevenantKeyboardSwitch state;
        RevenantKeyboardSwitchInit(&state);
        expect(state.shown.size.height > 0, "no keyboard at the start", NO);
        expect(RevenantKeyboardSwitchDue(&state, 0), "nothing to announce at the start", NO);

        RevenantKeyboardSwitchNotice(&state, keyboard(), screen(), 10);
        expect(state.shown.size.height == 216, "a keyboard on the bottom edge is shown", YES);
        expect(RevenantKeyboardSwitchBegan(&state, TypePhonePad), "the first input is no switch", NO);
        expect(RevenantKeyboardSwitchBegan(&state, TypePhonePad), "an input of the same keyboard type is no switch", NO);

        expect(RevenantKeyboardSwitchBegan(&state, TypeDefault), "a new keyboard type with the keyboard up is a switch", revenant_negative ? NO : YES);
        expect(RevenantKeyboardSwitchDue(&state, 11), "no notification since the input began: the app is told", YES);
        RevenantKeyboardSwitchNotice(&state, keyboard(), screen(), 11.05);
        expect(RevenantKeyboardSwitchDue(&state, 11), "UIKit posted one itself: the shim stays out", NO);
        expect(RevenantKeyboardSwitchBegan(&state, TypePhonePad), "switching back is a switch again", YES);

        CGRect hidden = RevenantKeyboardSwitchHidden(keyboard());
        revenant_check(CGRectEqualToRect(hidden, CGRectMake(0, 480, 320, 0)), "the hidden frame has no height on the bottom edge", NSStringFromRect(hidden));

        RevenantKeyboardSwitchNotice(&state, CGRectMake(0, 480, 320, 216), screen(), 12);
        expect(state.shown.size.height > 0, "a keyboard below the screen is not shown", NO);
        expect(RevenantKeyboardSwitchBegan(&state, TypeDefault), "no keyboard, no switch", NO);
        expect(RevenantKeyboardSwitchDue(&state, 11), "no keyboard, nothing to announce", NO);

        RevenantKeyboardSwitchNotice(&state, CGRectMake(0, 480, 320, 0), screen(), 13);
        expect(state.shown.size.height > 0, "an empty frame is not shown", NO);

        RevenantKeyboardSwitchNotice(&state, CGRectMake(0, 0, 162, 480), screen(), 14);
        expect(state.shown.size.height > 0, "a landscape keyboard is left alone", NO);
        RevenantKeyboardSwitchNotice(&state, CGRectMake(0, 0, 320, 216), screen(), 15);
        expect(state.shown.size.height > 0, "an upside-down keyboard is left alone", NO);

        RevenantKeyboardSwitchNotice(&state, CGRectMake(0, 777, 768, 247), CGRectMake(0, 0, 768, 1024), 16);
        expect(state.shown.size.height == 247, "an iPad keyboard is shown", YES);
    }
    return revenant_finish();
}

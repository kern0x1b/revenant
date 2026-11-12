#import "RevenantKeyboardSwitch.h"

void RevenantKeyboardSwitchInit(RevenantKeyboardSwitch *state)
{
    state->shown = CGRectZero;
    state->lastNotice = 0;
    state->lastType = -1;
}

void RevenantKeyboardSwitchNotice(RevenantKeyboardSwitch *state, CGRect end, CGRect screen, double now)
{
    state->lastNotice = now;
    CGRect common = CGRectIntersection(end, screen);
    BOOL covers = !CGRectIsNull(common) && common.size.width > 0 && common.size.height > 0;
    BOOL atBottom = fabs(CGRectGetMaxY(end) - CGRectGetMaxY(screen)) < 0.5 && end.size.width >= screen.size.width - 0.5;
    state->shown = covers && atBottom ? end : CGRectZero;
}

BOOL RevenantKeyboardSwitchBegan(RevenantKeyboardSwitch *state, long type)
{
    BOOL changed = state->lastType >= 0 && state->lastType != type;
    state->lastType = type;
    return changed && state->shown.size.height > 0;
}

BOOL RevenantKeyboardSwitchDue(const RevenantKeyboardSwitch *state, double began)
{
    return state->shown.size.height > 0 && state->lastNotice <= began;
}

CGRect RevenantKeyboardSwitchHidden(CGRect shown)
{
    return CGRectMake(shown.origin.x, CGRectGetMaxY(shown), shown.size.width, 0);
}

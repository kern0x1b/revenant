#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct {
    CGRect shown;
    double lastNotice;
    long lastType;
} RevenantKeyboardSwitch;

void RevenantKeyboardSwitchInit(RevenantKeyboardSwitch *state);

void RevenantKeyboardSwitchNotice(RevenantKeyboardSwitch *state, CGRect end, CGRect screen, double now);

BOOL RevenantKeyboardSwitchBegan(RevenantKeyboardSwitch *state, long type);

BOOL RevenantKeyboardSwitchDue(const RevenantKeyboardSwitch *state, double began);

CGRect RevenantKeyboardSwitchHidden(CGRect shown);

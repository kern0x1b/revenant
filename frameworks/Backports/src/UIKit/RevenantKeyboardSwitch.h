#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

// iOS 6 posts no keyboard notification when the first responder moves to another text input and the keyboard stays up, even if the
// keyboard changes its layout (a number pad becomes the letter keyboard). An app that places its views from the window's keyboard
// height, as Telegram's sheets do, never hears that the new input is focused. This is the state the shim keeps to decide when to tell it.
typedef struct {
    CGRect shown;        // the frame of the keyboard on screen, CGRectZero when there is none
    double lastNotice;   // when the last keyboard notification arrived
    long lastType;       // the keyboard type of the input that began editing last, -1 before the first
} RevenantKeyboardSwitch;

void RevenantKeyboardSwitchInit(RevenantKeyboardSwitch *state);

// A keyboard notification arrived with this end frame. The keyboard counts as shown when the frame covers a part of the screen,
// spans its width and ends at its bottom edge (a portrait keyboard: the only one the shim acts on).
void RevenantKeyboardSwitchNotice(RevenantKeyboardSwitch *state, CGRect end, CGRect screen, double now);

// A text input of this keyboard type began editing. Returns YES when the keyboard is up and its type changed, the moment a later
// iOS tells the app about the new keyboard.
BOOL RevenantKeyboardSwitchBegan(RevenantKeyboardSwitch *state, long type);

// Checked after a short wait: the keyboard is still up and no notification came since the input began editing at `began`.
BOOL RevenantKeyboardSwitchDue(const RevenantKeyboardSwitch *state, double began);

// The frame that follows the shown keyboard out of sight: zero height, on the screen's bottom edge.
CGRect RevenantKeyboardSwitchHidden(CGRect shown);

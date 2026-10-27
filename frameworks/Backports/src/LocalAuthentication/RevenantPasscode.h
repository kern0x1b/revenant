#import <Foundation/Foundation.h>
#import <stdbool.h>
#import <stdint.h>

typedef NS_ENUM(NSInteger, RevenantPasscodeResult) {
    RevenantPasscodeAccepted,
    RevenantPasscodeRejected,
    RevenantPasscodeUnavailable,
    RevenantPasscodeCancelled,
};

typedef NS_ENUM(NSInteger, RevenantPasscodeStyle) {
    RevenantPasscodeStyleSimple,
    RevenantPasscodeStyleComplex,
};

bool RevenantPasscodeUnlockDevice(NSData *passcode, int32_t *status);
RevenantPasscodeResult RevenantPasscodeMapStatus(int32_t status);
BOOL RevenantPasscodeIsValid(NSString *text, RevenantPasscodeStyle style);
RevenantPasscodeResult RevenantPasscodeVerify(NSString *text, RevenantPasscodeStyle style);
RevenantPasscodeResult RevenantPasscodeOutcome(BOOL cancelled, NSString *text, RevenantPasscodeStyle style);
void RevenantPasscodePresent(NSString *reason, RevenantPasscodeStyle style, void (^completion)(RevenantPasscodeResult result));

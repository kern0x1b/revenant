#import <Foundation/Foundation.h>
#import <TargetConditionals.h>
#import "RevenantPasscode.h"

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
#endif

static const int32_t revenant_passcode_kernel_refused = -2;
static const NSUInteger revenant_passcode_simple_length = 4;

RevenantPasscodeResult RevenantPasscodeMapStatus(int32_t status)
{
    if (status == 0)
        return RevenantPasscodeAccepted;
    if (status == revenant_passcode_kernel_refused)
        return RevenantPasscodeUnavailable;
    return RevenantPasscodeRejected;
}

BOOL RevenantPasscodeIsValid(NSString *text, RevenantPasscodeStyle style)
{
    if (text.length == 0)
        return NO;
    if (style == RevenantPasscodeStyleComplex)
        return YES;
    if (text.length != revenant_passcode_simple_length)
        return NO;
    NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
    return [text rangeOfCharacterFromSet:[digits invertedSet]].location == NSNotFound;
}

RevenantPasscodeResult RevenantPasscodeVerify(NSString *text, RevenantPasscodeStyle style)
{
    if (!RevenantPasscodeIsValid(text, style))
        return RevenantPasscodeRejected;
    int32_t status = 0;
    if (!RevenantPasscodeUnlockDevice([text dataUsingEncoding:NSUTF8StringEncoding], &status))
        return RevenantPasscodeUnavailable;
    return RevenantPasscodeMapStatus(status);
}

RevenantPasscodeResult RevenantPasscodeOutcome(BOOL cancelled, NSString *text, RevenantPasscodeStyle style)
{
    if (cancelled)
        return RevenantPasscodeCancelled;
    return RevenantPasscodeVerify(text, style);
}

#if TARGET_OS_IPHONE

@interface RevenantPasscodePrompt : NSObject <UIAlertViewDelegate>
@property (nonatomic) RevenantPasscodeStyle style;
@property (nonatomic, copy) void (^completion)(RevenantPasscodeResult result);
@property (nonatomic, strong) UIAlertView *alert;
- (void)finishWithResult:(RevenantPasscodeResult)result;
@end

static RevenantPasscodePrompt *revenant_passcode_active = nil;

@implementation RevenantPasscodePrompt

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index
{
    BOOL cancelled = index == alert.cancelButtonIndex;
    NSString *text = [alert textFieldAtIndex:0].text;
    RevenantPasscodeStyle style = self.style;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        RevenantPasscodeResult result = RevenantPasscodeOutcome(cancelled, text, style);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self finishWithResult:result];
        });
    });
}

- (void)finishWithResult:(RevenantPasscodeResult)result
{
    void (^completion)(RevenantPasscodeResult) = self.completion;
    self.completion = nil;
    self.alert.delegate = nil;
    self.alert = nil;
    if (revenant_passcode_active == self)
        revenant_passcode_active = nil;
    if (completion)
        completion(result);
}

@end

void RevenantPasscodePresent(NSString *reason, RevenantPasscodeStyle style, void (^completion)(RevenantPasscodeResult result))
{
    void (^handler)(RevenantPasscodeResult) = [completion copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (revenant_passcode_active) {
            handler(RevenantPasscodeUnavailable);
            return;
        }
        RevenantPasscodePrompt *prompt = [[RevenantPasscodePrompt alloc] init];
        prompt.style = style;
        prompt.completion = handler;
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Passcode" message:reason delegate:prompt
                                              cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
        alert.alertViewStyle = UIAlertViewStyleSecureTextInput;
        [alert textFieldAtIndex:0].keyboardType = style == RevenantPasscodeStyleSimple ? UIKeyboardTypeNumberPad : UIKeyboardTypeDefault;
        prompt.alert = alert;
        revenant_passcode_active = prompt;
        [alert show];
    });
}

#else

void RevenantPasscodePresent(NSString *reason, RevenantPasscodeStyle style, void (^completion)(RevenantPasscodeResult result))
{
    completion(RevenantPasscodeUnavailable);
}

#endif

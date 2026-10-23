#import "RevenantASAppleIDButtonMetrics.h"

const CGFloat RevenantASAppleIDButtonCornerRadius = 6;

const unichar RevenantASAppleIDButtonLogoCharacter = 0xF8FF;

NSString *RevenantASAppleIDButtonTitle(ASAuthorizationAppleIDButtonType type)
{
    switch (type) {
        case ASAuthorizationAppleIDButtonTypeContinue:
            return @"Continue with Apple";
        case ASAuthorizationAppleIDButtonTypeSignUp:
            return @"Sign up with Apple";
        case ASAuthorizationAppleIDButtonTypeSignIn:
            return @"Sign in with Apple";
    }
    return @"Sign in with Apple";
}

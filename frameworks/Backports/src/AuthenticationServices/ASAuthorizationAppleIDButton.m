#import <AuthenticationServices/AuthenticationServices.h>

@implementation ASAuthorizationAppleIDButton {
    ASAuthorizationAppleIDButtonType _buttonType;
    ASAuthorizationAppleIDButtonStyle _buttonStyle;
    CGFloat _cornerRadius;
}

+ (instancetype)buttonWithType:(ASAuthorizationAppleIDButtonType)type style:(ASAuthorizationAppleIDButtonStyle)style
{
    return [[self alloc] initWithAuthorizationButtonType:type authorizationButtonStyle:style];
}

- (instancetype)initWithAuthorizationButtonType:(ASAuthorizationAppleIDButtonType)type authorizationButtonStyle:(ASAuthorizationAppleIDButtonStyle)style
{
    if ((self = [super initWithFrame:CGRectZero])) {
        _buttonType = type;
        _buttonStyle = style;
        _cornerRadius = 8;
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (CGFloat)cornerRadius
{
    return _cornerRadius;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    _cornerRadius = cornerRadius;
    [self setNeedsDisplay];
}

- (NSString *)revenant_title
{
    switch (_buttonType) {
        case ASAuthorizationAppleIDButtonTypeContinue:
            return @"Continue with Apple";
        case ASAuthorizationAppleIDButtonTypeSignUp:
            return @"Sign up with Apple";
        case ASAuthorizationAppleIDButtonTypeSignIn:
            return @"Sign in with Apple";
    }
    return @"Sign in with Apple";
}

- (void)drawRect:(CGRect)rect
{
    BOOL black = _buttonStyle == ASAuthorizationAppleIDButtonStyleBlack;
    BOOL outlined = _buttonStyle == ASAuthorizationAppleIDButtonStyleWhiteOutline;
    UIColor *background = black ? [UIColor blackColor] : [UIColor whiteColor];
    UIColor *foreground = black ? [UIColor whiteColor] : [UIColor blackColor];
    CGRect bounds = self.bounds;
    [background setFill];
    [[UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:_cornerRadius] fill];
    if (outlined) {
        UIBezierPath *border = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(bounds, 0.5, 0.5) cornerRadius:_cornerRadius];
        border.lineWidth = 1;
        [[UIColor blackColor] setStroke];
        [border stroke];
    }
    NSString *title = [self revenant_title];
    UIFont *font = [UIFont boldSystemFontOfSize:17];
    CGSize size = [title sizeWithFont:font];
    CGRect text = CGRectMake(CGRectGetMidX(bounds) - size.width / 2, CGRectGetMidY(bounds) - size.height / 2, size.width, size.height);
    [foreground setFill];
    [title drawInRect:text withFont:font];
}

@end

#import <UIKit/UIKit.h>
#import <PassKit/PassKit.h>
#import "RevenantPassKit.h"

static NSString *RevenantPaymentButtonTitle(PKPaymentButtonType type)
{
    switch (type) {
        case PKPaymentButtonTypeBuy:
            return @"Buy with  Pay";
        case PKPaymentButtonTypeSetUp:
            return @"Set Up with  Pay";
        case PKPaymentButtonTypeInStore:
            return @"Pay with  Pay";
        case PKPaymentButtonTypeDonate:
            return @"Donate with  Pay";
        case PKPaymentButtonTypeCheckout:
            return @"Check out with  Pay";
        case PKPaymentButtonTypeBook:
            return @"Book with  Pay";
        case PKPaymentButtonTypeSubscribe:
            return @"Subscribe with  Pay";
        case PKPaymentButtonTypeReload:
            return @"Reload with  Pay";
        case PKPaymentButtonTypeAddMoney:
            return @"Add Money with  Pay";
        case PKPaymentButtonTypeTopUp:
            return @"Top Up with  Pay";
        case PKPaymentButtonTypeOrder:
            return @"Order with  Pay";
        case PKPaymentButtonTypeRent:
            return @"Rent with  Pay";
        case PKPaymentButtonTypeSupport:
            return @"Support with  Pay";
        case PKPaymentButtonTypeContribute:
            return @"Contribute with  Pay";
        case PKPaymentButtonTypeTip:
            return @"Tip with  Pay";
        case PKPaymentButtonTypeContinue:
            return @"Continue with  Pay";
        case PKPaymentButtonTypePlain:
        default:
            return @" Pay";
    }
}

@interface PKPaymentButton ()
- (instancetype)initWithCoder:(NSCoder *)coder __attribute__((objc_designated_initializer));
@end

@implementation PKPaymentButton

+ (instancetype)buttonWithType:(PKPaymentButtonType)buttonType style:(PKPaymentButtonStyle)buttonStyle
{
    return [[self alloc] initWithPaymentButtonType:buttonType paymentButtonStyle:buttonStyle];
}

+ (instancetype)buttonWithType:(PKPaymentButtonType)buttonType style:(PKPaymentButtonStyle)buttonStyle disableCardArt:(BOOL)disableCardArt
{
    (void)disableCardArt;
    return [self buttonWithType:buttonType style:buttonStyle];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [self initWithPaymentButtonType:PKPaymentButtonTypePlain paymentButtonStyle:PKPaymentButtonStyleWhite];
    if (self) {
        self.frame = frame;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self revenantSetUpWithType:PKPaymentButtonTypePlain style:PKPaymentButtonStyleWhite];
    }
    return self;
}

- (instancetype)initWithPaymentButtonType:(PKPaymentButtonType)type paymentButtonStyle:(PKPaymentButtonStyle)style
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        [self revenantSetUpWithType:type style:style];
    }
    return self;
}

- (instancetype)initWithPaymentButtonType:(PKPaymentButtonType)type paymentButtonStyle:(PKPaymentButtonStyle)style disableCardArt:(BOOL)disableCardArt
{
    (void)disableCardArt;
    return [self initWithPaymentButtonType:type paymentButtonStyle:style];
}

- (void)revenantSetUpWithType:(PKPaymentButtonType)type style:(PKPaymentButtonStyle)style
{
    BOOL black = style == PKPaymentButtonStyleBlack;
    BOOL outline = style == PKPaymentButtonStyleWhiteOutline;
    UIColor *ink = black ? [UIColor whiteColor] : [UIColor blackColor];
    UIColor *fill = black ? [UIColor blackColor] : (outline ? [UIColor clearColor] : [UIColor whiteColor]);
    self.titleLabel.font = [UIFont boldSystemFontOfSize:17.0];
    [self setTitle:RevenantPaymentButtonTitle(type) forState:UIControlStateNormal];
    [self setTitleColor:ink forState:UIControlStateNormal];
    self.backgroundColor = fill;
    self.layer.cornerRadius = 4.0;
    self.layer.borderColor = [UIColor blackColor].CGColor;
    self.layer.borderWidth = outline ? 1.0 : 0.0;
    [self addTarget:self action:@selector(revenantReportUnavailable) forControlEvents:UIControlEventTouchUpInside];
}

- (CGFloat)cornerRadius
{
    return self.layer.cornerRadius;
}

- (void)setCornerRadius:(CGFloat)cornerRadius
{
    self.layer.cornerRadius = cornerRadius;
}

- (void)revenantReportUnavailable
{
    NSLog(@"PKPaymentButton: %@", RevenantPassKitNoHardwareError().localizedDescription);
}

@end

#import <UIKit/UIKit.h>
#import <PassKit/PassKit.h>
#import "RevenantPassKit.h"

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
    (void)type;
    UIColor *ink = style == PKPaymentButtonStyleBlack ? [UIColor whiteColor] : [UIColor blackColor];
    UIColor *fill = style == PKPaymentButtonStyleBlack ? [UIColor blackColor] : (style == PKPaymentButtonStyleWhiteOutline ? [UIColor clearColor] : [UIColor whiteColor]);
    [self setTitle:@"Pay" forState:UIControlStateNormal];
    [self setTitleColor:ink forState:UIControlStateNormal];
    self.backgroundColor = fill;
    self.layer.borderColor = [UIColor blackColor].CGColor;
    self.layer.borderWidth = style == PKPaymentButtonStyleWhiteOutline ? 1.0 : 0.0;
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

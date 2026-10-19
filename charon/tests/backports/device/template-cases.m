#import <UIKit/UIKit.h>
#import "template-cases.h"

static UIImage *icon(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 1);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [[UIColor redColor] setFill];
    CGContextFillRect(context, CGRectMake(0, 0, 10, 20));
    [[UIColor colorWithWhite:0 alpha:0.5] setFill];
    CGContextFillRect(context, CGRectMake(10, 0, 10, 10));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static NSString *pixel(UIView *view, int x, int y)
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, NO, 1);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    uint8_t found[4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(found, 1, 1, 8, 4, space, kCGImageAlphaPremultipliedLast);
    CGContextTranslateCTM(context, -x, -(view.bounds.size.height - y - 1));
    CGContextDrawImage(context, CGRectMake(0, 0, view.bounds.size.width, view.bounds.size.height), snapshot.CGImage);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return [NSString stringWithFormat:@"%d,%d,%d,%d", found[0], found[1], found[2], found[3]];
}

static UIColor *colour(CGFloat red, CGFloat green, CGFloat blue)
{
    return [UIColor colorWithRed:red green:green blue:blue alpha:1];
}

static UIImageView *shown(UIWindow *window, UIImage *image, CGSize size)
{
    UIImageView *view = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    view.image = image;
    [window addSubview:view];
    return view;
}

void template_run(UIWindow *window, TemplateRecorder record)
{
    UIImage *base = icon();
    UIImage *template = [base imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    UIImage *original = [base imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    UIImage *automatic = [base imageWithRenderingMode:UIImageRenderingModeAutomatic];
    record(@"modes", [NSString stringWithFormat:@"%ld %ld %ld %ld", (long)base.renderingMode, (long)template.renderingMode, (long)original.renderingMode, (long)automatic.renderingMode]);

    UIImageView *plain = shown(window, base, CGSizeMake(20, 20));
    record(@"plain", [NSString stringWithFormat:@"%@ %@", pixel(plain, 5, 5), pixel(plain, 15, 5)]);
    UIImageView *view = shown(window, template, CGSizeMake(20, 20));
    view.tintColor = colour(0, 1, 0);
    record(@"template.green", [NSString stringWithFormat:@"%@ %@ %@ same=%d mode=%ld", pixel(view, 5, 5), pixel(view, 15, 5), pixel(view, 15, 15), view.image == template, (long)view.image.renderingMode]);
    view.tintColor = colour(0.2, 0.4, 0.6);
    record(@"template.changed", [NSString stringWithFormat:@"%@ %@", pixel(view, 5, 5), pixel(view, 15, 5)]);
    UIView *superview = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    superview.tintColor = colour(1, 0.5, 0);
    [window addSubview:superview];
    UIImageView *inherited = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 20, 20)];
    inherited.image = template;
    [superview addSubview:inherited];
    record(@"inherited", pixel(inherited, 5, 5));
    superview.tintAdjustmentMode = UIViewTintAdjustmentModeDimmed;
    record(@"dimmed", pixel(inherited, 5, 5));
    superview.tintAdjustmentMode = UIViewTintAdjustmentModeNormal;
    superview.tintColor = colour(0, 0, 1);
    record(@"inherited.changed", pixel(inherited, 5, 5));
    UIImageView *moved = shown(window, template, CGSizeMake(20, 20));
    [superview addSubview:moved];
    record(@"moved.into", pixel(moved, 5, 5));
    UIView *other = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    other.tintColor = colour(1, 0, 1);
    [window addSubview:other];
    [other addSubview:moved];
    record(@"moved.across", pixel(moved, 5, 5));
    view.image = original;
    record(@"original", pixel(view, 5, 5));
    view.image = automatic;
    record(@"automatic", pixel(view, 5, 5));
    view.image = template;
    view.image = nil;
    record(@"cleared", [NSString stringWithFormat:@"%d", view.image == nil]);

    UIImageView *highlighted = shown(window, base, CGSizeMake(20, 20));
    highlighted.tintColor = colour(0, 0.5, 1);
    highlighted.highlightedImage = template;
    record(@"highlighted.getter", [NSString stringWithFormat:@"%d", highlighted.highlightedImage == template]);
    highlighted.highlighted = YES;
    record(@"highlighted", [NSString stringWithFormat:@"%@ %@", pixel(highlighted, 5, 5), pixel(highlighted, 15, 5)]);
    highlighted.tintColor = colour(1, 0, 0);
    record(@"highlighted.changed", pixel(highlighted, 5, 5));

    UIImageView *stretched = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 40, 40)];
    stretched.image = [template resizableImageWithCapInsets:UIEdgeInsetsMake(5, 5, 5, 5)];
    stretched.tintColor = colour(0, 1, 1);
    [window addSubview:stretched];
    record(@"resizable", [NSString stringWithFormat:@"%ld %@ %@ %@", (long)stretched.image.renderingMode, pixel(stretched, 5, 5), pixel(stretched, 30, 5), pixel(stretched, 30, 30)]);

    UIImageView *initial = [[UIImageView alloc] initWithImage:template];
    initial.tintColor = colour(1, 1, 0);
    [window addSubview:initial];
    record(@"initWithImage", pixel(initial, 5, 5));
    UIImageView *both = [[UIImageView alloc] initWithImage:base highlightedImage:template];
    both.tintColor = colour(0.5, 0, 1);
    [window addSubview:both];
    both.highlighted = YES;
    record(@"initWithImage.highlighted", pixel(both, 5, 5));

    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(0, 0, 60, 40);
    [button setImage:template forState:UIControlStateNormal];
    button.tintColor = colour(0, 0, 1);
    [window addSubview:button];
    [button layoutIfNeeded];
    record(@"button", [NSString stringWithFormat:@"same=%d %@", [button imageForState:UIControlStateNormal] == template, pixel(button.imageView, 5, 5)]);
    button.tintColor = colour(0, 1, 0);
    [button layoutIfNeeded];
    record(@"button.changed", pixel(button.imageView, 5, 5));
    UIButton *plainButton = [UIButton buttonWithType:UIButtonTypeCustom];
    plainButton.frame = CGRectMake(0, 0, 60, 40);
    [plainButton setImage:base forState:UIControlStateNormal];
    plainButton.tintColor = colour(0, 0, 1);
    [window addSubview:plainButton];
    [plainButton layoutIfNeeded];
    record(@"button.plain", pixel(plainButton.imageView, 5, 5));
}

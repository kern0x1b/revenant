#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char revenant_preferred_key, revenant_title_key, revenant_title_label_key;
static const CGFloat revenant_title_gap = 8;

@implementation UISwitch (RevenantStyle14)

- (UISwitchStyle)style
{
    return UISwitchStyleSliding;
}

- (UISwitchStyle)preferredStyle
{
    return (UISwitchStyle)[objc_getAssociatedObject(self, &revenant_preferred_key) integerValue];
}

- (void)setPreferredStyle:(UISwitchStyle)preferredStyle
{
    objc_setAssociatedObject(self, &revenant_preferred_key, @(preferredStyle), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)title
{
    return objc_getAssociatedObject(self, &revenant_title_key);
}

- (void)setTitle:(NSString *)title
{
    objc_setAssociatedObject(self, &revenant_title_key, [title copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UILabel *label = objc_getAssociatedObject(self, &revenant_title_label_key);
    if (!title.length) {
        [label removeFromSuperview];
        objc_setAssociatedObject(self, &revenant_title_label_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (!label) {
        label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.backgroundColor = [UIColor clearColor];
        label.font = [UIFont systemFontOfSize:17];
        label.textColor = [UIColor blackColor];
        [self addSubview:label];
        objc_setAssociatedObject(self, &revenant_title_label_key, label, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    label.text = title;
    [label sizeToFit];
    CGRect frame = label.frame;
    frame.origin = CGPointMake(-(CGRectGetWidth(frame) + revenant_title_gap), (CGRectGetHeight(self.bounds) - CGRectGetHeight(frame)) / 2);
    label.frame = frame;
}

@end

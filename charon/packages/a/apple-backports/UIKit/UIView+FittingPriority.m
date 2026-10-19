#import <UIKit/UIKit.h>

@implementation UIView (CharonFittingPriority)

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize withHorizontalFittingPriority:(UILayoutPriority)horizontalFittingPriority verticalFittingPriority:(UILayoutPriority)verticalFittingPriority
{
    NSMutableArray *held = [NSMutableArray array];
    if (horizontalFittingPriority > UILayoutPriorityDefaultLow) {
        NSLayoutConstraint *width = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:targetSize.width];
        width.priority = horizontalFittingPriority;
        [held addObject:width];
    }
    if (verticalFittingPriority > UILayoutPriorityDefaultLow) {
        NSLayoutConstraint *height = [NSLayoutConstraint constraintWithItem:self attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:targetSize.height];
        height.priority = verticalFittingPriority;
        [held addObject:height];
    }
    [self addConstraints:held];
    CGSize fitted = [self systemLayoutSizeFittingSize:targetSize];
    [self removeConstraints:held];
    return fitted;
}

@end

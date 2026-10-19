#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char revenant_estimated_row_key;
static const char revenant_estimated_header_key;
static const char revenant_estimated_footer_key;

static CGFloat revenant_estimate(UITableView *table, const void *key)
{
    NSNumber *value = objc_getAssociatedObject(table, key);
    return value ? value.doubleValue : UITableViewAutomaticDimension;
}

static void revenant_set_estimate(UITableView *table, const void *key, CGFloat value, NSString *name)
{
    if (value < 0 && value != UITableViewAutomaticDimension)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid estimated %@ set (%g). Value must be at least 0.0, or UITableViewAutomaticDimension.", name, value];
    objc_setAssociatedObject(table, key, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UITableView (RevenantEstimatedHeights)

- (CGFloat)estimatedRowHeight
{
    return revenant_estimate(self, &revenant_estimated_row_key);
}

- (void)setEstimatedRowHeight:(CGFloat)estimatedRowHeight
{
    revenant_set_estimate(self, &revenant_estimated_row_key, estimatedRowHeight, @"row height");
}

- (CGFloat)estimatedSectionHeaderHeight
{
    return revenant_estimate(self, &revenant_estimated_header_key);
}

- (void)setEstimatedSectionHeaderHeight:(CGFloat)estimatedSectionHeaderHeight
{
    revenant_set_estimate(self, &revenant_estimated_header_key, estimatedSectionHeaderHeight, @"section header height");
}

- (CGFloat)estimatedSectionFooterHeight
{
    return revenant_estimate(self, &revenant_estimated_footer_key);
}

- (void)setEstimatedSectionFooterHeight:(CGFloat)estimatedSectionFooterHeight
{
    revenant_set_estimate(self, &revenant_estimated_footer_key, estimatedSectionFooterHeight, @"section footer height");
}

@end

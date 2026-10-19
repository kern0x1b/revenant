#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_estimated_row_key;
static const char charon_estimated_header_key;
static const char charon_estimated_footer_key;

static CGFloat charon_estimate(UITableView *table, const void *key)
{
    NSNumber *value = objc_getAssociatedObject(table, key);
    return value ? value.doubleValue : UITableViewAutomaticDimension;
}

static void charon_set_estimate(UITableView *table, const void *key, CGFloat value, NSString *name)
{
    if (value < 0 && value != UITableViewAutomaticDimension)
        [NSException raise:NSInternalInconsistencyException format:@"Invalid estimated %@ set (%g). Value must be at least 0.0, or UITableViewAutomaticDimension.", name, value];
    objc_setAssociatedObject(table, key, @(value), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@implementation UITableView (CharonEstimatedHeights)

- (CGFloat)estimatedRowHeight
{
    return charon_estimate(self, &charon_estimated_row_key);
}

- (void)setEstimatedRowHeight:(CGFloat)estimatedRowHeight
{
    charon_set_estimate(self, &charon_estimated_row_key, estimatedRowHeight, @"row height");
}

- (CGFloat)estimatedSectionHeaderHeight
{
    return charon_estimate(self, &charon_estimated_header_key);
}

- (void)setEstimatedSectionHeaderHeight:(CGFloat)estimatedSectionHeaderHeight
{
    charon_set_estimate(self, &charon_estimated_header_key, estimatedSectionHeaderHeight, @"section header height");
}

- (CGFloat)estimatedSectionFooterHeight
{
    return charon_estimate(self, &charon_estimated_footer_key);
}

- (void)setEstimatedSectionFooterHeight:(CGFloat)estimatedSectionFooterHeight
{
    charon_set_estimate(self, &charon_estimated_footer_key, estimatedSectionFooterHeight, @"section footer height");
}

@end

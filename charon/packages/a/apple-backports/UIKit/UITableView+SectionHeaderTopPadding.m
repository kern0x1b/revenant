#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char charon_section_header_top_padding_key;

@implementation UITableView (CharonSectionHeaderTopPadding)

- (CGFloat)sectionHeaderTopPadding
{
    NSNumber *kept = objc_getAssociatedObject(self, &charon_section_header_top_padding_key);
    return kept ? kept.doubleValue : UITableViewAutomaticDimension;
}

- (void)setSectionHeaderTopPadding:(CGFloat)sectionHeaderTopPadding
{
    if (sectionHeaderTopPadding < 0)
        sectionHeaderTopPadding = UITableViewAutomaticDimension;
    if (sectionHeaderTopPadding > 0) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            NSLog(@"UITableView.sectionHeaderTopPadding is kept and not applied on iOS 6: a section header has no padding above it");
        });
    }
    objc_setAssociatedObject(self, &charon_section_header_top_padding_key, @(sectionHeaderTopPadding), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

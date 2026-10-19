#import "fitting-cases.h"

static NSString *fit(UIView *view, CGSize target, UILayoutPriority horizontal, UILayoutPriority vertical)
{
    CGSize size = [view systemLayoutSizeFittingSize:target withHorizontalFittingPriority:horizontal verticalFittingPriority:vertical];
    return [NSString stringWithFormat:@"%g x %g", ceil(size.width), ceil(size.height)];
}

void fitting_run(UIWindow *window, FittingRecorder record)
{
    UIViewController *root = [[UIViewController alloc] init];
    window.rootViewController = root;
    UIView *card = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    UILabel *label = [[UILabel alloc] init];
    label.font = [UIFont fontWithName:@"Courier" size:14];
    label.numberOfLines = 0;
    label.text = @"Another rather long sentence with quite a few words in it to make it wrap around twice";
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:label];
    NSDictionary *views = @{@"l": label};
    [card addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-8-[l]-8-|" options:0 metrics:nil views:views]];
    [card addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-6-[l]-6-|" options:0 metrics:nil views:views]];
    [root.view addSubview:card];
    for (NSNumber *width in @[@320, @200, @150]) {
        label.preferredMaxLayoutWidth = width.doubleValue - 16;
        record([NSString stringWithFormat:@"width%@", width], fit(card, CGSizeMake(width.doubleValue, 0), UILayoutPriorityRequired, UILayoutPriorityFittingSizeLevel));
    }
    label.preferredMaxLayoutWidth = 304;
    record(@"compressed", fit(card, UILayoutFittingCompressedSize, UILayoutPriorityFittingSizeLevel, UILayoutPriorityFittingSizeLevel));
    record(@"expanded", fit(card, UILayoutFittingExpandedSize, UILayoutPriorityFittingSizeLevel, UILayoutPriorityFittingSizeLevel));
    record(@"heightRequired", fit(card, CGSizeMake(0, 120), UILayoutPriorityFittingSizeLevel, UILayoutPriorityRequired));
    record(@"bothRequired", fit(card, CGSizeMake(320, 90), UILayoutPriorityRequired, UILayoutPriorityRequired));
    record(@"highHigh", fit(card, CGSizeMake(320, 90), UILayoutPriorityDefaultHigh, UILayoutPriorityDefaultHigh));
    record(@"lowLow", fit(card, CGSizeMake(320, 90), UILayoutPriorityDefaultLow, UILayoutPriorityDefaultLow));
    label.preferredMaxLayoutWidth = 304;
    record(@"widthAfter", fit(card, CGSizeMake(320, 0), UILayoutPriorityRequired, UILayoutPriorityFittingSizeLevel));
    record(@"constraintsKept", [NSString stringWithFormat:@"%lu", (unsigned long)card.constraints.count]);
}

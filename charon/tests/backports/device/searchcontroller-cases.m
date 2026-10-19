#import "searchcontroller-cases.h"

static void spin(NSTimeInterval seconds)
{
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while (end.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
}

static BOOL shown(UIView *view)
{
    if (!view.window)
        return NO;
    for (UIView *current = view; current; current = current.superview) {
        if (current.hidden || current.alpha < 0.01)
            return NO;
    }
    return YES;
}

static UITextField *textField(UIView *view)
{
    if ([view isKindOfClass:[UITextField class]])
        return (UITextField *)view;
    for (UIView *subview in view.subviews) {
        UITextField *found = textField(subview);
        if (found)
            return found;
    }
    return nil;
}

static UIButton *cancelButton(UIView *view)
{
    if ([view isKindOfClass:[UIButton class]] && !view.hidden && [((UIButton *)view) titleForState:UIControlStateNormal].length)
        return (UIButton *)view;
    for (UIView *subview in view.subviews) {
        UIButton *found = cancelButton(subview);
        if (found)
            return found;
    }
    return nil;
}

@interface SearchWatcher : NSObject <UISearchControllerDelegate, UISearchResultsUpdating, UISearchBarDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *log;
@property (nonatomic, weak) UIViewController *modalHost;
@property (nonatomic) BOOL presentsItself;
@end

@implementation SearchWatcher

- (instancetype)init
{
    self = [super init];
    _log = [NSMutableArray array];
    return self;
}

- (void)willPresentSearchController:(UISearchController *)controller
{
    [self.log addObject:@"willPresent"];
}

- (void)didPresentSearchController:(UISearchController *)controller
{
    [self.log addObject:@"didPresent"];
}

- (void)willDismissSearchController:(UISearchController *)controller
{
    [self.log addObject:[NSString stringWithFormat:@"willDismiss active=%d", controller.active]];
}

- (void)didDismissSearchController:(UISearchController *)controller
{
    [self.log addObject:[NSString stringWithFormat:@"didDismiss active=%d", controller.active]];
}

- (void)presentSearchController:(UISearchController *)controller
{
    [self.log addObject:@"presentSearchController"];
    [self.modalHost presentViewController:controller animated:NO completion:nil];
}

- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(presentSearchController:))
        return self.presentsItself;
    return [super respondsToSelector:selector];
}

- (void)updateSearchResultsForSearchController:(UISearchController *)controller
{
    [self.log addObject:[NSString stringWithFormat:@"update text=%@", controller.searchBar.text ?: @"nil"]];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    [self.log addObject:[NSString stringWithFormat:@"app textDidChange %@", searchText]];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self.log addObject:@"app cancel"];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [self.log addObject:@"app search"];
}

@end

static NSString *joined(NSArray *log)
{
    NSMutableArray *collapsed = [NSMutableArray array];
    for (NSString *entry in log) {
        if (![collapsed.lastObject isEqualToString:entry])
            [collapsed addObject:entry];
    }
    return collapsed.count ? [collapsed componentsJoinedByString:@" | "] : @"none";
}

static NSString *where(UIView *bar, UITableViewController *table)
{
    if (!bar.superview)
        return @"detached";
    if (bar.superview == table.tableView)
        return @"table";
    return [bar.superview isDescendantOfView:table.view.window] ? @"in the window elsewhere" : @"outside";
}

void searchcontroller_run(UIWindow *window, SearchCaseRecorder record)
{
    UITableViewController *table = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
    table.title = @"Search";
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:table];
    window.rootViewController = navigation;
    [window makeKeyAndVisible];
    spin(0.5);
    UIViewController *results = [[UIViewController alloc] init];
    results.view.backgroundColor = [UIColor whiteColor];
    UISearchController *controller = [[UISearchController alloc] initWithSearchResultsController:results];
    SearchWatcher *watcher = [[SearchWatcher alloc] init];
    UISearchBar *bar = controller.searchBar;
    table.definesPresentationContext = YES;

    record(@"new.state", [NSString stringWithFormat:@"active=%d updater=%d delegate=%d results=%d dims=%d obscures=%d hidesNav=%d cancel=%d", controller.active, controller.searchResultsUpdater != nil, controller.delegate != nil, controller.searchResultsController == results,
                          controller.dimsBackgroundDuringPresentation, controller.obscuresBackgroundDuringPresentation, controller.hidesNavigationBarDuringPresentation, bar.showsCancelButton]);
    record(@"new.bar", [NSString stringWithFormat:@"class=%@ placeholder=%@ barDelegate=%d text=%@", NSStringFromClass([bar class]), bar.placeholder ?: @"nil", bar.delegate != nil, bar.text ?: @"nil"]);
    controller.dimsBackgroundDuringPresentation = NO;
    record(@"flags.alias", [NSString stringWithFormat:@"obscures=%d", controller.obscuresBackgroundDuringPresentation]);
    controller.dimsBackgroundDuringPresentation = YES;

    bar.frame = CGRectMake(0, 0, table.tableView.bounds.size.width, 44);
    table.tableView.tableHeaderView = bar;
    controller.delegate = watcher;
    controller.searchResultsUpdater = watcher;
    spin(0.3);

    [watcher.log removeAllObjects];
    controller.active = YES;
    record(@"present.sync", [NSString stringWithFormat:@"active=%d log=%@", controller.active, joined(watcher.log)]);
    spin(1.5);
    record(@"present.log", joined(watcher.log));
    record(@"present.state", [NSString stringWithFormat:@"view shown=%d bar=%@ barShown=%d navHidden=%d resultsShown=%d cancel=%d presented=%d", shown(controller.view), where(bar, table), shown(bar), navigation.navigationBarHidden, shown(results.view), bar.showsCancelButton, controller.presentedViewController != nil]);
    record(@"present.parent", [NSString stringWithFormat:@"parent=%@ presenting=%@", controller.parentViewController ? NSStringFromClass([controller.parentViewController class]) : @"nil", controller.presentingViewController ? NSStringFromClass([controller.presentingViewController class]) : @"nil"]);

    [watcher.log removeAllObjects];
    UITextField *field = textField(bar);
    record(@"typing.field", field ? @"found" : @"missing");
    [field becomeFirstResponder];
    spin(0.5);
    [field insertText:@"ab"];
    spin(0.5);
    record(@"typing.log", joined(watcher.log));
    record(@"typing.state", [NSString stringWithFormat:@"text=%@ resultsShown=%d firstResponder=%d", bar.text ?: @"nil", shown(results.view), [field isFirstResponder]]);
    [watcher.log removeAllObjects];
    bar.delegate = watcher;
    [field insertText:@"c"];
    spin(0.5);
    record(@"typing.appDelegate", [NSString stringWithFormat:@"%@ || delegate=%d", joined(watcher.log), bar.delegate == watcher]);
    [watcher.log removeAllObjects];
    [field deleteBackward];
    [field deleteBackward];
    [field deleteBackward];
    spin(0.5);
    record(@"typing.emptied", [NSString stringWithFormat:@"%@ || resultsShown=%d text=%@", joined(watcher.log), shown(results.view), bar.text ?: @"nil"]);

    [watcher.log removeAllObjects];
    [field insertText:@"typed"];
    spin(0.3);
    [watcher.log removeAllObjects];
    UIButton *cancel = cancelButton(bar);
    record(@"cancel.button", cancel ? @"found" : @"missing");
    if (cancel)
        [cancel sendActionsForControlEvents:UIControlEventTouchUpInside];
    else
        controller.active = NO;
    record(@"cancel.sync", [NSString stringWithFormat:@"%@ || active=%d", joined(watcher.log), controller.active]);
    spin(1.5);
    record(@"cancel.log", joined(watcher.log));
    record(@"cancel.state", [NSString stringWithFormat:@"viewAttached=%d parent=%d bar=%@ frame=%@ navHidden=%d text=%@ cancel=%d", controller.view.superview != nil, controller.parentViewController != nil, where(bar, table), NSStringFromCGRect(bar.frame), navigation.navigationBarHidden, bar.text ?: @"nil", bar.showsCancelButton]);

    [watcher.log removeAllObjects];
    controller.active = NO;
    record(@"inactive.noop", joined(watcher.log));

    controller.hidesNavigationBarDuringPresentation = NO;
    controller.dimsBackgroundDuringPresentation = NO;
    [watcher.log removeAllObjects];
    controller.active = YES;
    spin(1.5);
    record(@"options.present", [NSString stringWithFormat:@"navHidden=%d log=%@", navigation.navigationBarHidden, joined(watcher.log)]);
    controller.active = NO;
    spin(1.5);
    record(@"options.dismiss", [NSString stringWithFormat:@"active=%d attached=%d", controller.active, controller.view.superview != nil]);
    controller.hidesNavigationBarDuringPresentation = YES;
    controller.dimsBackgroundDuringPresentation = YES;

    watcher.presentsItself = YES;
    watcher.modalHost = table;
    [watcher.log removeAllObjects];
    controller.active = YES;
    spin(1);
    record(@"delegatePresents.present", [NSString stringWithFormat:@"%@ || active=%d presented=%d", joined(watcher.log), controller.active, table.presentedViewController == controller]);
    [watcher.log removeAllObjects];
    controller.active = NO;
    spin(1.5);
    record(@"delegatePresents.dismiss", [NSString stringWithFormat:@"%@ || active=%d presented=%d", joined(watcher.log), controller.active, table.presentedViewController != nil]);
    watcher.presentsItself = NO;

    [watcher.log removeAllObjects];
    controller.searchResultsUpdater = nil;
    controller.active = YES;
    spin(1);
    controller.active = NO;
    spin(1);
    record(@"noUpdater.log", joined(watcher.log));
}

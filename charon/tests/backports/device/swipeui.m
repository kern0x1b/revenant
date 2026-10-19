#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "check.h"
#import "gesture.h"

static NSString *const results_folder = @"/private/var/backports";

@interface SwipeSource : NSObject <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) NSMutableArray *events;
@property (nonatomic) NSInteger rows;
@end

@implementation SwipeSource

- (instancetype)init
{
    if ((self = [super init])) {
        _events = [NSMutableArray array];
        _rows = 30;
    }
    return self;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
    return _rows;
}

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path
{
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    cell.textLabel.text = [NSString stringWithFormat:@"row %ld", (long)path.row];
    return cell;
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path
{
    [_events addObject:[NSString stringWithFormat:@"commit %ld", (long)path.row]];
}

- (void)tableView:(UITableView *)table didSelectRowAtIndexPath:(NSIndexPath *)path
{
    [_events addObject:[NSString stringWithFormat:@"select %ld", (long)path.row]];
}

- (void)tableView:(UITableView *)table willBeginEditingRowAtIndexPath:(NSIndexPath *)path
{
    [_events addObject:[NSString stringWithFormat:@"willBegin %ld", (long)path.row]];
}

- (void)tableView:(UITableView *)table didEndEditingRowAtIndexPath:(NSIndexPath *)path
{
    [_events addObject:[NSString stringWithFormat:@"didEnd %ld", (long)path.row]];
}

- (NSArray *)tableView:(UITableView *)table editActionsForRowAtIndexPath:(NSIndexPath *)path
{
    UITableViewRowAction *remove = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction *action, NSIndexPath *where) {
        [self.events addObject:[NSString stringWithFormat:@"delete %ld", (long)where.row]];
    }];
    UITableViewRowAction *more = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"More options" handler:^(UITableViewRowAction *action, NSIndexPath *where) {
        [self.events addObject:[NSString stringWithFormat:@"more %ld", (long)where.row]];
    }];
    return @[remove, more];
}

@end

@interface SwipeConfigured : SwipeSource
@property (nonatomic) BOOL fullSwipe;
@end

@implementation SwipeConfigured

- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(tableView:editActionsForRowAtIndexPath:))
        return NO;
    return [super respondsToSelector:selector];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)table trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)path
{
    UIContextualAction *archive = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Archive" handler:^(UIContextualAction *action, UIView *source, void (^completion)(BOOL)) {
        [self.events addObject:[NSString stringWithFormat:@"archive %ld source=%d", (long)path.row, source != nil]];
        completion(YES);
    }];
    archive.backgroundColor = [UIColor blueColor];
    UIContextualAction *flag = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:@"Flag" handler:^(UIContextualAction *action, UIView *source, void (^completion)(BOOL)) {
        [self.events addObject:[NSString stringWithFormat:@"flag %ld", (long)path.row]];
        completion(NO);
    }];
    UISwipeActionsConfiguration *configuration = [UISwipeActionsConfiguration configurationWithActions:@[archive, flag]];
    configuration.performsFirstActionWithFullSwipe = self.fullSwipe;
    return configuration;
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)table leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)path
{
    UIContextualAction *pin = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleNormal title:@"Pin" handler:^(UIContextualAction *action, UIView *source, void (^completion)(BOOL)) {
        [self.events addObject:[NSString stringWithFormat:@"pin %ld", (long)path.row]];
        completion(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[pin]];
}

@end

@interface SwipeBare : SwipeSource
@end

@implementation SwipeBare

- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(tableView:editActionsForRowAtIndexPath:))
        return NO;
    return [super respondsToSelector:selector];
}

@end

static UIWindow *the_window;
static UITableView *the_table;
static SwipeSource *the_source;

static UITableViewCell *cell_at(NSInteger row)
{
    return [the_table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
}

static CGFloat shift(NSInteger row)
{
    return cell_at(row).contentView.transform.tx;
}

static CGPoint row_point(NSInteger row, CGFloat x)
{
    CGRect rect = [the_table rectForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0]];
    return [the_table convertPoint:CGPointMake(x, CGRectGetMidY(rect)) toView:nil];
}

static CGFloat table_width(void)
{
    return the_table.bounds.size.width;
}

static NSString *joined(void)
{
    return [the_source.events componentsJoinedByString:@","];
}

static NSArray *buttons_of(NSInteger row)
{
    for (UIView *view in cell_at(row).subviews)
        if (strstr(class_getName([view class]), "CharonSwipeContainer"))
            return view.subviews;
    return nil;
}

static CGPoint centre_of(UIView *button)
{
    return [button.superview convertPoint:CGPointMake(CGRectGetMidX(button.frame), CGRectGetMidY(button.frame)) toView:nil];
}

static BOOL any_open(void)
{
    for (UITableViewCell *cell in the_table.visibleCells)
        if (fabs(cell.contentView.transform.tx) > 1)
            return YES;
    return NO;
}

static NSInteger visible_row(void)
{
    return [[the_table indexPathsForVisibleRows][2] row];
}

static void use_table(SwipeSource *source)
{
    gesture_step(0.3, ^{
        the_source = source;
        the_table = [[UITableView alloc] initWithFrame:the_window.bounds];
        the_table.dataSource = source;
        the_table.delegate = source;
        UIViewController *controller = [[UIViewController alloc] init];
        controller.view = the_table;
        the_window.rootViewController = controller;
        [the_table layoutIfNeeded];
    });
}

static void rows_scenario(void)
{
    use_table([[SwipeSource alloc] init]);
    gesture_drag(^{ return row_point(1, table_width() - 30); }, ^{ return row_point(1, table_width() - 150); }, 8, 0.6);
    gesture_step(0.1, ^{
        NSArray *buttons = buttons_of(1);
        CHECK(buttons.count == 2, "a swipe left on a row of a delegate that answers row actions shows two buttons");
        CHECK(shift(1) < -100, "and the content of the row has slid to the left");
        CGFloat total = 0;
        for (UIView *button in buttons)
            total += button.frame.size.width;
        CHECK(fabs(-shift(1) - total) < 1.5, "by the width of the buttons together");
        if (buttons.count == 2) {
            CHECK(((UIView *)buttons[0]).frame.origin.x > ((UIView *)buttons[1]).frame.origin.x, "the second action is to the left of the first, which is at the edge");
            CHECK(((UIView *)buttons[0]).backgroundColor != nil, "each has its colour");
        }
        CHECK([joined() isEqualToString:@"willBegin 1"], "the delegate is told that editing of the row begins");
    });
    gesture_tap(^{ return centre_of(buttons_of(1)[0]); }, 0.8);
    gesture_step(0.1, ^{
        CHECK([joined() hasPrefix:@"willBegin 1,delete 1"], "a tap on the button at the edge runs its handler with the row's index path");
        CHECK(fabs(shift(1)) < 0.5 && buttons_of(1) == nil, "and the row closes after it");
        CHECK([the_source.events containsObject:@"didEnd 1"], "and the delegate is told that editing of the row ended");
        [the_source.events removeAllObjects];
    });
    gesture_drag(^{ return row_point(2, table_width() - 30); }, ^{ return row_point(2, table_width() - 170); }, 6, 0.6);
    gesture_step(0.1, ^{
        CHECK(fabs(shift(2)) > 100, "a drag over half the buttons opens the row and it stays open");
    });
    gesture_tap(^{ return row_point(4, 60); }, 0.6);
    gesture_step(0.1, ^{
        CHECK(!any_open() && buttons_of(2) == nil, "a tap on another row closes it");
        CHECK(![joined() containsString:@"select"], "and selects nothing");
        [the_source.events removeAllObjects];
    });
    gesture_drag(^{ return row_point(3, table_width() - 20); }, ^{ return row_point(3, 20); }, 10, 1.0);
    gesture_step(0.1, ^{
        CHECK([joined() containsString:@"delete 3"], "a swipe across the row runs the first action");
        CHECK(!any_open(), "and the row is closed after it");
        [the_source.events removeAllObjects];
    });
    __block CGFloat before = 0;
    gesture_step(0.1, ^{ before = the_table.contentOffset.y; });
    gesture_drag(^{ return CGPointMake(160, 400); }, ^{ return CGPointMake(160, 200); }, 8, 2.0);
    gesture_step(0.1, ^{
        CHECK(the_table.contentOffset.y > before + 20, "a vertical drag still scrolls the table");
        CHECK(!any_open(), "and swipes nothing");
    });
    gesture_drag(^{ return row_point(visible_row(), table_width() - 30); }, ^{ return row_point(visible_row(), table_width() - 170); }, 6, 0.6);
    __block CGFloat scrolled = 0;
    gesture_step(0.1, ^{ scrolled = the_table.contentOffset.y; CHECK(any_open(), "a row is open again"); });
    gesture_drag(^{ return CGPointMake(160, 250); }, ^{ return CGPointMake(160, 400); }, 6, 2.0);
    gesture_step(0.1, ^{
        CHECK(fabs(the_table.contentOffset.y - scrolled) > 20, "the table scrolls with a row open");
        CHECK(!any_open(), "and the open row closes when it does");
    });
}

static void edges_scenario(void)
{
    use_table([[SwipeSource alloc] init]);
    gesture_drag(^{ return row_point(1, table_width() - 30); }, ^{ return row_point(1, table_width() - 170); }, 6, 0.6);
    gesture_step(0.1, ^{
        CHECK(fabs(shift(1)) > 100, "a row is open");
        [the_source.events removeAllObjects];
        [the_table setEditing:YES animated:NO];
    });
    gesture_step(0.3, ^{
        CHECK(!any_open() && buttons_of(1) == nil, "entering editing mode closes an open row");
        CHECK([the_source.events containsObject:@"didEnd 1"], "and tells the delegate");
    });
    gesture_drag(^{ return row_point(2, table_width() - 30); }, ^{ return row_point(2, table_width() - 170); }, 6, 0.6);
    gesture_step(0.1, ^{
        CHECK(buttons_of(2) == nil, "a table that is editing shows no swipe actions");
        [the_table setEditing:NO animated:NO];
    });
    gesture_step(0.3, ^{});
    gesture_drag(^{ return row_point(2, table_width() - 30); }, ^{ return row_point(2, table_width() - 170); }, 6, 0.6);
    gesture_step(0.1, ^{
        CHECK(fabs(shift(2)) > 100, "and does again when it stops");
        [the_source.events removeAllObjects];
        [the_table reloadData];
    });
    gesture_step(0.3, ^{
        CHECK(!any_open() && buttons_of(2) == nil && fabs(shift(2)) < 0.5, "reloading the table closes an open row");
        CHECK([the_source.events containsObject:@"didEnd 2"], "and tells the delegate");
    });
    gesture_drag(^{ return row_point(3, table_width() - 30); }, ^{ return row_point(3, table_width() - 170); }, 6, 0.6);
    gesture_step(0.1, ^{
        CHECK(fabs(shift(3)) > 100, "a row opens after a reload");
        the_source.rows = 29;
        [the_table deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:3 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
    });
    gesture_step(0.5, ^{
        CHECK(!any_open(), "deleting the open row leaves no row open, and the row that takes its place is at rest");
    });
    gesture_drag(^{ return row_point(1, table_width() - 30); }, ^{ return row_point(1, table_width() - 170); }, 6, 0.6);
    gesture_step(0.1, ^{
        CHECK(fabs(shift(1)) > 100, "a row is open before the table is resized");
        CGRect frame = the_table.frame;
        frame.size.width -= 40;
        the_table.frame = frame;
        [the_table layoutIfNeeded];
    });
    gesture_step(0.5, ^{
        CHECK(!any_open() && buttons_of(1) == nil, "a change of the table's width, as a rotation makes, closes it");
        CGRect frame = the_table.frame;
        frame.size.width += 40;
        the_table.frame = frame;
    });
    gesture_step(0.3, ^{});
    gesture_drag(^{ return row_point(1, table_width() - 30); }, ^{ return row_point(1, table_width() - 170); }, 6, 0.6);
    gesture_step(0.1, ^{
        CHECK(fabs(shift(1)) > 100, "a row is open before the table scrolls away from it");
        [the_table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:25 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        [the_table layoutIfNeeded];
        [the_table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
        [the_table layoutIfNeeded];
    });
    gesture_step(0.5, ^{
        CHECK(!any_open(), "a row that scrolls away and comes back is at rest");
    });
    gesture_drag(^{ return row_point(4, table_width() - 30); }, ^{ return row_point(4, table_width() - 170); }, 6, 0.6);
    gesture_step(0.1, ^{
        CHECK(fabs(shift(4)) > 100, "and a swipe still opens a row afterwards");
    });
}

static void lifetime_scenario(void)
{
    gesture_step(0.1, ^{
        __weak UITableView *weakTable = nil;
        for (int round = 0; round < 40; round++) {
            @autoreleasepool {
                SwipeSource *source = [[SwipeSource alloc] init];
                UITableView *bare = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
                (void)bare;
                UITableView *withDelegate = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
                withDelegate.dataSource = source;
                withDelegate.delegate = source;
                [withDelegate layoutIfNeeded];
                UITableView *cleared = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
                cleared.dataSource = source;
                cleared.delegate = source;
                cleared.delegate = nil;
                weakTable = withDelegate;
            }
        }
        CHECK(weakTable == nil, "tables made with, without and with a cleared delegate go away without a crash, and the last one is gone");
        UITableView *empty = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
        empty.delegate = nil;
        CHECK(empty.gestureRecognizers.count > 0, "a table without a delegate still works");
        SwipeSource *source = [[SwipeSource alloc] init];
        UITableView *late = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, 320, 400)];
        late.dataSource = source;
        late.delegate = nil;
        late.delegate = source;
        [late layoutIfNeeded];
        NSUInteger recognizers = 0;
        for (UIGestureRecognizer *recognizer in late.gestureRecognizers)
            if (strstr(class_getName([recognizer class]), "UIPanGestureRecognizer") && ![recognizer isKindOfClass:NSClassFromString(@"UIScrollViewPanGestureRecognizer")])
                recognizers++;
        CHECK(recognizers == 1, "a delegate set after a nil one gets the swipe recognizer, once");
        late.delegate = source;
        late.delegate = nil;
        late.delegate = source;
        recognizers = 0;
        for (UIGestureRecognizer *recognizer in late.gestureRecognizers)
            if (strstr(class_getName([recognizer class]), "UIPanGestureRecognizer") && ![recognizer isKindOfClass:NSClassFromString(@"UIScrollViewPanGestureRecognizer")])
                recognizers++;
        CHECK(recognizers == 1, "and setting the delegate again does not add another");
    });
}

static void bare_scenario(void)
{
    use_table([[SwipeBare alloc] init]);
    gesture_drag(^{ return row_point(1, table_width() - 30); }, ^{ return row_point(1, table_width() - 150); }, 8, 0.6);
    gesture_step(0.1, ^{
        CHECK(buttons_of(1) == nil && fabs(shift(1)) < 0.5, "a table whose delegate answers no actions is left to the release");
    });
}

static void configuration_scenario(void)
{
    use_table([[SwipeConfigured alloc] init]);
    gesture_drag(^{ return row_point(1, table_width() - 30); }, ^{ return row_point(1, table_width() - 200); }, 8, 0.6);
    gesture_step(0.1, ^{
        NSArray *buttons = buttons_of(1);
        CHECK(buttons.count == 2, "the trailing configuration shows its two actions");
        UIView *first = buttons.count == 2 ? buttons[0] : nil;
        CHECK([[[first valueForKey:@"item"] valueForKey:@"color"] isEqual:[UIColor blueColor]], "the first action is at the edge with the colour it was given");
    });
    gesture_tap(^{ return centre_of(buttons_of(1)[0]); }, 0.8);
    gesture_step(0.1, ^{
        CHECK([joined() containsString:@"archive 1 source=1"], "a tap runs the handler with the action's view as its source");
        CHECK(!any_open(), "and the completion handler closes the row");
        [the_source.events removeAllObjects];
    });
    gesture_drag(^{ return row_point(2, 30); }, ^{ return row_point(2, 200); }, 8, 0.6);
    gesture_step(0.1, ^{
        CHECK(buttons_of(2).count == 1 && shift(2) > 60, "a swipe to the right shows the leading action and slides the row to the right");
    });
    gesture_tap(^{ return row_point(5, 60); }, 0.6);
    gesture_drag(^{ return row_point(3, table_width() - 20); }, ^{ return row_point(3, 20); }, 10, 0.8);
    gesture_step(0.1, ^{
        CHECK(![joined() containsString:@"archive"], "a swipe across a row whose configuration does not ask for a full swipe runs nothing");
        CHECK(fabs(shift(3)) > 100, "and leaves it open");
    });
    gesture_tap(^{ return row_point(6, 60); }, 0.6);
    gesture_step(0.1, ^{
        ((SwipeConfigured *)the_source).fullSwipe = YES;
        [the_source.events removeAllObjects];
    });
    gesture_drag(^{ return row_point(4, table_width() - 20); }, ^{ return row_point(4, 20); }, 10, 1.0);
    gesture_step(0.1, ^{
        CHECK([joined() containsString:@"archive 4"], "with full swipe it runs the first action");
    });
}

@interface SwipeDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation SwipeDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"swipeui.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"swipeui.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    the_window = self.window;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gesture_step(0.01, ^{ CHECK(gesture_ready(), "touches can be sent to the application through the HID event system"); });
        rows_scenario();
        lifetime_scenario();
        bare_scenario();
        edges_scenario();
        configuration_scenario();
        gesture_run(^{
            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"swipeui.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([SwipeDelegate class]));
    }
}

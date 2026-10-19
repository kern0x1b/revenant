#import <UIKit/UIKit.h>
#include <dlfcn.h>
#import <objc/runtime.h>
#import "check.h"
#import "gesture.h"

static NSString *const results_folder = @"/private/var/backports";

typedef struct {
    int width, height;
    unsigned char *pixels;
} Screen;

static Screen native_screen, facade_screen;

static Screen shot(NSString *name)
{
    Screen screen = {0, 0, NULL};
    CGImageRef (*capture)(void) = dlsym(RTLD_DEFAULT, "UIGetScreenImage");
    if (!capture)
        return screen;
    CGImageRef image = capture();
    NSData *data = UIImagePNGRepresentation([UIImage imageWithCGImage:image]);
    [data writeToFile:[results_folder stringByAppendingPathComponent:[NSString stringWithFormat:@"swipelook-%@.png", name]] atomically:YES];
    screen.width = (int)CGImageGetWidth(image);
    screen.height = (int)CGImageGetHeight(image);
    screen.pixels = calloc((size_t)screen.width * screen.height, 4);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(screen.pixels, screen.width, screen.height, 8, screen.width * 4, space, kCGImageAlphaPremultipliedLast);
    CGContextDrawImage(context, CGRectMake(0, 0, screen.width, screen.height), image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return screen;
}

static BOOL is_red(const unsigned char *p)
{
    return p[0] > 110 && p[1] < 100 && p[2] < 100 && p[0] > p[1] + 60;
}

static BOOL red_pad(Screen screen, int *left, int *top, int *right, int *bottom)
{
    int minX = screen.width, maxX = -1, minY = screen.height, maxY = -1;
    for (int y = 40; y < screen.height / 2; y++)
        for (int x = 0; x < screen.width; x++) {
            const unsigned char *p = screen.pixels + ((size_t)y * screen.width + x) * 4;
            if (is_red(p)) {
                minX = MIN(minX, x); maxX = MAX(maxX, x); minY = MIN(minY, y); maxY = MAX(maxY, y);
            }
        }
    if (maxX < minX)
        return NO;
    int scale = (int)[UIScreen mainScreen].scale;
    int column = minX + 8 * scale;
    int first = -1, last = -1;
    for (int y = MAX(0, minY - 8 * scale); y < MIN(screen.height, maxY + 8 * scale); y++) {
        const unsigned char *p = screen.pixels + ((size_t)y * screen.width + column) * 4;
        if (p[0] + p[1] + p[2] < 620) {
            if (first < 0)
                first = y;
            last = y;
        }
    }
    *left = minX; *right = maxX; *top = first; *bottom = last;
    return first >= 0;
}

static void profile(Screen screen, int left, int top, int bottom, int rows, int column_offset, int values[][3])
{
    int x = left + column_offset;
    for (int row = 0; row < rows; row++) {
        int y = top + (int)((row + 0.5) * (bottom - top + 1) / rows);
        const unsigned char *p = screen.pixels + ((size_t)y * screen.width + x) * 4;
        for (int c = 0; c < 3; c++)
            values[row][c] = p[c];
    }
}

static void compare_with_native(void)
{
    int nl, nt, nr, nb, fl, ft, fr, fb;
    CHECK(native_screen.pixels && facade_screen.pixels, "both screens were taken");
    if (!native_screen.pixels || !facade_screen.pixels)
        return;
    CHECK(red_pad(native_screen, &nl, &nt, &nr, &nb) && red_pad(facade_screen, &fl, &ft, &fr, &fb), "a red button is on both screens");
    int scale = (int)([UIScreen mainScreen].scale);
    int native_height = nb - nt + 1, facade_height = fb - ft + 1;
    NSLog(@"native pad %d,%d-%d,%d facade pad %d,%d-%d,%d", nl, nt, nr, nb, fl, ft, fr, fb);
    CHECK(abs(native_height - facade_height) <= scale, "the delete button is as tall as the system's");
    int native_values[33][3], facade_values[33][3];
    profile(native_screen, nl, nt, nb, 33, 4 * scale, native_values);
    profile(facade_screen, fl, ft, fb, 33, 4 * scale, facade_values);
    int worst = 0, worst_row = 0;
    for (int row = 1; row < 32; row++)
        for (int c = 0; c < 3; c++) {
            int d = abs(native_values[row][c] - facade_values[row][c]);
            if (d > worst) { worst = d; worst_row = row; }
        }
    NSLog(@"worst channel difference %d at row %d", worst, worst_row);
    CHECK(worst <= 24, "the gloss, from the first gradient row to the last flat one, is the system's within a channel difference of 24");
    BOOL lighter_top = facade_values[3][1] > facade_values[14][1] + 30 && facade_values[14][1] > facade_values[20][1] + 20;
    CHECK(lighter_top, "the top half is a lighter gradient over a darker flat lower half");
    BOOL flat_and_edge = abs(facade_values[24][0] - native_values[24][0]) <= 10 && abs(facade_values[24][1] - native_values[24][1]) <= 10 && facade_values[32][0] < 165;
    CHECK(flat_and_edge, "the lower half is the flat red of the system and the lower edge is darker");
}

@interface LookController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic) BOOL facade;
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation LookController

- (void)loadView
{
    self.tableView = [[UITableView alloc] initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.view = self.tableView;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 8; }

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path
{
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    cell.textLabel.text = [NSString stringWithFormat:@"Row %ld", (long)path.row];
    return cell;
}

- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {}

- (BOOL)respondsToSelector:(SEL)selector
{
    if (selector == @selector(tableView:editActionsForRowAtIndexPath:))
        return self.facade;
    return [super respondsToSelector:selector];
}

- (NSArray *)tableView:(UITableView *)table editActionsForRowAtIndexPath:(NSIndexPath *)path
{
    UITableViewRowAction *remove = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction *a, NSIndexPath *p) {}];
    UITableViewRowAction *more = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"More" handler:^(UITableViewRowAction *a, NSIndexPath *p) {}];
    more.backgroundColor = [UIColor colorWithRed:0.2f green:0.4f blue:0.9f alpha:1];
    return @[remove, more];
}

@end

@interface LookTableController : UITableViewController
@end

@implementation LookTableController

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section { return 8; }

- (UITableViewCell *)tableView:(UITableView *)table cellForRowAtIndexPath:(NSIndexPath *)path
{
    UITableViewCell *cell = [table dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    cell.textLabel.text = [NSString stringWithFormat:@"Row %ld", (long)path.row];
    return cell;
}

- (NSArray *)tableView:(UITableView *)table editActionsForRowAtIndexPath:(NSIndexPath *)path
{
    return @[[UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete" handler:^(UITableViewRowAction *a, NSIndexPath *p) {}]];
}

@end

@interface LookCommitController : LookTableController
@end

@implementation LookCommitController
- (void)tableView:(UITableView *)table commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {}
@end

@interface LookDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation LookDelegate

- (void)scenario:(BOOL)facade
{
    __block LookController *controller;
    gesture_step(0.1, ^{
        controller = [[LookController alloc] init];
        controller.facade = facade;
        self.window.rootViewController = controller;
    });
    gesture_step(1.0, ^{});
    gesture_drag(^{ CGRect r = [controller.tableView convertRect:[controller.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]] toView:nil]; return CGPointMake(r.size.width - 20, CGRectGetMidY(r)); },
                 ^{ CGRect r = [controller.tableView convertRect:[controller.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]] toView:nil]; return CGPointMake(r.size.width - (facade ? 160 : 120), CGRectGetMidY(r)); }, 10, 1.2);
    gesture_step(0.5, ^{ if (facade) facade_screen = shot(@"facade"); else native_screen = shot(@"native"); });
}

- (void)tableControllerScenario:(Class)controllerClass
{
    __block LookTableController *controller;
    gesture_step(0.1, ^{
        controller = [[controllerClass alloc] initWithStyle:UITableViewStylePlain];
        self.window.rootViewController = controller;
    });
    gesture_step(1.0, ^{});
    gesture_drag(^{ CGRect r = [controller.tableView convertRect:[controller.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]] toView:nil]; return CGPointMake(r.size.width - 20, CGRectGetMidY(r)); },
                 ^{ CGRect r = [controller.tableView convertRect:[controller.tableView rectForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]] toView:nil]; return CGPointMake(r.size.width - 160, CGRectGetMidY(r)); }, 10, 1.2);
    gesture_step(0.3, ^{
        UITableViewCell *cell = [controller.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
        BOOL found = NO;
        for (UIView *view in cell.subviews)
            found = found || [NSStringFromClass([view class]) isEqual:@"CharonSwipeContainer"];
        CHECK(found && !controller.tableView.editing, "the swipe buttons of a table view controller's table are shown, and the table is not put into editing by the controller's own willBegin");
    });
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"swipelook.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"swipelook.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        gesture_step(0.01, ^{ CHECK(gesture_ready(), "touches can be sent"); });
        [self scenario:NO];
        [self scenario:YES];
        [self tableControllerScenario:[LookCommitController class]];
        [self tableControllerScenario:[LookTableController class]];
        gesture_run(^{
            compare_with_native();
            printf("checks=%d failures=%d\n", charon_checks, charon_failures);
            NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
            [summary writeToFile:[results_folder stringByAppendingPathComponent:@"swipelook.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        });
    });
    return YES;
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([LookDelegate class]));
    }
}

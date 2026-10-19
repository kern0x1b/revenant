#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <stdio.h>

static void Mark(NSString *event)
{
    NSString *line = [NSString stringWithFormat:@"UIDEMO %@\n", event];
    fputs(line.UTF8String, stdout);
    fflush(stdout);
    NSString *path = @"/private/var/charon/uidemo.log";
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!handle) {
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
        handle = [NSFileHandle fileHandleForWritingAtPath:path];
    }
    [handle seekToEndOfFile];
    [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
}

@protocol CanvasViewDelegate <NSObject>
- (void)canvasView:(UIView *)view didTapAtPoint:(CGPoint)point;
@optional
- (NSInteger)numberOfShapesForCanvasView:(UIView *)view;
@end

@interface CanvasView : UIView
@property (nonatomic, weak) id<CanvasViewDelegate> delegate;
@property (nonatomic) CGFloat phase;
@end

@implementation CanvasView

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor whiteColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (void)dealloc
{
    Mark(@"dealloc CanvasView");
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (self.phase > 2.6) {
        Mark([NSString stringWithFormat:@"draw phase %.1f self %p", self.phase, self]);
    }
    NSInteger count = [self.delegate respondsToSelector:@selector(numberOfShapesForCanvasView:)]
                          ? [self.delegate numberOfShapesForCanvasView:self]
                          : 3;
    CGFloat width = CGRectGetWidth(self.bounds);
    for (NSInteger i = 0; i < count; i++) {
        CGFloat hue = (CGFloat)i / (CGFloat)count;
        CGContextSetFillColorWithColor(context, [UIColor colorWithHue:hue saturation:0.8 brightness:0.9 alpha:1].CGColor);
        CGRect box = CGRectMake(10 + i * (width - 20) / count, 20 + 10 * sin(self.phase + i), (width - 20) / count - 6, 60);
        CGContextFillRect(context, box);
    }
    CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextSetLineWidth(context, 2);
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 10, 120);
    for (int x = 0; x <= 30; x++) {
        CGPathAddLineToPoint(path, NULL, 10 + x * (width - 20) / 30, 120 + 20 * sin(self.phase + x / 3.0));
    }
    CGContextAddPath(context, path);
    CGContextStrokePath(context);
    CGPathRelease(path);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    [self.delegate canvasView:self didTapAtPoint:[touch locationInView:self]];
}

@end

@interface DetailViewController : UIViewController <CanvasViewDelegate>
@property (nonatomic, copy) NSString *item;
@property (nonatomic, strong) CanvasView *canvas;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic) NSUInteger ticks;
@end

@implementation DetailViewController

- (void)loadView
{
    UIView *root = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    root.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.canvas = [[CanvasView alloc] initWithFrame:CGRectMake(0, 0, root.bounds.size.width, 160)];
    self.canvas.delegate = self;
    self.canvas.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [root addSubview:self.canvas];
    self.label = [[UILabel alloc] initWithFrame:CGRectMake(10, 170, root.bounds.size.width - 20, 40)];
    self.label.text = self.item;
    self.label.textAlignment = NSTextAlignmentCenter;
    self.label.font = [UIFont boldSystemFontOfSize:22];
    [root addSubview:self.label];
    self.view = root;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(tick:) userInfo:@{@"item" : self.item} repeats:YES];
    [UIView animateWithDuration:0.5
        animations:^{
            self.label.transform = CGAffineTransformMakeScale(1.3, 1.3);
        }
        completion:^(BOOL finished) {
            Mark([NSString stringWithFormat:@"animation-finished %d", finished]);
        }];
    Mark([NSString stringWithFormat:@"detail-appeared %@", self.item]);
}

- (void)dealloc
{
    Mark(@"dealloc DetailViewController");
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.timer invalidate];
}

- (void)tick:(NSTimer *)timer
{
    self.ticks++;
    self.canvas.phase += 0.3;
    [self.canvas setNeedsDisplay];
    if (self.ticks == 10) {
        Mark([NSString stringWithFormat:@"ticks %lu %@", (unsigned long)self.ticks, timer.userInfo[@"item"]]);
    }
}

- (void)canvasView:(UIView *)view didTapAtPoint:(CGPoint)point
{
    self.label.text = [NSString stringWithFormat:@"%.0f,%.0f", point.x, point.y];
    Mark([NSString stringWithFormat:@"tap %.0f %.0f", point.x, point.y]);
}

- (NSInteger)numberOfShapesForCanvasView:(UIView *)view
{
    return 4 + (NSInteger)(self.ticks % 3);
}

@end

@interface ListViewController : UITableViewController
@property (nonatomic, copy) NSArray<NSString *> *items;
@end

@implementation ListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"xlate";
    NSMutableArray *items = [NSMutableArray array];
    for (NSInteger i = 0; i < 40; i++) {
        [items addObject:[NSString stringWithFormat:@"Row %ld", (long)i]];
    }
    self.items = items;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return (NSInteger)self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    cell.textLabel.text = self.items[(NSUInteger)indexPath.row];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld × %.2f", (long)indexPath.row, indexPath.row * 1.5];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DetailViewController *detail = [[DetailViewController alloc] init];
    detail.item = self.items[(NSUInteger)indexPath.row];
    [self.navigationController pushViewController:detail animated:YES];
    Mark([NSString stringWithFormat:@"selected %ld", (long)indexPath.row]);
}

@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    ListViewController *list = [[ListViewController alloc] initWithStyle:UITableViewStylePlain];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:list];
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
    Mark([NSString stringWithFormat:@"launched %@", NSStringFromCGRect(self.window.bounds)]);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [list tableView:list.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:7 inSection:0]];
    });
    return YES;
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}

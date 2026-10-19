#import <UIKit/UIKit.h>

static UIImage *Stripes(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(8, 8), YES, 1);
    [[UIColor yellowColor] setFill];
    UIRectFill(CGRectMake(0, 0, 8, 8));
    [[UIColor blueColor] setFill];
    UIRectFill(CGRectMake(0, 0, 4, 8));
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

CGImageRef UIGetScreenImage(void);

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *controller = [[UIViewController alloc] init];
    UIView *root = [[UIView alloc] initWithFrame:[UIScreen mainScreen].applicationFrame];
    root.backgroundColor = [UIColor whiteColor];
    NSArray *titles = @[@"solid red", @"pattern image", @"groupTableViewBackground", @"UIImageView", @"scrollViewTexturedBackground"];
    UIImage *stripes = Stripes();
    NSArray *colors = @[[UIColor redColor], [UIColor colorWithPatternImage:stripes], [UIColor groupTableViewBackgroundColor], [UIColor clearColor], [UIColor scrollViewTexturedBackgroundColor]];
    for (NSUInteger i = 0; i < titles.count; i++) {
        CGRect frame = CGRectMake(10, 10 + i * 88, 300, 80);
        UIView *box = [[UIView alloc] initWithFrame:frame];
        box.backgroundColor = colors[i];
        if (i == 3) {
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:box.bounds];
            imageView.image = [stripes resizableImageWithCapInsets:UIEdgeInsetsZero resizingMode:UIImageResizingModeTile];
            [box addSubview:imageView];
        }
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(8, 50, 284, 24)];
        label.text = titles[i];
        label.backgroundColor = [UIColor whiteColor];
        [box addSubview:label];
        [root addSubview:box];
    }
    controller.view = root;
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    FILE *log = fopen("/private/var/charon/render-pattern.log", "a");
    if (log) {
        fprintf(log, "RENDER launched\n");
        fclose(log);
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGImageRef screen = UIGetScreenImage();
        if (screen) {
            NSData *png = UIImagePNGRepresentation([UIImage imageWithCGImage:screen]);
            CGImageRelease(screen);
            [png writeToFile:@"/var/tmp/xlate/render-pattern.png" atomically:YES];
            [png writeToFile:@"/private/var/charon/render-pattern.png" atomically:YES];
        }
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

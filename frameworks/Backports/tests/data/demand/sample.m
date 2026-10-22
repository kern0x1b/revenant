#import <UIKit/UIKit.h>
@interface Foo : NSObject
@property (nonatomic, strong) UIView *panel;
@end
- (void)bar {
    UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
    [v setBackgroundColor:[UIColor redColor]];
    [self.view addSubview:v];
    NSString *s = [NSString stringWithFormat:@"%d [x]", 3];
    SEL sel = @selector(viewDidLoad);
    int arr[3]; arr[1] = 2;
    CGRect r = CGRectMake(0, 0, 1, 1);
    NSArray *a = @[@1];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(foo:bar:) name:UIApplicationDidBecomeActiveNotification object:nil];
    int x = (int)[v tag];
    [[[Foo alloc] init] run:1];
    char *c = "[UIView comment]";
    /* [UILabel block] */ [[Foo alloc] init];
    int attr[[nodiscard]] = 0;
}

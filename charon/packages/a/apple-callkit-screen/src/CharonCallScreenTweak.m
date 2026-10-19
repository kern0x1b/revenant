#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#include <notify.h>

static NSString *const charon_call_screen_folder = @"/var/mobile/Library/Caches/org.charon.callkit";
static const char *const charon_call_incoming = "org.charon.callkit.incoming";
static const char *const charon_call_ended = "org.charon.callkit.ended";
static const char *const charon_call_answered = "org.charon.callkit.answered";
static const char *const charon_call_declined = "org.charon.callkit.declined";

static NSString *charon_call_file(NSString *name)
{
    return [charon_call_screen_folder stringByAppendingPathComponent:name];
}

@interface CharonCallScreenTweak : NSObject
+ (instancetype)shared;
- (void)incoming;
- (void)ended;
@end

@implementation CharonCallScreenTweak {
    UIWindow *_window;
    UILabel *_name;
    UILabel *_handle;
    NSString *_UUID;
}

+ (instancetype)shared
{
    static CharonCallScreenTweak *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[CharonCallScreenTweak alloc] init];
    });
    return shared;
}

- (void)makeWindow
{
    if (_window)
        return;
    _window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _window.windowLevel = UIWindowLevelStatusBar + 1000;
    _window.backgroundColor = [UIColor colorWithWhite:0 alpha:0.92];
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor clearColor];
    _window.rootViewController = root;

    CGFloat width = CGRectGetWidth(_window.bounds), height = CGRectGetHeight(_window.bounds);

    _name = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, width - 40, 40)];
    _name.textColor = [UIColor whiteColor];
    _name.font = [UIFont boldSystemFontOfSize:28];
    _name.textAlignment = NSTextAlignmentCenter;
    [root.view addSubview:_name];

    _handle = [[UILabel alloc] initWithFrame:CGRectMake(20, 125, width - 40, 24)];
    _handle.textColor = [UIColor colorWithWhite:1 alpha:0.7];
    _handle.font = [UIFont systemFontOfSize:16];
    _handle.textAlignment = NSTextAlignmentCenter;
    [root.view addSubview:_handle];

    UIButton *decline = [UIButton buttonWithType:UIButtonTypeSystem];
    decline.frame = CGRectMake(width / 2 - 130, height - 140, 100, 100);
    decline.backgroundColor = [UIColor colorWithRed:1 green:0.23 blue:0.19 alpha:1];
    decline.layer.cornerRadius = 50;
    [decline setTitle:@"End" forState:UIControlStateNormal];
    [decline setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [decline addTarget:self action:@selector(decline) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:decline];

    UIButton *answer = [UIButton buttonWithType:UIButtonTypeSystem];
    answer.frame = CGRectMake(width / 2 + 30, height - 140, 100, 100);
    answer.backgroundColor = [UIColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1];
    answer.layer.cornerRadius = 50;
    [answer setTitle:@"Answer" forState:UIControlStateNormal];
    [answer setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [answer addTarget:self action:@selector(answer) forControlEvents:UIControlEventTouchUpInside];
    [root.view addSubview:answer];
}

- (void)incoming
{
    NSDictionary *payload = [NSDictionary dictionaryWithContentsOfFile:charon_call_file(@"incoming")];
    NSString *UUID = payload[@"UUID"];
    if (!UUID.length)
        return;
    [self makeWindow];
    _UUID = [UUID copy];
    _name.text = payload[@"name"] ?: @"";
    _handle.text = payload[@"handle"] ?: @"";
    _window.hidden = NO;
    [_window makeKeyAndVisible];
}

- (void)ended
{
    _UUID = nil;
    _window.hidden = YES;
}

- (void)respond:(BOOL)answered
{
    if (!_UUID)
        return;
    NSString *identifier = _UUID;
    _UUID = nil;
    _window.hidden = YES;
    [identifier writeToFile:charon_call_file(answered ? @"answered" : @"declined") atomically:YES
                    encoding:NSUTF8StringEncoding error:NULL];
    notify_post(answered ? charon_call_answered : charon_call_declined);
}

- (void)answer { [self respond:YES]; }
- (void)decline { [self respond:NO]; }

@end

__attribute__((constructor))
static void charon_callkit_screen_load(void)
{
    [[NSFileManager defaultManager] createDirectoryAtPath:charon_call_screen_folder withIntermediateDirectories:YES
                                                attributes:@{NSFilePosixPermissions: @(0777)} error:NULL];
    NSString *marker = [NSString stringWithFormat:@"pid=%d\n", getpid()];
    [marker writeToFile:charon_call_file(@"loaded") atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    notify_post("org.charon.callkit.screen-loaded");

    static int incoming = NOTIFY_TOKEN_INVALID, ended = NOTIFY_TOKEN_INVALID;
    notify_register_dispatch(charon_call_incoming, &incoming, dispatch_get_main_queue(), ^(int token) {
        (void)token;
        [[CharonCallScreenTweak shared] incoming];
    });
    notify_register_dispatch(charon_call_ended, &ended, dispatch_get_main_queue(), ^(int token) {
        (void)token;
        [[CharonCallScreenTweak shared] ended];
    });
}

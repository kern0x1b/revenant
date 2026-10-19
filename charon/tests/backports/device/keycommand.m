#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <dlfcn.h>
#import "check.h"

static NSString *const results_folder = @"/private/var/backports";

static void *(*create_key_event)(long, CGPoint, CFStringRef, CFStringRef, long, long, long, long);
static long (*event_flags)(void *);
static long (*event_code)(void *);

static void send_key(UIApplication *application, long type, NSString *characters, NSString *plain, long flags, long code)
{
    void *event = create_key_event(type, CGPointZero, (__bridge CFStringRef)characters, (__bridge CFStringRef)plain, flags, code, 0, 0);
    ((void (*)(id, SEL, void *))objc_msgSend)(application, NSSelectorFromString(@"handleKeyEvent:"), event);
    CFRelease(event);
}

@interface CommandView : UIView
@property (nonatomic, strong) NSMutableArray *fired;
@end

@implementation CommandView
- (BOOL)canBecomeFirstResponder { return YES; }
- (NSArray *)keyCommands
{
    return @[[UIKeyCommand keyCommandWithInput:@"k" modifierFlags:UIKeyModifierCommand action:@selector(commandK:)],
             [UIKeyCommand keyCommandWithInput:UIKeyInputUpArrow modifierFlags:0 action:@selector(arrowUp)],
             [UIKeyCommand keyCommandWithInput:@"a" modifierFlags:UIKeyModifierShift | UIKeyModifierAlternate action:@selector(shiftOptionA:)],
             [UIKeyCommand keyCommandWithInput:@"z" modifierFlags:0 action:@selector(nobodyHasThis:)],
             [UIKeyCommand keyCommandWithInput:@"s" modifierFlags:UIKeyModifierCommand action:@selector(inner:)]];
}
- (void)commandK:(UIKeyCommand *)sender { [self.fired addObject:[NSString stringWithFormat:@"k %@ %ld", sender.input, (long)sender.modifierFlags]]; }
- (void)arrowUp { [self.fired addObject:@"up"]; }
- (void)shiftOptionA:(UIKeyCommand *)sender { [self.fired addObject:@"shift-option-a"]; }
- (void)inner:(UIKeyCommand *)sender { [self.fired addObject:@"inner s"]; }
@end

@interface CommandController : UIViewController
@property (nonatomic, strong) NSMutableArray *fired;
@end

@implementation CommandController
- (NSArray *)keyCommands
{
    return @[[UIKeyCommand keyCommandWithInput:@"s" modifierFlags:UIKeyModifierCommand action:@selector(outer:)],
             [UIKeyCommand keyCommandWithInput:@"z" modifierFlags:0 action:@selector(zed:)],
             [UIKeyCommand keyCommandWithInput:UIKeyInputEscape modifierFlags:0 action:@selector(escape)]];
}
- (void)outer:(UIKeyCommand *)sender { [self.fired addObject:@"outer s"]; }
- (void)zed:(UIKeyCommand *)sender { [self.fired addObject:@"outer z"]; }
- (void)escape { [self.fired addObject:@"escape"]; }
@end

@interface KeyDelegate : UIResponder <UIApplicationDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableArray *fired;
@end

@implementation KeyDelegate

- (NSArray *)keyCommands
{
    return @[[UIKeyCommand keyCommandWithInput:@"q" modifierFlags:UIKeyModifierCommand action:@selector(quit:)]];
}
- (void)quit:(UIKeyCommand *)sender { [self.fired addObject:@"delegate q"]; }

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"keycommand.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"keycommand.log"]);
    self.fired = [NSMutableArray array];
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    CommandController *controller = [[CommandController alloc] init];
    controller.fired = self.fired;
    CommandView *view = [[CommandView alloc] initWithFrame:self.window.bounds];
    view.fired = self.fired;
    controller.view = view;
    self.window.rootViewController = controller;
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self run:application view:view]; });
    return YES;
}

- (void)run:(UIApplication *)application view:(CommandView *)view
{
    void *graphics = dlopen("/System/Library/PrivateFrameworks/GraphicsServices.framework/GraphicsServices", RTLD_NOW);
    create_key_event = dlsym(graphics, "GSEventCreateKeyEvent");
    event_flags = dlsym(graphics, "GSEventGetModifierFlags");
    event_code = dlsym(graphics, "GSEventGetKeyCode");
    CHECK(create_key_event && event_flags && event_code, "the release's key event functions are there");
    void *probe = create_key_event(10, CGPointZero, CFSTR("k"), CFSTR("k"), UIKeyModifierCommand, 14, 0, 0);
    CHECK(event_flags(probe) == UIKeyModifierCommand && event_code(probe) == 14, "a key event made with GSEventCreateKeyEvent holds the flags and key code it was given");
    CFRelease(probe);

    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(10, 60, 300, 40)];
    field.delegate = self;
    [view addSubview:field];
    [field becomeFirstResponder];
    CHECK(field.isFirstResponder, "a text field in the view is the first responder");

    send_key(application, 10, @"k", @"k", UIKeyModifierCommand, 14);
    CHECK_EQUAL(self.fired, (@[@"k k 1048576"]), "command-K reaches the command of the view that holds the field, with the command as sender");
    CHECK([field.text length] == 0, "and is not typed into the text field");
    [self.fired removeAllObjects];

    send_key(application, 10, @"k", @"k", 0, 14);
    CHECK(self.fired.count == 0 && [field.text isEqual:@"k"], "K without command is no command and is typed as before");
    field.text = @"";

    send_key(application, 11, @"k", @"k", UIKeyModifierCommand, 14);
    CHECK(self.fired.count == 0, "a key going up runs no command");

    send_key(application, 10, @"K", @"k", UIKeyModifierCommand, 14);
    send_key(application, 10, @"K", @"k", UIKeyModifierCommand, 14);
    CHECK(self.fired.count == 2, "a key that repeats runs the command again each time");
    [self.fired removeAllObjects];

    send_key(application, 10, @"", @"", 0, 0x52);
    CHECK_EQUAL(self.fired, (@[@"up"]), "the up arrow by its key code runs the command with no arguments");
    [self.fired removeAllObjects];

    send_key(application, 10, @"", @"", 0, 0);
    CHECK_EQUAL(self.fired, (@[@"up"]), "and by its function-key character");
    [self.fired removeAllObjects];

    send_key(application, 10, @"A", @"a", UIKeyModifierShift | UIKeyModifierAlternate, 4);
    CHECK_EQUAL(self.fired, (@[@"shift-option-a"]), "several modifiers must all be down");
    [self.fired removeAllObjects];
    send_key(application, 10, @"A", @"a", UIKeyModifierShift, 4);
    CHECK(self.fired.count == 0, "and no others");
    field.text = @"";

    send_key(application, 10, @"s", @"s", UIKeyModifierCommand, 22);
    CHECK_EQUAL(self.fired, (@[@"inner s"]), "of two responders with the same command the nearer runs it, and only it");
    [self.fired removeAllObjects];

    send_key(application, 10, @"z", @"z", 0, 29);
    CHECK_EQUAL(self.fired, (@[@"outer z"]), "a command its responder cannot perform is passed over to the next");
    [self.fired removeAllObjects];

    send_key(application, 10, @"\e", @"\e", 0, 0x29);
    CHECK_EQUAL(self.fired, (@[@"escape"]), "escape reaches the command of the view controller in the chain");
    [self.fired removeAllObjects];

    send_key(application, 10, @"q", @"q", UIKeyModifierCommand, 20);
    CHECK_EQUAL(self.fired, (@[@"delegate q"]), "the application delegate is the end of the chain");
    [self.fired removeAllObjects];

    [field resignFirstResponder];
    [view resignFirstResponder];
    send_key(application, 10, @"s", @"s", UIKeyModifierCommand, 22);
    CHECK(self.fired.count == 0, "with no first responder the chain starts at the window and the view controller's commands are not reached");
    send_key(application, 10, @"q", @"q", UIKeyModifierCommand, 20);
    CHECK_EQUAL(self.fired, (@[@"delegate q"]), "but the delegate's are");

    [field becomeFirstResponder];
    send_key(application, 10, @"x", @"x", 0, 27);
    CHECK([field.text isEqual:@"x"], "a key that is no command goes on to the keyboard");

    printf("checks=%d failures=%d\n", charon_checks, charon_failures);
    NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
    [summary writeToFile:[results_folder stringByAppendingPathComponent:@"keycommand.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([KeyDelegate class]));
    }
}

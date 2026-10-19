#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <Social/Social.h>
#import <QuickLook/QuickLook.h>
#import <MediaPlayer/MediaPlayer.h>
#import "check.h"

/* The release's own view controllers presented without a style, in a program linked with SDK 13 or later: the style
   resolves as iOS 13 resolves it (facts/UIKit/UIModalPresentationAutomatic.md), so the ones that prefer no style of
   their own are shown in the port's sheet. A controller whose own initializer on 6.1.3 sets a style keeps it and is the
   release's own presentation (the activity view controller sets 17, the preview controller full screen: measured on
   the iPad 2, 2026-09-24); for those the check is that the port's sheet stays out of it. Each is presented, and after a
   moment it must be the presented controller, in the window, with its view at the sheet's frame when it is in the
   sheet; dismissed, the presenter must be itself again. The composers are skipped where the device cannot send (no account). An iPhone application
   (UIDeviceFamily 1), so that the iPad 2 runs it phone-sized. Nothing of what the controllers show is read or logged:
   only their classes, frames and the presentation's state. */

static NSString *const results_folder = @"/private/var/backports";

static NSString *rect_text(CGRect r)
{
    return [NSString stringWithFormat:@"%.1f %.1f %.1f %.1f", r.origin.x, r.origin.y, r.size.width, r.size.height];
}

@interface ReleaseSheetDelegate : UIResponder <UIApplicationDelegate, QLPreviewControllerDataSource, MFMailComposeViewControllerDelegate, MFMessageComposeViewControllerDelegate>
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) NSMutableArray *cases;
@property (nonatomic, strong) NSURL *previewFile;
@end

@implementation ReleaseSheetDelegate

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller { return 1; }
- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index { return self.previewFile; }
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {}
- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result {}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options
{
    [[NSFileManager defaultManager] createDirectoryAtPath:results_folder withIntermediateDirectories:YES attributes:nil error:NULL];
    [[NSFileManager defaultManager] removeItemAtPath:[results_folder stringByAppendingPathComponent:@"releasesheet.done"] error:NULL];
    charon_log_to([results_folder stringByAppendingPathComponent:@"releasesheet.log"]);
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *root = [[UIViewController alloc] init];
    root.view.backgroundColor = [UIColor whiteColor];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    self.previewFile = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"releasesheet.txt"]];
    [@"releasesheet" writeToURL:self.previewFile atomically:YES encoding:NSUTF8StringEncoding error:NULL];

    self.cases = [NSMutableArray array];
    __weak ReleaseSheetDelegate *me = self;
    [self.cases addObject:@[@"activity", ^UIViewController *{ return [[UIActivityViewController alloc] initWithActivityItems:@[@"releasesheet"] applicationActivities:nil]; }, [NSNull null]]];
    [self.cases addObject:@[@"quicklook", ^UIViewController *{ QLPreviewController *c = [[QLPreviewController alloc] init]; c.dataSource = me; return c; }, [NSNull null]]];
    [self.cases addObject:@[@"mediapicker", ^UIViewController *{ return [[MPMediaPickerController alloc] initWithMediaTypes:MPMediaTypeAnyAudio]; }, @(UIModalPresentationPageSheet)]];
    [self.cases addObject:@[@"imagepicker", ^UIViewController *{ return [[UIImagePickerController alloc] init]; }, @(UIModalPresentationPageSheet)]];
    [self.cases addObject:@[@"mail", ^UIViewController *{
        if (![MFMailComposeViewController canSendMail]) return nil;
        MFMailComposeViewController *c = [[MFMailComposeViewController alloc] init]; c.mailComposeDelegate = me; return c; }, @(UIModalPresentationPageSheet)]];
    [self.cases addObject:@[@"message", ^UIViewController *{
        if (![MFMessageComposeViewController canSendText]) return nil;
        MFMessageComposeViewController *c = [[MFMessageComposeViewController alloc] init]; c.messageComposeDelegate = me; return c; }, @(UIModalPresentationPageSheet)]];
    [self.cases addObject:@[@"social", ^UIViewController *{
        if (![SLComposeViewController isAvailableForServiceType:SLServiceTypeTwitter]) return nil;
        return [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter]; }, @(UIModalPresentationPageSheet)]];
    [self performSelector:@selector(next) withObject:nil afterDelay:1];
    return YES;
}

- (void)next
{
    UIViewController *root = self.window.rootViewController;
    if (!self.cases.count) {
        printf("checks=%d failures=%d\n", charon_checks, charon_failures);
        NSString *summary = [NSString stringWithFormat:@"%@ checks=%d failures=%d\n", charon_failures ? @"FAIL" : @"ok", charon_checks, charon_failures];
        [summary writeToFile:[results_folder stringByAppendingPathComponent:@"releasesheet.done"] atomically:YES encoding:NSUTF8StringEncoding error:NULL];
        return;
    }
    NSArray *entry = self.cases.firstObject;
    [self.cases removeObjectAtIndex:0];
    NSString *name = entry[0];
    UIViewController *(^make)(void) = entry[1];
    UIViewController *controller = make();
    if (!controller) {
        printf("skip %s: the device cannot send with it\n", name.UTF8String);
        [self next];
        return;
    }
    UIModalPresentationStyle style = controller.modalPresentationStyle;
    BOOL ownStyle = entry[2] == [NSNull null];
    printf("record %s.style: %ld\n", name.UTF8String, (long)style);
    if (ownStyle)
        charon_check(style != UIModalPresentationPageSheet, [[name stringByAppendingString:@".style"] UTF8String], @"the release's own style");
    else
        CHECK_EQUAL(@(style), entry[2], [[name stringByAppendingString:@".style"] UTF8String]);
    CGRect before = [root.view convertRect:root.view.bounds toView:nil];
    [root presentViewController:controller animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIView *view = controller.view;
        CGRect frame = [view convertRect:view.bounds toView:nil];
        printf("record %s.presented: presented=%d window=%d frame=%s presentation=%s\n", name.UTF8String, root.presentedViewController == controller, view.window != nil,
               rect_text(frame).UTF8String, NSStringFromClass([controller.presentationController class]).UTF8String);
        charon_check(root.presentedViewController == controller && view.window != nil, [[name stringByAppendingString:@".presented"] UTF8String], nil);
        /* The sheet's large detent: 320 wide from y 40 to the bottom of a 320 x 480 window. */
        BOOL sheetFrame = frame.origin.x == 0 && frame.origin.y == 40 && frame.size.width == 320 && frame.size.height == 440;
        BOOL inSheet = [controller.presentationController isKindOfClass:[UISheetPresentationController class]];
        if (ownStyle)
            charon_check(!inSheet, [[name stringByAppendingString:@".presentation"] UTF8String], NSStringFromClass([controller.presentationController class]));
        else
            charon_check(inSheet && sheetFrame, [[name stringByAppendingString:@".frame"] UTF8String], rect_text(frame));
        [root dismissViewControllerAnimated:YES completion:nil];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CGRect after = [root.view convertRect:root.view.bounds toView:nil];
            printf("record %s.dismissed: presented=%s root=%s transform=%s\n", name.UTF8String, root.presentedViewController ? NSStringFromClass([root.presentedViewController class]).UTF8String : "nil",
                   rect_text(after).UTF8String, NSStringFromCGAffineTransform(root.view.transform).UTF8String);
            charon_check(root.presentedViewController == nil && CGRectEqualToRect(after, before) && CGAffineTransformIsIdentity(root.view.transform),
                         [[name stringByAppendingString:@".dismissed"] UTF8String], rect_text(after));
            [self next];
        });
    });
}

@end

int main(int argc, char **argv)
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([ReleaseSheetDelegate class]));
    }
}

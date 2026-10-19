#import <UIKit/UIKit.h>
#include <stdio.h>
static FILE *out;
static void report(const char *check, NSString *value) { fprintf(out, "%s\t%s\n", check, value ? [value UTF8String] : "nil"); }
static NSString *yes_no(BOOL a) { return a ? @"yes" : @"no"; }
static NSString *num(long long v) { return [NSString stringWithFormat:@"%lld", v]; }
static NSString *cls(id o) { return o ? NSStringFromClass([o class]) : @"nil"; }

@interface RevenantCountingDelegate : NSObject <NSTextContentStorageDelegate, NSTextLayoutManagerDelegate>
@property (nonatomic) int paragraphCalls;
@property (nonatomic) int fragmentCalls;
@end
@implementation RevenantCountingDelegate
- (NSTextParagraph *)textContentStorage:(NSTextContentStorage *)storage textParagraphWithRange:(NSRange)range
{
    self.paragraphCalls++;
    return nil;
}
- (NSTextLayoutFragment *)textLayoutManager:(NSTextLayoutManager *)manager textLayoutFragmentForLocation:(id<NSTextLocation>)location inTextElement:(NSTextElement *)element
{
    self.fragmentCalls++;
    return nil;
}
@end

@interface RevenantAppDelegate : UIResponder <UIApplicationDelegate>
@end
@implementation RevenantAppDelegate
- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{ return [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role]; }
@end

@interface RevenantSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation RevenantSceneDelegate
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    const char *path = getenv("REVENANT_SCENE_OUT");
    out = fopen(path ? path : "/dev/stdout", "w");
    UIViewController *root = [[UIViewController alloc] init];
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    report("idiom", [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"pad" : @"other");
    report("class-layout-manager", NSClassFromString(@"NSTextLayoutManager") ? @"present" : @"absent");
    report("class-layout-fragment", NSClassFromString(@"NSTextLayoutFragment") ? @"present" : @"absent");
    report("class-line-fragment", NSClassFromString(@"NSTextLineFragment") ? @"present" : @"absent");
    report("class-viewport", NSClassFromString(@"NSTextViewportLayoutController") ? @"present" : @"absent");

    UITextView *plain = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    report("plain-text-layout-manager", cls(plain.textLayoutManager));
    report("plain-container-layout-manager", cls(plain.textContainer.textLayoutManager));

    UITextView *tk2 = [UITextView textViewUsingTextLayoutManager:YES];
    [root.view addSubview:tk2];
    report("tk2-factory-layout-manager", cls(tk2.textLayoutManager));
    report("tk2-container-layout-manager", cls(tk2.textContainer.textLayoutManager));
    report("tk2-container-is-view-manager", yes_no(tk2.textContainer.textLayoutManager == tk2.textLayoutManager));
    NSTextLayoutManager *lm = tk2.textLayoutManager;
    NSTextContentStorage *storage = (NSTextContentStorage *)lm.textContentManager;
    report("tk2-storage-class", cls(storage));
    report("tk2-viewport-class", cls(lm.textViewportLayoutController));
    report("tk2-viewport-delegate-default", cls(lm.textViewportLayoutController.delegate));
    report("tk2-lm-delegate-default", cls(lm.delegate));
    report("storage-delegate-default", cls(storage.delegate));
    report("storage-includes-markers-default", yes_no(storage.includesTextListMarkers));

    RevenantCountingDelegate *counter = [[RevenantCountingDelegate alloc] init];
    storage.delegate = counter;
    lm.delegate = counter;
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.textLists = @[[[NSTextList alloc] initWithMarkerFormat:NSTextListMarkerDisc options:0]];
    tk2.attributedText = [[NSAttributedString alloc] initWithString:@"alpha\nbeta" attributes:@{NSParagraphStyleAttributeName: style}];
    [lm ensureLayoutForRange:lm.documentRange];
    __block int fragments = 0;
    __block long long lines = 0;
    [lm enumerateTextLayoutFragmentsFromLocation:lm.documentRange.location options:0 usingBlock:^BOOL(NSTextLayoutFragment *fragment) {
        fragments++;
        lines += fragment.textLineFragments.count;
        return YES;
    }];
    report("fragments-for-two-paragraphs", num(fragments));
    report("line-fragments-for-two-paragraphs", num(lines));
    report("storage-paragraph-calls", num(counter.paragraphCalls));
    report("lm-fragment-calls", num(counter.fragmentCalls));

    __block NSString *markers = @"none";
    [storage enumerateTextElementsFromLocation:storage.documentRange.location options:0 usingBlock:^BOOL(NSTextElement *element) {
        NSTextParagraph *paragraph = (NSTextParagraph *)element;
        markers = [paragraph.attributedString.string substringToIndex:MIN((NSUInteger)4, paragraph.attributedString.length)];
        return NO;
    }];
    report("first-paragraph-prefix-without-markers", markers);
    storage.includesTextListMarkers = YES;
    tk2.attributedText = [[NSAttributedString alloc] initWithString:@"alpha\nbeta" attributes:@{NSParagraphStyleAttributeName: style}];
    __block NSString *withMarkers = @"none";
    [storage enumerateTextElementsFromLocation:storage.documentRange.location options:0 usingBlock:^BOOL(NSTextElement *element) {
        NSTextParagraph *paragraph = (NSTextParagraph *)element;
        withMarkers = [paragraph.attributedString.string substringToIndex:MIN((NSUInteger)4, paragraph.attributedString.length)];
        return NO;
    }];
    report("storage-includes-markers-set", yes_no(storage.includesTextListMarkers));
    report("first-paragraph-prefix-with-markers", withMarkers);
    fclose(out);
    exit(0);
}
@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([RevenantAppDelegate class]));
    }
}

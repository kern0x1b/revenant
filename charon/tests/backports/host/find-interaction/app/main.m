#import <UIKit/UIKit.h>
#include <stdio.h>

static FILE *out;
static FILE *hostOnly;
static const char *side;
static int sequence;

static UIView *expectedView;
static UIFindSession *givenSession;

static void report(const char *check, NSString *value)
{
    fprintf(out, "%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static void report_host(const char *check, NSString *value)
{
    if (hostOnly)
        fprintf(hostOnly, "%s\t%s\n", check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *class_name(id object)
{
    NSString *name = NSStringFromClass([object class]);
    return [name hasPrefix:@"CharonPort"] ? [name substringFromIndex:10] : name;
}

static NSString *number(NSInteger value)
{
    return [NSString stringWithFormat:@"%ld", (long)value];
}

static void call(NSString *what)
{
    report("delegate-call", [NSString stringWithFormat:@"%d %@", ++sequence, what]);
}

@interface CharonFindDelegate : NSObject <UIFindInteractionDelegate>
@end

@implementation CharonFindDelegate

- (UIFindSession *)findInteraction:(UIFindInteraction *)interaction sessionForView:(UIView *)view
{
    call([NSString stringWithFormat:@"sessionForView same=%@", yes_no(view == expectedView)]);
    return givenSession;
}

- (void)findInteraction:(UIFindInteraction *)interaction didBeginFindSession:(UIFindSession *)session
{
    call(@"didBeginFindSession");
}

- (void)findInteraction:(UIFindInteraction *)interaction didEndFindSession:(UIFindSession *)session
{
    call(@"didEndFindSession");
}

@end

@interface CharonSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation CharonSceneDelegate

static void checks(UIView *view, UITextView *text)
{
    CharonFindDelegate *delegate = [[CharonFindDelegate alloc] init];
    UIFindInteraction *interaction = [[UIFindInteraction alloc] initWithSessionDelegate:delegate];
    report("interaction-class", class_name(interaction));
    report("delegate-kept", yes_no(interaction.delegate == delegate));
    report("find-navigator-visible-default", yes_no(interaction.findNavigatorVisible));
    report("active-session-default", interaction.activeFindSession ? class_name(interaction.activeFindSession) : @"nil");
    report("search-text-default", interaction.searchText ?: @"nil");
    report("replacement-text-default", interaction.replacementText ?: @"nil");
    report("options-menu-provider-default", interaction.optionsMenuProvider ? @"set" : @"nil");
    report("view-before-add", yes_no(interaction.view == nil));

    NSMutableString *query = [NSMutableString stringWithString:@"query"];
    interaction.searchText = query;
    [query appendString:@"-changed"];
    report("search-text-kept-object", interaction.searchText);
    interaction.replacementText = @"replacement";
    report("replacement-text-set", interaction.replacementText);
    interaction.searchText = nil;
    report("search-text-cleared", interaction.searchText ?: @"nil");

    interaction.optionsMenuProvider = ^UIMenu *(NSArray<UIMenuElement *> *defaults) { return nil; };
    report("options-menu-provider-set", interaction.optionsMenuProvider ? @"set" : @"nil");
    interaction.optionsMenuProvider = nil;
    report("options-menu-provider-cleared", interaction.optionsMenuProvider ? @"set" : @"nil");

    expectedView = view;
    [view addInteraction:interaction];
    report("view-after-add", yes_no(interaction.view == view));

    [interaction presentFindNavigatorShowingReplace:NO];
    report("find-navigator-visible-after-present", yes_no(interaction.findNavigatorVisible));
    report("active-session-after-present", interaction.activeFindSession ? class_name(interaction.activeFindSession) : @"nil");
    [interaction dismissFindNavigator];
    report("find-navigator-visible-after-dismiss", yes_no(interaction.findNavigatorVisible));

    givenSession = [[UITextSearchingFindSession alloc] initWithSearchableObject:text];
    [interaction presentFindNavigatorShowingReplace:NO];
    report("session-navigator-visible", yes_no(interaction.findNavigatorVisible));
    report("session-active-class", interaction.activeFindSession ? class_name(interaction.activeFindSession) : @"nil");
    report("session-active-same", yes_no(interaction.activeFindSession == givenSession));
    report("session-searchable-same-text", yes_no([(UITextSearchingFindSession *)givenSession searchableObject] == text));
    report("session-result-count", number(givenSession.resultCount));
    report("session-highlighted-index", number(givenSession.highlightedResultIndex));
    report("session-supports-replacement", yes_no(givenSession.supportsReplacement));
    report("session-allows-replacement-highlighted", yes_no(givenSession.allowsReplacementForCurrentlyHighlightedResult));
    report("session-display-style", number(givenSession.searchResultDisplayStyle));
    [interaction dismissFindNavigator];
    report("session-navigator-visible-after-dismiss", yes_no(interaction.findNavigatorVisible));
    report("session-active-after-dismiss", interaction.activeFindSession ? class_name(interaction.activeFindSession) : @"nil");
    givenSession = nil;

    givenSession = [[UITextSearchingFindSession alloc] initWithSearchableObject:text];
    [interaction presentFindNavigatorShowingReplace:YES];
    report("replace-session-supports-replacement", yes_no(givenSession.supportsReplacement));
    [interaction dismissFindNavigator];
    givenSession = nil;

    [view removeInteraction:interaction];
    report("view-after-remove", yes_no(interaction.view == nil));

    CharonFindDelegate *gone = [[CharonFindDelegate alloc] init];
    __weak id weakGone = gone;
    UIFindInteraction *lone = [[UIFindInteraction alloc] initWithSessionDelegate:gone];
    gone = nil;
    report("delegate-weak-after-release", yes_no(lone.delegate == nil && weakGone == nil));

#ifndef CHARON_PORT_SIDE
    report_host("text-find-interaction-default", nil == text.findInteraction ? @"nil" : class_name(text.findInteraction));
    report_host("text-find-enabled-default", yes_no(text.findInteractionEnabled));
    text.findInteractionEnabled = YES;
    report_host("text-find-interaction-after-enable", text.findInteraction ? class_name(text.findInteraction) : @"nil");
    UIFindInteraction *own = text.findInteraction;
    report_host("text-find-view-is-text", yes_no(own.view == text));
    report_host("text-find-delegate-class", own.delegate ? class_name(own.delegate) : @"nil");
    report_host("text-interactions-hold-find", yes_no([text.interactions containsObject:own]));
    [own presentFindNavigatorShowingReplace:YES];
    report_host("text-own-navigator-visible", yes_no(own.findNavigatorVisible));
    report_host("text-own-active-class", own.activeFindSession ? class_name(own.activeFindSession) : @"nil");
    report_host("text-own-supports-replacement", yes_no(own.activeFindSession.supportsReplacement));
    [own dismissFindNavigator];
    text.findInteractionEnabled = NO;
    report_host("text-find-interaction-after-disable", text.findInteraction ? class_name(text.findInteraction) : @"nil");
#endif
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    const char *path = getenv("CHARON_SCENE_OUT");
    out = fopen(path ? path : "/dev/stdout", "w");
#ifdef CHARON_PORT_SIDE
    side = "port";
#else
    side = "host";
    const char *extra = getenv("CHARON_HOST_ONLY_OUT");
    hostOnly = extra ? fopen(extra, "w") : NULL;
#endif
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    UIViewController *root = [[UIViewController alloc] init];
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 300, 300)];
    UITextView *text = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 300, 100)];
    [root.view addSubview:view];
    [root.view addSubview:text];
    self.window.rootViewController = root;
    [self.window makeKeyAndVisible];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.window layoutIfNeeded];
        checks(view, text);
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        fclose(out);
        if (hostOnly)
            fclose(hostOnly);
        exit(0);
    });
}

@end

int main(int argc, char *argv[])
{
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([CharonSceneDelegate class]));
    }
}

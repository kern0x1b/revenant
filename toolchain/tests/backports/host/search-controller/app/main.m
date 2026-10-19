#import <UIKit/UIKit.h>
#include <stdio.h>

static FILE *out;

static void report(const char *side, const char *check, NSString *value)
{
    fprintf(out, "%s\t%s\t%s\n", side, check, value ? [value UTF8String] : "nil");
}

static NSString *yes_no(BOOL answer)
{
    return answer ? @"yes" : @"no";
}

static NSString *number(long long value)
{
    return [NSString stringWithFormat:@"%lld", value];
}

static NSString *count_text(NSArray *items)
{
    return items ? [NSString stringWithFormat:@"%lu", (unsigned long)items.count] : @"nil";
}

static NSMutableArray *given_suggestions(void)
{
    return [NSMutableArray arrayWithObject:[UISearchSuggestionItem suggestionWithLocalizedSuggestion:@"first"]];
}

static void suggestion_checks(const char *side, const char *prefix, UISearchController *controller)
{
    NSMutableArray *given = given_suggestions();
    char name[96];
    snprintf(name, sizeof name, "%s-set-count", prefix);
    controller.searchSuggestions = given;
    report(side, name, count_text(controller.searchSuggestions));
    snprintf(name, sizeof name, "%s-same-array", prefix);
    report(side, name, yes_no(controller.searchSuggestions == given));
    [given removeAllObjects];
    snprintf(name, sizeof name, "%s-after-change", prefix);
    report(side, name, count_text(controller.searchSuggestions));
    snprintf(name, sizeof name, "%s-first", prefix);
    report(side, name, [[controller.searchSuggestions.firstObject localizedSuggestion] description]);
    controller.searchSuggestions = nil;
    snprintf(name, sizeof name, "%s-cleared", prefix);
    report(side, name, count_text(controller.searchSuggestions));
}

static void checks(const char *side, UISearchController *controller, UINavigationController *navigation, UIViewController *root)
{
    report(side, "idiom", [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad ? @"pad" : @"other");
    report(side, "responds-suggestions", yes_no([controller respondsToSelector:@selector(searchSuggestions)]));

    report(side, "bare-placement", number(controller.searchBarPlacement));
    report(side, "scope-activation-default", number(controller.scopeBarActivation));
    report(side, "automatic-default", yes_no(controller.automaticallyShowsScopeBar));
    report(side, "ignores-default", yes_no(controller.ignoresSearchSuggestionsForSearchBarPlacementStacked));
    report(side, "bare-suggestions-default", count_text(controller.searchSuggestions));
    suggestion_checks(side, "bare-suggestions", controller);

    controller.automaticallyShowsScopeBar = NO;
    report(side, "automatic-set-no", yes_no(controller.automaticallyShowsScopeBar));
    report(side, "scope-activation-after-no", number(controller.scopeBarActivation));
    controller.automaticallyShowsScopeBar = YES;
    report(side, "scope-activation-after-yes", number(controller.scopeBarActivation));
    controller.scopeBarActivation = UISearchControllerScopeBarActivationOnTextEntry;
    report(side, "scope-activation-set", number(controller.scopeBarActivation));
    report(side, "automatic-after-on-text-entry", yes_no(controller.automaticallyShowsScopeBar));
    controller.automaticallyShowsScopeBar = NO;
    report(side, "scope-activation-after-no-from-on-text-entry", number(controller.scopeBarActivation));
    controller.scopeBarActivation = UISearchControllerScopeBarActivationAutomatic;
    report(side, "automatic-after-automatic", yes_no(controller.automaticallyShowsScopeBar));

    controller.ignoresSearchSuggestionsForSearchBarPlacementStacked = YES;
    report(side, "ignores-set", yes_no(controller.ignoresSearchSuggestionsForSearchBarPlacementStacked));
    controller.ignoresSearchSuggestionsForSearchBarPlacementStacked = NO;
    report(side, "ignores-cleared", yes_no(controller.ignoresSearchSuggestionsForSearchBarPlacementStacked));

    report(side, "item-preference-default", number(root.navigationItem.preferredSearchBarPlacement));
    root.navigationItem.searchController = controller;
    report(side, "item-placement-automatic", number(controller.searchBarPlacement));
    root.navigationItem.preferredSearchBarPlacement = UINavigationItemSearchBarPlacementStacked;
    report(side, "item-placement-stacked", number(controller.searchBarPlacement));
    suggestion_checks(side, "stacked-suggestions", controller);
    root.navigationItem.preferredSearchBarPlacement = UINavigationItemSearchBarPlacementInline;
    report(side, "item-placement-inline", number(controller.searchBarPlacement));
    suggestion_checks(side, "inline-suggestions", controller);
    root.navigationItem.preferredSearchBarPlacement = UINavigationItemSearchBarPlacementAutomatic;
    root.navigationItem.searchController = nil;
    report(side, "item-placement-let-go", number(controller.searchBarPlacement));
    report(side, "navigation-class", NSStringFromClass([navigation class]));
}

@interface RevenantAppDelegate : UIResponder <UIApplicationDelegate>
@end

@implementation RevenantAppDelegate

- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options
{
    return [[UISceneConfiguration alloc] initWithName:@"Default" sessionRole:session.role];
}

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
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
#ifdef REVENANT_PORT_SIDE
    checks("port", [[UISearchController alloc] initWithSearchResultsController:nil], navigation, root);
#else
    checks("host", [[UISearchController alloc] initWithSearchResultsController:nil], navigation, root);
#endif
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

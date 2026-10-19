#import "views13_scenario.h"

void charon_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        struct {
            const char *cls;
            const char *selector;
        } probes[] = {{"UIView", "transform3D"}, {"UIView", "overrideUserInterfaceStyle"}, {"UIView", "focusGroupIdentifier"}, {"UIViewController", "isModalInPresentation"}, {"UISwitch", "preferredStyle"},
                      {"UIPageControl", "indicatorImageForPage:"}, {"UILabel", "lineBreakStrategy"}, {"NSLayoutManager", "usesDefaultHyphenation"}, {"UIDatePicker", "preferredDatePickerStyle"}, {"NSObject", "accessibilityUserInputLabels"},
                      {"UIAccessibilityCustomAction", "actionHandler"}, {"UIScreen", "calibratedLatency"}, {"UISegmentedControl", "selectedSegmentTintColor"}, {"UIResponder", "validateCommand:"}};
        Dl_info self_info;
        memset(&self_info, 0, sizeof(self_info));
        dladdr((void *)&charon_windowed_run, &self_info);
        const char *path = self_info.dli_fname;
        charon_check(path != NULL, "this executable's own image has a path", @"dladdr answered none");
        NSMutableArray *others = [NSMutableArray array];
        for (size_t index = 0; index < sizeof(probes) / sizeof(probes[0]); index++) {
            const char *name = probes[index].selector;
            char prefixed[128];
            snprintf(prefixed, sizeof(prefixed), "charonHost%c%s", name[0] - 32, name + 1);
            Class owner = objc_getClass(probes[index].cls);
            IMP carried = class_getMethodImplementation(owner, sel_registerName(prefixed));
            IMP bare = class_getMethodImplementation(owner, sel_registerName(name));
            Dl_info inside, outside;
            memset(&inside, 0, sizeof(inside));
            memset(&outside, 0, sizeof(outside));
            BOOL ours = path && dladdr((void *)carried, &inside) && inside.dli_fname && !strcmp(inside.dli_fname, path);
            BOOL still_system = path && dladdr((void *)bare, &outside) && outside.dli_fname && !!strcmp(outside.dli_fname, path);
            if (!ours || !still_system)
                [others addObject:[NSString stringWithFormat:@"%s %s (%s%s)", probes[index].cls, name,
                                    ours ? "prefixed " : "prefixed not the app's: ", still_system ? "bare is the system's" : "bare is the app's"]];
        }
        charon_check(others.count == 0, "the port's members are the ones the classes answer with, and it no longer takes the system's names",
                     [others componentsJoinedByString:@", "]);
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("CHARON_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
        ur_agree(@"view, controller, control and accessibility members", views_scenario(), [expected componentsSeparatedByString:@"\n"]);
    }
}

#import "focus_scenario.h"
#import <dlfcn.h>

void revenant_windowed_run(UIWindow *window)
{
    @autoreleasepool {
        Dl_info self_info;
        memset(&self_info, 0, sizeof(self_info));
        dladdr((void *)&revenant_windowed_run, &self_info);
        const char *path = self_info.dli_fname;
        Class classes[] = {[UICollectionView class], [UITableView class]};
        NSMutableArray *others = [NSMutableArray array];
        for (size_t index = 0; index < 2; index++) {
            IMP carried = class_getMethodImplementation(classes[index], sel_registerName("revenantHostSelectionFollowsFocus"));
            Dl_info inside;
            memset(&inside, 0, sizeof(inside));
            BOOL ours = path && dladdr((void *)carried, &inside) && inside.dli_fname && !strcmp(inside.dli_fname, path);
            if (!ours)
                [others addObject:NSStringFromClass(classes[index])];
        }
        revenant_check(others.count == 0, "the port's selectionFollowsFocus is the app's own implementation on both list views",
                     [others componentsJoinedByString:@", "]);
        NSString *expected = [NSString stringWithContentsOfFile:[NSString stringWithUTF8String:getenv("REVENANT_EXPECTED")] encoding:NSUTF8StringEncoding error:NULL];
        ur_agree(@"selection follows focus on the list views", focus_scenario(), [expected componentsSeparatedByString:@"\n"]);
    }
}

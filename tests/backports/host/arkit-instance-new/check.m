// check.m - the instance -new of the three raycast classes, measured on the Catalyst copy of ARKit.
//
// The SDK declares `- (instancetype)new NS_UNAVAILABLE;` on each class (run.sh reads the headers). On the host the
// class defines no such method of its own, respondsToSelector: answers NO, and a call raises the unrecognised-selector
// exception that NSObject raises for any selector it does not answer. The port defines no -new either, so its answer
// is the same: the test prints the three answers, and run.sh compares them with the expected lines.
#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>
#import <objc/runtime.h>

static void probe(NSString *name)
{
    Class c = NSClassFromString(name);
    SEL sel = @selector(new);
    unsigned int n = 0;
    Method *list = class_copyMethodList(c, &n);
    BOOL own = NO;
    for (unsigned int i = 0; i < n; i++)
        if (method_getName(list[i]) == sel) own = YES;
    free(list);
    printf("%s instance-new own=%s\n", [name UTF8String], own ? "YES" : "NO");
    id obj = [c alloc];
    printf("  respondsToSelector:new = %s\n", [obj respondsToSelector:sel] ? "YES" : "NO");
    @try {
        (void)[obj performSelector:sel];
        printf("  call answered\n");
    } @catch (NSException *e) {
        printf("  call raised %s\n", [[e name] UTF8String]);
    }
}

int main(void)
{
    @autoreleasepool {
        probe(@"ARRaycastQuery");
        probe(@"ARRaycastResult");
        probe(@"ARTrackedRaycast");
    }
    return 0;
}

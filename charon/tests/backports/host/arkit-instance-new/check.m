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

#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>
#import <SensorKit/SensorKit.h>
#import <objc/runtime.h>

static int failures = 0;
static int checks = 0;

static void check(BOOL ok, NSString *line)
{
    checks++;
    if (ok) printf("  ok   %s\n", line.UTF8String);
    else { printf("  FAIL %s\n", line.UTF8String); failures++; }
}

@interface CharonInitOverrider : NSObject
@end

@implementation CharonInitOverrider
- (instancetype)init { return [super init]; }
@end

static BOOL definesOwn(Class c, SEL sel, BOOL classMethod)
{
    Class where = classMethod ? object_getClass(c) : c;
    unsigned n = 0;
    Method *list = class_copyMethodList(where, &n);
    BOOL found = NO;
    for (unsigned i = 0; i < n; i++)
        if (sel_isEqual(method_getName(list[i]), sel)) found = YES;
    free(list);
    return found;
}

static IMP impOf(Class c, SEL sel, BOOL classMethod)
{
    Method m = classMethod ? class_getClassMethod(c, sel) : class_getInstanceMethod(c, sel);
    return m ? method_getImplementation(m) : NULL;
}

typedef struct { const char *cls; int isClassMethod; const char *sel; } Row;

static const Row rows[] = {
#include "rows.inc"
};

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    @autoreleasepool {
        printf("controls\n");
        Class over = [CharonInitOverrider class];
        check(impOf(over, @selector(init), NO) != impOf(class_getSuperclass(over), @selector(init), NO)
              && definesOwn(over, @selector(init), NO),
              @"an overriding class has its own IMP, which differs from the superclass's");
        check(NSClassFromString(@"ZZZNoSuchNameCharonR16") == nil, @"a name no framework has is not a class");

        printf("the rows, on the host\n");
        for (size_t i = 0; i < sizeof rows / sizeof rows[0]; i++) {
            const Row *r = &rows[i];
            BOOL cm = r->isClassMethod != 0;
            NSString *cls = [NSString stringWithUTF8String:r->cls];
            NSString *sel = [NSString stringWithUTF8String:r->sel];
            NSString *label = [NSString stringWithFormat:@"%@[%@ %@]", cm ? @"+" : @"-", cls, sel];
            Class c = NSClassFromString(cls);
            if (!c) { check(NO, [label stringByAppendingString:@": the class is there"]); continue; }
            Class s = class_getSuperclass(c);
            SEL selector = NSSelectorFromString(sel);
            IMP own = impOf(c, selector, cm), up = impOf(s, selector, cm);
            check(own != NULL, [label stringByAppendingString:@": the selector is answered"]);
            check(own == up, [label stringByAppendingFormat:@": is the IMP of %s", class_getName(s)]);
            check(!definesOwn(c, selector, cm), [label stringByAppendingString:@": not defined by the class itself"]);
        }
        printf("%d checks\n", checks);
    }
    printf("%s\n", failures == 0 ? "VERDICT ok" : "VERDICT FAIL");
    return failures == 0 ? 0 : 1;
}

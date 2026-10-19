#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *shown(Class c)
{
    NSString *name = [NSString stringWithUTF8String:class_getName(c)];
    return [name hasPrefix:@"CharonHost"] ? [name substringFromIndex:10] : name;
}

static const char *kBase[] = { "previouslyFocusedView", "nextFocusedView", "previouslyFocusedItem", "nextFocusedItem", "focusHeading" };
static const char *kIndex[] = { "previouslyFocusedIndexPath", "nextFocusedIndexPath" };
static const char *kSub[] = { "previouslyFocusedView", "nextFocusedView", "previouslyFocusedItem", "nextFocusedItem", "focusHeading", "previouslyFocusedIndexPath", "nextFocusedIndexPath" };

static void answers(Class c, id o, const char *prop)
{
    id v = [o valueForKey:[NSString stringWithUTF8String:prop]];
    printf("%s alloc %s = %s\n", shown(c).UTF8String, prop, [[NSString stringWithFormat:@"%@", v] UTF8String]);
}

static void responds(Class c, const char *prop)
{
    printf("%s responds %s %d\n", shown(c).UTF8String, prop, [c instancesRespondToSelector:sel_registerName(prop)]);
}

static void type_of(Class c, const char *prop)
{
    objc_property_t p = class_getProperty(c, prop);
    if (!p) {
        printf("%s type %s absent\n", shown(c).UTF8String, prop);
        return;
    }
    char *t = property_copyAttributeValue(p, "T");
    char *r = property_copyAttributeValue(p, "R");
    printf("%s type %s = %s %s\n", shown(c).UTF8String, prop, t, r ? "readonly" : "readwrite");
    free(t);
    free(r);
}

static void failure(Class c, const char *label, NSException *e)
{
    NSString *keys = e.userInfo ? [[e.userInfo allKeys] componentsJoinedByString:@","] : @"none";
    printf("%s %s raised name=%s reason=%s userinfo-keys=%s\n", shown(c).UTF8String, label, e.name.UTF8String,
           e.reason.UTF8String, keys.UTF8String);
}

static void check(Class c, const char **props, int n)
{
    printf("%s exists %d super %s\n", shown(c).UTF8String, c != nil, shown(class_getSuperclass(c)).UTF8String);
    for (int i = 0; i < n; i++)
        responds(c, props[i]);

    @try {
        id o = [[c alloc] init];
        printf("%s init returned %d\n", shown(c).UTF8String, o != nil);
    } @catch (NSException *e) {
        failure(c, "init", e);
    }
    @try {
        id o = [c new];
        printf("%s new returned %d\n", shown(c).UTF8String, o != nil);
    } @catch (NSException *e) {
        failure(c, "new", e);
    }

    id o = [c alloc];
    printf("%s alloc returned %d\n", shown(c).UTF8String, o != nil);
    for (int i = 0; i < n; i++)
        answers(c, o, props[i]);
}

int main(void)
{
    @autoreleasepool {
        check([UIFocusUpdateContext class], kBase, 5);
        check([UICollectionViewFocusUpdateContext class], kSub, 7);
        check([UITableViewFocusUpdateContext class], kSub, 7);
        for (int i = 0; i < 2; i++) {
            type_of([UICollectionViewFocusUpdateContext class], kIndex[i]);
            type_of([UITableViewFocusUpdateContext class], kIndex[i]);
        }
    }
    return 0;
}

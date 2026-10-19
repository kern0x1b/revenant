#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static BOOL charon_is_keyboard_notification(NSString *name)
{
    return [name hasPrefix:@"UIKeyboard"] && ([name hasSuffix:@"ShowNotification"] || [name hasSuffix:@"HideNotification"] || [name hasSuffix:@"FrameNotification"]);
}

static NSDictionary *charon_local_info(NSDictionary *info)
{
    if (!info || info[UIKeyboardIsLocalUserInfoKey])
        return info;
    NSMutableDictionary *merged = [info mutableCopy];
    merged[UIKeyboardIsLocalUserInfoKey] = @YES;
    return merged;
}

@interface CharonKeyboardLocalInstaller : NSObject
@end

@implementation CharonKeyboardLocalInstaller

+ (void)load
{
    Class center = [NSNotificationCenter class];
    SEL named = @selector(postNotificationName:object:userInfo:);
    Method namedMethod = class_getInstanceMethod(center, named);
    void (*namedOriginal)(id, SEL, NSString *, id, NSDictionary *) = (void (*)(id, SEL, NSString *, id, NSDictionary *))method_getImplementation(namedMethod);
    class_replaceMethod(center, named, imp_implementationWithBlock(^(NSNotificationCenter *self, NSString *name, id object, NSDictionary *info) {
        namedOriginal(self, named, name, object, charon_is_keyboard_notification(name) ? charon_local_info(info) : info);
    }), method_getTypeEncoding(namedMethod));

    SEL whole = @selector(postNotification:);
    Method wholeMethod = class_getInstanceMethod(center, whole);
    void (*wholeOriginal)(id, SEL, NSNotification *) = (void (*)(id, SEL, NSNotification *))method_getImplementation(wholeMethod);
    class_replaceMethod(center, whole, imp_implementationWithBlock(^(NSNotificationCenter *self, NSNotification *notification) {
        NSString *name = notification.name;
        if (charon_is_keyboard_notification(name) && notification.userInfo && !notification.userInfo[UIKeyboardIsLocalUserInfoKey])
            notification = [NSNotification notificationWithName:name object:notification.object userInfo:charon_local_info(notification.userInfo)];
        wholeOriginal(self, whole, notification);
    }), method_getTypeEncoding(wholeMethod));
}

@end

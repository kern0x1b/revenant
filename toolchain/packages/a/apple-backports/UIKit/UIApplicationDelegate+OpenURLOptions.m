#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wdeprecated-declarations"

NSString *const UIApplicationOpenURLOptionsAnnotationKey = @"UIApplicationOpenURLOptionsAnnotationKey";

static NSDictionary *charon_open_options(NSString *source, id annotation)
{
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    if (source)
        options[UIApplicationOpenURLOptionsSourceApplicationKey] = source;
    if (annotation)
        options[UIApplicationOpenURLOptionsAnnotationKey] = annotation;
    options[UIApplicationOpenURLOptionsOpenInPlaceKey] = @NO;
    return options;
}

static void charon_bridge_open_url(id delegate)
{
    Class cls = object_getClass(delegate);
    SEL old = @selector(application:openURL:sourceApplication:annotation:);
    SEL current = @selector(application:openURL:options:);
    if (!delegate || class_getInstanceMethod(cls, old) || !class_getInstanceMethod(cls, current))
        return;
    class_addMethod(cls, old, imp_implementationWithBlock(^BOOL(id self, UIApplication *application, NSURL *url, NSString *source, id annotation) {
        return ((BOOL (*)(id, SEL, UIApplication *, NSURL *, NSDictionary *))objc_msgSend)(self, current, application, url, charon_open_options(source, annotation));
    }), "c@:@@@@");
}

@interface CharonOpenURLBridgeInstaller : NSObject
@end

@implementation CharonOpenURLBridgeInstaller

+ (void)load
{
    Method method = class_getInstanceMethod([UIApplication class], @selector(setDelegate:));
    void (*original)(id, SEL, id) = (void (*)(id, SEL, id))method_getImplementation(method);
    class_replaceMethod([UIApplication class], @selector(setDelegate:), imp_implementationWithBlock(^(UIApplication *application, id delegate) {
        charon_bridge_open_url(delegate);
        original(application, @selector(setDelegate:), delegate);
    }), method_getTypeEncoding(method));
}

@end

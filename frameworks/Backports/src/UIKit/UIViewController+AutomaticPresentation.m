#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "../RevenantProgramSDK.h"

@interface UIViewController (RevenantAutomaticPresentation)
- (UIModalPresentationStyle)revenant_preferredModalPresentationStyle;
@end

@implementation UIViewController (RevenantAutomaticPresentation)
- (UIModalPresentationStyle)revenant_preferredModalPresentationStyle
{
    return UIModalPresentationAutomatic;
}
@end

@implementation UIImagePickerController (RevenantAutomaticPresentation)
- (UIModalPresentationStyle)revenant_preferredModalPresentationStyle
{
    return self.sourceType == UIImagePickerControllerSourceTypeCamera ? UIModalPresentationFullScreen : [super revenant_preferredModalPresentationStyle];
}
@end

@implementation UISplitViewController (RevenantAutomaticPresentation)
- (UIModalPresentationStyle)revenant_preferredModalPresentationStyle
{
    return UIModalPresentationCustom;
}
@end

static UIModalPresentationStyle revenant_automatic_style(UIViewController *controller)
{
    UIModalPresentationStyle preferred = [controller revenant_preferredModalPresentationStyle];
    return preferred == UIModalPresentationAutomatic ? UIModalPresentationPageSheet : preferred;
}

@interface RevenantAutomaticPresentationInstaller : NSObject
@end

@implementation RevenantAutomaticPresentationInstaller

+ (void)load
{
    if ([UIViewController instancesRespondToSelector:@selector(isModalInPresentation)] || revenant_program_sdk() < 0x000d0000)
        return;
    Class controller = [UIViewController class];
    SEL setter = @selector(setModalPresentationStyle:);
    void (*store)(id, SEL, UIModalPresentationStyle) = (void (*)(id, SEL, UIModalPresentationStyle))class_getMethodImplementation(controller, setter);

    SEL getter = @selector(modalPresentationStyle);
    UIModalPresentationStyle (*stored)(id, SEL) = (UIModalPresentationStyle (*)(id, SEL))class_getMethodImplementation(controller, getter);
    class_replaceMethod(controller, getter, imp_implementationWithBlock(^UIModalPresentationStyle (UIViewController *self_) {
        UIModalPresentationStyle style = stored(self_, getter);
        return style == UIModalPresentationAutomatic ? revenant_automatic_style(self_) : style;
    }), method_getTypeEncoding(class_getInstanceMethod(controller, getter)));

    SEL nib = @selector(initWithNibName:bundle:);
    id (*nibOriginal)(id, SEL, NSString *, NSBundle *) = (id (*)(id, SEL, NSString *, NSBundle *))class_getMethodImplementation(controller, nib);
    class_replaceMethod(controller, nib, imp_implementationWithBlock(^id (UIViewController *self_, NSString *name, NSBundle *bundle) {
        UIViewController *made = nibOriginal(self_, nib, name, bundle);
        if (made)
            store(made, setter, UIModalPresentationAutomatic);
        return made;
    }), method_getTypeEncoding(class_getInstanceMethod(controller, nib)));

    SEL coded = @selector(initWithCoder:);
    id (*codedOriginal)(id, SEL, NSCoder *) = (id (*)(id, SEL, NSCoder *))class_getMethodImplementation(controller, coded);
    class_replaceMethod(controller, coded, imp_implementationWithBlock(^id (UIViewController *self_, NSCoder *coder) {
        UIViewController *made = codedOriginal(self_, coded, coder);
        if (made && ![coder containsValueForKey:@"UIModalPresentationStyle"])
            store(made, setter, UIModalPresentationAutomatic);
        return made;
    }), method_getTypeEncoding(class_getInstanceMethod(controller, coded)));
}

@end

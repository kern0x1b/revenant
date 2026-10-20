#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char revenant_natural_key;

static NSTextAlignment revenant_natural_for(id view, BOOL byText)
{
    NSLocaleLanguageDirection direction = NSLocaleLanguageDirectionLeftToRight;
    NSString *text = byText ? [view text] : nil;
    if (text.length) {
        CFStringRef language = CFStringTokenizerCopyBestStringLanguage((__bridge CFStringRef)text, CFRangeMake(0, (CFIndex)MIN(text.length, (NSUInteger)256)));
        if (language) {
            direction = [NSLocale characterDirectionForLanguage:(__bridge NSString *)language];
            CFRelease(language);
        } else if ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) {
            direction = NSLocaleLanguageDirectionRightToLeft;
        }
    } else if ([UIApplication sharedApplication].userInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) {
        direction = NSLocaleLanguageDirectionRightToLeft;
    }
    return direction == NSLocaleLanguageDirectionRightToLeft ? NSTextAlignmentRight : NSTextAlignmentLeft;
}

static void revenant_hook_alignment(Class cls, BOOL byText)
{
    SEL setter = @selector(setTextAlignment:);
    Method setterMethod = class_getInstanceMethod(cls, setter);
    void (*setterOriginal)(id, SEL, NSTextAlignment) = (void (*)(id, SEL, NSTextAlignment))method_getImplementation(setterMethod);
    class_replaceMethod(cls, setter, imp_implementationWithBlock(^(id self, NSTextAlignment alignment) {
        if (alignment == NSTextAlignmentNatural) {
            objc_setAssociatedObject(self, &revenant_natural_key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            setterOriginal(self, setter, revenant_natural_for(self, byText));
        } else {
            objc_setAssociatedObject(self, &revenant_natural_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            setterOriginal(self, setter, alignment);
        }
    }), method_getTypeEncoding(setterMethod));
    SEL getter = @selector(textAlignment);
    Method getterMethod = class_getInstanceMethod(cls, getter);
    NSTextAlignment (*getterOriginal)(id, SEL) = (NSTextAlignment (*)(id, SEL))method_getImplementation(getterMethod);
    class_replaceMethod(cls, getter, imp_implementationWithBlock(^NSTextAlignment(id self) {
        return objc_getAssociatedObject(self, &revenant_natural_key) ? NSTextAlignmentNatural : getterOriginal(self, getter);
    }), method_getTypeEncoding(getterMethod));
    if (!byText)
        return;
    SEL text = @selector(setText:);
    Method textMethod = class_getInstanceMethod(cls, text);
    void (*textOriginal)(id, SEL, NSString *) = (void (*)(id, SEL, NSString *))method_getImplementation(textMethod);
    class_replaceMethod(cls, text, imp_implementationWithBlock(^(id self, NSString *string) {
        textOriginal(self, text, string);
        if (objc_getAssociatedObject(self, &revenant_natural_key))
            setterOriginal(self, setter, revenant_natural_for(self, YES));
    }), method_getTypeEncoding(textMethod));
}

@interface RevenantNaturalAlignmentInstaller : NSObject
@end

@implementation RevenantNaturalAlignmentInstaller

+ (void)load
{
    revenant_hook_alignment([UILabel class], NO);
    revenant_hook_alignment([UITextField class], YES);
    revenant_hook_alignment([UITextView class], YES);
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    for (NSString *name in @[UITextFieldTextDidChangeNotification, UITextViewTextDidChangeNotification]) {
        [center addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note) {
            id view = note.object;
            if (view && objc_getAssociatedObject(view, &revenant_natural_key)) {
                NSTextAlignment resolved = revenant_natural_for(view, YES);
                objc_setAssociatedObject(view, &revenant_natural_key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [view setTextAlignment:resolved];
                objc_setAssociatedObject(view, &revenant_natural_key, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }];
    }
}

@end

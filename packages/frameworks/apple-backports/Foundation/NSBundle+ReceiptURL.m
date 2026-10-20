#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSURL *revenant_receipt(NSBundle *bundle)
{
    return [bundle.bundleURL URLByAppendingPathComponent:@"StoreKit/receipt"];
}

@interface RevenantReceiptInstaller : NSObject
@end

@implementation RevenantReceiptInstaller

+ (void)load
{
    SEL selector = @selector(appStoreReceiptURL);
    IMP replacement = imp_implementationWithBlock(^NSURL *(NSBundle *self_) {
        return revenant_receipt(self_);
    });
    Method method = class_getInstanceMethod([NSBundle class], selector);
    if (method)
        method_setImplementation(method, replacement);
    else
        class_addMethod([NSBundle class], selector, replacement, "@@:");
}

@end

@implementation NSBundle (RevenantReceiptURL)

- (NSURL *)appStoreReceiptURL
{
    return revenant_receipt(self);
}

@end

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSURL *charon_receipt(NSBundle *bundle)
{
    return [bundle.bundleURL URLByAppendingPathComponent:@"StoreKit/receipt"];
}

@interface CharonReceiptInstaller : NSObject
@end

@implementation CharonReceiptInstaller

+ (void)load
{
    SEL selector = @selector(appStoreReceiptURL);
    IMP replacement = imp_implementationWithBlock(^NSURL *(NSBundle *self_) {
        return charon_receipt(self_);
    });
    Method method = class_getInstanceMethod([NSBundle class], selector);
    if (method)
        method_setImplementation(method, replacement);
    else
        class_addMethod([NSBundle class], selector, replacement, "@@:");
}

@end

@implementation NSBundle (CharonReceiptURL)

- (NSURL *)appStoreReceiptURL
{
    return charon_receipt(self);
}

@end

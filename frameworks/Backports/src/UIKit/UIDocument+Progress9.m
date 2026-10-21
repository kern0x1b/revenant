#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantDocumentProgressKey;

static void revenant_document_changed(UIDocument *document)
{
    [[NSNotificationCenter defaultCenter] postNotificationName:UIDocumentStateChangedNotification object:document];
}

static void (^revenant_document_tracking(UIDocument *document, void (^completion)(BOOL)))(BOOL)
{
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    objc_setAssociatedObject(document, &RevenantDocumentProgressKey, progress, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    revenant_document_changed(document);
    return ^(BOOL success) {
        progress.completedUnitCount = 1;
        if (objc_getAssociatedObject(document, &RevenantDocumentProgressKey) == progress)
            objc_setAssociatedObject(document, &RevenantDocumentProgressKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        if (completion)
            completion(success);
        revenant_document_changed(document);
    };
}

@interface RevenantDocumentProgress9 : NSObject
@end

@implementation RevenantDocumentProgress9

+ (void)load
{
    if ([UIDocument instancesRespondToSelector:@selector(progress)])
        return;
    Class document = [UIDocument class];
    SEL open = @selector(openWithCompletionHandler:);
    Method openMethod = class_getInstanceMethod(document, open);
    if (openMethod) {
        void (*original)(id, SEL, void (^)(BOOL)) = (void (*)(id, SEL, void (^)(BOOL)))method_getImplementation(openMethod);
        method_setImplementation(openMethod, imp_implementationWithBlock(^(UIDocument *self_, void (^completion)(BOOL)) {
            original(self_, open, revenant_document_tracking(self_, completion));
        }));
    }
    SEL save = @selector(saveToURL:forSaveOperation:completionHandler:);
    Method saveMethod = class_getInstanceMethod(document, save);
    if (saveMethod) {
        void (*original)(id, SEL, NSURL *, UIDocumentSaveOperation, void (^)(BOOL)) = (void (*)(id, SEL, NSURL *, UIDocumentSaveOperation, void (^)(BOOL)))method_getImplementation(saveMethod);
        method_setImplementation(saveMethod, imp_implementationWithBlock(^(UIDocument *self_, NSURL *url, UIDocumentSaveOperation operation, void (^completion)(BOOL)) {
            original(self_, save, url, operation, revenant_document_tracking(self_, completion));
        }));
    }
    SEL state = @selector(documentState);
    Method stateMethod = class_getInstanceMethod(document, state);
    if (stateMethod) {
        UIDocumentState (*original)(id, SEL) = (UIDocumentState (*)(id, SEL))method_getImplementation(stateMethod);
        method_setImplementation(stateMethod, imp_implementationWithBlock(^UIDocumentState(UIDocument *self_) {
            UIDocumentState value = original(self_, state);
            return objc_getAssociatedObject(self_, &RevenantDocumentProgressKey) ? (value | (1 << 4)) : value;
        }));
    }
}

@end

@implementation UIDocument (RevenantProgress9)

- (NSProgress *)progress
{
    return objc_getAssociatedObject(self, &RevenantDocumentProgressKey);
}

@end

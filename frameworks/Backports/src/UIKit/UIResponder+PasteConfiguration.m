#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "RevenantPasteMatching.h"

static const char revenant_paste_configuration_key;

@implementation UIResponder (RevenantPasteConfiguration)

- (UIPasteConfiguration *)pasteConfiguration
{
    return objc_getAssociatedObject(self, &revenant_paste_configuration_key);
}

- (void)setPasteConfiguration:(UIPasteConfiguration *)pasteConfiguration
{
    objc_setAssociatedObject(self, &revenant_paste_configuration_key, [pasteConfiguration copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)canPasteItemProviders:(NSArray<NSItemProvider *> *)itemProviders
{
    NSArray<NSString *> *typeIdentifiers = self.pasteConfiguration.acceptableTypeIdentifiers;
    return typeIdentifiers.count > 0 && revenant_paste_accepts(itemProviders, typeIdentifiers);
}

- (void)pasteItemProviders:(NSArray<NSItemProvider *> *)itemProviders
{
}

@end

#import "RevenantMenus.h"
#import <objc/runtime.h>

static const char revenant_paste_configuration_key;

@implementation UIResponder (RevenantPasteConfiguration)

- (UIPasteConfiguration *)pasteConfiguration
{
    return objc_getAssociatedObject(self, &revenant_paste_configuration_key);
}

- (void)setPasteConfiguration:(UIPasteConfiguration *)pasteConfiguration
{
    if (pasteConfiguration)
        revenant_menus_say_once(@"paste-configuration", @"UIResponder.pasteConfiguration is kept, and nothing on iOS 6 reads its acceptable types: UIPasteControl hands the pasteboard's item providers to the target, which decides with canPasteItemProviders:");
    objc_setAssociatedObject(self, &revenant_paste_configuration_key, [pasteConfiguration copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

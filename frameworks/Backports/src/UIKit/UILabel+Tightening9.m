#import "RevenantMenus.h"
#import <objc/runtime.h>

static const char RevenantLabelTighteningKey;

@implementation UILabel (RevenantTightening9)

- (BOOL)allowsDefaultTighteningForTruncation
{
    return [objc_getAssociatedObject(self, &RevenantLabelTighteningKey) boolValue];
}

- (void)setAllowsDefaultTighteningForTruncation:(BOOL)allowsDefaultTighteningForTruncation
{
    if (allowsDefaultTighteningForTruncation)
        revenant_menus_say_once(@"label-tightening", @"UILabel.allowsDefaultTighteningForTruncation: the iOS 6 label truncates without tightening the letter spacing, so YES is kept and read back and the text is drawn as before");
    objc_setAssociatedObject(self, &RevenantLabelTighteningKey, @(allowsDefaultTighteningForTruncation), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#import "RevenantBarPosition.h"
#import "RevenantWeak.h"

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static const char RevenantToolbarDelegateKey;

@implementation UIToolbar (RevenantBarPosition7)

- (id<UIToolbarDelegate>)delegate
{
    return revenant_weak_get(self, &RevenantToolbarDelegateKey);
}

- (void)setDelegate:(id<UIToolbarDelegate>)delegate
{
    revenant_weak_set(self, &RevenantToolbarDelegateKey, delegate);
}

- (UIBarPosition)barPosition
{
    return revenant_bar_position(self, UIBarPositionBottom);
}

@end

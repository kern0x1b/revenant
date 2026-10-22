#import <UIKit/UIKit.h>

@implementation UISearchController (RevenantScopeBar)

- (BOOL)automaticallyShowsScopeBar
{
    return self.scopeBarActivation != UISearchControllerScopeBarActivationManual;
}

- (void)setAutomaticallyShowsScopeBar:(BOOL)automaticallyShowsScopeBar
{
    self.scopeBarActivation = automaticallyShowsScopeBar ? UISearchControllerScopeBarActivationAutomatic : UISearchControllerScopeBarActivationManual;
}

@end

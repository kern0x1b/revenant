#import "RevenantMenus.h"

@implementation UISearchController (RevenantScopeBar)

- (BOOL)automaticallyShowsScopeBar
{
    return self.scopeBarActivation != UISearchControllerScopeBarActivationManual;
}

- (void)setAutomaticallyShowsScopeBar:(BOOL)automaticallyShowsScopeBar
{
    self.scopeBarActivation = automaticallyShowsScopeBar ? UISearchControllerScopeBarActivationAutomatic : UISearchControllerScopeBarActivationManual;
    revenant_menus_say_once(@"search-scope-bar", @"UISearchController.automaticallyShowsScopeBar: the scope bar is not shown by the controller on this release; the application shows the search bar's scope bar itself");
}

@end

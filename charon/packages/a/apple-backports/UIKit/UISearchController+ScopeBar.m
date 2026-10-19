#import "CharonMenus.h"

@implementation UISearchController (CharonScopeBar)

// The flag is the activation's Automatic (YES) and Manual (NO); OnTextEntry reads as YES. The activation is kept by the controller, where it
// starts Manual, as the release's does on an iPad (measured by tests/backports/host/search-controller).
- (BOOL)automaticallyShowsScopeBar
{
    return self.scopeBarActivation != UISearchControllerScopeBarActivationManual;
}

- (void)setAutomaticallyShowsScopeBar:(BOOL)automaticallyShowsScopeBar
{
    self.scopeBarActivation = automaticallyShowsScopeBar ? UISearchControllerScopeBarActivationAutomatic : UISearchControllerScopeBarActivationManual;
    charon_menus_say_once(@"search-scope-bar", @"UISearchController.automaticallyShowsScopeBar: the scope bar is not shown by the controller on this release; the application shows the search bar's scope bar itself");
}

@end

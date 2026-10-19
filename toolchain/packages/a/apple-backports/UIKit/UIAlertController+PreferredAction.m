#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char revenant_preferred_action_key;

@implementation UIAlertController (RevenantPreferredAction)

- (UIAlertAction *)preferredAction
{
    return objc_getAssociatedObject(self, &revenant_preferred_action_key);
}

- (void)setPreferredAction:(UIAlertAction *)preferredAction
{
    if (preferredAction && [self.actions indexOfObjectIdenticalTo:preferredAction] == NSNotFound)
        [NSException raise:NSInternalInconsistencyException format:@"The -preferredAction of an alert controller must be contained in the -actions array or be nil."];
    objc_setAssociatedObject(self, &revenant_preferred_action_key, preferredAction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static char charon_preferred_action_key;

@implementation UIAlertController (CharonPreferredAction)

- (UIAlertAction *)preferredAction
{
    return objc_getAssociatedObject(self, &charon_preferred_action_key);
}

- (void)setPreferredAction:(UIAlertAction *)preferredAction
{
    if (preferredAction && [self.actions indexOfObjectIdenticalTo:preferredAction] == NSNotFound)
        [NSException raise:NSInternalInconsistencyException format:@"The -preferredAction of an alert controller must be contained in the -actions array or be nil."];
    objc_setAssociatedObject(self, &charon_preferred_action_key, preferredAction, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

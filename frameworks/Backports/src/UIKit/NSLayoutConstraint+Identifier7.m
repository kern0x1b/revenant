#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static const char RevenantConstraintIdentifierKey;

@implementation NSLayoutConstraint (RevenantIdentifier7)

- (NSString *)identifier
{
    return objc_getAssociatedObject(self, &RevenantConstraintIdentifierKey);
}

- (void)setIdentifier:(NSString *)identifier
{
    objc_setAssociatedObject(self, &RevenantConstraintIdentifierKey, [identifier copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char RevenantTargetContentKey;

@implementation NSUserActivity (RevenantTargetContent)

- (NSString *)targetContentIdentifier
{
    return objc_getAssociatedObject(self, &RevenantTargetContentKey);
}

- (void)setTargetContentIdentifier:(NSString *)identifier
{
    objc_setAssociatedObject(self, &RevenantTargetContentKey, [identifier copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static char RevenantDayOfYearKey;

@implementation NSDateComponents (RevenantDayOfYear18)

- (NSInteger)dayOfYear
{
    NSNumber *value = objc_getAssociatedObject(self, &RevenantDayOfYearKey);
    return value ? value.integerValue : NSDateComponentUndefined;
}

- (void)setDayOfYear:(NSInteger)dayOfYear
{
    objc_setAssociatedObject(self, &RevenantDayOfYearKey, @(dayOfYear), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

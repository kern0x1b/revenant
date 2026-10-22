#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

static char RevenantRepeatedDayKey;

@implementation NSDateComponents (RevenantRepeatedDay26)

- (BOOL)isRepeatedDay
{
    return [objc_getAssociatedObject(self, &RevenantRepeatedDayKey) boolValue];
}

- (void)setRepeatedDay:(BOOL)repeatedDay
{
    objc_setAssociatedObject(self, &RevenantRepeatedDayKey, @(repeatedDay), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

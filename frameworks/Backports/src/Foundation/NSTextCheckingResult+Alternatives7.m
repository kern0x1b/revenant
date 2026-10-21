#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static char RevenantAlternativeStringsKey;

@implementation NSTextCheckingResult (RevenantAlternatives7)

+ (NSTextCheckingResult *)correctionCheckingResultWithRange:(NSRange)range replacementString:(NSString *)replacementString alternativeStrings:(NSArray<NSString *> *)alternativeStrings
{
    NSTextCheckingResult *result = [self correctionCheckingResultWithRange:range replacementString:replacementString];
    objc_setAssociatedObject(result, &RevenantAlternativeStringsKey, [alternativeStrings copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
    return result;
}

- (NSArray<NSString *> *)alternativeStrings
{
    return objc_getAssociatedObject(self, &RevenantAlternativeStringsKey);
}

@end
